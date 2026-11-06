import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sisyphus/core/ambience.dart';
import 'package:sisyphus/core/laurels.dart';
import 'package:sisyphus/core/session.dart';
import 'package:sisyphus/core/settings.dart';
import 'package:sisyphus/core/stats.dart';

final t0 = DateTime(2026, 11, 5, 9);

void main() {
  test('long rest comes after every Nth climb', () {
    final s = Session(
      focusMinutes: 25,
      restMinutes: 5,
      climbs: 5,
      started: t0,
      longRestMinutes: 15,
      longEvery: 2,
    );
    // Phases: A R A [LR] A R A [LR] A
    expect([for (var i = 1; i < s.phaseCount; i += 2) s.isLongRest(i)], [false, true, false, true]);
    expect(s.phaseLength(3), const Duration(minutes: 15));
    expect(s.plannedTotal, const Duration(minutes: 125 + 5 + 15 + 5 + 15));
    var longs = 0;
    s.onLongRest = () => longs++;
    s.update(t0.add(const Duration(hours: 4)));
    expect(s.finished, isTrue);
    expect(longs, 2);
    // Survives a save.
    final r = Session.fromJson(s.toJson());
    expect(r.longRestMinutes, 15);
    expect(r.longEvery, 2);
  });

  test('labels: add, pick, remove', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final s = Settings(prefs)..addLabel('  Thesis ');
    expect(s.labels, contains('Thesis'));
    expect(s.label, 'Thesis');
    s.addLabel('Thesis');
    expect(s.labels.where((l) => l == 'Thesis').length, 1);
    s.removeLabel('Thesis');
    expect(s.label, isNull);
    expect(Settings(prefs).labels, isNot(contains('Thesis')));
  });

  test('stats by label and laurels', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final stats = Stats(prefs);
    final watch = LaurelWatch(prefs, stats);
    expect(skinUnlocked(stats, 'granite'), isTrue);
    expect(skinUnlocked(stats, 'sandstone'), isFalse);
    stats.addSession(
      SessionRecord(
        start: DateTime(2026, 11, 5, 21),
        end: DateTime(2026, 11, 5, 22, 30),
        focus: const Duration(minutes: 75),
        climbsDone: 3,
        climbsPlanned: 3,
        skips: 0,
        shoves: 0,
        summited: true,
        label: 'Study',
      ),
    );
    expect(stats.byLabel['Study']!.focus, 75 * 60);
    expect(stats.byLabel['Study']!.mountains, 1);
    expect(watch.queue.map((l) => l.id), containsAll(['first', 'night']));
    expect(skinUnlocked(stats, 'sandstone'), isTrue);
    expect(skinUnlocked(stats, 'obsidian'), isTrue);
    // Saved and loaded.
    final again = Stats(prefs);
    expect(again.byLabel['Study']!.mountains, 1);
    expect(again.nightSummits, 1);
    // Announced once only.
    final watch2 = LaurelWatch(prefs, again);
    again.addOwlTap();
    expect(watch2.queue, isEmpty);
  });

  test('every skin and laurel is consistent', () {
    for (final l in laurels) {
      if (l.skin != null) expect(skins.map((s) => s.id), contains(l.skin));
    }
    expect(laurels.map((l) => l.id).toSet().length, laurels.length);
  });

  test('sound: the wind is a clean, seamless WAV loop', () {
    final wav = synthesize(seconds: 8);
    final data = ByteData.sublistView(wav);
    expect(String.fromCharCodes(wav.sublist(0, 4)), 'RIFF');
    expect(String.fromCharCodes(wav.sublist(8, 12)), 'WAVE');
    expect(data.getUint32(24, Endian.little), 22050);
    final n = (wav.length - 44) ~/ 2;
    expect(n, 8 * 22050);
    int at(int i) => data.getInt16(44 + i * 2, Endian.little);
    var peak = 0;
    var sum = 0.0;
    var jumps = 0;
    for (var i = 0; i < n; i++) {
      final v = at(i);
      peak = v.abs() > peak ? v.abs() : peak;
      sum += v;
      if (i > 0 && (v - at(i - 1)).abs() > 3000) jumps++;
    }
    expect(peak, greaterThan(10000)); // audible
    expect(peak, lessThan(32767)); // no clipping
    expect((sum / n).abs(), lessThan(800)); // centred, no DC
    expect(jumps, 0); // smooth: no clicks or hiss spikes
    // The loop point is smooth too.
    expect((at(0) - at(n - 1)).abs(), lessThan(3000));
  });
}
