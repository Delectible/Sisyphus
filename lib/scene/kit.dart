import 'dart:math' as math;
import 'dart:ui';

/// Small drawing helpers shared by the scenes.

/// Deterministic 0..1 noise for an integer seed.
double hash(int n) {
  var x = (n * 374761393 + 668265263) & 0x7fffffff;
  x = ((x ^ (x >> 13)) * 1274126177) & 0x7fffffff;
  return (x & 0xffffff) / 0xffffff;
}

double smooth(double x) {
  final c = x.clamp(0.0, 1.0);
  return c * c * (3 - 2 * c);
}

Color mix(Color a, Color b, double t) => Color.lerp(a, b, t.clamp(0.0, 1.0))!;

Color fade(Color c, double alpha) => c.withValues(alpha: (c.a * alpha).clamp(0.0, 1.0));

Paint fill(Color c) => Paint()
  ..color = c
  ..isAntiAlias = true;

Paint stroke(Color c, double w) => Paint()
  ..color = c
  ..style = PaintingStyle.stroke
  ..strokeWidth = w
  ..strokeCap = StrokeCap.round
  ..strokeJoin = StrokeJoin.round
  ..isAntiAlias = true;

/// A vertical gradient filling [r].
void vGradient(Canvas c, Rect r, List<Color> colors, [List<double>? stops]) {
  c.drawRect(r, Paint()..shader = Gradient.linear(r.topCenter, r.bottomCenter, colors, stops));
}

/// A soft glow (radial falloff).
void glow(Canvas c, Offset at, double radius, Color color) {
  c.drawCircle(at, radius, Paint()..shader = Gradient.radial(at, radius, [color, fade(color, 0)]));
}

/// A rounded line between two points, thicker at [a] than at [b].
Path taper(Offset a, Offset b, double wa, double wb) {
  final d = b - a;
  final len = d.distance;
  if (len == 0) return Path()..addOval(Rect.fromCircle(center: a, radius: wa / 2));
  final n = Offset(-d.dy / len, d.dx / len);
  return Path()
    ..moveTo(a.dx + n.dx * wa / 2, a.dy + n.dy * wa / 2)
    ..lineTo(b.dx + n.dx * wb / 2, b.dy + n.dy * wb / 2)
    ..arcToPoint(b - n * (wb / 2), radius: Radius.circular(wb / 2), clockwise: false)
    ..lineTo(a.dx - n.dx * wa / 2, a.dy - n.dy * wa / 2)
    ..arcToPoint(a + n * (wa / 2), radius: Radius.circular(wa / 2), clockwise: false)
    ..close();
}

/// A puffy cloud: overlapping circles along a line, flat-ish bottom.
Path cloud(Offset at, double w, int seed) {
  final p = Path();
  final n = 5 + (hash(seed) * 3).floor();
  for (var i = 0; i < n; i++) {
    final f = i / (n - 1);
    final r = w * (0.13 + 0.12 * math.sin(f * math.pi) + 0.05 * hash(seed * 7 + i));
    p.addOval(Rect.fromCircle(center: at + Offset((f - 0.5) * w * 0.8, -r * 0.45), radius: r));
  }
  p.addRRect(
    RRect.fromRectAndRadius(
      Rect.fromCenter(center: at, width: w * 0.95, height: w * 0.16),
      Radius.circular(w * 0.08),
    ),
  );
  return p;
}

/// Stars that twinkle slowly, in the top [r] of the canvas.
void stars(Canvas c, Rect r, double t, Color color, {int count = 70, int seed = 3}) {
  final p = Paint();
  for (var i = 0; i < count; i++) {
    final x = r.left + hash(seed * 1000 + i) * r.width;
    final y = r.top + math.pow(hash(seed * 2000 + i), 1.6) * r.height;
    final tw = 0.55 + 0.45 * math.sin(t * (0.6 + hash(i) * 1.4) + i);
    final size = 0.6 + hash(seed * 3000 + i) * 1.3;
    p.color = fade(color, tw * (0.35 + 0.65 * hash(i * 31)));
    c.drawCircle(Offset(x, y), size, p);
  }
}

