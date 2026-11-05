import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/format.dart';
import '../core/scope.dart';
import '../core/session.dart';
import '../core/settings.dart';
import '../core/theme.dart';
import '../scene/summit.dart';
import '../widgets/common.dart';
import 'climb_screen.dart';
import 'laurels_screen.dart';
import 'settings_screen.dart';
import 'stats_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final p = Palette.of(context);
    final s = scope.settings;
    return Scaffold(
      body: SafeArea(
        child: ListenableBuilder(
          listenable: Listenable.merge([s, scope.stats]),
          builder: (context, _) => LayoutBuilder(
            builder: (context, box) => SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: box.maxHeight - 28),
                child: IntrinsicHeight(
                  child: Column(
                    children: [
                      Row(
                        children: [
                          _TopButton(
                            icon: Icons.leaderboard_outlined,
                            label: 'Stats',
                            onTap: () => _push(context, const StatsScreen()),
                          ),
                          const Spacer(),
                          _TopButton(
                            icon: Icons.emoji_events_outlined,
                            label: 'Laurels',
                            onTap: () => _push(context, const LaurelsScreen()),
                          ),
                          const Spacer(),
                          _TopButton(
                            icon: Icons.tune,
                            label: 'Settings',
                            onTap: () => _push(context, const SettingsScreen()),
                          ),
                        ],
                      ),
                      const Spacer(),
                      Container(
                        width: 172,
                        height: 172,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(color: Color(0x33000000), blurRadius: 30, offset: Offset(0, 12)),
                          ],
                        ),
                        child: CustomPaint(painter: MedallionPainter(dark: p.brightness == Brightness.dark)),
                      ),
                      const SizedBox(height: 18),
                      GestureDetector(
                        onLongPress: () {
                          HapticFeedback.mediumImpact();
                          ScaffoldMessenger.of(
                            context,
                          ).showSnackBar(const SnackBar(content: Text('Roll the stone. Rest. Roll again.')));
                        },
                        child: Text('SISYPHUS', style: Type.title(p.ink, size: 34, weight: FontWeight.w700)),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'One must imagine Sisyphus happy.',
                        style: Type.title(
                          p.muted,
                          size: 14,
                          weight: FontWeight.w400,
                        ).copyWith(letterSpacing: 1.2),
                      ),
                      const SizedBox(height: 2),
                      Text('Albert Camus', style: Type.text(p.muted.withValues(alpha: 0.7), size: 12)),
                      const SizedBox(height: 14),
                      KeyBand(color: p.line),
                      const SizedBox(height: 14),
                      _Presets(settings: s),
                      const SizedBox(height: 10),
                      _Labels(settings: s),
                      const SizedBox(height: 12),
                      Panel(
                        padding: const EdgeInsets.fromLTRB(18, 6, 10, 6),
                        child: Column(
                          children: [
                            _Stepper(
                              label: 'Ascent',
                              hint: 'focus',
                              value: s.focus,
                              unit: 'min',
                              onChanged: (v) => s.focus = v,
                              min: Settings.minFocus,
                              max: Settings.maxFocus,
                              step: (v, up) => up ? (v < 10 ? 1 : 5) : (v <= 10 ? 1 : 5),
                            ),
                            Divider(height: 1, color: p.line),
                            _Stepper(
                              label: 'Rest',
                              hint: 'break',
                              value: s.rest,
                              unit: 'min',
                              onChanged: (v) => s.rest = v,
                              min: Settings.minRest,
                              max: Settings.maxRest,
                              step: (v, up) => up ? (v < 10 ? 1 : 5) : (v <= 10 ? 1 : 5),
                            ),
                            Divider(height: 1, color: p.line),
                            _Stepper(
                              label: 'Climbs',
                              hint: 'rounds',
                              value: s.climbs,
                              unit: '',
                              onChanged: (v) => s.climbs = v,
                              min: Settings.minClimbs,
                              max: Settings.maxClimbs,
                              step: (v, up) => 1,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(_summary(s), style: Type.text(p.muted, size: 13.5), textAlign: TextAlign.center),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        child: PillButton(
                          label: 'Begin the ascent',
                          icon: Icons.landscape_outlined,
                          onTap: () {
                            scope.expedition.begin();
                            Navigator.of(context).push(_fade(const ClimbScreen()));
                          },
                        ),
                      ),
                      const Spacer(),
                      const SizedBox(height: 18),
                      if (scope.stats.sessions > 0)
                        GestureDetector(
                          onTap: () => _push(context, const StatsScreen()),
                          child: Text(
                            '${scope.stats.mountains} ${scope.stats.mountains == 1 ? 'mountain' : 'mountains'} climbed'
                            '  ·  ${hours(scope.stats.focus)} h of focus',
                            style: Type.label(p.muted, size: 11),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  static String _summary(Settings s) {
    final now = DateTime.now();
    final plan = Session(
      focusMinutes: s.focus,
      restMinutes: s.rest,
      climbs: s.climbs,
      started: now,
      longRestMinutes: s.longRest ? s.longMinutes : 0,
      longEvery: s.longEvery,
    );
    final total = plan.plannedTotal;
    return '${span(plan.plannedFocus)} of focus  ·  ${span(total)} in all  ·  summit at ${timeOfDay(now.add(total))}';
  }

  static void _push(BuildContext context, Widget w) =>
      Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => w));
}

Route<void> _fade(Widget w) => PageRouteBuilder<void>(
  transitionDuration: const Duration(milliseconds: 700),
  pageBuilder: (_, _, _) => w,
  transitionsBuilder: (_, a, _, child) => FadeTransition(
    opacity: CurvedAnimation(parent: a, curve: Curves.easeInOut),
    child: child,
  ),
);

class _TopButton extends StatelessWidget {
  const _TopButton({required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return TextButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 19, color: p.ink),
      label: Text(label.toUpperCase(), style: Type.label(p.ink, size: 11)),
    );
  }
}

class _Presets extends StatelessWidget {
  const _Presets({required this.settings});
  final Settings settings;

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    const presets = [('Classic', 25, 5), ('Deep', 50, 10), ('Brief', 15, 3)];
    return Row(
      children: [
        for (final (name, f, r) in presets)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Builder(
                builder: (context) {
                  final on = settings.focus == f && settings.rest == r;
                  return Material(
                    color: on ? p.ink : Colors.transparent,
                    shape: StadiumBorder(side: BorderSide(color: on ? p.ink : p.line)),
                    child: InkWell(
                      customBorder: const StadiumBorder(),
                      onTap: () {
                        HapticFeedback.selectionClick();
                        settings.preset(f, r);
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 9),
                        child: Column(
                          children: [
                            Text(name.toUpperCase(), style: Type.label(on ? p.background : p.ink, size: 11)),
                            const SizedBox(height: 2),
                            Text(
                              '$f / $r',
                              style: Type.text(on ? p.background.withValues(alpha: 0.7) : p.muted, size: 12),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
      ],
    );
  }
}

class _Stepper extends StatelessWidget {
  const _Stepper({
    required this.label,
    required this.hint,
    required this.value,
    required this.unit,
    required this.onChanged,
    required this.min,
    required this.max,
    required this.step,
  });

  final String label, hint, unit;
  final int value, min, max;
  final ValueChanged<int> onChanged;
  final int Function(int value, bool up) step;

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label.toUpperCase(), style: Type.label(p.ink, size: 13)),
                Text(hint, style: Type.text(p.muted, size: 12.5)),
              ],
            ),
          ),
          _RoundButton(
            icon: Icons.remove,
            enabled: value > min,
            onStep: () => onChanged(value - step(value, false)),
          ),
          SizedBox(
            width: 78,
            child: Column(
              children: [
                Text('$value', style: Type.number(p.ink, size: 26)),
                if (unit.isNotEmpty) Text(unit, style: Type.text(p.muted, size: 11)),
              ],
            ),
          ),
          _RoundButton(
            icon: Icons.add,
            enabled: value < max,
            onStep: () => onChanged(value + step(value, true)),
          ),
        ],
      ),
    );
  }
}

/// +/- that repeats while held.
class _RoundButton extends StatefulWidget {
  const _RoundButton({required this.icon, required this.enabled, required this.onStep});
  final IconData icon;
  final bool enabled;
  final VoidCallback onStep;

  @override
  State<_RoundButton> createState() => _RoundButtonState();
}

class _RoundButtonState extends State<_RoundButton> {
  Timer? _repeat;

  void _stop() {
    _repeat?.cancel();
    _repeat = null;
  }

  @override
  void dispose() {
    _stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return GestureDetector(
      onTap: widget.enabled
          ? () {
              HapticFeedback.selectionClick();
              widget.onStep();
            }
          : null,
      onLongPressStart: widget.enabled
          ? (_) => _repeat = Timer.periodic(const Duration(milliseconds: 110), (_) {
              if (!mounted) return _stop();
              widget.onStep();
            })
          : null,
      onLongPressEnd: (_) => _stop(),
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: widget.enabled ? p.line : p.line.withValues(alpha: 0.4)),
        ),
        child: Icon(widget.icon, size: 20, color: widget.enabled ? p.ink : p.muted.withValues(alpha: 0.4)),
      ),
    );
  }
}

