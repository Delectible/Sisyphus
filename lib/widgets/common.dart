import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/theme.dart';
import '../scene/kit.dart';

/// A Greek-key divider.
class KeyBand extends StatelessWidget {
  const KeyBand({super.key, this.color, this.height = 22, this.unit = 4});
  final Color? color;
  final double height;
  final double unit;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: height,
    width: double.infinity,
    child: CustomPaint(painter: _KeyPainter(color ?? Palette.of(context).line, unit)),
  );
}

class _KeyPainter extends CustomPainter {
  _KeyPainter(this.color, this.unit);
  final Color color;
  final double unit;
  @override
  void paint(Canvas canvas, Size size) => meander(canvas, Offset.zero & size, color, unit: unit);
  @override
  bool shouldRepaint(covariant _KeyPainter old) => old.color != color;
}

/// The big pill button (Begin, Climb again).
class PillButton extends StatelessWidget {
  const PillButton({super.key, required this.label, required this.onTap, this.filled = true, this.icon});
  final String label;
  final VoidCallback onTap;
  final bool filled;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final fg = filled ? const Color(0xFFFFF8EE) : p.ink;
    return Material(
      color: filled ? p.terracotta : Colors.transparent,
      shape: StadiumBorder(side: filled ? BorderSide.none : BorderSide(color: p.line, width: 1.4)),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 17),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[Icon(icon, size: 18, color: fg), const SizedBox(width: 10)],
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(label.toUpperCase(), style: Type.label(fg, size: 14, weight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A card-ish surface.
class Panel extends StatelessWidget {
  const Panel({super.key, required this.child, this.padding = const EdgeInsets.all(18)});
  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: p.line),
      ),
      child: child,
    );
  }
}
