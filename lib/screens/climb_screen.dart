import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/expedition.dart';
import '../core/format.dart';
import '../core/poems.dart';
import '../core/scope.dart';
import '../core/session.dart';
import '../core/theme.dart';
import '../scene/ascent.dart';
import '../scene/clock.dart';
import '../scene/rest.dart';
import 'home_screen.dart';
import 'summit_screen.dart';

/// The session: the ascent (hands on the boulder) and the rest (the valley),
/// the timer on top, skip / motivate / exit below.
class ClimbScreen extends StatefulWidget {
  const ClimbScreen({super.key});

  @override
  State<ClimbScreen> createState() => _ClimbScreenState();
}

class _ClimbScreenState extends State<ClimbScreen> {
  final clock = SceneClock();
  final ascent = AscentState();
  late final AppLifecycleListener _life;
  late Expedition _exp;
  int _seenEvent = -1;
  double _owlAt = -100;
  final _taps = <double>[];
  String? _bubble;
  int _bubbleId = 0;
  bool _breathing = false;
  bool _leaving = false;
  final _rnd = math.Random();

  @override
  void initState() {
    super.initState();
    _life = AppLifecycleListener(
      onShow: clock.start,
      onResume: clock.start,
      onHide: clock.stop,
      onPause: clock.stop,
    );
    clock.start();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final exp = AppScope.of(context).expedition;
    if (_seenEvent < 0) {
      _exp = exp;
      _seenEvent = exp.eventCount;
      exp.addListener(_onEvent);
    }
    final settings = AppScope.of(context).settings;
    clock
      ..still = settings.stillScenes
      ..fps = settings.fps;
  }

  @override
  void dispose() {
    _exp.removeListener(_onEvent);
    _life.dispose();
    clock.dispose();
    super.dispose();
  }

  void _onEvent() {
    if (_exp.eventCount == _seenEvent) return;
    _seenEvent = _exp.eventCount;
    switch (_exp.event) {
      case SessionEvent.restBegins:
      case SessionEvent.waitingForRest:
        _say('The stone rolls back down. Rest.');
      case SessionEvent.ascentBegins:
      case SessionEvent.waitingForAscent:
        if (_exp.session != null && _exp.session!.index > 0) _say('Back to the stone.');
      case SessionEvent.summit:
        _toSummit();
      case SessionEvent.none:
        break;
    }
  }

