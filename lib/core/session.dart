import 'dart:math' as math;

/// The two halves of the work: pushing the boulder up, and resting in the
/// valley while it waits at the bottom.
enum Phase { ascent, rest }

/// Something that happened that the screen may want to mark (a haptic, a
/// line of text).
enum SessionEvent { none, restBegins, ascentBegins, waitingForRest, waitingForAscent, summit }

/// One focus session: ascent, rest, ascent ... ascent, then the summit. Pure
/// logic on wall-clock times (no timers), so it survives the app being
/// closed: [update] catches up on everything that happened meanwhile.
class Session {
  Session({
    required this.focusMinutes,
    required this.restMinutes,
    required this.climbs,
    required this.started,
    this.speed = 1,
    this.autoContinue = true,
    this.longRestMinutes = 0,
    this.longEvery = 4,
    this.label,
  }) : _segmentStart = started,
       _endsAt = started.add(_dur(focusMinutes, speed));

  final int focusMinutes;
  final int restMinutes;
  final int climbs;
  final DateTime started;

  /// Debug: times faster than real time (1 normally). Stats count the
  /// nominal minutes.
  final int speed;
  bool autoContinue;

  /// A longer rest after every [longEvery] climbs (0 = off).
  final int longRestMinutes;
  final int longEvery;

  /// What this session is for ("Study"), if anything.
  final String? label;

  int _index = 0;
  DateTime? _endsAt;
  Duration? _left;
  bool _waiting = false;
  bool _finished = false;
  DateTime? _finishedAt;
  DateTime _segmentStart;

  Duration focused = Duration.zero;
  int ascentsDone = 0;
  int restsTaken = 0;
  int skips = 0;
  int shoves = 0;

  /// Called with nominal focus time as it's earned, and when an ascent is
  /// completed in full.
  void Function(Duration focus, DateTime at)? onFocus;
  void Function()? onAscent;
  void Function()? onLongRest;

  static Duration _dur(int minutes, int speed) =>
      Duration(milliseconds: (minutes * 60000 / math.max(1, speed)).round());

  int get phaseCount => climbs * 2 - 1;
  int get index => _index;
  Phase get phase => _index.isEven ? Phase.ascent : Phase.rest;

  /// 1-based number of the climb in progress (or the one just finished,
  /// during a rest).
  int get climb => _index ~/ 2 + 1;
  bool get paused => _endsAt == null && !_waiting && !_finished;
  bool get waiting => _waiting;
  bool get finished => _finished;
  bool get running => _endsAt != null;
  DateTime? get endsAt => _endsAt;
  DateTime? get finishedAt => _finishedAt;

  Duration get plannedFocus => Duration(minutes: focusMinutes * climbs);

  /// Reached the top having done at least half the planned focus.
  bool get summited => _finished && focused * 2 >= plannedFocus;

  /// Whether rest phase [i] (default: the current phase) is a long rest.
  bool isLongRest([int? i]) {
    final k = i ?? _index;
    return k.isOdd && longRestMinutes > 0 && longEvery > 0 && ((k + 1) ~/ 2) % longEvery == 0;
  }

  Duration phaseLength([int? i]) {
    final k = i ?? _index;
    if (k.isEven) return _dur(focusMinutes, speed);
    return _dur(isLongRest(k) ? longRestMinutes : restMinutes, speed);
  }

  /// Total planned length of the whole session (nominal minutes).
  Duration get plannedTotal {
    var d = Duration.zero;
    for (var i = 0; i < phaseCount; i++) {
      d += phaseLength(i) * speed;
    }
    return d;
  }

  Duration remaining(DateTime now) {
    if (_finished) return Duration.zero;
    final e = _endsAt;
    if (e == null) return _left ?? phaseLength();
    final r = e.difference(now);
    return r.isNegative ? Duration.zero : r;
  }

  /// How far through the current phase, 0..1.
  double progress(DateTime now) {
    final len = phaseLength().inMilliseconds;
    if (len <= 0) return 1;
    return (1 - remaining(now).inMilliseconds / len).clamp(0.0, 1.0);
  }

  /// Every phase end still to come, if nothing is touched (for alerts).
  List<({DateTime at, int index})> upcoming() {
    final e = _endsAt;
    if (e == null) return const [];
    final out = [(at: e, index: _index)];
    if (!autoContinue) return out;
    var t = e;
    for (var i = _index + 1; i < phaseCount; i++) {
      t = t.add(phaseLength(i));
      out.add((at: t, index: i));
    }
    return out;
  }

