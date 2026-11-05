import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/format.dart';
import '../core/scope.dart';
import '../core/stats.dart';
import '../core/theme.dart';
import '../widgets/common.dart';

class StatsScreen extends StatelessWidget {
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final stats = AppScope.of(context).stats;
    final p = Palette.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('THE LEDGER')),
      body: ListenableBuilder(
        listenable: stats,
        builder: (context, _) => ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            GestureDetector(
              onLongPress: () {
                HapticFeedback.mediumImpact();
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(const SnackBar(content: Text('Every mountain is the same mountain.')));
              },
              child: Panel(
                padding: const EdgeInsets.symmetric(vertical: 26, horizontal: 18),
                child: Column(
                  children: [
                    Text(
                      '${stats.mountains}',
                      style: Type.title(
                        p.terracotta,
                        size: 64,
                        weight: FontWeight.w700,
                      ).copyWith(letterSpacing: 2),
                    ),
                    Text(
                      stats.mountains == 1 ? 'MOUNTAIN CLIMBED' : 'MOUNTAINS CLIMBED',
                      style: Type.label(p.ink, size: 13),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        _Big(value: hours(stats.focus), label: 'hours focused'),
                        _Big(value: '${stats.ascents}', label: 'ascents'),
                        _Big(value: '${stats.streak()}', label: 'day streak'),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            Panel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('THIS WEEK', style: Type.label(p.ink, size: 12)),
                  const SizedBox(height: 14),
                  SizedBox(height: 120, child: _Week(stats: stats)),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Panel(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
              child: Column(
                children: [
                  _Row('Sessions started', '${stats.sessions}'),
                  _Row('Left before the top', '${stats.abandoned}'),
                  _Row('Longest climb', span(stats.longest)),
                  _Row('Best streak', '${stats.bestStreak} ${stats.bestStreak == 1 ? 'day' : 'days'}'),
                  _Row('Shoves of motivation', '${stats.shoves}'),
                  if (stats.slips > 0) _Row('Times it slipped', '${stats.slips}'),
                  _Row('First climb', stats.first == null ? '—' : date(stats.first!), last: true),
                ],
              ),
            ),
            if (stats.recent.isNotEmpty) ...[
              const SizedBox(height: 22),
              Text('RECENT CLIMBS', style: Type.label(p.muted, size: 11)),
              const SizedBox(height: 8),
              for (final r in stats.recent.take(8)) _Recent(r: r),
            ],
            const SizedBox(height: 24),
            KeyBand(color: p.line),
          ],
        ),
      ),
    );
  }
}

class _Big extends StatelessWidget {
  const _Big({required this.value, required this.label});
  final String value, label;
  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return Expanded(
      child: Column(
        children: [
          Text(value, style: Type.number(p.ink, size: 26)),
          Text(label, style: Type.text(p.muted, size: 12)),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row(this.k, this.v, {this.last = false});
  final String k, v;
  final bool last;
  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        border: last ? null : Border(bottom: BorderSide(color: p.line)),
      ),
      child: Row(
        children: [
          Expanded(child: Text(k, style: Type.text(p.ink))),
          Text(v, style: Type.number(p.ink, size: 15)),
        ],
      ),
    );
  }
}

class _Recent extends StatelessWidget {
  const _Recent({required this.r});
  final SessionRecord r;
  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(
            r.summited ? Icons.landscape : Icons.landscape_outlined,
            size: 18,
            color: r.summited ? p.terracotta : p.muted,
          ),
          const SizedBox(width: 12),
          Expanded(child: Text('${date(r.start)}, ${timeOfDay(r.start)}', style: Type.text(p.ink, size: 14))),
          Text(
            '${span(r.focus)}  ·  ${r.climbsDone}/${r.climbsPlanned}',
            style: Type.text(p.muted, size: 13.5),
          ),
        ],
      ),
    );
  }
}

class _Week extends StatelessWidget {
  const _Week({required this.stats});
  final Stats stats;

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final week = stats.week();
    final top = math.max(30, week.map((d) => d.inMinutes).fold(0, math.max));
    const names = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    final today = DateTime.now();
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        for (var i = 0; i < 7; i++)
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (week[i].inMinutes > 0) Text(span(week[i]), style: Type.text(p.muted, size: 10)),
                const SizedBox(height: 4),
                Container(
                  height: math.max(3, 74 * week[i].inMinutes / top),
                  margin: const EdgeInsets.symmetric(horizontal: 7),
                  decoration: BoxDecoration(
                    color: i == 6 ? p.terracotta : p.terracotta.withValues(alpha: 0.45),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  names[today.subtract(Duration(days: 6 - i)).weekday - 1],
                  style: Type.label(i == 6 ? p.ink : p.muted, size: 10),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