  void _toSummit() {
    if (_leaving) return;
    _leaving = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        PageRouteBuilder<void>(
          transitionDuration: const Duration(milliseconds: 1200),
          pageBuilder: (_, _, _) => const SummitScreen(),
          transitionsBuilder: (_, a, _, child) => FadeTransition(opacity: a, child: child),
        ),
      );
    });
  }

  void _say(String text) {
    final id = ++_bubbleId;
    setState(() => _bubble = text);
    Future.delayed(const Duration(milliseconds: 2600), () {
      if (mounted && _bubbleId == id) setState(() => _bubble = null);
    });
  }

  void _shove() {
    HapticFeedback.mediumImpact();
    ascent.shove(clock.t);
    _exp.shove();
    _say(shoveLines[_rnd.nextInt(shoveLines.length)]);
  }

  void _tapBoulder() {
    final t = clock.t;
    _taps
      ..add(t)
      ..removeWhere((x) => t - x > 3);
    if (_taps.length >= 7) {
      _taps.clear();
      ascent.slipAt = t;
      HapticFeedback.heavyImpact();
      AppScope.of(context).stats.addSlip();
      _say('It slips... as it always does.');
    } else {
      HapticFeedback.selectionClick();
    }
  }

  void _tapOwl() {
    setState(() => _owlAt = clock.t);
    HapticFeedback.lightImpact();
    _say(owlLines[_rnd.nextInt(owlLines.length)]);
  }

  Future<void> _exit() async {
    final s = _exp.session;
    final p = Palette.of(context);
    final ok = s == null
        ? true
        : await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('LEAVE THE MOUNTAIN?'),
              content: Text(
                'The boulder will wait at the bottom. Your ${span(s.focused)} of focus still counts.',
                style: Type.text(p.ink),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('KEEP CLIMBING'),
                ),
                TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('LEAVE')),
              ],
            ),
          );
    if (ok != true || !mounted) return;
    _leaving = true;
    _exp.abandon();
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
    final dark = p.brightness == Brightness.dark;
    ascent.dark = dark;
    return ListenableBuilder(
      listenable: _exp,
      builder: (context, _) {
        final s = _exp.session;
        if (s == null) return Scaffold(backgroundColor: p.background);
        final now = _exp.now();
        final resting = s.phase == Phase.rest;
        ascent.progress = resting ? 0 : s.progress(now);
        ascent.paused = s.paused || s.waiting;
        return PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop) _exit();
          },
          child: Scaffold(
            backgroundColor: dark ? Colors.black : const Color(0xFF3C3F46),
            body: Stack(
              fit: StackFit.expand,
              children: [
                RepaintBoundary(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 1400),
                    child: LayoutBuilder(
                      key: ValueKey(resting),
                      builder: (context, box) {
                        final size = box.biggest;
                        return GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTapUp: (d) {
                            if (resting) {
                              if (RestPainter.owlRect(size).inflate(12).contains(d.localPosition)) _tapOwl();
                            } else {
                              final (c, r) = AscentPainter.boulderAt(size);
                              if ((d.localPosition - c).distance < r) _tapBoulder();
                            }
                          },
                          child: CustomPaint(
                            size: size,
                            painter: resting
                                ? RestPainter(clock, dark: dark, owlAt: _owlAt)
                                : AscentPainter(clock, ascent),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                SafeArea(
                  child: Column(
                    children: [
                      const SizedBox(height: 10),
                      _TimerPill(session: s, now: now, onTap: _exp.togglePause, dark: dark),
                      const Spacer(),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 300),
                        child: _bubble == null
                            ? const SizedBox(height: 44)
                            : _Bubble(key: ValueKey(_bubble), text: _bubble!, resting: resting),
                      ),
                      const SizedBox(height: 14),
                      _Controls(
                        resting: resting,
                        onExit: _exit,
                        onSkip: () {
                          HapticFeedback.selectionClick();
                          _exp.skip();
                        },
                        onMiddle: resting ? () => setState(() => _breathing = true) : _shove,
                      ),
                      const SizedBox(height: 18),
                    ],
                  ),
                ),
                if (s.waiting) _Waiting(session: s, onGo: _exp.proceed),
                if (_breathing) _Breathe(onDone: () => setState(() => _breathing = false)),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _TimerPill extends StatefulWidget {
  const _TimerPill({required this.session, required this.now, required this.onTap, required this.dark});
  final Session session;
  final DateTime now;
  final VoidCallback onTap;
  final bool dark;

  @override
  State<_TimerPill> createState() => _TimerPillState();
}

class _TimerPillState extends State<_TimerPill> with SingleTickerProviderStateMixin {
  // Paused: the time breathes, so it's clearly stopped.
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );

  // "Tap to pause" shows for the first moments of each phase.
  int _hintPhase = -1;
  DateTime _hintUntil = DateTime(0);

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = widget.session, now = widget.now, dark = widget.dark;
    final resting = session.phase == Phase.rest;
    final paused = session.paused;
    if (paused && !_pulse.isAnimating) {
      _pulse.repeat(reverse: true);
    } else if (!paused && _pulse.isAnimating) {
      _pulse
        ..stop()
        ..value = 0;
    }
    if (_hintPhase != session.index) {
      _hintPhase = session.index;
      _hintUntil = now.add(const Duration(seconds: 6));
    }
    final hint = paused ? 'tap to resume' : (now.isBefore(_hintUntil) ? 'tap the timer to pause' : null);
    // Ascending: stark, heavy, ember accent. Resting: soft and warm.
    final bg = resting ? (dark ? const Color(0xA6202A44) : const Color(0xC2FFF8EA)) : const Color(0xA6101114);
    final fg = resting ? (dark ? const Color(0xFFE9E3D2) : const Color(0xFF4B4636)) : const Color(0xFFF3EEE4);
    final accent = resting
        ? (dark ? const Color(0xFF9DB07A) : const Color(0xFF66784A))
        : const Color(0xFFE0703F);
    final label = paused ? 'PAUSED' : (resting ? 'RESTING' : 'ASCENDING');
    final sub = resting
        ? 'in the valley  ·  ${session.climb} of ${session.climbs} climbed'
        : 'climb ${session.climb} of ${session.climbs}';
    return Semantics(
      button: true,
      label: paused ? 'Resume timer' : 'Pause timer',
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          widget.onTap();
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 900),
          margin: const EdgeInsets.symmetric(horizontal: 32),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: accent.withValues(alpha: paused ? 0.8 : 0.35),
              width: paused ? 1.5 : 1,
            ),
            boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 24, offset: Offset(0, 8))],
          ),
          child: Stack(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(26, 13, 26, 13),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AnimatedDefaultTextStyle(
                      duration: const Duration(milliseconds: 900),
                      style: resting
                          ? Type.label(accent, size: 13, weight: FontWeight.w400).copyWith(letterSpacing: 6)
                          : Type.label(accent, size: 13, weight: FontWeight.w700).copyWith(letterSpacing: 4),
                      child: Text(label),
                    ),
                    const SizedBox(height: 2),
                    FadeTransition(
                      opacity: Tween(begin: 1.0, end: 0.35).animate(_pulse),
                      child: Text(
                        clock(session.remaining(now)),
                        style: resting
                            ? Type.number(fg, size: 56, weight: FontWeight.w400)
                            : Type.number(fg, size: 58, weight: FontWeight.w600),
                      ),
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(2),
                      child: LinearProgressIndicator(
                        value: session.progress(now),
                        minHeight: 3,
                        backgroundColor: fg.withValues(alpha: 0.15),
                        valueColor: AlwaysStoppedAnimation(accent),
                      ),
                    ),
                    const SizedBox(height: 7),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 400),
                      child: Text(
                        hint ?? sub,
                        key: ValueKey(hint ?? sub),
                        style: hint != null
                            ? Type.text(accent, size: 12.5, weight: FontWeight.w500)
                            : Type.text(fg.withValues(alpha: 0.75), size: 12.5),
                      ),
                    ),
                  ],
                ),
              ),
              // The pause / play glyph, top right.
              Positioned(
                top: 10,
                right: 12,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: paused ? accent : fg.withValues(alpha: 0.1),
                  ),
                  child: Icon(
                    paused ? Icons.play_arrow_rounded : Icons.pause_rounded,
                    size: 19,
                    color: paused
                        ? (resting ? const Color(0xFFFFFBF2) : Colors.white)
                        : fg.withValues(alpha: 0.8),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Controls extends StatelessWidget {
  const _Controls({
    required this.resting,
    required this.onExit,
    required this.onSkip,
    required this.onMiddle,
  });
  final bool resting;
  final VoidCallback onExit, onSkip, onMiddle;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _GlassButton(icon: Icons.close, label: 'Exit', onTap: onExit, resting: resting),
        _GlassButton(
          icon: resting ? Icons.air : Icons.bolt,
          label: resting ? 'Breathe' : 'Motivate',
          onTap: onMiddle,
          big: true,
          resting: resting,
        ),
        _GlassButton(icon: Icons.skip_next_rounded, label: 'Skip', onTap: onSkip, resting: resting),
      ],
    );
  }
}

