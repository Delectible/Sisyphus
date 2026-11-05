import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/rendering.dart' hide Gradient;

import 'clock.dart';
import 'kit.dart';

/// What the ascent painter needs besides the clock.
class AscentState {
  /// How far up this climb, 0..1.
  double progress = 0;

  /// Clock times of recent shoves (Motivate) and the last slip.
  final List<double> shoves = [];
  double slipAt = -100;
  bool dark = false;
}

/// POV: Sisyphus's hands on the boulder, the slope rising to a ridge under
/// a heavy sky.
class AscentPainter extends CustomPainter {
  AscentPainter(this.clock, this.state) : super(repaint: clock);

  final SceneClock clock;
  final AscentState state;

  static const _period = 1.7; // one step, seconds

  /// Where the boulder sits for a canvas [size] (for tap detection too).
  static (Offset, double) boulderAt(Size size) {
    final r = math.min(size.width * 0.43, size.height * 0.26);
    return (Offset(size.width * 0.5, size.height * 0.57), r);
  }

  /// Ground travelled (world units).
  double _walked(double t) {
    var w = t * 0.55 + 0.12 * math.sin(t * math.pi * 2 / _period);
    for (final s in state.shoves) {
      final d = t - s;
      if (d > 0) w += 1.2 * (1 - math.exp(-d * 4));
    }
    final ds = t - state.slipAt;
    if (ds > 0 && ds < 4) w -= 2.2 * math.sin(math.min(ds / 0.6, 1) * math.pi / 2) * math.exp(-ds * 0.9);
    return w;
  }

  double _shoveKick(double t) {
    var k = 0.0;
    for (final s in state.shoves) {
      final d = t - s;
      if (d > 0 && d < 0.8) k = math.max(k, math.sin(d / 0.8 * math.pi));
    }
    return k;
  }