/// What the next session is for: a row of label chips (tap to pick, long
/// press to remove, + to add).
class _Labels extends StatelessWidget {
  const _Labels({required this.settings});
  final Settings settings;

  Future<void> _add(BuildContext context) async {
    final ctrl = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('NEW LABEL'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          maxLength: 18,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(hintText: 'Reading, Code, Thesis...'),
          onSubmitted: (v) => Navigator.pop(context, v),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCEL')),
          TextButton(onPressed: () => Navigator.pop(context, ctrl.text), child: const Text('ADD')),
        ],
      ),
    );
    if (name != null) settings.addLabel(name);
  }

  Future<void> _remove(BuildContext context, String name) async {
    unawaited(HapticFeedback.mediumImpact());
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('REMOVE "${name.toUpperCase()}"?'),
        content: const Text('Its past focus stays in the ledger.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('KEEP')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('REMOVE')),
        ],
      ),
    );
    if (ok == true) settings.removeLabel(name);
  }

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    Widget chip(String text, bool on, VoidCallback onTap, {VoidCallback? onLong, IconData? icon}) => Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Material(
        color: on ? p.olive : Colors.transparent,
        shape: StadiumBorder(side: BorderSide(color: on ? p.olive : p.line)),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: () {
            HapticFeedback.selectionClick();
            onTap();
          },
          onLongPress: onLong,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) Icon(icon, size: 15, color: on ? p.background : p.muted),
                if (icon != null && text.isNotEmpty) const SizedBox(width: 4),
                if (text.isNotEmpty)
                  Text(
                    text,
                    style: Type.text(on ? p.background : p.ink, size: 13.5, weight: FontWeight.w500),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
    return SizedBox(
      height: 36,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          Center(
            child: Padding(
              padding: const EdgeInsets.only(left: 4, right: 10),
              child: Text('FOR', style: Type.label(p.muted, size: 10.5)),
            ),
          ),
          for (final l in settings.labels)
            chip(
              l,
              settings.label == l,
              () => settings.label = settings.label == l ? null : l,
              onLong: () => _remove(context, l),
            ),
          chip('', false, () => _add(context), icon: Icons.add),
        ],
      ),
    );
  }
}
