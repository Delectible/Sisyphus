import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/laurels.dart';
import '../core/theme.dart';
import '../scene/kit.dart';

/// A laurel wreath: two curved branches of leaves, open at the top.
class WreathPainter extends CustomPainter {
  WreathPainter({required this.color, this.leafColor});
  final Color color;
  final Color? leafColor;

  @override
  void paint(Canvas canvas, Size size) {
    final r = size.shortestSide / 2 * 0.86;
    final ctr = size.center(Offset.zero);
    final stem = stroke(color, r * 0.05);
    final leaf = Paint()..color = leafColor ?? color;
    for (final side in [-1.0, 1.0]) {
      // Each branch runs from the bottom up the side, stopping short of the top.
      final path = Path();
      const a0 = math.pi / 2 + 0.25, a1 = math.pi * 1.5 - 0.55;
      for (var i = 0; i <= 20; i++) {
        final a = a0 + (a1 - a0) * i / 20;
        final pt = ctr + Offset(side * math.cos(a) * r, math.sin(a) * r);
        i == 0 ? path.moveTo(pt.dx, pt.dy) : path.lineTo(pt.dx, pt.dy);
      }
      canvas.drawPath(path, stem);
      for (var k = 0; k < 7; k++) {
        final a = a0 + (a1 - a0) * (k + 0.5) / 7;
        final at = ctr + Offset(side * math.cos(a) * r, math.sin(a) * r);
        final tangent = math.atan2(math.cos(a), -side * math.sin(a));
        for (final out in [1.0, -1.0]) {
          canvas.save();
          canvas.translate(at.dx, at.dy);
          canvas.rotate(tangent + out * 0.6 * side + math.pi);
          final len = r * (0.34 - k * 0.02);
          canvas.drawOval(Rect.fromCenter(center: Offset(0, -len / 2), width: len * 0.42, height: len), leaf);
          canvas.restore();
        }
      }
    }
    // The ribbon tie at the bottom.
    final tie = ctr + Offset(0, r * 0.98);
    canvas.drawCircle(tie, r * 0.08, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant WreathPainter old) => old.color != color || old.leafColor != leafColor;
}

class Wreath extends StatelessWidget {
  const Wreath({super.key, required this.earned, this.size = 56, this.child});
  final bool earned;
  final double size;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: WreathPainter(color: earned ? p.gold : p.line, leafColor: earned ? p.gold : p.line),
        child: Center(child: child),
      ),
    );
  }
}

/// A small boulder in a skin (laurels screen, previews).
class SkinStone extends StatelessWidget {
  const SkinStone({super.key, required this.skin, this.size = 54});
  final Skin skin;
  final double size;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: size,
    height: size,
    child: CustomPaint(painter: _StonePainter(skin)),
  );
}

class _StonePainter extends CustomPainter {
  _StonePainter(this.skin);
  final Skin skin;
  @override
  void paint(Canvas canvas, Size size) {
    final r = size.shortestSide / 2 * 0.9;
    final ctr = size.center(Offset.zero);
    canvas.drawOval(
      Rect.fromCenter(center: ctr + Offset(0, r * 0.95), width: r * 1.6, height: r * 0.22),
      fill(const Color(0x33000000)),
    );
    skinnedBoulder(canvas, ctr, r, skin, roll: 0.7);
  }

  @override
  bool shouldRepaint(covariant _StonePainter old) => old.skin.id != skin.id;
}

/// Slides a "Laurel earned" banner in from the top whenever [watch] has one.
class LaurelBanner extends StatefulWidget {
  const LaurelBanner({super.key, required this.watch});
  final LaurelWatch watch;

  @override
  State<LaurelBanner> createState() => _LaurelBannerState();
}

class _LaurelBannerState extends State<LaurelBanner> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 450),
  );
  Laurel? _showing;
  Timer? _hide;

  @override
  void initState() {
    super.initState();
    widget.watch.addListener(_next);
    WidgetsBinding.instance.addPostFrameCallback((_) => _next());
  }

  @override
  void dispose() {
    widget.watch.removeListener(_next);
    _hide?.cancel();
    _hide = null;
    _c.dispose();
    super.dispose();
  }

  void _next() {
    if (_showing != null || !mounted) return;
    final l = widget.watch.take();
    if (l == null) return;
    HapticFeedback.mediumImpact();
    setState(() => _showing = l);
    _c.forward(from: 0);
    _hide = Timer(const Duration(milliseconds: 3400), () async {
      if (!mounted) return;
      await _c.reverse();
      if (!mounted) return;
      setState(() => _showing = null);
      _next();
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = _showing;
    if (l == null) return const SizedBox.shrink();
    final p = Palette.of(context);
    final skin = l.skin == null ? null : skinById(l.skin!);
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        child: SlideTransition(
          position: Tween(
            begin: const Offset(0, -1.4),
            end: Offset.zero,
          ).animate(CurvedAnimation(parent: _c, curve: Curves.easeOutBack)),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Material(
              color: p.ink,
              elevation: 8,
              borderRadius: BorderRadius.circular(20),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 18, 10),
                child: Row(
                  children: [
                    Wreath(earned: true, size: 44, child: Icon(Icons.star_rounded, size: 14, color: p.gold)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('LAUREL EARNED', style: Type.label(p.gold, size: 10.5)),
                          const SizedBox(height: 2),
                          Text(l.name, style: Type.title(p.background, size: 16, weight: FontWeight.w700)),
                          if (skin != null)
                            Text(
                              'Unlocks the ${skin.name} stone',
                              style: Type.text(p.background.withValues(alpha: 0.7), size: 12),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