class _GlassButton extends StatelessWidget {
  const _GlassButton({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.resting,
    this.big = false,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool big, resting;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final bg = resting ? (dark ? const Color(0x99202A44) : const Color(0xB3FFF8EA)) : const Color(0x99101114);
    final fg = resting ? (dark ? const Color(0xFFE9E3D2) : const Color(0xFF4B4636)) : const Color(0xFFF3EEE4);
    final accent = big && !resting ? const Color(0xFFE0703F) : null;
    final d = big ? 74.0 : 58.0;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Material(
            color: accent ?? bg,
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: onTap,
              child: SizedBox(
                width: d,
                height: d,
                child: Icon(icon, color: accent != null ? Colors.white : fg, size: big ? 32 : 24),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: resting ? bg : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              label.toUpperCase(),
              style: Type.label(
                fg,
                size: 10.5,
              ).copyWith(shadows: resting ? null : const [Shadow(blurRadius: 6, color: Color(0x88000000))]),
            ),
          ),
        ],
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({super.key, required this.text, required this.resting});
  final String text;
  final bool resting;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final bg = resting ? (dark ? const Color(0xCC202A44) : const Color(0xE6FFF8EA)) : const Color(0xCC101114);
    final fg = resting ? (dark ? const Color(0xFFE9E3D2) : const Color(0xFF4B4636)) : const Color(0xFFF3EEE4);
    return Container(
      constraints: const BoxConstraints(minHeight: 44),
      margin: const EdgeInsets.symmetric(horizontal: 28),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(22)),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: Type.title(fg, size: 15, weight: FontWeight.w600).copyWith(letterSpacing: 1.2),
      ),
    );
  }
}

