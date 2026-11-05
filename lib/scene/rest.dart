import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/rendering.dart' hide Gradient;

import 'clock.dart';
import 'kit.dart';

/// The valley: lying in the grass at the foot of the mountain, the boulder
/// waiting nearby. Calm light, slow clouds, an owl on a broken column.
class RestPainter extends CustomPainter {
  RestPainter(this.clock, {required this.dark, this.owlAt = -100}) : super(repaint: clock);

  final SceneClock clock;
  final bool dark;

  /// Clock time the owl was last tapped (it ruffles).
  final double owlAt;

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
    boulder(
      c,
      bc,
      br,
      roll: 0.6,
      base: dark ? const Color(0xFF5B5C66) : const Color(0xFF9C968A),
      lit: dark ? const Color(0xFF8D90A6) : const Color(0xFFD8D0BE),
      shade: dark ? const Color(0xFF24252E) : const Color(0xFF55504A),
      light: dark ? const Offset(0.5, -0.6) : const Offset(0.55, -0.6),
    );

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

    _owl(c, Offset(colBase.dx, colBase.dy - colH - colW * 0.05), colW, t);

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
  bool shouldRepaint(covariant RestPainter old) => old.dark != dark || old.owlAt != owlAt;
}
