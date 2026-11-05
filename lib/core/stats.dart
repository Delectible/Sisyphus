import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// One finished (or abandoned) session.
class SessionRecord {
  final DateTime start;
  final DateTime end;
  final Duration focus;
  final int climbsDone;
  final int climbsPlanned;
  final int skips;
  final int shoves;

  /// Reached the summit having focused at least half the planned time.
  final bool summited;

  const SessionRecord({
    required this.start,
    required this.end,
    required this.focus,
    required this.climbsDone,
    required this.climbsPlanned,
    required this.skips,
    required this.shoves,
    required this.summited,
    this.label,
  });

  final String? label;

  Map<String, Object> toJson() => {
    's': start.millisecondsSinceEpoch,
    'e': end.millisecondsSinceEpoch,
    'f': focus.inSeconds,
    'c': climbsDone,
    'p': climbsPlanned,
    'k': skips,
    'v': shoves,
    'u': summited,
    'l': ?label,
  };

  static SessionRecord fromJson(Map<String, dynamic> j) => SessionRecord(
    start: DateTime.fromMillisecondsSinceEpoch(j['s'] as int),
    end: DateTime.fromMillisecondsSinceEpoch(j['e'] as int),
    focus: Duration(seconds: j['f'] as int),
    climbsDone: j['c'] as int,
    climbsPlanned: j['p'] as int,
    skips: j['k'] as int,
    shoves: j['v'] as int,
    summited: j['u'] as bool,
    label: j['l'] as String?,
  );
}

/// Lifetime totals, plus focus minutes per day for the week chart and the
/// streaks. Saved as one JSON value.
class Stats extends ChangeNotifier {
  Stats(this._prefs) {
    final raw = _prefs.getString(_key);
    if (raw != null) {
      try {
        _load(jsonDecode(raw) as Map<String, dynamic>);
      } catch (_) {
        // A broken save starts over rather than crashing the app.
      }
    }
  }

  static const _key = 'stats';
  final SharedPreferences _prefs;

  int mountains = 0;
  int sessions = 0;
  int abandoned = 0;
  int ascents = 0;
  int shoves = 0;
  int slips = 0;
  int bestStreak = 0;
  int owlTaps = 0;
  int breaths = 0;
  int nightSummits = 0;
  int dawnSummits = 0;
  int cleanSummits = 0;
  int longRests = 0;
  Duration focus = Duration.zero;
  Duration longest = Duration.zero;
  DateTime? first;

  /// Focus seconds per local day ('2026-11-05'), the last ~400 days.
  final Map<String, int> daily = {};

  /// Per label: focus seconds and mountains.
  final Map<String, ({int focus, int mountains})> byLabel = {};

  /// Metres climbed: every minute of focus is twelve metres of mountain.
  int get metres => focus.inMinutes * 12;

  /// The last few sessions, newest first.
  final List<SessionRecord> recent = [];

  static String dayKey(DateTime t) =>
      '${t.year}-${t.month.toString().padLeft(2, '0')}-${t.day.toString().padLeft(2, '0')}';

  /// Days in a row (ending today, or yesterday if today has none yet) with
  /// at least a minute of focus.
  int streak([DateTime? now]) {
    final today = _day(now ?? DateTime.now());
    var d = today;
    if ((daily[dayKey(d)] ?? 0) < 60) d = d.subtract(const Duration(days: 1));
    var n = 0;
    while ((daily[dayKey(d)] ?? 0) >= 60) {
      n++;
      d = DateTime(d.year, d.month, d.day - 1);
    }
    return n;
  }

  /// The longest run of days in a row with at least a minute of focus.
  int longestRun() {
    final days = daily.entries.where((e) => e.value >= 60).map((e) => DateTime.parse(e.key)).toList()..sort();
    var best = 0, run = 0;
    DateTime? prev;
    for (final d in days) {
      run = prev != null && DateTime(prev.year, prev.month, prev.day + 1) == d ? run + 1 : 1;
      best = math.max(best, run);
      prev = d;
    }
    return best;
  }

  /// Focus per day for the 7 days ending today (oldest first).
  List<Duration> week([DateTime? now]) {
    final today = _day(now ?? DateTime.now());
    return [
      for (var i = 6; i >= 0; i--)
        Duration(seconds: daily[dayKey(DateTime(today.year, today.month, today.day - i))] ?? 0),
    ];
  }

