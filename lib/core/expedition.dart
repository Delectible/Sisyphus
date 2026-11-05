import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'alerts.dart';
import 'session.dart';
import 'settings.dart';
import 'stats.dart';

/// The app's running session: starts it, ticks it once a second while the
/// app is open, saves it so it survives a restart, keeps the alerts in step
/// and writes the stats.
class Expedition extends ChangeNotifier {
  Expedition(this._prefs, this.settings, this.stats, {this.alerts}) {
    settings.addListener(_settingsChanged);
    final raw = _prefs.getString(_key);
    if (raw != null) {
      try {
        session = _wire(Session.fromJson(jsonDecode(raw) as Map<String, dynamic>));
        _catchUp();
      } catch (_) {
        _prefs.remove(_key);
      }
    }
  }

  static const _key = 'session';
  final SharedPreferences _prefs;
  final Settings settings;
  final Stats stats;
  final Alerts? alerts;

  /// Overridable clock (tests).
  DateTime Function() now = DateTime.now;

  Session? session;

  /// The last finished session, for the summit screen.
  SessionRecord? last;

  /// The latest thing that happened, and a counter so listeners see repeats.
  SessionEvent event = SessionEvent.none;
  int eventCount = 0;

  Timer? _tick;
  bool _foreground = true;

  bool get active => session != null && session!.finishedAt == null;

  void begin() {
    final s = Session(
      focusMinutes: settings.focus,
      restMinutes: settings.rest,
      climbs: settings.climbs,
      started: now(),
      speed: settings.speed,
      autoContinue: settings.autoContinue,
    );
    session = _wire(s);
    last = null;
    event = SessionEvent.ascentBegins;
    eventCount++;
    if (settings.alerts) unawaited(alerts?.ask().then((_) => _changed()));
    _changed();
  }

  void togglePause() {
    final s = session;
    if (s == null) return;
    if (s.paused) {
      s.resume(now());
    } else if (s.running) {
      s.pause(now());
    }
    _changed();
  }

  /// Starts the phase that's waiting (auto-continue off).
  void proceed() {
    final s = session;
    if (s == null || !s.waiting) return;
    s.resume(now());
    _changed();
  }

  void skip() {
    final s = session;
    if (s == null) return;
    _emit(s.skip(now()));
    _changed();
  }

  void shove() {
    final s = session;
    if (s == null) return;
    s.shoves++;
    stats.addShove();
    _save();
  }

  /// Leaves the climb. Returns the record when something was done.
  SessionRecord? abandon() {
    final s = session;
    if (s == null) return null;
    if (s.finished) {
      close();
      return last;
    }
    s.abandon(now());
    final r = _record(s);
    stats.addSession(r);
    session = null;
    _changed();
    return r;
  }

  /// The summit screen has been shown; forget the session.
  void close() {
    session = null;
    _changed();
  }

  /// App to foreground / background: ticks only while visible.
  void setForeground(bool on) {
    _foreground = on;
    if (on) _catchUp();
    _schedule();
  }

  void _settingsChanged() {
    final s = session;
    if (s == null || s.autoContinue == settings.autoContinue) return;
    s.autoContinue = settings.autoContinue;
    _changed();
  }

  void _catchUp() {
    final s = session;
    if (s == null) return;
    final ev = s.update(now());
    if (ev != SessionEvent.none) _emit(ev);
    if (s.finished && s.finishedAt != null && last == null) {
      last = _record(s);
      stats.addSession(last!);
    }
    _save();
    notifyListeners();
  }

  void _emit(SessionEvent ev) {
    if (ev == SessionEvent.none) return;
    event = ev;
    eventCount++;
    if (settings.vibrate) {
      unawaited(HapticFeedback.heavyImpact());
    }
    final s = session;
    if (ev == SessionEvent.summit && s != null && last == null) {
      last = _record(s);
      stats.addSession(last!);
    }
  }

  void _changed() {
    _save();
    unawaited(alerts?.schedule(settings.alerts ? session : null));
    _schedule();
    notifyListeners();
  }

  void _schedule() {
    final want = _foreground && session != null && session!.running;
    if (want && _tick == null) {
      _tick = Timer.periodic(const Duration(seconds: 1), (_) => _catchUp());
    } else if (!want) {
      _tick?.cancel();
      _tick = null;
    }
  }

  Session _wire(Session s) {
    s.onFocus = stats.addFocus;
    s.onAscent = stats.addAscent;
    return s;
  }

  SessionRecord _record(Session s) => SessionRecord(
    start: s.started,
    end: s.finishedAt ?? now(),
    focus: s.focused,
    climbsDone: s.ascentsDone,
    climbsPlanned: s.climbs,
    skips: s.skips,
    shoves: s.shoves,
    summited: s.summited,
  );

  void _save() {
    final s = session;
    if (s == null || s.finishedAt != null) {
      _prefs.remove(_key);
    } else {
      _prefs.setString(_key, jsonEncode(s.toJson()));
    }
  }

  @override
  void dispose() {
    settings.removeListener(_settingsChanged);
    _tick?.cancel();
    super.dispose();
  }
}
