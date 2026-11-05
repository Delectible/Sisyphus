import 'package:flutter/material.dart';

import '../core/format.dart';
import '../core/poems.dart';
import '../core/scope.dart';
import '../core/stats.dart';
import '../core/theme.dart';
import '../scene/clock.dart';
import '../scene/summit.dart';
import '../widgets/common.dart';
import 'climb_screen.dart';
import 'home_screen.dart';

/// The end of a session: Sisyphus at rest on the peak, the numbers, a poem.
class SummitScreen extends StatefulWidget {
  const SummitScreen({super.key, this.record});

  /// Shown instead of the expedition's last record (previews, tests).
  final SessionRecord? record;

  @override
  State<SummitScreen> createState() => _SummitScreenState();
}

class _SummitScreenState extends State<SummitScreen> {
  final clock = SceneClock();
  SessionRecord? _record;
  Poem? _poem;

  @override
  void initState() {
    super.initState();
    clock.start();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final scope = AppScope.of(context);
    clock
      ..still = scope.settings.stillScenes
      ..fps = scope.settings.fps;
    if (_record == null) {
      _record = widget.record ?? scope.expedition.last;
      final r = _record;
      if (r != null) {
        _poem = choosePoem(r, mountainsBefore: scope.stats.mountains - (r.summited ? 1 : 0));
      }
      if (widget.record == null) scope.expedition.close();
    }
  }

  @override
  void dispose() {
    clock.dispose();
    super.dispose();
  }

  void _home() {
    final nav = Navigator.of(context);
    if (nav.canPop()) {
      nav.pop();
    } else {
      nav.pushReplacement(MaterialPageRoute<void>(builder: (_) => const HomeScreen()));
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final r = _record;
    final dark = p.brightness == Brightness.dark;
    return Scaffold(
      body: LayoutBuilder(
        builder: (context, box) {
          final sceneH = box.maxHeight * 0.44;
          return SingleChildScrollView(
            child: Column(
              children: [
                SizedBox(
                  height: sceneH,
                  width: double.infinity,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      RepaintBoundary(
                        child: CustomPaint(painter: SummitPainter(clock, dark: dark)),
                      ),
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: -1,
                        height: 90,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [p.background.withValues(alpha: 0), p.background],
                            ),
                          ),
                        ),
                      ),
                      SafeArea(
                        child: Padding(
                          padding: const EdgeInsets.only(top: 18),
                          child: Align(
                            alignment: Alignment.topCenter,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  r == null || r.summited ? 'THE SUMMIT' : 'A SUMMIT, OF SORTS',
                                  style:
                                      Type.title(
                                        const Color(0xFFFFF6E6),
                                        size: 26,
                                        weight: FontWeight.w700,
                                      ).copyWith(
                                        shadows: const [Shadow(blurRadius: 12, color: Color(0x66000000))],
                                      ),
                                ),
                                const SizedBox(height: 4),
                                if (r != null)
                                  Text(
                                    '${timeOfDay(r.start)} – ${timeOfDay(r.end)}',
                                    style: Type.text(const Color(0xE6FFF6E6), size: 13).copyWith(
                                      shadows: const [Shadow(blurRadius: 8, color: Color(0x66000000))],
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
                  child: Column(
                    children: [
                      if (r != null) _Numbers(r: r),
                      const SizedBox(height: 22),
                      if (_poem != null) ...[
                        KeyBand(color: p.line, unit: 3.5),
                        const SizedBox(height: 16),
                        for (final line in _poem!.lines)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 2.5),
                            child: Text(
                              line,
                              textAlign: TextAlign.center,
                              style: Type.title(
                                p.ink,
                                size: 15,
                                weight: FontWeight.w400,
                              ).copyWith(letterSpacing: 0.6, height: 1.35),
                            ),
                          ),
                        const SizedBox(height: 16),
                        KeyBand(color: p.line, unit: 3.5),
                      ],
                      const SizedBox(height: 26),
                      Row(
                        children: [
                          Expanded(
                            child: PillButton(label: 'Home', filled: false, onTap: _home),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: PillButton(
                              label: 'Climb again',
                              onTap: () {
                                AppScope.of(context).expedition.begin();
                                Navigator.of(context).pushReplacement(
                                  MaterialPageRoute<void>(builder: (_) => const ClimbScreen()),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _Numbers extends StatelessWidget {
  const _Numbers({required this.r});
  final SessionRecord r;

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final cells = [
      ('Focus', span(r.focus)),
      ('Climbs', '${r.climbsDone} / ${r.climbsPlanned}'),
      ('Shoves', '${r.shoves}'),
      ('Skips', '${r.skips}'),
    ];
    return Panel(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 6),
      child: Row(
        children: [
          for (final (k, v) in cells)
            Expanded(
              child: Column(
                children: [
                  Text(v, style: Type.number(p.ink, size: 21)),
                  const SizedBox(height: 2),
                  Text(k.toUpperCase(), style: Type.label(p.muted, size: 9.5)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
