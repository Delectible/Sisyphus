import 'package:flutter_test/flutter_test.dart';
import 'package:sisyphus/scene/ascent.dart';
import 'package:sisyphus/scene/clock.dart';

void main() {
  test('ground moves forward smoothly however fast Motivate is tapped', () {
    final state = AscentState();
    final painter = AscentPainter(SceneClock(), state);
    var prev = painter.walked(0);
    // 30 s at 120 Hz, shoving 8 times a second for the first 20 s.
    for (var i = 1; i <= 3600; i++) {
      final t = i / 120;
      if (t < 20 && i % 15 == 0) state.shove(t);
      state.advance(t);
      final w = painter.walked(t);
      final step = w - prev;
      // Never backwards (the step bob is gentle), never a jump.
      expect(step, greaterThan(-0.01), reason: 'at $t');
      expect(step, lessThan(0.25), reason: 'at $t');
      prev = w;
    }
    expect(state.shoves.length, lessThan(30));
  });

  test('a slip eases back without a jump at the end', () {
    final state = AscentState()..slipAt = 1;
    final painter = AscentPainter(SceneClock(), state);
    state.paused = true; // no walking: only the slip moves the ground
    state.motion = 0;
    final before = painter.walked(12.999);
    final after = painter.walked(13.001);
    expect((after - before).abs(), lessThan(0.01));
  });

  test('pausing eases to a stop, then picks up again', () {
    final state = AscentState();
    final painter = AscentPainter(SceneClock(), state);
    for (var i = 0; i <= 600; i++) {
      state.advance(i / 120);
    }
    state.paused = true;
    var prevStep = double.infinity;
    var prev = painter.walked(5);
    for (var i = 601; i <= 1200; i++) {
      state.advance(i / 120);
      final w = painter.walked(i / 120);
      final step = w - prev;
      prev = w;
      if (i > 640) expect(step, lessThanOrEqualTo(prevStep + 1e-4)); // slowing, no jolt
      prevStep = step;
    }
    expect(state.motion, 0);
    final stopped = painter.walked(10);
    state.advance(10.5);
    expect(painter.walked(10.5), stopped);
    state.paused = false;
    for (var i = 1261; i <= 1500; i++) {
      state.advance(i / 120);
    }
    expect(state.motion, closeTo(1, 0.01));
  });
}
