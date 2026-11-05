import 'package:flutter/material.dart';

import 'core/ambience.dart';
import 'core/expedition.dart';
import 'core/laurels.dart';
import 'core/scope.dart';
import 'core/settings.dart';
import 'core/stats.dart';
import 'core/theme.dart';
import 'screens/climb_screen.dart';
import 'screens/home_screen.dart';
import 'widgets/laurel.dart';

class SisyphusApp extends StatefulWidget {
  const SisyphusApp({
    super.key,
    required this.settings,
    required this.stats,
    required this.expedition,
    required this.laurels,
  });

  final Settings settings;
  final Stats stats;
  final Expedition expedition;
  final LaurelWatch laurels;

  @override
  State<SisyphusApp> createState() => _SisyphusAppState();
}

class _SisyphusAppState extends State<SisyphusApp> with WidgetsBindingObserver {
  // A session left running opens straight onto the mountain.
  late final Widget _home = widget.expedition.session != null ? const ClimbScreen() : const HomeScreen();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final shown = state == AppLifecycleState.resumed;
    widget.expedition.setForeground(shown);
    if (state == AppLifecycleState.resumed || state == AppLifecycleState.paused) {
      Ambience.instance.suspend(!shown);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScope(
      settings: widget.settings,
      stats: widget.stats,
      expedition: widget.expedition,
      laurels: widget.laurels,
      child: ListenableBuilder(
        listenable: widget.settings,
        builder: (context, _) => MaterialApp(
          title: 'Sisyphus',
          debugShowCheckedModeBanner: false,
          theme: buildTheme(Palette.light),
          darkTheme: buildTheme(Palette.dark),
          themeMode: widget.settings.theme,
          home: _home,
          builder: (context, child) => Stack(
            children: [
              child!,
              LaurelBanner(watch: widget.laurels),
            ],
          ),
        ),
      ),
    );
  }
}