  /// Focus time [d] spent at [at] (counted the moment it happens, so an
  /// abandoned climb still counts).
  void addFocus(Duration d, DateTime at) {
    if (d <= Duration.zero) return;
    focus += d;
    final k = dayKey(at);
    daily[k] = (daily[k] ?? 0) + d.inSeconds;
    bestStreak = math.max(bestStreak, longestRun());
    _save();
  }

  void addAscent() {
    ascents++;
    _save();
  }

  void addShove() {
    shoves++;
    _save();
  }

  void addSlip() {
    slips++;
    _save();
  }

  void addOwlTap() {
    owlTaps++;
    _save();
  }

  void addBreath() {
    breaths++;
    _save();
  }

  void addLongRest() {
    longRests++;
    _save();
  }

  void addSession(SessionRecord r) {
    sessions++;
    first ??= r.start;
    if (r.summited) {
      mountains++;
      final hr = r.end.hour;
      if (hr >= 21 || hr < 4) nightSummits++;
      if (hr >= 4 && hr < 8) dawnSummits++;
      if (r.skips == 0) cleanSummits++;
    } else if (r.climbsDone < r.climbsPlanned) {
      abandoned++;
    }
    if (r.focus > longest) longest = r.focus;
    final l = r.label;
    if (l != null) {
      final b = byLabel[l] ?? (focus: 0, mountains: 0);
      byLabel[l] = (focus: b.focus + r.focus.inSeconds, mountains: b.mountains + (r.summited ? 1 : 0));
    }
    recent.insert(0, r);
    if (recent.length > 30) recent.removeRange(30, recent.length);
    _save();
  }

  void reset() {
    mountains = sessions = abandoned = ascents = shoves = slips = bestStreak = 0;
    owlTaps = breaths = nightSummits = dawnSummits = cleanSummits = longRests = 0;
    byLabel.clear();
    focus = longest = Duration.zero;
    first = null;
    daily.clear();
    recent.clear();
    _save();
  }

  static DateTime _day(DateTime t) => DateTime(t.year, t.month, t.day);

  void _load(Map<String, dynamic> j) {
    mountains = j['mountains'] as int? ?? 0;
    sessions = j['sessions'] as int? ?? 0;
    abandoned = j['abandoned'] as int? ?? 0;
    ascents = j['ascents'] as int? ?? 0;
    shoves = j['shoves'] as int? ?? 0;
    slips = j['slips'] as int? ?? 0;
    bestStreak = j['bestStreak'] as int? ?? 0;
    owlTaps = j['owlTaps'] as int? ?? 0;
    breaths = j['breaths'] as int? ?? 0;
    nightSummits = j['nightSummits'] as int? ?? 0;
    dawnSummits = j['dawnSummits'] as int? ?? 0;
    cleanSummits = j['cleanSummits'] as int? ?? 0;
    longRests = j['longRests'] as int? ?? 0;
    (j['byLabel'] as Map<String, dynamic>? ?? {}).forEach((k, v) {
      final m = v as Map<String, dynamic>;
      byLabel[k] = (focus: m['f'] as int? ?? 0, mountains: m['m'] as int? ?? 0);
    });
    focus = Duration(seconds: j['focus'] as int? ?? 0);
    longest = Duration(seconds: j['longest'] as int? ?? 0);
    final f = j['first'] as int?;
    first = f == null ? null : DateTime.fromMillisecondsSinceEpoch(f);
    (j['daily'] as Map<String, dynamic>? ?? {}).forEach((k, v) => daily[k] = v as int);
    for (final r in j['recent'] as List<dynamic>? ?? const []) {
      recent.add(SessionRecord.fromJson(r as Map<String, dynamic>));
    }
  }

  void _save() {
    if (daily.length > 400) {
      final keys = daily.keys.toList()..sort();
      for (final k in keys.take(daily.length - 400)) {
        daily.remove(k);
      }
    }
    _prefs.setString(
      _key,
      jsonEncode({
        'mountains': mountains,
        'sessions': sessions,
        'abandoned': abandoned,
        'ascents': ascents,
        'shoves': shoves,
        'slips': slips,
        'bestStreak': bestStreak,
        'owlTaps': owlTaps,
        'breaths': breaths,
        'nightSummits': nightSummits,
        'dawnSummits': dawnSummits,
        'cleanSummits': cleanSummits,
        'longRests': longRests,
        'byLabel': {
          for (final e in byLabel.entries) e.key: {'f': e.value.focus, 'm': e.value.mountains},
        },
        'focus': focus.inSeconds,
        'longest': longest.inSeconds,
        'first': first?.millisecondsSinceEpoch,
        'daily': daily,
        'recent': [for (final r in recent) r.toJson()],
      }),
    );
    notifyListeners();
  }
}