/// Auto-continue off: the next phase waits for a tap.
class _Waiting extends StatelessWidget {
  const _Waiting({required this.session, required this.onGo});
  final Session session;
  final VoidCallback onGo;

  @override
  Widget build(BuildContext context) {
    final rest = session.phase == Phase.rest;
    return Container(
      color: const Color(0x88000000),
      alignment: Alignment.center,
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            rest ? 'The stone rolls back\nto the valley.' : 'The stone waits\nat the bottom.',
            textAlign: TextAlign.center,
            style: Type.title(const Color(0xFFF3EEE4), size: 22),
          ),
          const SizedBox(height: 24),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFE0703F),
              padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 16),
            ),
            onPressed: onGo,
            child: Text(rest ? 'REST' : 'CLIMB AGAIN', style: Type.label(Colors.white, size: 14)),
          ),
        ],
      ),
    );
  }
}

/// A short guided breath at rest: in 4, hold 2, out 6, three times.
class _Breathe extends StatefulWidget {
  const _Breathe({required this.onDone});
  final VoidCallback onDone;

  @override
  State<_Breathe> createState() => _BreatheState();
}

class _BreatheState extends State<_Breathe> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(seconds: 36))
    ..forward().whenComplete(widget.onDone);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onDone,
      child: Container(
        color: const Color(0x99000000),
        alignment: Alignment.center,
        child: AnimatedBuilder(
          animation: _c,
          builder: (context, _) {
            final t = (_c.value * 36) % 12;
            final (word, size) = t < 4
                ? ('breathe in', 0.45 + 0.55 * Curves.easeInOut.transform(t / 4))
                : t < 6
                ? ('hold', 1.0)
                : ('breathe out', 1 - 0.55 * Curves.easeInOut.transform((t - 6) / 6));
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 220 * size,
                  height: 220 * size,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const RadialGradient(colors: [Color(0x88F4E2C2), Color(0x228EC0CC)]),
                    border: Border.all(color: const Color(0x99F4E2C2), width: 1.5),
                  ),
                ),
                const SizedBox(height: 30),
                Text(
                  word.toUpperCase(),
                  style: Type.label(
                    const Color(0xFFF3EEE4),
                    size: 16,
                    weight: FontWeight.w400,
                  ).copyWith(letterSpacing: 6),
                ),
                const SizedBox(height: 8),
                Text('tap to stop', style: Type.text(const Color(0x99F3EEE4), size: 12)),
              ],
            );
          },
        ),
      ),
    );
  }
}
