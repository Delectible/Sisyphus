import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/rendering.dart' hide Gradient;

import 'clock.dart';
import 'kit.dart';

/// The end of the session: Sisyphus sitting against the boulder on the
/// summit, above a sea of clouds (sunset, or a starry night in dark mode).
class SummitPainter extends CustomPainter {
  SummitPainter(this.clock, {required this.dark}) : super(repaint: clock);

  final SceneClock clock;
  final bool dark;

  @override
  void paint(Canvas c, Size size) {
    final t = clock.t;
    final w = size.width, h = size.height;
    final plateau = h * 0.74;

    // Sky.
    vGradient(
      c,
      Offset.zero & size,
      dark
          ? const [Color(0xFF060A1C), Color(0xFF161C4A), Color(0xFF3A3769), Color(0xFF7E6178)]
          : const [Color(0xFF5E68A6), Color(0xFFB384A4), Color(0xFFF0A585), Color(0xFFFCD9A0)],
      const [0, 0.38, 0.62, 0.78],
    );
    final sun = Offset(w * 0.8, h * 0.5);
    if (dark) {
      stars(c, Rect.fromLTWH(0, 0, w, h * 0.55), t, const Color(0xFFFFFFFF), count: 120, seed: 9);
      final moon = Offset(w * 0.14, h * 0.17);
      glow(c, moon, w * 0.16, const Color(0x40D8DEFF));
      c.drawCircle(moon, w * 0.036, fill(const Color(0xFFF3F0E2)));
      c.drawCircle(moon + Offset(w * 0.015, -w * 0.008), w * 0.032, fill(const Color(0xFF121844)));
      glow(c, sun + Offset(0, h * 0.1), w * 0.7, const Color(0x30F2A982));
    } else {
      // Low sun with a soft corona and faint rays.
      final rays = Paint()..color = const Color(0x14FFF4D6);
      for (var i = 0; i < 9; i++) {
        final a = math.pi + 0.25 + i * 0.27 + math.sin(t * 0.05 + i) * 0.02;
        final a2 = a + 0.06;
        c.drawPath(
          Path()
            ..moveTo(sun.dx, sun.dy)
            ..lineTo(sun.dx + math.cos(a) * w * 1.4, sun.dy + math.sin(a) * w * 1.4)
            ..lineTo(sun.dx + math.cos(a2) * w * 1.4, sun.dy + math.sin(a2) * w * 1.4)
            ..close(),
          rays,
        );
      }
      glow(c, sun, w * 0.8, const Color(0x80FFE3A8));
      glow(c, sun, w * 0.22, const Color(0xAAFFF2D0));
      c.drawCircle(sun, w * 0.07, fill(const Color(0xFFFFF4D8)));
      // Two birds far off.
      for (var i = 0; i < 2; i++) {
        final bx = w * (0.25 + 0.12 * i) + math.sin(t * 0.2 + i) * 10;
        final by = h * (0.22 + 0.05 * i);
        final flap = math.sin(t * 4 + i * 2) * 2.5;
        c.drawPath(
          Path()
            ..moveTo(bx - 7, by - flap)
            ..quadraticBezierTo(bx - 3, by - 4, bx, by)
            ..quadraticBezierTo(bx + 3, by - 4, bx + 7, by - flap),
          stroke(const Color(0x995A4A5E), 1.4),
        );
      }
    }

    // Far ranges, hazier with distance.
    void range(double base, double amp, Color col, int seed, int n) {
      final p = Path()..moveTo(0, h);
      for (var i = 0; i <= n; i++) {
        final x = w * i / n;
        final peak = hash(seed * 31 + i);
        p.lineTo(x - w / n * 0.5, base - amp * (0.2 + 0.4 * hash(seed * 17 + i)));
        p.lineTo(x, base - amp * (0.4 + 0.6 * peak));
      }
      p
        ..lineTo(w, h)
        ..close();
      c.drawPath(p, fill(col));
    }

    range(h * 0.66, h * 0.16, dark ? const Color(0xFF2B2A57) : const Color(0xFFC4909F), 3, 5);
    range(h * 0.69, h * 0.1, dark ? const Color(0xFF34336A) : const Color(0xFFD99D9C), 5, 7);

    // Sea of clouds, lit from above.
    for (var row = 0; row < 3; row++) {
      final y = h * (0.72 + row * 0.08);
      final top = dark
          ? [const Color(0xFF6A6597), const Color(0xFF575387), const Color(0xFF464373)][row]
          : [const Color(0xFFFFE6CC), const Color(0xFFF9D2BC), const Color(0xFFF0BDB0)][row];
      final bottom = dark
          ? [const Color(0xFF3A3866), const Color(0xFF2F2D5A), const Color(0xFF26244C)][row]
          : [const Color(0xFFE8A9A0), const Color(0xFFDC9A98), const Color(0xFFCD8C92)][row];
      for (var i = 0; i < 7; i++) {
        final cw = w * (0.38 + 0.2 * hash(row * 10 + i));
        final x = ((i * w * 0.24 + t * (2 + row * 1.5) + hash(row * 50 + i) * 40) % (w + cw)) - cw / 2;
        final at = Offset(x, y);
        c.drawPath(
          cloud(at, cw, row * 10 + i),
          Paint()
            ..shader = Gradient.linear(at - Offset(0, cw * 0.3), at + Offset(0, cw * 0.06), [top, bottom]),
        );
      }
    }

    // The summit: a broad rocky crown with facets, lit from the right.
    final edge = <Offset>[
      Offset(-w * 0.02, h * 1.02),
      Offset(w * 0.06, h * 0.9),
      Offset(w * 0.12, h * 0.86),
      Offset(w * 0.17, plateau + h * 0.03),
      Offset(w * 0.24, plateau + h * 0.005),
      Offset(w * 0.4, plateau - h * 0.004),
      Offset(w * 0.58, plateau + h * 0.002),
      Offset(w * 0.74, plateau + h * 0.01),
      Offset(w * 0.8, plateau + h * 0.035),
      Offset(w * 0.86, h * 0.84),
      Offset(w * 0.93, h * 0.9),
      Offset(w * 1.02, h * 1.02),
    ];
    final rock = Path()..moveTo(edge.first.dx, edge.first.dy);
    for (final e in edge.skip(1)) {
      rock.lineTo(e.dx, e.dy);
    }
    rock.close();
    final rockDark = dark ? const Color(0xFF12111F) : const Color(0xFF33252F);
    final rockMid = dark ? const Color(0xFF1F1C33) : const Color(0xFF4E3639);
    final rockLit = dark ? const Color(0xFF3B2F4A) : const Color(0xFF8A574A);
    c.drawPath(
      rock,
      Paint()
        ..shader = Gradient.linear(
          Offset(w * 0.2, 0),
          Offset(w * 0.9, 0),
          [rockDark, rockMid, rockLit],
          const [0, 0.55, 1],
        ),
    );
    c.save();
    c.clipPath(rock);
    // Facets: lit planes on the right, shadowed planes on the left.
    void facet(List<Offset> pts, Color col) {
      final p = Path()..moveTo(pts.first.dx, pts.first.dy);
      for (final q in pts.skip(1)) {
        p.lineTo(q.dx, q.dy);
      }
      c.drawPath(p..close(), fill(col));
    }

    facet([
      Offset(w * 0.74, plateau + h * 0.01),
      Offset(w * 0.8, plateau + h * 0.035),
      Offset(w * 0.86, h * 0.84),
      Offset(w * 0.93, h * 0.9),
      Offset(w * 0.78, h),
      Offset(w * 0.66, h * 0.86),
    ], fade(rockLit, 0.55));
    facet([
      Offset(w * 0.17, plateau + h * 0.03),
      Offset(w * 0.24, plateau + h * 0.005),
      Offset(w * 0.3, h * 0.86),
      Offset(w * 0.22, h),
      Offset(w * 0.06, h * 0.9),
    ], fade(rockDark, 0.6));
    facet([
      Offset(w * 0.4, plateau + h * 0.03),
      Offset(w * 0.58, plateau + h * 0.03),
      Offset(w * 0.62, h * 0.9),
      Offset(w * 0.45, h),
    ], fade(rockMid, 0.6));
    // Ledge just under the top and a few cracks.
    c.drawPath(
      Path()
        ..moveTo(w * 0.2, plateau + h * 0.035)
        ..quadraticBezierTo(w * 0.48, plateau + h * 0.05, w * 0.78, plateau + h * 0.04),
      stroke(fade(const Color(0xFF000000), 0.28), 2),
    );
    for (var i = 0; i < 6; i++) {
      final x = w * (0.2 + 0.6 * hash(i * 7 + 3));
      final y0 = plateau + h * (0.06 + 0.1 * hash(i * 5));
      c.drawPath(
        Path()
          ..moveTo(x, y0)
          ..lineTo(x + (hash(i) - 0.5) * 14, y0 + 10)
          ..lineTo(x + (hash(i + 9) - 0.5) * 20, y0 + 24),
        stroke(fade(const Color(0xFF000000), 0.22), 1.2),
      );
    }
    // Warm light skimming the top surface.
    c.drawRect(
      Rect.fromLTRB(0, plateau - h * 0.01, w, plateau + h * 0.04),
      Paint()
        ..shader = Gradient.linear(Offset(w * 0.2, 0), Offset(w * 0.85, 0), [
          fade(rockLit, 0),
          fade(dark ? const Color(0xFFE9A98A) : const Color(0xFFFFB27A), dark ? 0.12 : 0.28),
        ]),
    );

    // Boulder and Sisyphus, with shadows cast left along the rock (sun right).
    final br = math.min(w * 0.135, h * 0.13);
    final u = br / 50;
    final bc = Offset(w * 0.4, plateau - br * 0.96);
    final shadow = Paint()
      ..shader = Gradient.linear(Offset(bc.dx + br, 0), Offset(bc.dx - br * 3.4, 0), [
        fade(const Color(0xFF000000), 0.55),
        fade(const Color(0xFF000000), 0),
      ]);
    c.drawPath(
      Path()
        ..moveTo(bc.dx + br * 0.6, plateau)
        ..quadraticBezierTo(bc.dx - br * 1.5, plateau - h * 0.012, bc.dx - br * 3.4, plateau + h * 0.006)
        ..quadraticBezierTo(bc.dx - br * 1.5, plateau + h * 0.03, bc.dx + br * 0.6, plateau + h * 0.012)
        ..close(),
      shadow,
    );
    c.drawPath(
      Path()
        ..moveTo(bc.dx + br * 2.3, plateau)
        ..quadraticBezierTo(bc.dx + br * 1.2, plateau + h * 0.006, bc.dx + br * 0.4, plateau + h * 0.008)
        ..lineTo(bc.dx + br * 2.3, plateau + h * 0.014)
        ..close(),
      fill(fade(const Color(0xFF000000), 0.35)),
    );
    // Pebbles and dry tufts.
    for (var i = 0; i < 9; i++) {
      final x = w * (0.2 + 0.58 * hash(i * 13 + 1));
      if ((x - bc.dx).abs() < br * 1.1) continue;
      final r = 1.5 + 3 * hash(i * 3);
      c.drawOval(
        Rect.fromCenter(center: Offset(x, plateau + 1), width: r * 2.6, height: r * 1.4),
        fill(rockDark),
      );
      c.drawOval(
        Rect.fromCenter(center: Offset(x + r * 0.4, plateau), width: r * 1.2, height: r * 0.6),
        fill(fade(rockLit, 0.8)),
      );
    }
    for (final x in [w * 0.22, w * 0.27, w * 0.71, w * 0.76]) {
      final sway = math.sin(t * 1.4 + x) * 1.5;
      for (var k = -2; k <= 2; k++) {
        c.drawLine(
          Offset(x + k * 1.6, plateau + 1),
          Offset(x + k * 3 + sway, plateau - 7 + k.abs() * 1.5),
          stroke(rockDark, 1.1),
        );
      }
    }
    c.restore();
    // Rim light along the lit crest.
    c.drawPath(
      Path()
        ..moveTo(w * 0.52, plateau)
        ..lineTo(w * 0.58, plateau + h * 0.002)
        ..lineTo(w * 0.74, plateau + h * 0.01)
        ..lineTo(w * 0.8, plateau + h * 0.035)
        ..lineTo(w * 0.86, h * 0.84)
        ..lineTo(w * 0.93, h * 0.9),
      stroke(dark ? const Color(0x88F2A982) : const Color(0xDDFFC98A), 1.6),
    );

    // Contact shadow right under the stone.
    c.drawOval(
      Rect.fromCenter(center: Offset(bc.dx, plateau), width: br * 1.5, height: br * 0.16),
      Paint()
        ..color = fade(const Color(0xFF000000), 0.6)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
    );
    boulder(
      c,
      bc,
      br,
      roll: 1.1,
      base: dark ? const Color(0xFF3A3550) : const Color(0xFF6B5150),
      lit: dark ? const Color(0xFFB08C98) : const Color(0xFFF6C090),
      shade: dark ? const Color(0xFF110F1C) : const Color(0xFF2A1E25),
      light: const Offset(0.85, 0.05),
    );
    // Warm bounce light from the rock on the stone's lower right.
    c.save();
    c.clipPath(Path()..addOval(Rect.fromCircle(center: bc, radius: br)));
    glow(
      c,
      bc + Offset(br * 0.8, br * 0.9),
      br * 0.7,
      dark ? const Color(0x22E9A98A) : const Color(0x33FFB27A),
    );
    c.restore();

    _figure(c, Offset(bc.dx + 41 * u, plateau), u, t);
  }

