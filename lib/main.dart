import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'core/alerts.dart';
import 'core/expedition.dart';
import 'core/settings.dart';
import 'core/stats.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  final prefs = await SharedPreferences.getInstance();
  await Alerts.instance.init();
  final settings = Settings(prefs);
  final stats = Stats(prefs);
  final expedition = Expedition(prefs, settings, stats, alerts: Alerts.instance);
  runApp(SisyphusApp(settings: settings, stats: stats, expedition: expedition));
}