/// The boulder: a shaded sphere whose speckles turn with [roll] (radians,
/// rolling away from the viewer / up the slope). Light from [light]
/// (unit-ish offset toward the lit side).
void boulder(
  Canvas c,
  Offset center,
  double r, {
  required double roll,
  required Color base,
  required Color lit,
  required Color shade,
  Offset light = const Offset(-0.45, -0.55),
  double spin = 0,
  int seed = 11,
}) {
  final rect = Rect.fromCircle(center: center, radius: r);
  c.drawCircle(
    center,
    r,
    Paint()
      ..shader = Gradient.radial(
        center + Offset(light.dx * r * 0.75, light.dy * r * 0.75),
        r * 1.65,
        [lit, base, shade, mix(shade, const Color(0xFF000000), 0.35)],
        [0.0, 0.38, 0.8, 1.0],
      ),
  );
  c.save();
  c.clipPath(Path()..addOval(rect));
  // Speckles, lichen and chips on the sphere, turning with the roll.
  final cr = math.cos(roll), sr = math.sin(roll);
  final cs = math.cos(spin), ss = math.sin(spin);
  final dots = Paint();
  for (var i = 0; i < 46; i++) {
    final lat = math.asin(hash(seed * 100 + i) * 2 - 1);
    final lon = hash(seed * 200 + i) * math.pi * 2;
    var x = math.cos(lat) * math.sin(lon);
    final y = math.sin(lat);
    var z = math.cos(lat) * math.cos(lon);
    // roll about the x axis (front goes up), then a little spin about z.
    final y2 = y * cr + z * sr;
    final z2 = -y * sr + z * cr;
    z = z2;
    final x3 = x * cs - y2 * ss;
    final y3 = x * ss + y2 * cs;
    x = x3;
    if (z <= 0.05) continue;
    final at = center + Offset(x * r, -y3 * r);
    final size = r * (0.03 + 0.09 * hash(seed * 300 + i));
    final kind = hash(seed * 400 + i);
    final shadeAmt = (0.5 + 0.5 * (-(x * light.dx + y3 * -light.dy))).clamp(0.0, 1.0);
    dots.color = kind < 0.55
        ? fade(mix(shade, const Color(0xFF000000), 0.2), 0.32 * z)
        : kind < 0.8
        ? fade(mix(lit, base, shadeAmt), 0.4 * z)
        : fade(const Color(0xFF7D8A5A), 0.22 * z);
    c.save();
    c.translate(at.dx, at.dy);
    c.rotate(math.atan2(-y3, x));
    // foreshortened toward the rim.
    c.drawOval(Rect.fromCenter(center: Offset.zero, width: size * 2 * z, height: size * 2), dots);
    c.restore();
  }
  // A crack or two.
  for (var k = 0; k < 2; k++) {
    final lat0 = (hash(seed + k * 17) - 0.5) * 1.6;
    final lon0 = hash(seed + k * 29) * math.pi * 2;
    final path = Path();
    var started = false;
    for (var j = 0; j < 7; j++) {
      final lat = lat0 + j * 0.09;
      final lon = lon0 + math.sin(j * 1.7 + k) * 0.08;
      final x = math.cos(lat) * math.sin(lon);
      final y = math.sin(lat);
      final z0 = math.cos(lat) * math.cos(lon);
      final y2 = y * cr + z0 * sr;
      final z2 = -y * sr + z0 * cr;
      if (z2 <= 0.1) {
        started = false;
        continue;
      }
      final pt = center + Offset((x * cs - y2 * ss) * r, -(x * ss + y2 * cs) * r);
      if (!started) {
        path.moveTo(pt.dx, pt.dy);
        started = true;
      } else {
        path.lineTo(pt.dx, pt.dy);
      }
    }
    c.drawPath(path, stroke(fade(shade, 0.7), r * 0.012));
  }
  // Ambient occlusion along the bottom and a rim of reflected light.
  c.drawCircle(
    center,
    r,
    Paint()
      ..shader = Gradient.linear(center + Offset(0, r * 0.2), center + Offset(0, r), [
        fade(const Color(0xFF000000), 0),
        fade(const Color(0xFF000000), 0.35),
      ]),
  );
  c.restore();
  c.drawCircle(center, r - 0.5, stroke(fade(mix(shade, const Color(0xFF000000), 0.5), 0.6), 1.2));
}