  /// Moves through every phase that has ended by [now]. Returns the last
  /// thing that happened.
  SessionEvent update(DateTime now) {
    var ev = SessionEvent.none;
    while (true) {
      final e = _endsAt;
      if (e == null || now.isBefore(e)) return ev;
      _credit(e);
      if (phase == Phase.ascent) {
        ascentsDone++;
        onAscent?.call();
      } else {
        restsTaken++;
        if (isLongRest()) onLongRest?.call();
      }
      ev = _advance(e, start: autoContinue);
    }
  }

  void pause(DateTime now) {
    update(now);
    final e = _endsAt;
    if (e == null) return;
    _credit(now);
    _left = e.difference(now);
    _endsAt = null;
  }

  void resume(DateTime now) {
    if (!paused && !_waiting) return;
    _endsAt = now.add(_left ?? phaseLength());
    _left = null;
    _waiting = false;
    _segmentStart = now;
  }

  /// Ends the current phase now and starts the next one.
  SessionEvent skip(DateTime now) {
    if (_finished) return SessionEvent.none;
    update(now);
    if (_finished) return SessionEvent.summit;
    if (running) _credit(now);
    skips++;
    return _advance(now, start: true);
  }

  /// Leaves for the valley for good: credits what was done.
  void abandon(DateTime now) {
    if (_finished) return;
    update(now);
    if (running) _credit(now);
    _endsAt = null;
    _finishedAt = now;
  }

  void _credit(DateTime until) {
    if (phase != Phase.ascent || _endsAt == null) return;
    final d = until.difference(_segmentStart);
    if (d <= Duration.zero) return;
    final nominal = d * speed;
    focused += nominal;
    onFocus?.call(nominal, until);
    _segmentStart = until;
  }

  SessionEvent _advance(DateTime at, {required bool start}) {
    if (_index + 1 >= phaseCount) {
      _endsAt = null;
      _left = null;
      _finished = true;
      _finishedAt = at;
      return SessionEvent.summit;
    }
    _index++;
    _segmentStart = at;
    if (start) {
      _endsAt = at.add(phaseLength());
      _left = null;
      _waiting = false;
      return phase == Phase.rest ? SessionEvent.restBegins : SessionEvent.ascentBegins;
    }
    _endsAt = null;
    _left = phaseLength();
    _waiting = true;
    return phase == Phase.rest ? SessionEvent.waitingForRest : SessionEvent.waitingForAscent;
  }

  Map<String, Object?> toJson() => {
    'focusMinutes': focusMinutes,
    'restMinutes': restMinutes,
    'climbs': climbs,
    'started': started.millisecondsSinceEpoch,
    'speed': speed,
    'auto': autoContinue,
    'longRest': longRestMinutes,
    'longEvery': longEvery,
    'label': label,
    'index': _index,
    'endsAt': _endsAt?.millisecondsSinceEpoch,
    'left': _left?.inMilliseconds,
    'waiting': _waiting,
    'segmentStart': _segmentStart.millisecondsSinceEpoch,
    'focused': focused.inMilliseconds,
    'ascents': ascentsDone,
    'rests': restsTaken,
    'skips': skips,
    'shoves': shoves,
  };

  static Session fromJson(Map<String, dynamic> j) {
    DateTime? t(String k) => j[k] == null ? null : DateTime.fromMillisecondsSinceEpoch(j[k] as int);
    final s = Session(
      focusMinutes: j['focusMinutes'] as int,
      restMinutes: j['restMinutes'] as int,
      climbs: j['climbs'] as int,
      started: t('started')!,
      speed: j['speed'] as int? ?? 1,
      autoContinue: j['auto'] as bool? ?? true,
      longRestMinutes: j['longRest'] as int? ?? 0,
      longEvery: j['longEvery'] as int? ?? 4,
      label: j['label'] as String?,
    );
    s._index = j['index'] as int;
    s._endsAt = t('endsAt');
    s._left = j['left'] == null ? null : Duration(milliseconds: j['left'] as int);
    s._waiting = j['waiting'] as bool? ?? false;
    s._segmentStart = t('segmentStart') ?? s.started;
    s.focused = Duration(milliseconds: j['focused'] as int? ?? 0);
    s.ascentsDone = j['ascents'] as int? ?? 0;
    s.restsTaken = j['rests'] as int? ?? 0;
    s.skips = j['skips'] as int? ?? 0;
    s.shoves = j['shoves'] as int? ?? 0;
    return s;
  }
}
