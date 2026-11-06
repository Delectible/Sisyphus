import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../core/ambience.dart';
import '../core/format.dart';
import '../core/laurels.dart';
import '../core/poems.dart';
import '../core/scope.dart';
import '../core/stats.dart';
import '../core/theme.dart';
import '../scene/clock.dart';
import '../scene/summit.dart';
import '../widgets/common.dart';
import '../widgets/laurel.dart';
import 'climb_screen.dart';
import 'home_screen.dart';

/// The end of a session: Sisyphus at rest on the peak, the numbers, the
/// laurels earned on the way, a poem, and a card to share.
class SummitScreen extends StatefulWidget {
  const SummitScreen({super.key, this.record});

  /// Shown instead of the expedition's last record (previews, tests).
  final SessionRecord? record;

  @override
  State<SummitScreen> createState() => _SummitScreenState();
}

class _SummitScreenState extends State<SummitScreen> {
  final clock = SceneClock();
  final _card = GlobalKey();
  SessionRecord? _record;
  Poem? _poem;
  List<Laurel> _earned = const [];
  bool _sound = false;

  /// Climb again: the next session keeps the wind going.
  bool _continuing = false;
  bool _sharing = false;

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
      if (widget.record == null) {
        _earned = newlyEarned(scope.stats, scope.expedition.laurelsAtStart);
        scope.expedition.close();
      }
      _sound = scope.settings.sound;
      if (_sound) unawaited(Ambience.instance.play(true));
    }
  }

  @override
  void dispose() {
    if (_sound && !_continuing) unawaited(Ambience.instance.play(false));
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

  /// Renders the card (scene, numbers, poem) to a PNG and opens the share
  /// sheet.
  Future<void> _share(Rect origin) async {
    if (_sharing) return;
    setState(() => _sharing = true);
    try {
      final boundary = _card.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 3);
      final png = await image.toByteData(format: ui.ImageByteFormat.png);
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/sisyphus-summit.png');
      await file.writeAsBytes(png!.buffer.asUint8List(), flush: true);
      final r = _record;
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path, mimeType: 'image/png')],
          text: r == null
              ? 'The summit.'
              : 'I reached the summit: ${span(r.focus)} of focus. One must imagine Sisyphus happy.',
          sharePositionOrigin: origin,
        ),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Could not share the card.')));
      }
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final r = _record;
    final dark = p.brightness == Brightness.dark;
    final skin = skinById(AppScope.of(context).settings.skin);
    return Scaffold(
      body: LayoutBuilder(
        builder: (context, box) {
          final sceneH = box.maxHeight * 0.44;
          return SingleChildScrollView(
            child: Column(
              children: [
                RepaintBoundary(
                  key: _card,
                  child: ColoredBox(
                    color: p.background,
                    child: Column(
                      children: [
                        SizedBox(
                          height: sceneH,
                          width: double.infinity,
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              RepaintBoundary(
                                child: CustomPaint(
                                  painter: SummitPainter(clock, dark: dark, skin: skin),
                                ),
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
                                                shadows: const [
                                                  Shadow(blurRadius: 12, color: Color(0x66000000)),
                                                ],
                                              ),
                                        ),
                                        const SizedBox(height: 4),
                                        if (r != null)
                                          Text(
                                            '${r.label != null ? '${r.label}  ·  ' : ''}'
                                            '${timeOfDay(r.start)} – ${timeOfDay(r.end)}',
                                            style: Type.text(const Color(0xE6FFF6E6), size: 13).copyWith(
                                              shadows: const [
                                                Shadow(blurRadius: 8, color: Color(0x66000000)),
                                              ],
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
                          padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
                          child: Column(
                            children: [
                              if (r != null) _Numbers(r: r),
                              if (_earned.isNotEmpty) ...[
                                const SizedBox(height: 14),
                                _Earned(laurels: _earned),
                              ],
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
                              const SizedBox(height: 10),
                              Text('SISYPHUS', style: Type.label(p.muted.withValues(alpha: 0.6), size: 9.5)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
                  child: Column(
                    children: [
                      Builder(
                        builder: (context) => TextButton.icon(
                          onPressed: _sharing
                              ? null
                              : () {
                                  final box = context.findRenderObject() as RenderBox?;
                                  final origin = box == null
                                      ? const Rect.fromLTWH(0, 0, 1, 1)
                                      : box.localToGlobal(Offset.zero) & box.size;
                                  _share(origin);
                                },
                          icon: Icon(Icons.ios_share_rounded, size: 18, color: p.terracotta),
                          label: const Text('SHARE THE SUMMIT'),
                        ),
                      ),
                      const SizedBox(height: 12),
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
                                _continuing = true;
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

/// The laurels earned during this session.
class _Earned extends StatelessWidget {
  const _Earned({required this.laurels});
  final List<Laurel> laurels;

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 10,
      runSpacing: 8,
      children: [
        for (final l in laurels)
          Container(
            padding: const EdgeInsets.fromLTRB(6, 4, 14, 4),
            decoration: BoxDecoration(
              color: p.surface,
              borderRadius: BorderRadius.circular(30),
              border: Border.all(color: p.gold.withValues(alpha: 0.6)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Wreath(earned: true, size: 30),
                const SizedBox(width: 6),
                Text(l.name.toUpperCase(), style: Type.label(p.ink, size: 10.5)),
              ],
            ),
          ),
      ],
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
