import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/rendering.dart' hide Gradient;

import '../core/laurels.dart';
import 'clock.dart';
import 'kit.dart';

/// What the ascent painter needs besides the clock.
class AscentState {
  /// How far up this climb, 0..1.
  double progress = 0;

  /// Clock times of shoves (Motivate) still settling, the distance of the
  /// ones that have settled, and the last slip.
  final List<double> shoves = [];
  double shoveBase = 0;
  double slipAt = -100;

  /// Ground each shove adds (world units) and how fast it eases in.
  static const shoveDistance = 1.2;
  static const shoveRate = 4.0;

  /// Adds a shove at clock time [t]. Shoves older than 3 s have settled
  /// (within a millionth) and fold into [shoveBase], so the ground never
  /// jumps however fast Motivate is tapped.
  void shove(double t) {
    shoves.removeWhere((s) {
      if (t - s < 3) return false;
      shoveBase += shoveDistance;
      return true;
    });
    shoves.add(t);
  }

  bool dark = false;

  /// The boulder's stone (a laurel reward).
  Skin skin = skins.first;

  /// Paused (or waiting): Sisyphus eases to a stop and leans on the stone.
  bool paused = false;

  /// 0 (standing still) .. 1 (climbing), eased toward [paused].
  double motion = 1;

  /// Climbing time: clock time scaled by [motion], so steps and the ground
  /// slow down and stop smoothly instead of freezing.
  double walkT = 0;
  double _lastT = double.nan;

