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
    final before = painter.walked(12.999) - 12.999 * 0.55;
    final after = painter.walked(13.001) - 13.001 * 0.55;
    expect((after - before).abs(), lessThan(0.01));
  });
}