  @override
  void paint(Canvas c, Size size) {
    final t = clock.t;
    final dark = state.dark;
    final w = size.width, h = size.height;
    final p = state.progress.clamp(0.0, 1.0);
    final kick = _shoveKick(t);
    final ds = t - state.slipAt;
    final slip = ds > 0 && ds < 2.5
        ? math.sin(math.min(ds / 0.4, 1) * math.pi / 2) * math.exp(-ds * 1.6)
        : 0.0;

    // Lightning: now and then, a flash behind the ridge.
    final win = (t / 83).floor();
    final strikeAt = win * 83 + 20 + hash(win * 13) * 50;
    final since = t - strikeAt;
    final strikes = hash(win * 7 + 1) < 0.55;
    final flash = strikes && since > 0 && since < 1.2
        ? math.exp(-since * 6) + (since > 0.18 ? 0.6 * math.exp(-(since - 0.18) * 9) : 0)
        : 0.0;

    // Camera bob with each step (and a jolt on a shove / slip).
    final step = math.sin(t * math.pi * 2 / _period);
    c.save();
    c.translate(math.sin(t * math.pi / _period) * 2.5, step * 3.5 - kick * 6 + slip * 14);
    final full = Rect.fromLTWH(-10, -20, w + 20, h + 40);

    // Sky: heavy, brightening a touch near the top of the climb.
    final skyTop = dark ? const Color(0xFF0E1017) : const Color(0xFF5B626D);
    final skyLow = dark ? const Color(0xFF292B37) : const Color(0xFF9A9EA3);
    final horizonY = h * 0.27;
    vGradient(c, Rect.fromLTRB(full.left, full.top, full.right, h * 0.6), [
      mix(skyTop, const Color(0xFF8C93A0), flash * 0.6 + p * 0.08),
      mix(skyLow, const Color(0xFFD9D4C2), flash * 0.5 + p * 0.25),
    ]);
    if (dark) stars(c, Rect.fromLTWH(0, 0, w, horizonY), t, const Color(0x55FFFFFF), count: 18);

    // Distant peaks beyond the ridge.
    final far = Path()..moveTo(full.left, horizonY);
    for (var i = 0; i <= 8; i++) {
      final x = full.left + full.width * i / 8;
      far.lineTo(x, horizonY - (12 + 30 * hash(i + 40)) * (1 - p * 0.4));
    }
    far
      ..lineTo(full.right, h)
      ..lineTo(full.left, h)
      ..close();
    c.drawPath(far, fill(fade(dark ? const Color(0xFF1E2029) : const Color(0xFF7D828A), 1)));

    if (strikes && since > 0 && since < 0.35) {
      _bolt(c, Offset(w * (0.15 + 0.7 * hash(win * 3)), 0), horizonY, win);
    }

    // Storm clouds drifting.
    final cloudColor = dark ? const Color(0xFF1A1C25) : const Color(0xFF4F5661);
    for (var i = 0; i < 6; i++) {
      final speed = 4 + hash(i * 5) * 6;
      final cw = w * (0.5 + 0.4 * hash(i * 9));
      final x = ((hash(i * 3) * (w + cw) + t * speed) % (w + cw * 1.2)) - cw * 0.6;
      final y = h * (0.02 + 0.2 * hash(i * 11));
      c.drawPath(cloud(Offset(x, y), cw, i + 2), fill(fade(cloudColor, 0.55 + 0.3 * hash(i))));
    }
    if (flash > 0) c.drawRect(full, fill(fade(const Color(0xFFE8ECFF), flash * 0.18)));

    // The slope: rises toward the viewer; the ridge comes closer as we climb.
    final ground = h * 0.95;
    double yAt(double z) => horizonY + (ground - horizonY) / z;
    final ridgeZ = 30 - 26 * smooth(p);
    final ridgeY = yAt(ridgeZ);
    final slopeFar = dark ? const Color(0xFF3A3A40) : const Color(0xFF948C7D);
    final slopeNear = dark ? const Color(0xFF15151A) : const Color(0xFF453F37);
    final ridge = Path()..moveTo(full.left, ridgeY + 8);
    for (var i = 0; i <= 12; i++) {
      ridge.lineTo(full.left + full.width * i / 12, ridgeY + (hash(i * 3 + 7) - 0.5) * 10);
    }
    ridge
      ..lineTo(full.right, full.bottom)
      ..lineTo(full.left, full.bottom)
      ..close();
    c.drawPath(
      ridge,
      Paint()
        ..shader = Gradient.linear(Offset(0, ridgeY), Offset(0, h), [mix(slopeFar, skyLow, 0.25), slopeNear]),
    );

    // Stones, tufts and cracks on the slope, coming toward us.
    final walked = _walked(t);
    final (bc, br) = boulderAt(size);
    final contactY = bc.dy + br * 0.92;
    final items = <(double z, double x, int i)>[];
    const depth = 14.0;
    for (var i = 0; i < 70; i++) {
      final z = 0.85 + ((hash(i * 17) * depth - walked) % depth + depth) % depth;
      if (z > ridgeZ) continue;
      items.add((z, (hash(i * 23) - 0.5) * 7, i));
    }
    items.sort((a, b) => b.$1.compareTo(a.$1));
    void drawItem((double, double, int) it) {
      final (z, x, i) = it;
      final y = yAt(z);
      final sx = w / 2 + x * (w * 0.32) / z;
      final s = (w * 0.05) / z;
      final kind = hash(i * 41);
      final fog = ((z - 1) / ridgeZ).clamp(0.0, 1.0);
      if (kind < 0.45) {
        final col = mix(dark ? const Color(0xFF55545A) : const Color(0xFF7A7266), slopeFar, fog * 0.6);
        c.drawOval(
          Rect.fromCenter(center: Offset(sx, y + s * 0.15), width: s * 2.3, height: s * 0.5),
          fill(fade(const Color(0xFF000000), 0.25)),
        );
        c.drawOval(
          Rect.fromCenter(center: Offset(sx, y - s * 0.2), width: s * 2, height: s * 1.1),
          fill(col),
        );
        c.drawOval(
          Rect.fromCenter(center: Offset(sx - s * 0.3, y - s * 0.45), width: s * 0.8, height: s * 0.35),
          fill(fade(const Color(0xFFFFFFFF), dark ? 0.06 : 0.14)),
        );
      } else if (kind < 0.8) {
        final col = mix(dark ? const Color(0xFF3C4232) : const Color(0xFF6F6A45), slopeFar, fog * 0.6);
        final sway = math.sin(t * 1.3 + i) * s * 0.25;
        for (var k = -2; k <= 2; k++) {
          c.drawLine(
            Offset(sx + k * s * 0.2, y),
            Offset(sx + k * s * 0.45 + sway, y - s * (1.4 - k.abs() * 0.25)),
            stroke(col, math.max(0.8, s * 0.12)),
          );
        }
      } else {
        c.drawLine(
          Offset(sx - s * 1.5, y),
          Offset(sx + s * 1.2, y + s * 0.15),
          stroke(fade(const Color(0xFF000000), 0.25), math.max(0.6, s * 0.08)),
        );
      }
    }

    for (final it in items) {
      if (yAt(it.$1) < contactY) drawItem(it);
    }

    // Shadow under the boulder.
    c.drawOval(
      Rect.fromCenter(center: Offset(bc.dx, contactY), width: br * 2.2, height: br * 0.5),
      Paint()
        ..shader = Gradient.radial(Offset(bc.dx, contactY), br * 1.1, [
          fade(const Color(0xFF000000), 0.5),
          fade(const Color(0xFF000000), 0),
        ]),
    );
    // The boulder.
    final rollR = walked / (br / (w * 0.32)) * 0.9;
    boulder(
      c,
      bc + Offset(0, -kick * 4),
      br,
      roll: rollR,
      spin: math.sin(t * 0.3) * 0.05,
      base: dark ? const Color(0xFF4D4B48) : const Color(0xFF8C867B),
      lit: dark ? const Color(0xFF77736C) : const Color(0xFFBDB6A8),
      shade: dark ? const Color(0xFF1E1D1F) : const Color(0xFF433F3A),
      light: const Offset(-0.35, -0.75),
    );
    if (flash > 0) {
      c.drawCircle(bc, br, fill(fade(const Color(0xFFDDE4FF), flash * 0.12)));
    }

    for (final it in items) {
      if (yAt(it.$1) >= contactY) drawItem(it);
    }

    // The hands.
    final push = kick * 0.08 - slip * 0.1;
    final skin = dark ? const Color(0xFF9A6E54) : const Color(0xFFC88C64);
    final skinLit = dark ? const Color(0xFFB98A6C) : const Color(0xFFE2AE86);
    final skinDark = dark ? const Color(0xFF5E3F2E) : const Color(0xFF8D5A3D);
    for (final side in [-1, 1]) {
      final phase = side < 0 ? step : -step;
      final reach = 0.02 * phase + push;
      final palm = bc + Offset(side * br * 0.5, br * (0.32 - reach * 3));
      final elbow = Offset(w / 2 + side * w * 0.52, h * 1.08);
      _arm(c, elbow, palm, side, w, skin, skinLit, skinDark, dark, br);
    }

    c.restore();

    // Vignette: closes in during the climb.
    c.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = Gradient.radial(
          Offset(w / 2, h * 0.5),
          math.max(w, h) * 0.75,
          [fade(const Color(0xFF000000), 0), fade(const Color(0xFF000000), dark ? 0.6 : 0.42)],
          [0.55, 1],
        ),
    );
  }

  void _bolt(Canvas c, Offset top, double bottom, int seed) {
    final path = Path()..moveTo(top.dx, top.dy);
    var x = top.dx, y = top.dy;
    var i = 0;
    while (y < bottom) {
      y += 14 + hash(seed * 50 + i) * 18;
      x += (hash(seed * 70 + i) - 0.5) * 34;
      path.lineTo(x, y);
      i++;
    }
    c.drawPath(path, stroke(fade(const Color(0xFFE9EEFF), 0.35), 6));
    c.drawPath(path, stroke(const Color(0xFFF7F8FF), 1.8));
  }

  void _arm(
    Canvas c,
    Offset elbow,
    Offset palm,
    int side,
    double w,
    Color skin,
    Color lit,
    Color dark2,
    bool night,
    double br,
  ) {
    final dir = palm - elbow;
    final len = dir.distance;
    final u = dir / len;
    final n = Offset(-u.dy, u.dx) * side.toDouble();
    final wrist = palm - u * (w * 0.05);
    // Contact shadow of the hand on the stone (light from the upper left).
    c.drawOval(
      Rect.fromCenter(
        center: wrist + u * (w * 0.1) + Offset(w * 0.025, w * 0.02),
        width: w * 0.2,
        height: w * 0.2,
      ),
      Paint()
        ..color = fade(const Color(0xFF000000), 0.3)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
    );
    // Forearm.
    final arm = taper(elbow, wrist, w * 0.24, w * 0.12);
    c.drawPath(
      arm,
      Paint()
        ..shader = Gradient.linear(
          elbow + n * (w * 0.12),
          elbow - n * (w * 0.12),
          [lit, skin, dark2],
          [0, 0.5, 1],
        ),
    );
    c.drawPath(arm, stroke(fade(dark2, 0.8), 1.4));
    // Leather bracer.
    final b0 = wrist - u * (w * 0.03), b1 = wrist - u * (w * 0.13);
    final bracer = taper(b1, b0, w * 0.155, w * 0.13);
    final leather = night ? const Color(0xFF3E2A1E) : const Color(0xFF6A4328);
    c.drawPath(
      bracer,
      Paint()
        ..shader = Gradient.linear(
          b1 + n * (w * 0.08),
          b1 - n * (w * 0.08),
          [mix(leather, const Color(0xFFFFFFFF), 0.18), leather, mix(leather, const Color(0xFF000000), 0.4)],
          [0, 0.5, 1],
        ),
    );
    for (var k = 1; k <= 3; k++) {
      final m = Offset.lerp(b1, b0, k / 4)!;
      c.drawLine(m + n * (w * 0.065), m - n * (w * 0.06), stroke(fade(const Color(0xFF000000), 0.3), 1.2));
    }
    // Back of the hand, fingers spread on the stone.
    c.save();
    c.translate(wrist.dx, wrist.dy);
    c.rotate(math.atan2(u.dy, u.dx) + math.pi / 2);
    // Local: y negative = toward fingertips.
    final s = w * 0.0118;
    final hand = Path()
      ..moveTo(-5 * s, 0.5 * s)
      ..cubicTo(-7.6 * s, -2 * s, -8.6 * s, -6.5 * s, -7.4 * s, -9.6 * s)
      ..quadraticBezierTo(0, -11.6 * s, 7 * s, -9.8 * s)
      ..cubicTo(8.2 * s, -6.5 * s, 7.4 * s, -2 * s, 5 * s, 0.5 * s)
      ..quadraticBezierTo(0, 1.6 * s, -5 * s, 0.5 * s)
      ..close();
    final skinShader = Gradient.linear(
      Offset(-8 * s * side, 0),
      Offset(8 * s * side, 0),
      [lit, skin, dark2],
      [0, 0.55, 1],
    );
    // fingers: spread fan
    const fingers = [(-5.4, 7.6, -0.16), (-1.8, 9.0, -0.05), (1.8, 8.6, 0.05), (5.2, 6.8, 0.15)];
    for (final f in fingers) {
      final base = Offset(f.$1 * s * side, -9 * s);
      final tip = base + Offset(math.sin(f.$3 * side) * f.$2 * s, -math.cos(f.$3) * f.$2 * s);
      final finger = taper(base, tip, 3.6 * s, 3.0 * s);
      c.drawPath(finger, Paint()..shader = skinShader);
      c.drawPath(finger, stroke(fade(dark2, 0.85), 1.1));
      // knuckle crease
      final mid = Offset.lerp(base, tip, 0.5)!;
      c.drawLine(mid + const Offset(-1, 0) * s, mid + const Offset(1, 0) * s, stroke(fade(dark2, 0.5), 0.9));
      // nail
      final nail = Offset.lerp(base, tip, 0.86)!;
      c.drawOval(
        Rect.fromCenter(center: nail, width: 1.8 * s, height: 1.3 * s),
        fill(fade(mix(lit, const Color(0xFFFFFFFF), 0.3), 0.5)),
      );
    }
    // thumb: toward the middle of the boulder
    final tb = Offset(-5.5 * s * side, -3 * s);
    final tt = tb + Offset(-5.5 * s * side, -4.5 * s);
    final thumb = taper(tb, tt, 4 * s, 3 * s);
    c.drawPath(thumb, Paint()..shader = skinShader);
    c.drawPath(thumb, stroke(fade(dark2, 0.85), 1.1));
    c.drawPath(hand, Paint()..shader = skinShader);
    c.drawPath(hand, stroke(fade(dark2, 0.85), 1.2));
    // knuckles and tendons
    for (final f in fingers) {
      c.drawCircle(Offset(f.$1 * s * side, -8.6 * s), 1.1 * s, fill(fade(lit, 0.45)));
      c.drawLine(
        Offset(f.$1 * s * side * 0.5, -1.5 * s),
        Offset(f.$1 * s * side, -7.5 * s),
        stroke(fade(dark2, 0.22), 0.9),
      );
    }
    c.restore();
  }

  @override
  bool shouldRepaint(covariant AscentPainter old) => true;
}