/// Black-figure Sisyphus pushing a boulder (side view), for the home
/// medallion and small marks. Drawn in a 111 x 100-unit box (100 = [box]'s
/// width), ground line at y = 98.
void pusherFigure(Canvas c, Rect box, Color ink, {double step = 0}) {
  final s = box.width / 100;
  Offset p(double x, double y) => box.topLeft + Offset(x * s, y * s);
  final w = Paint()..color = ink;
  // Boulder ahead, resting on the ground line (y = 98).
  c.drawCircle(p(81, 68), 30 * s, w);
  // Head (bent forward), beard.
  c.drawCircle(p(38, 37), 6.4 * s, w);
  c.drawPath(
    Path()
      ..moveTo(p(42, 39).dx, p(42, 39).dy)
      ..lineTo(p(46, 45).dx, p(46, 45).dy)
      ..lineTo(p(39, 43).dx, p(39, 43).dy)
      ..close(),
    w,
  );
  // Torso leaning into the stone.
  c.drawPath(taper(p(26, 66), p(41, 44), 13 * s, 11 * s), w);
  // Arms, palms flat on the stone.
  c.drawPath(taper(p(39, 47), p(57, 50), 4.6 * s, 4 * s), w);
  c.drawPath(taper(p(41, 51), p(54.5, 56), 4.6 * s, 4 * s), w);
  // Tunic.
  c.drawPath(
    Path()
      ..moveTo(p(21, 60).dx, p(21, 60).dy)
      ..lineTo(p(33, 62).dx, p(33, 62).dy)
      ..lineTo(p(31, 76).dx, p(31, 76).dy)
      ..lineTo(p(15, 74).dx, p(15, 74).dy)
      ..close(),
    w,
  );
  // Legs: back leg pushing, front leg bent.
  final b = step * 2;
  c.drawPath(taper(p(22, 72), p(8 - b, 96), 6.5 * s, 4.5 * s), w);
  c.drawPath(taper(p(28, 72), p(36 + b, 82), 6.5 * s, 5 * s), w);
  c.drawPath(taper(p(36 + b, 82), p(33 + b, 96), 5 * s, 4.2 * s), w);
  // Feet.
  c.drawPath(taper(p(8 - b, 96), p(2 - b, 98.5), 4 * s, 3 * s), w);
  c.drawPath(taper(p(33 + b, 96), p(39 + b, 96.5), 4 * s, 3 * s), w);
}

/// A Greek key (meander) band along [r]'s width, centred vertically.
void meander(Canvas c, Rect r, Color color, {double unit = 6}) {
  final paint = stroke(color, unit * 0.32)..strokeCap = StrokeCap.square;
  final cell = unit * 4;
  final n = (r.width / cell).floor();
  if (n <= 0) return;
  final x0 = r.left + (r.width - n * cell) / 2;
  final top = r.center.dy - unit * 1.5;
  final path = Path()..moveTo(x0, top + unit * 3);
  for (var i = 0; i < n; i++) {
    final x = x0 + i * cell;
    path
      ..lineTo(x, top + unit * 3)
      ..lineTo(x, top)
      ..lineTo(x + unit * 3, top)
      ..lineTo(x + unit * 3, top + unit * 2)
      ..lineTo(x + unit, top + unit * 2)
      ..lineTo(x + unit, top + unit)
      ..lineTo(x + unit * 2, top + unit)
      ..moveTo(x + unit * 3, top + unit * 3)
      ..lineTo(x + cell, top + unit * 3);
  }
  c.drawPath(path, paint);
  c.drawLine(Offset(x0, top - unit), Offset(x0 + n * cell, top - unit), paint);
  c.drawLine(Offset(x0, top + unit * 4), Offset(x0 + n * cell, top + unit * 4), paint);
}
