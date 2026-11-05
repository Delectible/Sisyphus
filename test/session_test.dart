import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sisyphus/core/poems.dart';
import 'package:sisyphus/core/session.dart';
import 'package:sisyphus/core/stats.dart';

final t0 = DateTime(2026, 11, 5, 9);

Session make({int focus = 25, int rest = 5, int climbs = 3, bool auto = true}) =>
    Session(focusMinutes: focus, restMinutes: rest, climbs: climbs, started: t0, autoContinue: auto);

DateTime at(int minutes, [int seconds = 0]) => t0.add(Duration(minutes: minutes, seconds: seconds));

void main() {
  test('runs ascent, rest, ascent ... to the summit on its own', () {
    final s = make();
    var focus = Duration.zero;
    s.onFocus = (d, _) => focus += d;
    expect(s.phase, Phase.ascent);
    expect(s.remaining(at(10)), const Duration(minutes: 15));
    expect(s.update(at(25)), SessionEvent.restBegins);
    expect(s.phase, Phase.rest);
    expect(s.update(at(30)), SessionEvent.ascentBegins);
    expect(s.climb, 2);
    // Catch up across several phases at once (app was closed).
    expect(s.update(at(200)), SessionEvent.summit);
    expect(s.finished, isTrue);
    expect(s.summited, isTrue);
    expect(s.focused, const Duration(minutes: 75));
    expect(focus, const Duration(minutes: 75));
    expect(s.ascentsDone, 3);
    expect(s.restsTaken, 2);
  });

  test('pause stops the clock and credits focus so far', () {
    final s = make();
    s.pause(at(10));
    expect(s.paused, isTrue);
    expect(s.focused, const Duration(minutes: 10));
    expect(s.update(at(60)), SessionEvent.none);
    expect(s.remaining(at(60)), const Duration(minutes: 15));
    s.resume(at(60));
    expect(s.update(at(75)), SessionEvent.restBegins);
    expect(s.focused, const Duration(minutes: 25));
  });

  test('skip moves on now and counts partial focus', () {
    final s = make(climbs: 2);
    expect(s.skip(at(5)), SessionEvent.restBegins);
    expect(s.focused, const Duration(minutes: 5));
    expect(s.skip(at(6)), SessionEvent.ascentBegins);
    expect(s.skip(at(7)), SessionEvent.summit);
    expect(s.skips, 3);
    expect(s.finished, isTrue);
    expect(s.summited, isFalse); // 6 of 50 minutes is no summit.
  });

  test('without auto-continue the next phase waits for a tap', () {
    final s = make(auto: false);
    expect(s.update(at(40)), SessionEvent.waitingForRest);
    expect(s.waiting, isTrue);
    expect(s.remaining(at(50)), const Duration(minutes: 5));
    s.resume(at(50));
    expect(s.update(at(55)), SessionEvent.waitingForAscent);
    expect(s.upcoming(), isEmpty);
  });

  test('upcoming lists every phase end for alerts', () {
    final s = make();
    final u = s.upcoming();
    expect(u.length, 5);
    expect(u.first.at, at(25));
    expect(u.last.at, at(25 + 5 + 25 + 5 + 25));
  });

  test('survives a save and restore', () {
    final s = make()..update(at(27));
    s.shoves = 3;
    final r = Session.fromJson(s.toJson());
    expect(r.phase, Phase.rest);
    expect(r.remaining(at(28)), const Duration(minutes: 2));
    expect(r.focused, const Duration(minutes: 25));
    expect(r.shoves, 3);
  });

  test('debug speed runs faster but counts nominal minutes', () {
    final s = Session(focusMinutes: 25, restMinutes: 5, climbs: 1, started: t0, speed: 60);
    expect(s.update(t0.add(const Duration(seconds: 25))), SessionEvent.summit);
    expect(s.focused, const Duration(minutes: 25));
  });

  test('streaks', () async {
    SharedPreferences.setMockInitialValues({});
    final stats = Stats(await SharedPreferences.getInstance());
    final today = DateTime(2026, 11, 5, 12);
    for (final d in [0, 1, 2, 5, 6, 7, 8]) {
      stats.daily[Stats.dayKey(today.subtract(Duration(days: d)))] = 1500;
    }
    expect(stats.streak(today), 3);
    expect(stats.longestRun(), 4);
    expect(stats.week(today).last, const Duration(seconds: 1500));
  });

  test('poems suit the climb', () {
    SessionRecord rec({bool summited = true, int skips = 0, int hour = 14}) => SessionRecord(
      start: DateTime(2026, 11, 5, hour - 2),
      end: DateTime(2026, 11, 5, hour),
      focus: const Duration(minutes: 100),
      climbsDone: 4,
      climbsPlanned: 4,
      skips: skips,
      shoves: 0,
      summited: summited,
    );
    final rnd = math.Random(1);
    expect(choosePoem(rec(), mountainsBefore: 0, random: rnd).mood, Mood.first);
    expect(choosePoem(rec(summited: false), mountainsBefore: 3, random: rnd).mood, Mood.shortcut);
    for (var i = 0; i < 20; i++) {
      final m = choosePoem(rec(hour: 23), mountainsBefore: 3, random: rnd).mood;
      expect([Mood.night, Mood.triumph, Mood.steady], contains(m));
    }
    for (final p in poems) {
      expect(p.lines.length, 4);
    }
  });
}
