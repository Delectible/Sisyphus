import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/laurels.dart';
import '../core/scope.dart';
import '../core/theme.dart';
import '../widgets/common.dart';
import '../widgets/laurel.dart';

/// Achievements, and the boulder stones they unlock.
class LaurelsScreen extends StatelessWidget {
  const LaurelsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final stats = scope.stats, settings = scope.settings;
    final p = Palette.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('LAURELS')),
      body: ListenableBuilder(
        listenable: Listenable.merge([stats, settings]),
        builder: (context, _) {
          final earned = laurels.where((l) => l.earned(stats)).length;
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
            children: [
              Text(
                '$earned of ${laurels.length} earned',
                textAlign: TextAlign.center,
                style: Type.text(p.muted, size: 14),
              ),
              const SizedBox(height: 18),
              Text('YOUR STONE', style: Type.label(p.ink, size: 12)),
              const SizedBox(height: 10),
              SizedBox(
                height: 112,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: skins.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 10),
                  itemBuilder: (context, i) {
                    final sk = skins[i];
                    final open = skinUnlocked(stats, sk.id);
                    final on = settings.skin == sk.id;
                    final from = laurels.where((l) => l.skin == sk.id).firstOrNull;
                    return GestureDetector(
                      onTap: () {
                        if (open) {
                          HapticFeedback.selectionClick();
                          settings.skin = sk.id;
                        } else {
                          ScaffoldMessenger.of(context)
                            ..hideCurrentSnackBar()
                            ..showSnackBar(
                              SnackBar(
                                content: Text(
                                  from == null
                                      ? '${sk.name} is locked.'
                                      : '${sk.name}: earn "${from.secret ? '???' : from.name}". ${from.secret ? '' : from.hint}',
                                ),
                              ),
                            );
                        }
                      },
                      child: Container(
                        width: 84,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: on ? p.surface : Colors.transparent,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: on ? p.terracotta : p.line, width: on ? 1.6 : 1),
                        ),
                        child: Column(
                          children: [
                            Opacity(
                              opacity: open ? 1 : 0.3,
                              child: SkinStone(skin: sk, size: 52),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                if (!open) Icon(Icons.lock_outline, size: 12, color: p.muted),
                                if (!open) const SizedBox(width: 3),
                                Text(
                                  sk.name.toUpperCase(),
                                  style: Type.label(open ? p.ink : p.muted, size: 9.5),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 22),
              Text('LAURELS', style: Type.label(p.ink, size: 12)),
              const SizedBox(height: 10),
              for (final l in laurels) _LaurelRow(laurel: l),
              const SizedBox(height: 20),
              KeyBand(color: p.line),
            ],
          );
        },
      ),
    );
  }
}

class _LaurelRow extends StatelessWidget {
  const _LaurelRow({required this.laurel});
  final Laurel laurel;

  @override
  Widget build(BuildContext context) {
    final stats = AppScope.of(context).stats;
    final p = Palette.of(context);
    final (have, need) = laurel.progress(stats);
    final done = have >= need;
    final hidden = laurel.secret && !done;
    final skin = laurel.skin == null ? null : skinById(laurel.skin!);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Panel(
        padding: const EdgeInsets.fromLTRB(12, 10, 14, 10),
        child: Row(
          children: [
            Wreath(
              earned: done,
              size: 50,
              child: hidden
                  ? Text('?', style: Type.title(p.muted, size: 16))
                  : (skin != null ? SkinStone(skin: skin, size: 18) : null),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    hidden ? 'A SECRET' : laurel.name.toUpperCase(),
                    style: Type.label(done ? p.ink : p.muted, size: 12.5),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    hidden ? 'Some things are found, not chased.' : laurel.hint,
                    style: Type.text(p.muted, size: 13),
                  ),
                  if (!done && !hidden && need > 1) ...[
                    const SizedBox(height: 7),
                    Row(
                      children: [
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(2),
                            child: LinearProgressIndicator(
                              value: (have / need).clamp(0.0, 1.0),
                              minHeight: 3,
                              backgroundColor: p.line,
                              valueColor: AlwaysStoppedAnimation(p.gold),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text('${have.clamp(0, need)} / $need', style: Type.number(p.muted, size: 11)),
                      ],
                    ),
                  ],
                  if (skin != null && !hidden)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        done ? '${skin.name} stone unlocked' : 'Unlocks the ${skin.name} stone',
                        style: Type.text(done ? p.olive : p.muted, size: 12, weight: FontWeight.w500),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
