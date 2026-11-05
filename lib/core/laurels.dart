import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'stats.dart';

/// The boulder's stone. Granite is everyone's; the rest are laurel rewards.
class Skin {
  final String id;
  final String name;
  final Color base;
  final Color lit;
  final Color shade;

  /// Veins (marble) instead of speckles.
  final bool veined;

  /// Metallic: a sharper, brighter highlight.
  final bool metal;

  const Skin(this.id, this.name, this.base, this.lit, this.shade, {this.veined = false, this.metal = false});

  /// The same stone in sunset light (summit by day).
  Skin get sunset => Skin(
    id,
    name,
    Color.lerp(base, const Color(0xFF7A5450), 0.4)!,
    Color.lerp(lit, const Color(0xFFF6C090), 0.55)!,
    Color.lerp(shade, const Color(0xFF2A1E25), 0.5)!,
    veined: veined,
    metal: metal,
  );

  /// The same stone in the dark (night scenes).
  Skin get night => Skin(
    id,
    name,
    Color.lerp(base, const Color(0xFF2A2C3A), 0.45)!,
    Color.lerp(lit, const Color(0xFF8E94B0), 0.4)!,
    Color.lerp(shade, const Color(0xFF0E0F16), 0.4)!,
    veined: veined,
    metal: metal,
  );
}

const granite = Skin('granite', 'Granite', Color(0xFF8C867B), Color(0xFFBDB6A8), Color(0xFF433F3A));

const skins = <Skin>[
  granite,
  Skin('sandstone', 'Sandstone', Color(0xFFB98B5E), Color(0xFFE7C79A), Color(0xFF5E3F27)),
  Skin('marble', 'Marble', Color(0xFFD9D4CB), Color(0xFFFBF9F4), Color(0xFF8A847A), veined: true),
  Skin('moss', 'Mossy', Color(0xFF6E7A55), Color(0xFFA8B582), Color(0xFF2E3523)),
  Skin('obsidian', 'Obsidian', Color(0xFF2B2A33), Color(0xFF8C8FA8), Color(0xFF09090D), metal: true),
  Skin('bronze', 'Bronze', Color(0xFF9A6A3C), Color(0xFFE8B77A), Color(0xFF3E2512), metal: true),
  Skin('gold', 'Gold', Color(0xFFC79A32), Color(0xFFFFE9A0), Color(0xFF5E4310), metal: true),
];

Skin skinById(String id) => skins.firstWhere((s) => s.id == id, orElse: () => skins.first);

/// An achievement. [progress] returns (have, need).
class Laurel {
  final String id;
  final String name;
  final String hint;

  /// The skin it unlocks, if any.
  final String? skin;

  /// Hidden until earned.
  final bool secret;
  final (int, int) Function(Stats s) progress;

  const Laurel(this.id, this.name, this.hint, this.progress, {this.skin, this.secret = false});

  bool earned(Stats s) {
    final (have, need) = progress(s);
    return have >= need;
  }
}

final laurels = <Laurel>[
  Laurel('first', 'First Ascent', 'Reach the summit once.', (s) => (s.mountains, 1), skin: 'sandstone'),
  Laurel('ten', 'Seasoned Climber', 'Climb 10 mountains.', (s) => (s.mountains, 10), skin: 'marble'),
  Laurel('fifty', 'Living Myth', 'Climb 50 mountains.', (s) => (s.mountains, 50), skin: 'gold'),
  Laurel('streak', 'Unbroken', 'Focus 7 days in a row.', (s) => (s.bestStreak, 7)),
  Laurel('marathon', 'Marathon', 'Focus 3 hours in one session.', (s) => (s.longest.inMinutes, 180)),
  Laurel(
    'hundred',
    'Hundred Hours',
    'Focus 100 hours in all.',
    (s) => (s.focus.inHours, 100),
    skin: 'bronze',
  ),
  Laurel('night', 'Night Owl', 'Reach a summit after 9 pm.', (s) => (s.nightSummits, 1), skin: 'obsidian'),
  Laurel('dawn', 'Rosy-Fingered Dawn', 'Reach a summit before 8 am.', (s) => (s.dawnSummits, 1)),
  Laurel('clean', 'No Shortcuts', 'Reach 5 summits without skipping.', (s) => (s.cleanSummits, 5)),
  Laurel('long', 'The Long Rest', 'Take 5 long rests.', (s) => (s.longRests, 5)),
  Laurel('shoves', 'Heave!', 'Shove the boulder 100 times.', (s) => (s.shoves, 100)),
  Laurel('owl', 'Wisdom', 'Listen to the owl 7 times.', (s) => (s.owlTaps, 7), skin: 'moss', secret: true),
  Laurel('breath', 'Deep Breath', 'Finish a guided breath.', (s) => (s.breaths, 1), secret: true),
  Laurel('slip', 'As It Always Does', 'Let the boulder slip.', (s) => (s.slips, 1), secret: true),
];

/// Laurels earned now that weren't in [before] (ids).
List<Laurel> newlyEarned(Stats s, Set<String> before) => [
  for (final l in laurels)
    if (l.earned(s) && !before.contains(l.id)) l,
];

Set<String> earnedIds(Stats s) => {
  for (final l in laurels)
    if (l.earned(s)) l.id,
};

bool skinUnlocked(Stats s, String id) => id == 'granite' || laurels.any((l) => l.skin == id && l.earned(s));

/// Watches the stats and announces laurels as they're earned (once each).
class LaurelWatch extends ChangeNotifier {
  LaurelWatch(this._prefs, this.stats) {
    final seen = _prefs.getStringList(_key);
    if (seen == null) {
      // First run with laurels: count what's already earned as seen.
      _seen = earnedIds(stats);
      _prefs.setStringList(_key, _seen.toList());
    } else {
      _seen = seen.toSet();
    }
    stats.addListener(_check);
  }

  static const _key = 'laurelsSeen';
  final SharedPreferences _prefs;
  final Stats stats;
  late Set<String> _seen;

  /// Laurels waiting to be announced, oldest first.
  final List<Laurel> queue = [];

  void _check() {
    final fresh = newlyEarned(stats, _seen);
    if (fresh.isEmpty) return;
    _seen.addAll(fresh.map((l) => l.id));
    _prefs.setStringList(_key, _seen.toList());
    queue.addAll(fresh);
    notifyListeners();
  }

  Laurel? take() {
    if (queue.isEmpty) return null;
    final l = queue.removeAt(0);
    notifyListeners();
    return l;
  }

  @override
  void dispose() {
    stats.removeListener(_check);
    super.dispose();
  }
}
