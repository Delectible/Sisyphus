import 'package:flutter/widgets.dart';

import 'expedition.dart';
import 'laurels.dart';
import 'settings.dart';
import 'stats.dart';

/// Hands the app's state to every screen.
class AppScope extends InheritedWidget {
  const AppScope({
    super.key,
    required this.settings,
    required this.stats,
    required this.expedition,
    required this.laurels,
    required super.child,
  });

  final Settings settings;
  final Stats stats;
  final Expedition expedition;
  final LaurelWatch laurels;

  static AppScope of(BuildContext context) => context.dependOnInheritedWidgetOfExactType<AppScope>()!;

  @override
  bool updateShouldNotify(AppScope old) => false;
}
