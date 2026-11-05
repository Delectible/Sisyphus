import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sisyphus/app.dart';
import 'package:sisyphus/core/expedition.dart';
import 'package:sisyphus/core/settings.dart';
import 'package:sisyphus/core/stats.dart';
import 'package:sisyphus/screens/stats_screen.dart';
import 'package:sisyphus/screens/summit_screen.dart';

import 'shots.dart';

Future<(Settings, Stats, Expedition)> _app(WidgetTester tester, {required bool dark}) async {
  SharedPreferences.setMockInitialValues({'theme': dark ? 2 : 1});
  final prefs = await SharedPreferences.getInstance();
  final settings = Settings(prefs);
  final stats = Stats(prefs);
  final exp = Expedition(prefs, settings, stats);
  return (settings, stats, exp);
}

Future<void> _settle(WidgetTester tester, [int ms = 1600]) async {
  for (var i = 0; i < ms ~/ 100; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> _done(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 3));
}

void main() {
  setUpAll(loadFonts);

  for (final dark in [false, true]) {
    final mode = dark ? 'dark' : 'light';

    testWidgets('home ($mode)', (tester) async {
      setPhone(tester);
      final (settings, stats, exp) = await _app(tester, dark: dark);
      await tester.pumpWidget(SisyphusApp(settings: settings, stats: stats, expedition: exp));
      await _settle(tester, 300);
      expect(find.text('SISYPHUS'), findsOneWidget);
      await shot(tester, '1_home_$mode');
      await _done(tester);
    });

    testWidgets('ascent and rest ($mode)', (tester) async {
      setPhone(tester);
      final (settings, stats, exp) = await _app(tester, dark: dark);
      await tester.pumpWidget(SisyphusApp(settings: settings, stats: stats, expedition: exp));
      await tester.pump();
      await tester.ensureVisible(find.text('BEGIN THE ASCENT'));
      await tester.tap(find.text('BEGIN THE ASCENT'));
      await _settle(tester);
      expect(find.text('ASCENDING'), findsOneWidget);
      await shot(tester, '2_ascent_$mode');
      await tester.tap(find.text('MOTIVATE'));
      await _settle(tester, 300);
      await shot(tester, '3_motivate_$mode');
      await _settle(tester, 2800);
      await tester.tap(find.text('SKIP'));
      await _settle(tester, 2000);
      expect(find.text('RESTING'), findsOneWidget);
      await shot(tester, '4_rest_$mode');
      exp.dispose();
      await _done(tester);
    });

    testWidgets('summit ($mode)', (tester) async {
      setPhone(tester);
      final (settings, stats, exp) = await _app(tester, dark: dark);
      final now = DateTime(2026, 11, 5, 18, 40);
      final r = SessionRecord(
        start: now.subtract(const Duration(minutes: 115)),
        end: now,
        focus: const Duration(minutes: 100),
        climbsDone: 4,
        climbsPlanned: 4,
        skips: 0,
        shoves: 7,
        summited: true,
      );
      stats.addSession(r);
      await tester.pumpWidget(SisyphusApp(settings: settings, stats: stats, expedition: exp));
      final nav = tester.state<NavigatorState>(find.byType(Navigator));
      nav.push(MaterialPageRoute<void>(builder: (_) => SummitScreen(record: r)));
      await _settle(tester, 800);
      expect(find.text('THE SUMMIT'), findsOneWidget);
      await shot(tester, '5_summit_$mode');
      await _done(tester);
    });

    testWidgets('stats ($mode)', (tester) async {
      setPhone(tester);
      final (settings, stats, exp) = await _app(tester, dark: dark);
      final now = DateTime.now();
      for (var d = 0; d < 6; d++) {
        stats.addFocus(Duration(minutes: 25 * (1 + d % 3)), now.subtract(Duration(days: d)));
      }
      for (var i = 0; i < 3; i++) {
        stats.addSession(
          SessionRecord(
            start: now.subtract(Duration(days: i, minutes: 120)),
            end: now.subtract(Duration(days: i)),
            focus: const Duration(minutes: 100),
            climbsDone: 4,
            climbsPlanned: 4,
            skips: i,
            shoves: 3,
            summited: true,
          ),
        );
      }
      await tester.pumpWidget(SisyphusApp(settings: settings, stats: stats, expedition: exp));
      tester
          .state<NavigatorState>(find.byType(Navigator))
          .push(MaterialPageRoute<void>(builder: (_) => const StatsScreen()));
      await _settle(tester, 800);
      await shot(tester, '6_stats_$mode');
      await _done(tester);
    });
  }
}