  /// Sitting with his back against the stone, knees up, an arm draped over
  /// a knee, head tipped back toward the sky. [hip] on the ground; [u] is
  /// one fiftieth of the boulder's radius.
  void _figure(Canvas c, Offset hip, double u, double t) {
    final ink = dark ? const Color(0xFF0C0A17) : const Color(0xFF24171E);
    final far = dark ? const Color(0xFF07060F) : const Color(0xFF1A1016);
    final rim = dark ? const Color(0xFFEFB394) : const Color(0xFFFFD49A);
    final breath = math.sin(t * 1.1) * 0.8;
    Offset p(double x, double y) => hip + Offset(x * u, -y * u);
    Path limb(double x0, double y0, double x1, double y1, double w0, double w1) =>
        taper(p(x0, y0), p(x1, y1), w0 * u, w1 * u);

    List<Path> body() {
      final b = <Path>[];
      // Torso, seat and tunic as one outline.
      b.add(
        Path()
          ..moveTo(p(-9, 1).dx, p(-9, 1).dy)
          ..cubicTo(
            p(-11, 14).dx,
            p(-11, 14).dy,
            p(-4, 40).dx,
            p(-4, 40).dy,
            p(4, 58 + breath).dx,
            p(4, 58 + breath).dy,
          )
          ..cubicTo(
            p(8, 63 + breath).dx,
            p(8, 63 + breath).dy,
            p(16, 64 + breath).dx,
            p(16, 64 + breath).dy,
            p(21, 61 + breath).dx,
            p(21, 61 + breath).dy,
          )
          ..cubicTo(p(25, 52).dx, p(25, 52).dy, p(25, 40).dx, p(25, 40).dy, p(24, 30).dx, p(24, 30).dy)
          // tunic hem over the thigh
          ..lineTo(p(36, 38).dx, p(36, 38).dy)
          ..lineTo(p(34, 31).dx, p(34, 31).dy)
          ..lineTo(p(26, 22).dx, p(26, 22).dy)
          ..cubicTo(p(20, 8).dx, p(20, 8).dy, p(12, 0).dx, p(12, 0).dy, p(4, -1).dx, p(4, -1).dy)
          ..close(),
      );
      // Near leg: thigh to knee, shin, foot.
      b.add(limb(10, 10, 44, 40, 17, 11));
      b.add(limb(44, 40, 52, 5, 11, 7));
      b.add(limb(49, 3, 62, 1.5, 7, 4.5));
      // Neck and head (tipped back, face up and right).
      b.add(limb(14, 60 + breath, 19, 70 + breath, 9, 8));
      b.add(Path()..addOval(Rect.fromCircle(center: p(17, 77 + breath), radius: 8.6 * u)));
      // Nose and brow.
      b.add(
        Path()
          ..moveTo(p(23, 82 + breath).dx, p(23, 82 + breath).dy)
          ..lineTo(p(28.5, 81 + breath).dx, p(28.5, 81 + breath).dy)
          ..lineTo(p(24.5, 77.5 + breath).dx, p(24.5, 77.5 + breath).dy)
          ..close(),
      );
      // Beard.
      b.add(
        Path()
          ..moveTo(p(17, 72 + breath).dx, p(17, 72 + breath).dy)
          ..quadraticBezierTo(
            p(27, 72 + breath).dx,
            p(27, 72 + breath).dy,
            p(25.5, 76 + breath).dx,
            p(25.5, 76 + breath).dy,
          )
          ..lineTo(p(23, 77 + breath).dx, p(23, 77 + breath).dy)
          ..lineTo(p(22, 68 + breath).dx, p(22, 68 + breath).dy)
          ..close(),
      );
      // Curls at the back of the head.
      for (var k = 0; k < 5; k++) {
        final a = 1.9 + k * 0.42;
        b.add(
          Path()..addOval(
            Rect.fromCircle(center: p(17 + math.cos(a) * 8, 77 + breath + math.sin(a) * 8), radius: 3.6 * u),
          ),
        );
      }
      // Arm: shoulder to elbow on the knee, forearm hanging, loose hand.
      b.add(limb(14, 57 + breath, 41, 45, 9, 7.5));
      b.add(limb(41, 45, 50, 30, 7, 5.5));
      b.add(limb(50, 30, 52, 23, 5.5, 4.5));
      return b;
    }

    // Far leg behind, darker.
    final farLeg = [
      limb(14, 8, 50, 35, 15, 10),
      limb(50, 35, 60, 4, 10, 6.5),
      limb(57, 2.5, 70, 1.5, 6.5, 4.5),
    ];
    for (final q in farLeg) {
      c.drawPath(q.shift(Offset(u * 1.4, -u * 0.4)), fill(rim));
    }
    for (final q in farLeg) {
      c.drawPath(q, fill(far));
    }

    // Rim light on the sun-facing edges, then the figure over it.
    final parts = body();
    for (final q in parts) {
      c.drawPath(q.shift(Offset(u * 1.3, -u * 0.5)), fill(rim));
    }
    for (final q in parts) {
      c.drawPath(q, fill(ink));
    }
    // Shadow under him.
    c.drawOval(
      Rect.fromCenter(center: hip + Offset(u * 20, 0), width: u * 70, height: u * 4),
      Paint()
        ..color = fade(const Color(0xFF000000), 0.45)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
    );
  }

