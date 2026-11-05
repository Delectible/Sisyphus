import 'dart:math' as math;
import 'dart:ui';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart' hide Gradient;

import '../core/laurels.dart';
import 'clock.dart';
import 'kit.dart';

/// The valley: lying in the grass at the foot of the mountain, the boulder
/// waiting nearby. Calm light, slow clouds, an owl on a broken column.
class RestPainter extends CustomPainter {
  RestPainter(this.clock, {required this.dark, this.owlAt = -100, this.skin = granite, this.longRest = false})
    : super(repaint: clock);

  /// The boulder's stone.
  final Skin skin;

  /// A long rest: a campfire burns by the stream.
  final bool longRest;

  final SceneClock clock;
  final bool dark;

  /// Clock time the owl was last tapped (it ruffles).
  final double owlAt;

  static ui.Picture? _cache;
  static String? _cacheKey;

  static Rect owlRect(Size s) => Rect.fromCenter(
    center: Offset(s.width * 0.17, s.height * 0.56),
    width: s.width * 0.16,
    height: s.width * 0.18,
  );

  @override
  void paint(Canvas c, Size size) {
    final t = clock.t;
    final w = size.width, h = size.height;
    final horizon = h * 0.6;

    // Sky.
    vGradient(
      c,
      Offset.zero & size,
      dark
          ? const [Color(0xFF0B1230), Color(0xFF1E2A50), Color(0xFF3B4670)]
          : const [Color(0xFF8EC0CC), Color(0xFFC8DDD6), Color(0xFFF4E2C2)],
      const [0, 0.45, 0.62],
    );
    if (dark) {
      stars(c, Rect.fromLTWH(0, 0, w, horizon * 0.8), t, const Color(0xFFFFFFFF), count: 90);
      final moon = Offset(w * 0.78, h * 0.13);
      glow(c, moon, w * 0.22, const Color(0x40C9D6FF));
      c.drawCircle(moon, w * 0.055, fill(const Color(0xFFF1EEDF)));
      c.drawCircle(moon + Offset(w * 0.018, -w * 0.01), w * 0.05, fill(fade(const Color(0xFF1E2A50), 0.15)));
      c.drawCircle(moon + Offset(-w * 0.015, w * 0.012), w * 0.01, fill(const Color(0x22000000)));
    } else {
      final sun = Offset(w * 0.8, h * 0.17);
      glow(c, sun, w * 0.45, const Color(0x66FFF1C9));
      c.drawCircle(sun, w * 0.065, fill(const Color(0xFFFFF4D6)));
    }

    // Clouds.
    for (var i = 0; i < 4; i++) {
      final cw = w * (0.35 + 0.3 * hash(i * 9 + 1));
      final x = ((hash(i * 3 + 1) * (w + cw) + t * (2 + hash(i) * 3)) % (w + cw * 1.2)) - cw * 0.6;
      final y = h * (0.08 + 0.22 * hash(i * 11 + 2));
      c.drawPath(
        cloud(Offset(x, y), cw, i + 20),
        fill(dark ? const Color(0x2A9AA6D0) : const Color(0xB3FFFFFF)),
      );
    }

    // Everything that doesn't move, drawn once per size and theme.
    final key = '${size.width}x${size.height}/$dark/${skin.id}';
    if (_cacheKey != key) {
      final rec = ui.PictureRecorder();
      _scenery(Canvas(rec), w, h, horizon);
      _cache?.dispose();
      _cache = rec.endRecording();
      _cacheKey = key;
    }
    c.drawPicture(_cache!);

    // Light moving on the water.
    for (var k = 0; k < 14; k++) {
      final u = ((hash(k * 7) + t * 0.025) % 1.0);
      if (u < 0.08) continue;
      final (cx, cy, half) = _streamAt(u, w, h, horizon);
      final off = (hash(k * 11) - 0.5) * half * 1.2;
      final len = half * (0.3 + 0.4 * hash(k * 3));
      final a = math.sin(u * math.pi) * (0.5 + 0.5 * math.sin(t * 2 + k));
      c.drawLine(
        Offset(cx + off - len / 2, cy),
        Offset(cx + off + len / 2, cy),
        stroke(fade(dark ? const Color(0xFFC9D6FF) : const Color(0xFFFFFFFF), 0.55 * a), 1.2),
      );
    }

    // Sheep grazing.
    for (var k = 0; k < 3; k++) {
      final drift = math.sin(t * 0.05 + k * 2) * w * 0.02;
      final at = Offset(w * (0.38 + 0.08 * k) + drift, horizon + h * (0.075 + 0.018 * k));
      _sheep(c, at, w * (0.026 + 0.004 * k), t + k * 3.3, facingLeft: k == 1);
    }

    if (longRest) _campfire(c, Offset(w * 0.56, h * 0.765), w * 0.05, t);

    final colBase = Offset(w * 0.17, h * 0.78);
    final colW = w * 0.11, colH = h * 0.19;
    _owl(c, Offset(colBase.dx, colBase.dy - colH - colW * 0.05), colW, t);

    // Butterflies by day.
    if (!dark) {
      for (var k = 0; k < 2; k++) {
        final bx = w * (0.55 + 0.25 * k) + math.sin(t * 0.37 + k * 4) * w * 0.12 + math.sin(t * 1.3 + k) * 8;
        final by = h * (0.8 - 0.05 * k) + math.cos(t * 0.5 + k * 2) * h * 0.04 + math.sin(t * 2.2 + k) * 5;
        final flap = math.sin(t * 14 + k * 2).abs();
        final col = k == 0 ? const Color(0xFFF0B13A) : const Color(0xFFF7F2E4);
        c.drawOval(
          Rect.fromCenter(center: Offset(bx - 3.5 * flap, by), width: 7 * flap + 1, height: 6),
          fill(col),
        );
        c.drawOval(
          Rect.fromCenter(center: Offset(bx + 3.5 * flap, by), width: 7 * flap + 1, height: 6),
          fill(col),
        );
        c.drawLine(Offset(bx, by - 3), Offset(bx, by + 3), stroke(const Color(0xFF3A2A1A), 1.2));
      }
    }

    // Fireflies or birds.
    if (dark) {
      for (var i = 0; i < 12; i++) {
        final fx = w * (0.1 + 0.8 * hash(i * 5)) + math.sin(t * 0.4 + i) * 18;
        final fy = horizon + h * (0.06 + 0.25 * hash(i * 7)) + math.cos(t * 0.33 + i * 2) * 12;
        final on = (0.5 + 0.5 * math.sin(t * (0.7 + hash(i) * 0.6) + i * 3));
        glow(c, Offset(fx, fy), 9, fade(const Color(0xFFE8F28A), on * 0.5));
        c.drawCircle(Offset(fx, fy), 1.4, fill(fade(const Color(0xFFF6FFB8), on)));
      }
    } else {
      for (var i = 0; i < 3; i++) {
        final x = ((t * (14 + i * 3) + hash(i * 7) * w * 2) % (w * 1.6)) - w * 0.3;
        final by = h * (0.12 + 0.1 * hash(i * 13)) + math.sin(t * 0.5 + i) * 6;
        final flap = math.sin(t * 5 + i) * 3;
        final bs = 7.0 - i;
        c.drawPath(
          Path()
            ..moveTo(x - bs, by - flap)
            ..quadraticBezierTo(x - bs * 0.4, by - bs * 0.4, x, by)
            ..quadraticBezierTo(x + bs * 0.4, by - bs * 0.4, x + bs, by - flap),
          stroke(const Color(0x995B5550), 1.3),
        );
      }
    }

    // Foreground grass and poppies, swaying.
    final grassDark = dark ? const Color(0xFF0D1510) : const Color(0xFF4B6630);
    final grassLit = dark ? const Color(0xFF2C4232) : const Color(0xFF8DA556);
    for (var i = 0; i < 70; i++) {
      final x = w * hash(i * 13 + 5);
      final base = h + 4;
      final len = h * (0.06 + 0.12 * hash(i * 19));
      final sway = math.sin(t * 0.9 + x * 0.02) * len * 0.12 + math.sin(t * 2.1 + i) * len * 0.02;
      final tip = Offset(x + sway + (hash(i) - 0.5) * len * 0.4, base - len);
      c.drawPath(
        Path()
          ..moveTo(x - 3, base)
          ..quadraticBezierTo(x, base - len * 0.6, tip.dx, tip.dy)
          ..quadraticBezierTo(x + 1, base - len * 0.5, x + 3, base)
          ..close(),
        fill(mix(grassDark, grassLit, hash(i * 3))),
      );
      if (hash(i * 29) > 0.86) {
        final col = hash(i * 31) > 0.5
            ? (dark ? const Color(0xFF8E3A33) : const Color(0xFFD2452F))
            : (dark ? const Color(0xFFB0B4C8) : const Color(0xFFF7F2E4));
        c.drawCircle(tip, 4.2, fill(col));
        c.drawCircle(tip, 1.4, fill(const Color(0xFF2B2219)));
      }
    }
  }

