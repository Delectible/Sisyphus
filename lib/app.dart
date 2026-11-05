import 'package:flutter/material.dart';

import 'core/expedition.dart';
import 'core/scope.dart';
import 'core/settings.dart';
import 'core/stats.dart';
import 'core/theme.dart';
import 'screens/climb_screen.dart';
import 'screens/home_screen.dart';

class SisyphusApp extends StatefulWidget {
  const SisyphusApp({super.key, required this.settings, required this.stats, required this.expedition});

  final Settings settings;
  final Stats stats;
  final Expedition expedition;

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
    widget.expedition.setForeground(state == AppLifecycleState.resumed);
  }

  @override
  Widget build(BuildContext context) {
    return AppScope(
      settings: widget.settings,
      stats: widget.stats,
      expedition: widget.expedition,
      child: ListenableBuilder(
        listenable: widget.settings,
        builder: (context, _) => MaterialApp(
          title: 'Sisyphus',
          debugShowCheckedModeBanner: false,
          theme: buildTheme(Palette.light),
          darkTheme: buildTheme(Palette.dark),
          themeMode: widget.settings.theme,
          home: _home,
        ),
      ),
    );
  }
}