  @override
  bool shouldRepaint(covariant SummitPainter old) => old.dark != dark;
}

/// The home medallion: black-figure Sisyphus pushing his stone up a slope,
/// in a ring with a Greek key, like the inside of a kylix.
class MedallionPainter extends CustomPainter {
  MedallionPainter({required this.dark});
  final bool dark;

  @override
  void paint(Canvas c, Size size) {
    final r = size.shortestSide / 2;
    final ctr = size.center(Offset.zero);
    final clay = dark ? const Color(0xFFB45E3A) : const Color(0xFFC86B42);
    final ink = dark ? const Color(0xFF15100E) : const Color(0xFF1E1714);
    c.drawCircle(ctr, r, fill(ink));
    c.drawCircle(ctr, r * 0.95, fill(clay));
    // Key ring.
    final ring = r * 0.83;
    final band = stroke(ink, r * 0.022)..strokeCap = StrokeCap.square;
    c.drawCircle(ctr, r * 0.92, band);
    c.drawCircle(ctr, ring - r * 0.02, band);
    const n = 28;
    for (var i = 0; i < n; i++) {
      final a0 = i / n * math.pi * 2;
      final a1 = (i + 0.7) / n * math.pi * 2;
      Offset at(double a, double rr) => ctr + Offset(math.cos(a), math.sin(a)) * rr;
      final ri = ring + r * 0.01, ro = r * 0.9;
      final rm = (ri + ro) / 2;
      c.drawPath(
        Path()
          ..moveTo(at(a0, ri).dx, at(a0, ri).dy)
          ..lineTo(at(a0, ro).dx, at(a0, ro).dy)
          ..lineTo(at(a1, ro).dx, at(a1, ro).dy)
          ..lineTo(at(a1, rm).dx, at(a1, rm).dy)
          ..lineTo(at((a0 + a1) / 2, rm).dx, at((a0 + a1) / 2, rm).dy),
        band,
      );
    }
    // Inside: slope and figure.
    c.save();
    c.clipPath(Path()..addOval(Rect.fromCircle(center: ctr, radius: ring - r * 0.03)));
    final slope = Path()
      ..moveTo(ctr.dx - r, ctr.dy + r * 0.62)
      ..lineTo(ctr.dx + r, ctr.dy - r * 0.05)
      ..lineTo(ctr.dx + r, ctr.dy + r)
      ..lineTo(ctr.dx - r, ctr.dy + r)
      ..close();
    c.drawPath(slope, fill(ink));
    c.save();
    c.translate(ctr.dx - r * 0.5, ctr.dy - r * 0.38);
    c.rotate(-0.33);
    pusherFigure(c, Rect.fromLTWH(0, 0, r * 0.95, r * 0.95), ink);
    c.restore();
    // Incised highlights (red-figure detail lines on the stone).
    c.drawArc(
      Rect.fromCircle(center: ctr + Offset(r * 0.25, -r * 0.31), radius: r * 0.16),
      3.6,
      1.2,
      false,
      stroke(fade(clay, 0.8), r * 0.015),
    );
    c.restore();
  }

  @override
  bool shouldRepaint(covariant MedallionPainter old) => old.dark != dark;
}