  /// The still parts of the valley (cached as a picture).
  void _scenery(Canvas c, double w, double h, double horizon) {
    // Far ranges.
    void range(double base, double amp, Color col, int seed, int n) {
      final p = Path()..moveTo(0, h);
      for (var i = 0; i <= n; i++) {
        final x = w * i / n;
        p.lineTo(x, base - amp * (0.4 + 0.6 * hash(seed * 31 + i)));
      }
      p
        ..lineTo(w, h)
        ..close();
      c.drawPath(p, fill(col));
    }

    range(horizon - h * 0.03, h * 0.06, dark ? const Color(0xFF2B3557) : const Color(0xFFB7C6C4), 1, 9);

    // The mountain: tall, its path zig-zagging to the peak.
    final peak = Offset(w * 0.62, h * 0.2);
    final mountain = Path()
      ..moveTo(-w * 0.1, horizon + h * 0.04)
      ..quadraticBezierTo(w * 0.3, horizon - h * 0.12, peak.dx - w * 0.06, peak.dy + h * 0.06)
      ..lineTo(peak.dx, peak.dy)
      ..lineTo(peak.dx + w * 0.05, peak.dy + h * 0.05)
      ..quadraticBezierTo(w * 0.9, horizon - h * 0.16, w * 1.1, horizon + h * 0.02)
      ..lineTo(w * 1.1, h)
      ..lineTo(-w * 0.1, h)
      ..close();
    c.drawPath(
      mountain,
      Paint()
        ..shader = Gradient.linear(
          peak,
          Offset(peak.dx, horizon + h * 0.05),
          dark ? const [Color(0xFF4A5274), Color(0xFF2A3150)] : const [Color(0xFFA8A496), Color(0xFF7F8A70)],
        ),
    );
    // Lit flank.
    c.drawPath(
      Path()
        ..moveTo(peak.dx, peak.dy)
        ..lineTo(peak.dx + w * 0.05, peak.dy + h * 0.05)
        ..quadraticBezierTo(w * 0.9, horizon - h * 0.16, w * 1.1, horizon + h * 0.02)
        ..lineTo(peak.dx + w * 0.08, horizon)
        ..close(),
      fill(dark ? const Color(0x22C9D6FF) : const Color(0x33FFF3D6)),
    );
    // Snow cap.
    c.drawPath(
      Path()
        ..moveTo(peak.dx - w * 0.045, peak.dy + h * 0.045)
        ..lineTo(peak.dx, peak.dy)
        ..lineTo(peak.dx + w * 0.04, peak.dy + h * 0.04)
        ..lineTo(peak.dx + w * 0.01, peak.dy + h * 0.035)
        ..lineTo(peak.dx - w * 0.015, peak.dy + h * 0.05)
        ..close(),
      fill(dark ? const Color(0xFFB8C0D8) : const Color(0xFFF8F6F0)),
    );
    // The path up.
    final trail = Path()..moveTo(w * 0.58, horizon + h * 0.02);
    var y = horizon + h * 0.02;
    var right = true;
    while (y > peak.dy + h * 0.06) {
      final f = (y - peak.dy) / (horizon - peak.dy);
      y -= h * 0.05;
      trail.lineTo(peak.dx + (right ? 1 : -1) * w * 0.12 * f, y);
      right = !right;
    }
    trail.lineTo(peak.dx, peak.dy + h * 0.01);
    c.drawPath(
      trail,
      stroke(dark ? const Color(0x55D9D2C0) : const Color(0x88F4ECD8), 1.4)..strokeCap = StrokeCap.round,
    );

    // Mountain detail: shaded west face, ridges, outcrops, scree, scrub
    // and a few pines, all clipped to the mountain.
    c.save();
    c.clipPath(mountain);
    c.drawPath(
      Path()
        ..moveTo(peak.dx, peak.dy)
        ..quadraticBezierTo(peak.dx - w * 0.05, horizon - h * 0.15, peak.dx - w * 0.02, horizon + h * 0.05)
        ..lineTo(-w * 0.1, horizon + h * 0.05)
        ..lineTo(-w * 0.1, peak.dy)
        ..close(),
      fill(dark ? const Color(0x22000010) : const Color(0x1A2B2A20)),
    );
    final crease = fade(dark ? const Color(0xFF1B2140) : const Color(0xFF5E5C50), 0.55);
    final litEdge = dark ? const Color(0x33C9D6FF) : const Color(0x55FFF6E0);
    // Ridges: short jagged spurs running down the faces.
    for (var k = 0; k < 9; k++) {
      final side = k.isEven ? -1.0 : 1.0;
      final f0 = 0.12 + 0.3 * hash(k * 3 + 1);
      final f1 = (f0 + 0.3 + 0.35 * hash(k * 5 + 2)).clamp(0.0, 0.95);
      final lane = 0.15 + 0.75 * hash(k * 7 + 3);
      Offset pt(double f, double wob) {
        final y = peak.dy + (horizon - peak.dy) * f;
        final halfW = (w * 0.06) + (w * 0.45) * f;
        return Offset(peak.dx + side * halfW * lane + wob, y);
      }

      final ridge = Path();
      for (var j = 0; j <= 6; j++) {
        final f = f0 + (f1 - f0) * j / 6;
        final q = pt(f, (hash(k * 50 + j) - 0.5) * w * 0.02);
        j == 0 ? ridge.moveTo(q.dx, q.dy) : ridge.lineTo(q.dx, q.dy);
      }
      c.drawPath(ridge, stroke(fade(crease, 0.8), 1.4));
      c.drawPath(ridge.shift(const Offset(1.5, -0.5)), stroke(litEdge, 1));
    }
    // Snow streaks below the cap.
    for (var k = 0; k < 5; k++) {
      final x = peak.dx + (k - 2) * w * 0.012;
      final y0 = peak.dy + h * (0.04 + 0.006 * k);
      c.drawLine(
        Offset(x, y0),
        Offset(x + (k - 2) * w * 0.006, y0 + h * (0.02 + 0.02 * hash(k + 40))),
        stroke(dark ? const Color(0x66B8C0D8) : const Color(0x99F8F6F0), 1.3),
      );
    }
    // Rock outcrops.
    final rockDark = dark ? const Color(0xFF2A3050) : const Color(0xFF7A766A);
    final rockLit = dark ? const Color(0xFF6A7298) : const Color(0xFFCFC8B4);
    for (var k = 0; k < 14; k++) {
      final f = 0.18 + 0.75 * hash(k * 11 + 1);
      final y = peak.dy + (horizon - peak.dy) * f;
      final halfW = (w * 0.06) + (w * 0.42) * f;
      final x = peak.dx + (hash(k * 13 + 2) - 0.5) * 2 * halfW * 0.8;
      final r = w * (0.008 + 0.014 * hash(k * 5)) * (0.6 + f);
      final rock = Path()
        ..moveTo(x - r * 1.4, y + r * 0.5)
        ..lineTo(x - r * 0.5, y - r * 0.8)
        ..lineTo(x + r * 0.4, y - r)
        ..lineTo(x + r * 1.3, y + r * 0.5)
        ..close();
      c.drawPath(rock, fill(rockDark));
      c.drawLine(Offset(x - r * 0.5, y - r * 0.8), Offset(x + r * 0.4, y - r), stroke(rockLit, 1.2));
      c.drawLine(Offset(x + r * 0.4, y - r), Offset(x + r * 1.3, y + r * 0.5), stroke(fade(rockLit, 0.7), 1));
    }
    // Scree fans at the foot.
    for (var k = 0; k < 40; k++) {
      final x = w * (0.3 + 0.62 * hash(k * 17 + 4));
      final y = horizon - h * 0.005 - h * 0.05 * hash(k * 19 + 5) * hash(k * 3);
      c.drawCircle(Offset(x, y), 0.8 + 1.2 * hash(k), fill(fade(rockLit, 0.55)));
    }
    // Scrub and small pines on the lower slopes.
    final scrub = dark ? const Color(0xFF1C2A26) : const Color(0xFF5F7444);
    final scrubLit = dark ? const Color(0xFF2E4038) : const Color(0xFF8DA061);
    for (var k = 0; k < 90; k++) {
      final f = 0.5 + 0.5 * math.sqrt(hash(k * 7 + 9));
      final y = peak.dy + (horizon + h * 0.03 - peak.dy) * f;
      final halfW = (w * 0.06) + (w * 0.45) * f;
      final x = peak.dx + (hash(k * 23 + 8) - 0.5) * 2 * halfW;
      final r = 1.2 + 2.4 * hash(k * 29) * f;
      c.drawCircle(Offset(x, y), r, fill(scrub));
      c.drawCircle(Offset(x + r * 0.3, y - r * 0.35), r * 0.55, fill(scrubLit));
    }
    for (var k = 0; k < 16; k++) {
      final f = 0.55 + 0.45 * hash(k * 31 + 2);
      final y = peak.dy + (horizon + h * 0.03 - peak.dy) * f;
      final halfW = (w * 0.06) + (w * 0.45) * f;
      final x = peak.dx + (hash(k * 37 + 6) - 0.5) * 2 * halfW;
      final ph = h * (0.012 + 0.012 * f);
      c.drawPath(
        Path()
          ..moveTo(x, y - ph)
          ..lineTo(x + ph * 0.3, y)
          ..lineTo(x - ph * 0.3, y)
          ..close(),
        fill(dark ? const Color(0xFF13201B) : const Color(0xFF3E5733)),
      );
    }
    c.restore();

    // A small temple on a ledge of the lower slope.
    {
      final tb = Offset(w * 0.4, horizon - h * 0.115);
      // a ledge for it to stand on
      c.drawOval(
        Rect.fromCenter(center: tb + const Offset(0, 0.5), width: w * 0.11, height: h * 0.007),
        fill(dark ? const Color(0xFF3A4366) : const Color(0xFFB2AE9E)),
      );
      final tw = w * 0.07, th = tw * 0.42;
      final stone = dark ? const Color(0xFF7A84A8) : const Color(0xFFF2EEE2);
      final shade = dark ? const Color(0xFF414B73) : const Color(0xFFB9BDB3);
      c.drawRect(Rect.fromLTWH(tb.dx - tw / 2 - 1.5, tb.dy - 2, tw + 3, 2.2), fill(shade));
      for (var k = 0; k < 5; k++) {
        final x = tb.dx - tw / 2 + tw * k / 4;
        c.drawRect(Rect.fromLTWH(x - 1.1, tb.dy - th, 2.2, th - 2), fill(stone));
      }
      c.drawRect(Rect.fromLTWH(tb.dx - tw / 2 - 1.5, tb.dy - th - 2.4, tw + 3, 2.6), fill(stone));
      c.drawPath(
        Path()
          ..moveTo(tb.dx - tw / 2 - 2, tb.dy - th - 2.4)
          ..lineTo(tb.dx, tb.dy - th - tw * 0.2)
          ..lineTo(tb.dx + tw / 2 + 2, tb.dy - th - 2.4)
          ..close(),
        fill(stone),
      );
    }

    // Meadow.
    final meadow = Path()
      ..moveTo(0, horizon + h * 0.04)
      ..quadraticBezierTo(w * 0.35, horizon - h * 0.02, w * 0.7, horizon + h * 0.03)
      ..quadraticBezierTo(w * 0.9, horizon + h * 0.06, w, horizon + h * 0.02)
      ..lineTo(w, h)
      ..lineTo(0, h)
      ..close();
    c.drawPath(
      meadow,
      Paint()
        ..shader = Gradient.linear(
          Offset(0, horizon),
          Offset(0, h),
          dark ? const [Color(0xFF2B3B2E), Color(0xFF111A14)] : const [Color(0xFFAEBB78), Color(0xFF5E7A3E)],
        ),
    );

    // A stream from the foot of the mountain to the foreground.
    final water = _stream(w, h, horizon);
    c.drawPath(water, fill(dark ? const Color(0xFF16213D) : const Color(0xFF6F8F5A)));
    c.drawPath(
      water.shift(const Offset(0, -1.5)),
      Paint()
        ..shader = Gradient.linear(
          Offset(0, horizon),
          Offset(0, h),
          dark ? const [Color(0xFF3F4C7E), Color(0xFF26325A)] : const [Color(0xFFCFE3E2), Color(0xFF8DBBC6)],
        ),
    );
    // Stepping stones and reeds along the banks.
    for (var k = 0; k < 7; k++) {
      final u = 0.25 + 0.1 * k;
      final (cx, cy, half) = _streamAt(u, w, h, horizon);
      final side = k.isEven ? -1.0 : 1.0;
      final at = Offset(cx + side * (half + 3), cy);
      for (var j = -1; j <= 1; j++) {
        c.drawLine(
          at + Offset(j * 2.0, 0),
          at + Offset(j * 3.5 + side, -6 - 6 * u - j.abs() * 2),
          stroke(dark ? const Color(0xFF2C3D30) : const Color(0xFF55703A), 1.2),
        );
      }
    }
    // An olive tree in the middle distance.
    {
      final base = Offset(w * 0.33, horizon + h * 0.035);
      final trunk = dark ? const Color(0xFF241D1A) : const Color(0xFF5E4A3A);
      c.drawPath(taper(base, base + Offset(-w * 0.01, -h * 0.035), w * 0.014, w * 0.008), fill(trunk));
      c.drawPath(
        taper(
          base + Offset(-w * 0.008, -h * 0.025),
          base + Offset(w * 0.02, -h * 0.045),
          w * 0.007,
          w * 0.005,
        ),
        fill(trunk),
      );
      final leaf = dark ? const Color(0xFF2F3D33) : const Color(0xFF8E9E74);
      final leafLit = dark ? const Color(0xFF465A4C) : const Color(0xFFB4C29A);
      for (var k = 0; k < 9; k++) {
        final o = Offset((hash(k * 3) - 0.5) * w * 0.07, -h * 0.045 - hash(k * 5) * h * 0.025);
        final r = w * (0.016 + 0.01 * hash(k * 7));
        c.drawCircle(base + o, r, fill(leaf));
        c.drawCircle(base + o + Offset(r * 0.25, -r * 0.3), r * 0.55, fill(leafLit));
      }
    }
    // A dry-stone wall across the meadow.
    {
      final stoneC = dark ? const Color(0xFF59607A) : const Color(0xFFC9C0AA);
      final stoneD = dark ? const Color(0xFF3A4058) : const Color(0xFF9C9480);
      for (var row = 0; row < 2; row++) {
        for (var k = 0; k < 16; k++) {
          final x = w * 0.27 + k * w * 0.016 + row * w * 0.008;
          final y = h * 0.735 - row * w * 0.012 - k * h * 0.0016;
          final rw = w * (0.014 + 0.004 * hash(k * 9 + row));
          final rect = Rect.fromCenter(center: Offset(x, y), width: rw, height: w * 0.012);
          c.drawRRect(
            RRect.fromRectAndRadius(rect, Radius.circular(w * 0.005)),
            fill(row == 0 ? stoneD : stoneC),
          );
          c.drawLine(
            rect.topLeft + const Offset(2, 1),
            rect.topRight + const Offset(-2, 1),
            stroke(fade(const Color(0xFFFFFFFF), 0.2), 0.8),
          );
        }
      }
    }
    // Bushes dotted through the meadow.
    for (var k = 0; k < 12; k++) {
      final x = w * hash(k * 41 + 3);
      final y = horizon + h * (0.04 + 0.12 * hash(k * 43 + 1));
      if ((x - w * 0.17).abs() < w * 0.1 && y > h * 0.62) continue;
      final r = w * (0.012 + 0.012 * hash(k * 47)) * (0.6 + (y - horizon) / (h * 0.2));
      c.drawOval(
        Rect.fromCenter(center: Offset(x, y + r * 0.6), width: r * 2.6, height: r * 0.6),
        fill(const Color(0x22000000)),
      );
      c.drawCircle(
        Offset(x - r * 0.5, y),
        r * 0.8,
        fill(dark ? const Color(0xFF1B2A20) : const Color(0xFF5D7A3E)),
      );
      c.drawCircle(
        Offset(x + r * 0.4, y - r * 0.2),
        r,
        fill(dark ? const Color(0xFF223326) : const Color(0xFF6E8C48)),
      );
      c.drawCircle(
        Offset(x + r * 0.5, y - r * 0.5),
        r * 0.45,
        fill(dark ? const Color(0xFF30463A) : const Color(0xFF9AB46A)),
      );
    }

    // Cypresses.
    void cypress(double x, double base, double height) {
      final tw = height * 0.16;
      final p = Path()
        ..moveTo(x, base - height)
        ..quadraticBezierTo(x + tw * 1.2, base - height * 0.5, x + tw * 0.5, base)
        ..lineTo(x - tw * 0.5, base)
        ..quadraticBezierTo(x - tw * 1.2, base - height * 0.5, x, base - height)
        ..close();
      c.drawPath(p, fill(dark ? const Color(0xFF14211A) : const Color(0xFF3F5A32)));
      c.drawPath(
        Path()
          ..moveTo(x, base - height)
          ..quadraticBezierTo(x - tw * 1.1, base - height * 0.5, x - tw * 0.5, base)
          ..lineTo(x - tw * 0.1, base)
          ..close(),
        fill(dark ? const Color(0x18FFFFFF) : const Color(0x22FFFFDD)),
      );
    }

    cypress(w * 0.88, horizon + h * 0.05, h * 0.16);
    cypress(w * 0.95, horizon + h * 0.05, h * 0.12);
    cypress(w * 0.4, horizon + h * 0.01, h * 0.08);

    // The boulder, waiting at the foot of the mountain.
    final bc = Offset(w * 0.66, horizon + h * 0.065);
    final br = w * 0.075;
    c.drawOval(
      Rect.fromCenter(center: bc + Offset(br * 0.3, br * 0.9), width: br * 2.6, height: br * 0.55),
      fill(const Color(0x44000000)),
    );
    skinnedBoulder(c, bc, br, dark ? skin.night : skin, roll: 0.6, light: const Offset(0.55, -0.6));

    // Broken column with the owl.
    final colBase = Offset(w * 0.17, h * 0.78);
    final colW = w * 0.11, colH = h * 0.19;
    final marble = dark ? const Color(0xFF8C90A3) : const Color(0xFFEDE6D8);
    final marbleShade = dark ? const Color(0xFF4D5164) : const Color(0xFFB9AF9C);
    c.drawOval(
      Rect.fromCenter(center: colBase + Offset(colW * 0.4, 0), width: colW * 2.4, height: colW * 0.4),
      fill(const Color(0x33000000)),
    );
    c.drawRect(
      Rect.fromLTWH(colBase.dx - colW * 0.7, colBase.dy - colW * 0.25, colW * 1.4, colW * 0.25),
      fill(marbleShade),
    );
    final shaft = Path()
      ..moveTo(colBase.dx - colW / 2, colBase.dy - colW * 0.25)
      ..lineTo(colBase.dx - colW * 0.46, colBase.dy - colH)
      ..lineTo(colBase.dx - colW * 0.1, colBase.dy - colH - colW * 0.12)
      ..lineTo(colBase.dx + colW * 0.15, colBase.dy - colH + colW * 0.05)
      ..lineTo(colBase.dx + colW * 0.46, colBase.dy - colH - colW * 0.06)
      ..lineTo(colBase.dx + colW / 2, colBase.dy - colW * 0.25)
      ..close();
    c.drawPath(
      shaft,
      Paint()
        ..shader = Gradient.linear(
          Offset(colBase.dx - colW / 2, 0),
          Offset(colBase.dx + colW / 2, 0),
          [marbleShade, marble, marble, marbleShade],
          const [0, 0.35, 0.6, 1],
        ),
    );
    for (var k = 1; k < 5; k++) {
      final x = colBase.dx - colW / 2 + colW * k / 5;
      c.drawLine(
        Offset(x, colBase.dy - colW * 0.3),
        Offset(x, colBase.dy - colH + colW * 0.05),
        stroke(fade(marbleShade, 0.8), 1),
      );
    }
    // Fallen capital in the grass.
    c.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: colBase + Offset(colW * 1.5, -colW * 0.1),
          width: colW * 1.3,
          height: colW * 0.45,
        ),
        Radius.circular(colW * 0.1),
      ),
      fill(marbleShade),
    );
    c.drawCircle(colBase + Offset(colW * 0.95, -colW * 0.12), colW * 0.17, fill(marble));
    c.drawCircle(colBase + Offset(colW * 2.05, -colW * 0.12), colW * 0.17, fill(marble));
  }

  /// The stream's centre and half-width at [u] (0 = source, 1 = foreground).
  static (double, double, double) _streamAt(double u, double w, double h, double horizon) {
    final y = horizon + h * 0.035 + (h * 0.88 - horizon - h * 0.035) * math.pow(u, 1.25);
    final x = w * (0.5 + 0.55 * u) + math.sin(u * math.pi * 2.3) * w * 0.07 * (u + 0.25);
    final half = 1.2 + w * 0.06 * math.pow(u, 1.6);
    return (x, y, half);
  }

  static Path _stream(double w, double h, double horizon) {
    final left = <Offset>[], right = <Offset>[];
    for (var i = 0; i <= 40; i++) {
      final (x, y, half) = _streamAt(i / 40, w, h, horizon);
      left.add(Offset(x - half, y));
      right.add(Offset(x + half, y));
    }
    final p = Path()..moveTo(left.first.dx, left.first.dy);
    for (final q in left.skip(1)) {
      p.lineTo(q.dx, q.dy);
    }
    for (final q in right.reversed) {
      p.lineTo(q.dx, q.dy);
    }
    return p..close();
  }

  void _sheep(Canvas c, Offset at, double s, double t, {bool facingLeft = false}) {
    final dir = facingLeft ? -1.0 : 1.0;
    final graze = (math.sin(t * 0.6) * 0.5 + 0.5);
    final wool = dark ? const Color(0xFF9EA3B8) : const Color(0xFFF7F3EA);
    final woolShade = dark ? const Color(0xFF6F758E) : const Color(0xFFD9D2C3);
    final face = dark ? const Color(0xFF1A1A22) : const Color(0xFF3A3330);
    c.drawOval(
      Rect.fromCenter(center: at + Offset(0, s * 0.75), width: s * 2.4, height: s * 0.35),
      fill(const Color(0x33000000)),
    );
    for (final lx in [-0.55, -0.2, 0.25, 0.6]) {
      c.drawLine(at + Offset(lx * s, s * 0.2), at + Offset(lx * s, s * 0.72), stroke(face, s * 0.14));
    }
    final head = at + Offset(dir * s * 1.0, -s * 0.05 + graze * s * 0.45);
    c.drawPath(taper(at + Offset(dir * s * 0.6, -s * 0.1), head, s * 0.35, s * 0.3), fill(face));
    c.drawOval(Rect.fromCenter(center: head, width: s * 0.55, height: s * 0.42), fill(face));
    c.drawOval(
      Rect.fromCenter(center: head + Offset(-dir * s * 0.15, -s * 0.2), width: s * 0.3, height: s * 0.14),
      fill(face),
    );
    for (var k = 0; k < 6; k++) {
      final o = Offset((k % 3 - 1) * s * 0.45, (k ~/ 3) * s * 0.3 - s * 0.25);
      c.drawCircle(at + o, s * 0.38, fill(k < 3 ? wool : woolShade));
    }
    c.drawCircle(at + Offset(-s * 0.2, -s * 0.35), s * 0.3, fill(wool));
    c.drawCircle(at + Offset(s * 0.25, -s * 0.38), s * 0.28, fill(wool));
  }

  /// A small fire: a ring of stones, crossed logs, flickering flames,
  /// sparks and a thread of smoke.
  void _campfire(Canvas c, Offset at, double s, double t) {
    glow(
      c,
      at - Offset(0, s * 0.4),
      s * (3.2 + 0.25 * math.sin(t * 9)),
      fade(const Color(0xFFFFB25A), dark ? 0.32 : 0.18),
    );
    for (var k = 0; k < 7; k++) {
      final a = math.pi * (0.05 + 0.9 * k / 6);
      final p = at + Offset(math.cos(a) * s * 0.9, math.sin(a) * s * 0.28 + s * 0.05);
      c.drawOval(
        Rect.fromCenter(center: p, width: s * 0.42, height: s * 0.26),
        fill(dark ? const Color(0xFF4A4F63) : const Color(0xFF8D877A)),
      );
    }
    final log = dark ? const Color(0xFF2A1C14) : const Color(0xFF5A3E2A);
    c.drawPath(
      taper(at + Offset(-s * 0.7, s * 0.05), at + Offset(s * 0.6, -s * 0.15), s * 0.2, s * 0.17),
      fill(log),
    );
    c.drawPath(
      taper(at + Offset(s * 0.7, s * 0.05), at + Offset(-s * 0.6, -s * 0.15), s * 0.2, s * 0.17),
      fill(log),
    );
    for (final (col, scale) in [
      (const Color(0xFFE2572B), 1.0),
      (const Color(0xFFF59A3A), 0.72),
      (const Color(0xFFFFE08A), 0.42),
    ]) {
      final f = Path();
      final hgt = s * 1.25 * scale * (0.9 + 0.12 * math.sin(t * 11 + scale * 5));
      final wob = math.sin(t * 7 + scale * 3) * s * 0.12;
      f
        ..moveTo(at.dx - s * 0.45 * scale, at.dy - s * 0.05)
        ..quadraticBezierTo(at.dx - s * 0.5 * scale, at.dy - hgt * 0.55, at.dx + wob, at.dy - hgt)
        ..quadraticBezierTo(
          at.dx + s * 0.5 * scale,
          at.dy - hgt * 0.5,
          at.dx + s * 0.45 * scale,
          at.dy - s * 0.05,
        )
        ..close();
      c.drawPath(f, fill(col));
    }
    for (var k = 0; k < 6; k++) {
      final life = (t * 0.7 + hash(k * 13)) % 1.0;
      final sp = at + Offset(math.sin(t * 2 + k) * s * 0.4 * life, -s * (0.8 + 2.4 * life));
      c.drawCircle(sp, 1.3 * (1 - life) + 0.3, fill(fade(const Color(0xFFFFC46B), 1 - life)));
    }
    for (var k = 0; k < 5; k++) {
      final life = (t * 0.12 + k / 5) % 1.0;
      final sp = at + Offset(math.sin(t * 0.6 + k) * s * 0.6 + life * s * 1.2, -s * (1.6 + 5 * life));
      c.drawCircle(
        sp,
        s * (0.25 + 0.5 * life),
        fill(fade(dark ? const Color(0xFF9AA0B8) : const Color(0xFFE6E2D8), 0.22 * (1 - life))),
      );
    }
  }

  void _owl(Canvas c, Offset perch, double cw, double t) {
    final s = cw * 0.09;
    final ruffle = math.max(0.0, 1 - (t - owlAt) / 0.8);
    final bob = math.sin((t - owlAt) * 20) * ruffle * s * 0.6;
    final body = perch + Offset(0, -s * 4.2 + bob);
    final feather = dark ? const Color(0xFF6C5D4C) : const Color(0xFF8A6F52);
    final belly = dark ? const Color(0xFFA2927A) : const Color(0xFFD9C7A6);
    c.drawOval(Rect.fromCenter(center: body, width: s * 6.2, height: s * 8), fill(feather));
    c.drawOval(
      Rect.fromCenter(center: body + Offset(0, s * 1.2), width: s * 3.8, height: s * 5),
      fill(belly),
    );
    for (var k = 0; k < 3; k++) {
      c.drawArc(
        Rect.fromCenter(center: body + Offset(0, s * (0.2 + k * 1.2)), width: s * 2.2, height: s * 1.2),
        0.3,
        2.5,
        false,
        stroke(fade(feather, 0.7), s * 0.25),
      );
    }
    final head = body + Offset(0, -s * 4.4);
    c.drawOval(Rect.fromCenter(center: head, width: s * 5.6, height: s * 4.4), fill(feather));
    // Ear tufts.
    for (final d in [-1.0, 1.0]) {
      c.drawPath(
        Path()
          ..moveTo(head.dx + d * s * 1.4, head.dy - s * 1.6)
          ..lineTo(head.dx + d * s * 2.6, head.dy - s * 3.2)
          ..lineTo(head.dx + d * s * 2.6, head.dy - s * 1.2)
          ..close(),
        fill(feather),
      );
    }
    // Eyes: blink every few seconds.
    final blink = (t % 4.3) < 0.14 || ruffle > 0.5;
    for (final d in [-1.0, 1.0]) {
      final e = head + Offset(d * s * 1.25, -s * 0.1);
      c.drawCircle(e, s * 1.15, fill(belly));
      if (blink) {
        c.drawLine(e - Offset(s * 0.7, 0), e + Offset(s * 0.7, 0), stroke(const Color(0xFF2A1F14), s * 0.35));
      } else {
        c.drawCircle(e, s * 0.75, fill(dark ? const Color(0xFFF2C14E) : const Color(0xFFE0A030)));
        c.drawCircle(e, s * 0.38, fill(const Color(0xFF16100A)));
      }
    }
    c.drawPath(
      Path()
        ..moveTo(head.dx - s * 0.4, head.dy + s * 0.6)
        ..lineTo(head.dx + s * 0.4, head.dy + s * 0.6)
        ..lineTo(head.dx, head.dy + s * 1.5)
        ..close(),
      fill(const Color(0xFFC79A3E)),
    );
    // Feet.
    c.drawLine(
      perch + Offset(-s, -s * 0.2),
      perch + Offset(-s, s * 0.3),
      stroke(const Color(0xFFC79A3E), s * 0.45),
    );
    c.drawLine(
      perch + Offset(s, -s * 0.2),
      perch + Offset(s, s * 0.3),
      stroke(const Color(0xFFC79A3E), s * 0.45),
    );
  }

  @override
  bool shouldRepaint(covariant RestPainter old) =>
      old.dark != dark || old.owlAt != owlAt || old.skin.id != skin.id;
}