  /// Moves the climb on to clock time [t] (once per frame).
  void advance(double t) {
    final dt = _lastT.isNaN ? 0.0 : (t - _lastT).clamp(0.0, 0.25);
    _lastT = t;
    final target = paused ? 0.0 : 1.0;
    // About 0.7 s to stop, a little quicker to get going again.
    final rate = paused ? 3.2 : 4.0;
    motion += (target - motion) * (1 - math.exp(-dt * rate));
    if ((motion - target).abs() < 0.001) motion = target;
    walkT += dt * motion;
  }
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
  double walked(double t) {
    final m = state.walkT;
    var w = m * 0.55 + 0.12 * math.sin(m * math.pi * 2 / _period) + state.shoveBase;
    for (final s in state.shoves) {
      final d = t - s;
      if (d > 0) w += AscentState.shoveDistance * (1 - math.exp(-d * AscentState.shoveRate));
    }
    // The slip eases back to nothing (gone to a thousandth by 12 s).
    final ds = t - state.slipAt;
    if (ds > 0 && ds < 12) w -= 2.2 * math.sin(math.min(ds / 0.6, 1) * math.pi / 2) * math.exp(-ds * 0.9);
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

    // Camera bob with each step (and a jolt on a shove / slip). Standing
    // still, only slow breathing.
    state.advance(t);
    final m = state.walkT;
    final rest = 1 - state.motion;
    final step = math.sin(m * math.pi * 2 / _period);
    final breathe = math.sin(t * 1.3) * rest;
    c.save();
    c.translate(
      math.sin(m * math.pi / _period) * 2.5,
      step * 3.5 * state.motion + breathe * 2.5 - kick * 6 + slip * 14,
    );
    final full = Rect.fromLTWH(-10, -20, w + 20, h + 40);

    // Sky: heavy, brightening a touch near the top of the climb.
    final skyTop = dark ? const Color(0xFF0E1017) : const Color(0xFF555C68);
    final skyLow = dark ? const Color(0xFF292B37) : const Color(0xFF9A9EA3);
    final horizonY = h * 0.27;
    vGradient(c, Rect.fromLTRB(full.left, full.top, full.right, h * 0.6), [
      mix(skyTop, const Color(0xFF8C93A0), flash * 0.6 + p * 0.08),
      mix(skyLow, const Color(0xFFD9D4C2), flash * 0.5 + p * 0.25),
    ]);
    if (dark) stars(c, Rect.fromLTWH(0, 0, w, horizonY), t, const Color(0x55FFFFFF), count: 22);

    // The slope's geometry: rises toward the viewer; the ridge comes closer
    // as we climb.
    final ground = h * 0.95;
    double yAt(double z) => horizonY + (ground - horizonY) / z;
    double xAt(double x, double z) => w / 2 + x * (w * 0.32) / z;
    final ridgeZ = 30 - 26 * smooth(p);
    final ridgeY = yAt(ridgeZ);

    // Light behind the ridge: the top is near.
    glow(
      c,
      Offset(w / 2, ridgeY),
      w * (0.6 + 0.4 * p),
      fade(dark ? const Color(0xFF8C7DBA) : const Color(0xFFFFE2AE), 0.1 + 0.32 * smooth(p)),
    );

    // Distant ranges, layered and hazy.
    void range(double base, double amp, Color col, int seed, int n) {
      final r = Path()..moveTo(full.left, h);
      for (var i = 0; i <= n; i++) {
        final x = full.left + full.width * i / n;
        r.lineTo(x - full.width / n * 0.5, base - amp * (0.2 + 0.35 * hash(seed * 17 + i)));
        r.lineTo(x, base - amp * (0.45 + 0.55 * hash(seed * 31 + i)));
      }
      r
        ..lineTo(full.right, h)
        ..close();
      c.drawPath(r, fill(col));
    }

    final shrink = 1 - p * 0.4;
    range(horizonY + 4, 46 * shrink, dark ? const Color(0xFF1C1E29) : const Color(0xFF858A93), 2, 6);
    range(horizonY + 8, 30 * shrink, dark ? const Color(0xFF22242F) : const Color(0xFF777C84), 4, 9);

    if (strikes && since > 0 && since < 0.35) {
      _bolt(c, Offset(w * (0.15 + 0.7 * hash(win * 3)), 0), horizonY, win);
    }

    // Storm clouds drifting, dark underneath.
    final cloudTop = dark ? const Color(0xFF2A2D3A) : const Color(0xFF6D7480);
    final cloudBottom = dark ? const Color(0xFF12131A) : const Color(0xFF424852);
    for (var i = 0; i < 7; i++) {
      final speed = 4 + hash(i * 5) * 6;
      final cw = w * (0.5 + 0.45 * hash(i * 9));
      final x = ((hash(i * 3) * (w + cw) + t * speed) % (w + cw * 1.2)) - cw * 0.6;
      final y = h * (0.0 + 0.22 * hash(i * 11));
      final at = Offset(x, y);
      c.drawPath(
        cloud(at, cw, i + 2),
        Paint()
          ..shader = Gradient.linear(at - Offset(0, cw * 0.3), at + Offset(0, cw * 0.08), [
            fade(cloudTop, 0.85),
            fade(cloudBottom, 0.95),
          ]),
      );
    }

    // Ravens circling far off.
    for (var i = 0; i < 3; i++) {
      final a = t * (0.18 + 0.05 * i) + i * 2.1;
      final rx = w * (0.18 + 0.05 * i), ry = h * 0.03;
      final bx = w * (0.62 - 0.08 * i) + math.cos(a) * rx;
      final by = horizonY - h * (0.1 + 0.03 * i) + math.sin(a) * ry;
      final flap = math.sin(t * 5 + i * 1.7) * 2.2;
      final bs = 5.5 - i * 0.8;
      c.drawPath(
        Path()
          ..moveTo(bx - bs, by - flap)
          ..quadraticBezierTo(bx - bs * 0.4, by - bs * 0.35, bx, by)
          ..quadraticBezierTo(bx + bs * 0.4, by - bs * 0.35, bx + bs, by - flap),
        stroke(dark ? const Color(0xCC07080C) : const Color(0xCC2A2D33), 1.5),
      );
    }
    if (flash > 0) c.drawRect(full, fill(fade(const Color(0xFFE8ECFF), flash * 0.18)));

    // Crags flanking the far end of the path.
    final cliffCol = dark ? const Color(0xFF1A1B22) : const Color(0xFF615D57);
    final cliffLit = dark ? const Color(0xFF2B2D3B) : const Color(0xFF8A847A);
    for (final side in [-1.0, 1.0]) {
      final base = ridgeY + 8;
      final x0 = side < 0 ? full.left : full.right;
      final reach = w * (0.34 + 0.08 * p);
      final height = h * (0.05 + 0.05 * smooth(p));
      final pts = <Offset>[Offset(x0, base + h * 0.03)];
      for (var k = 0; k <= 7; k++) {
        final f = k / 7;
        final hgt = height * (1 - f * f) * (0.55 + 0.45 * hash(k * 13 + (side < 0 ? 1 : 2)));
        pts.add(Offset(x0 - side * reach * f, base - hgt));
      }
      pts.add(Offset(x0 - side * reach, base + 2));
      final crag = Path()..moveTo(pts.first.dx, pts.first.dy);
      for (final q in pts.skip(1)) {
        crag.lineTo(q.dx, q.dy);
      }
      crag.close();
      c.drawPath(crag, fill(cliffCol));
      // Lit facets on the side facing the path, and cracks.
      for (var k = 1; k < 7; k += 2) {
        final a0 = pts[k], a1 = pts[k + 1];
        c.drawPath(
          Path()
            ..moveTo(a0.dx, a0.dy)
            ..lineTo(a1.dx, a1.dy)
            ..lineTo(a1.dx + side * 3, base)
            ..lineTo(a0.dx - side * 6, base)
            ..close(),
          fill(fade(cliffLit, 0.55)),
        );
        c.drawLine(a0, Offset(a0.dx - side * 4, base), stroke(fade(const Color(0xFF000000), 0.25), 1));
      }
    }

    // The slope.
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
    // The path: worn smooth by the stone, forever.
    final pathCol = dark ? const Color(0xFF26262C) : const Color(0xFF5E574C);
    final track = Path()
      ..moveTo(xAt(-0.25, ridgeZ), ridgeY + 2)
      ..lineTo(xAt(0.25, ridgeZ), ridgeY + 2)
      ..lineTo(xAt(1.25, 0.9), yAt(0.9))
      ..lineTo(xAt(-1.25, 0.9), yAt(0.9))
      ..close();
    c.drawPath(
      track,
      Paint()
        ..shader = Gradient.linear(Offset(0, ridgeY), Offset(0, h), [
          fade(pathCol, 0.15),
          fade(pathCol, 0.55),
        ]),
    );
    for (final edge in [-1.0, 1.0]) {
      final berm = Path()
        ..moveTo(xAt(edge * 0.27, ridgeZ), ridgeY + 2)
        ..lineTo(xAt(edge * 1.3, 0.9), yAt(0.9));
      c.drawPath(berm, stroke(fade(dark ? const Color(0xFF4A4A52) : const Color(0xFFA59C8B), 0.5), 2.2));
    }

    // Ridge-top markers: a dead tree and a cairn, nearer as we climb.
    {
      final sc = (6 / ridgeZ).clamp(0.2, 1.4);
      final ink = dark ? const Color(0xFF0D0E12) : const Color(0xFF3A3632);
      final tx = xAt(4.2, ridgeZ), ty = ridgeY + 3;
      final trunkH = h * 0.11 * sc;
      c.drawPath(taper(Offset(tx, ty), Offset(tx - trunkH * 0.1, ty - trunkH), 7 * sc, 2.5 * sc), fill(ink));
      for (final (f, ang, len) in [(0.55, -0.9, 0.45), (0.7, 0.7, 0.4), (0.85, -0.4, 0.3), (0.4, 1.1, 0.3)]) {
        final from = Offset(tx - trunkH * 0.1 * f, ty - trunkH * f);
        final to = from + Offset(math.sin(ang) * trunkH * len, -math.cos(ang) * trunkH * len);
        c.drawPath(taper(from, to, 3 * sc, 1.2 * sc), fill(ink));
      }
      final cx = xAt(-3.4, ridgeZ);
      for (var k = 0; k < 4; k++) {
        final r = (9 - k * 1.8) * sc;
        c.drawOval(
          Rect.fromCenter(
            center: Offset(cx + (k.isEven ? 1 : -1) * sc, ty - r * 0.7 - k * 8 * sc),
            width: r * 2.2,
            height: r * 1.3,
          ),
          fill(ink),
        );
      }
    }

    // Mist lying along the ridge.
    final mist = dark ? const Color(0xFF3A3D4C) : const Color(0xFFC9C8C0);
    final mistRect = Rect.fromLTRB(full.left, ridgeY - h * 0.03, full.right, ridgeY + h * 0.05);
    c.drawRect(
      mistRect,
      Paint()
        ..shader = Gradient.linear(
          mistRect.topCenter,
          mistRect.bottomCenter,
          [fade(mist, 0), fade(mist, 0.28 + 0.06 * math.sin(t * 0.3)), fade(mist, 0)],
          const [0, 0.45, 1],
        ),
    );

    // Stones, tufts, thistles, bones, shards and cracks, coming toward us.
    final walked = this.walked(t);
    final (bc, br) = boulderAt(size);
    final contactY = bc.dy + br * 0.92;
    final items = <(double z, double x, int i)>[];
    const depth = 14.0;
    for (var i = 0; i < 120; i++) {
      final z = 0.85 + ((hash(i * 17) * depth - walked) % depth + depth) % depth;
      if (z > ridgeZ) continue;
      final big = hash(i * 59) < 0.12;
      // Big rocks keep to the sides of the path.
      final x = big
          ? (hash(i * 23) < 0.5 ? -1.0 : 1.0) * (2.2 + hash(i * 61) * 2.5)
          : (hash(i * 23) - 0.5) * 8;
      items.add((z, x, i));
    }
    items.sort((a, b) => b.$1.compareTo(a.$1));
    final rockCol = dark ? const Color(0xFF55545A) : const Color(0xFF7A7266);
    final rockLit = dark ? const Color(0xFF7C7B86) : const Color(0xFFB6AD9C);
    void drawItem((double, double, int) it) {
      final (z, x, i) = it;
      final y = yAt(z);
      final sx = xAt(x, z);
      final s = (w * 0.05) / z;
      final fog = ((z - 1) / ridgeZ).clamp(0.0, 1.0);
      final big = hash(i * 59) < 0.12;
      final kind = hash(i * 41);
      Color fogged(Color col) => mix(col, slopeFar, fog * 0.7);
      if (big) {
        // A large boulder by the path, with a lit top and a crack.
        final r = s * (2.2 + 1.6 * hash(i * 67));
        c.drawOval(
          Rect.fromCenter(center: Offset(sx, y), width: r * 2.6, height: r * 0.5),
          fill(fade(const Color(0xFF000000), 0.3)),
        );
        final rock = Path()
          ..moveTo(sx - r * 1.2, y)
          ..lineTo(sx - r * 1.0, y - r * 0.8)
          ..lineTo(sx - r * 0.3, y - r * 1.25)
          ..lineTo(sx + r * 0.6, y - r * 1.1)
          ..lineTo(sx + r * 1.2, y - r * 0.4)
          ..lineTo(sx + r * 1.15, y)
          ..close();
        c.drawPath(rock, fill(fogged(rockCol)));
        c.drawPath(
          Path()
            ..moveTo(sx - r * 1.0, y - r * 0.8)
            ..lineTo(sx - r * 0.3, y - r * 1.25)
            ..lineTo(sx + r * 0.6, y - r * 1.1)
            ..lineTo(sx + r * 0.2, y - r * 0.7)
            ..lineTo(sx - r * 0.6, y - r * 0.65)
            ..close(),
          fill(fogged(rockLit)),
        );
        c.drawLine(
          Offset(sx + r * 0.2, y - r * 0.7),
          Offset(sx + r * 0.35, y),
          stroke(fade(const Color(0xFF000000), 0.3), math.max(0.8, s * 0.1)),
        );
        // Moss on the shadow side.
        c.drawOval(
          Rect.fromCenter(center: Offset(sx + r * 0.7, y - r * 0.25), width: r * 0.7, height: r * 0.3),
          fill(fade(fogged(dark ? const Color(0xFF3A4430) : const Color(0xFF6F7A45)), 0.7)),
        );
      } else if (kind < 0.36) {
        c.drawOval(
          Rect.fromCenter(center: Offset(sx, y + s * 0.15), width: s * 2.3, height: s * 0.5),
          fill(fade(const Color(0xFF000000), 0.25)),
        );
        c.drawOval(
          Rect.fromCenter(center: Offset(sx, y - s * 0.2), width: s * 2, height: s * 1.1),
          fill(fogged(rockCol)),
        );
        c.drawOval(
          Rect.fromCenter(center: Offset(sx - s * 0.3, y - s * 0.45), width: s * 0.8, height: s * 0.35),
          fill(fade(const Color(0xFFFFFFFF), dark ? 0.06 : 0.14)),
        );
      } else if (kind < 0.62) {
        final col = fogged(dark ? const Color(0xFF3C4232) : const Color(0xFF6F6A45));
        final sway = math.sin(t * 1.3 + i) * s * 0.25;
        for (var k = -2; k <= 2; k++) {
          c.drawLine(
            Offset(sx + k * s * 0.2, y),
            Offset(sx + k * s * 0.45 + sway, y - s * (1.4 - k.abs() * 0.25)),
            stroke(col, math.max(0.8, s * 0.12)),
          );
        }
      } else if (kind < 0.72) {
        // Thistle: stalk, spiky leaves, a purple head nodding in the wind.
        final sway = math.sin(t * 1.1 + i) * s * 0.3;
        final head = Offset(sx + sway, y - s * 2.2);
        final stalk = fogged(dark ? const Color(0xFF3B4436) : const Color(0xFF66704A));
        c.drawLine(Offset(sx, y), head, stroke(stalk, math.max(0.8, s * 0.12)));
        c.drawLine(
          Offset(sx, y - s * 0.8),
          Offset(sx - s * 0.6, y - s * 1.1),
          stroke(stalk, math.max(0.6, s * 0.1)),
        );
        c.drawLine(
          Offset(sx, y - s * 1.2),
          Offset(sx + s * 0.6, y - s * 1.5),
          stroke(stalk, math.max(0.6, s * 0.1)),
        );
        c.drawCircle(head, s * 0.35, fill(stalk));
        c.drawCircle(
          head - Offset(0, s * 0.3),
          s * 0.3,
          fill(fogged(dark ? const Color(0xFF6A4C7A) : const Color(0xFF9B6BB0))),
        );
      } else if (kind < 0.8) {
        // A shard of an old amphora.
        final shard = fogged(dark ? const Color(0xFF6E3E2C) : const Color(0xFFB0603F));
        c.drawArc(
          Rect.fromCenter(center: Offset(sx, y), width: s * 1.8, height: s * 1.1),
          3.4,
          1.8,
          true,
          fill(shard),
        );
        c.drawArc(
          Rect.fromCenter(center: Offset(sx, y), width: s * 1.8, height: s * 1.1),
          3.6,
          1.2,
          false,
          stroke(fade(const Color(0xFF1E1714), 0.6), math.max(0.6, s * 0.08)),
        );
      } else if (kind < 0.86) {
        // Bleached bone.
        final bone = fogged(dark ? const Color(0xFF9C9A92) : const Color(0xFFE6DFCC));
        final a = Offset(sx - s * 0.8, y), b = Offset(sx + s * 0.8, y - s * 0.2);
        c.drawLine(a, b, stroke(bone, math.max(0.8, s * 0.22)));
        c.drawCircle(a, s * 0.2, fill(bone));
        c.drawCircle(b, s * 0.2, fill(bone));
      } else {
        c.drawLine(
          Offset(sx - s * 1.5, y),
          Offset(sx + s * 1.2, y + s * 0.15),
          stroke(fade(const Color(0xFF000000), 0.25), math.max(0.6, s * 0.08)),
        );
        c.drawLine(
          Offset(sx + s * 0.2, y + s * 0.05),
          Offset(sx + s * 0.6, y - s * 0.3),
          stroke(fade(const Color(0xFF000000), 0.18), math.max(0.5, s * 0.06)),
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
    skinnedBoulder(
      c,
      bc + Offset(0, -kick * 4),
      br,
      dark ? state.skin.night : state.skin,
      roll: rollR,
      spin: math.sin(t * 0.3) * 0.05,
      light: const Offset(-0.35, -0.75),
    );
    if (flash > 0) {
      c.drawCircle(bc, br, fill(fade(const Color(0xFFDDE4FF), flash * 0.12)));
    }

    for (final it in items) {
      if (yAt(it.$1) >= contactY) drawItem(it);
    }

    // Weather: rain at night, wind-blown dust by day.
    if (dark) {
      final rain = stroke(const Color(0x22B8C4E0), 1);
      for (var k = 0; k < 70; k++) {
        final speed = 520 + 200 * hash(k * 3);
        final x = (hash(k * 7) * (w + 80) + t * 60) % (w + 80) - 40;
        final y = (hash(k * 11) * h + t * speed) % (h + 40) - 20;
        c.drawLine(Offset(x, y), Offset(x - 4, y + 14), rain);
      }
    } else {
      for (var k = 0; k < 26; k++) {
        final x = (hash(k * 7) * (w + 60) + t * (30 + 25 * hash(k))) % (w + 60) - 30;
        final y = h * (0.35 + 0.55 * hash(k * 13)) + math.sin(t * 0.8 + k) * 14;
        c.drawCircle(
          Offset(x, y),
          0.8 + 1.4 * hash(k * 5),
          fill(fade(const Color(0xFFE8DCC4), 0.25 + 0.2 * hash(k))),
        );
      }
    }

    // The hands.
    final push = kick * 0.08 - slip * 0.1;
    final skin = dark ? const Color(0xFF9A6E54) : const Color(0xFFC88C64);
    final skinLit = dark ? const Color(0xFFB98A6C) : const Color(0xFFE2AE86);
    final skinDark = dark ? const Color(0xFF5E3F2E) : const Color(0xFF8D5A3D);
    for (final side in [-1, 1]) {
      final phase = (side < 0 ? step : -step) * state.motion + breathe * 0.5;
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
