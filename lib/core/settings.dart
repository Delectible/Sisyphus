import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// What the next session looks like, and how the app behaves. Saved on
/// every change.
class Settings extends ChangeNotifier {
  Settings(this._prefs) {
    _focus = _prefs.getInt('focus') ?? 25;
    _rest = _prefs.getInt('rest') ?? 5;
    _climbs = _prefs.getInt('climbs') ?? 4;
    _theme = ThemeMode.values[(_prefs.getInt('theme') ?? 0).clamp(0, 2)];
    _autoContinue = _prefs.getBool('autoContinue') ?? true;
    _alerts = _prefs.getBool('alerts') ?? true;
    _vibrate = _prefs.getBool('vibrate') ?? true;
    _stillScenes = _prefs.getBool('stillScenes') ?? false;
    _debugOpen = _prefs.getBool('debugOpen') ?? false;
    _speed = _prefs.getInt('speed') ?? 1;
    _fps = _prefs.getInt('fps') == 30 ? 30 : 60;
  }

  final SharedPreferences _prefs;

  static const minFocus = 1, maxFocus = 120;
  static const minRest = 1, maxRest = 60;
  static const minClimbs = 1, maxClimbs = 12;

  late int _focus, _rest, _climbs, _speed, _fps;
  late ThemeMode _theme;
  late bool _autoContinue, _alerts, _vibrate, _stillScenes, _debugOpen;

  /// Minutes of each ascent (focus).
  int get focus => _focus;
  set focus(int v) => _setInt('focus', _focus = v.clamp(minFocus, maxFocus));

  /// Minutes of each rest.
  int get rest => _rest;
  set rest(int v) => _setInt('rest', _rest = v.clamp(minRest, maxRest));

  /// Ascents in a session.
  int get climbs => _climbs;
  set climbs(int v) => _setInt('climbs', _climbs = v.clamp(minClimbs, maxClimbs));

  ThemeMode get theme => _theme;
  set theme(ThemeMode v) => _setInt('theme', (_theme = v).index);

  /// Start the next phase on its own when one ends.
  bool get autoContinue => _autoContinue;
  set autoContinue(bool v) => _setBool('autoContinue', _autoContinue = v);

  /// Notify when a phase ends while the app is closed.
  bool get alerts => _alerts;
  set alerts(bool v) => _setBool('alerts', _alerts = v);

  bool get vibrate => _vibrate;
  set vibrate(bool v) => _setBool('vibrate', _vibrate = v);

  /// Battery saver: scenes stand still (they redraw once a second).
  bool get stillScenes => _stillScenes;
  set stillScenes(bool v) => _setBool('stillScenes', _stillScenes = v);

  /// Scene frame rate: 60 (smooth) or 30 (saves battery).
  int get fps => _fps;
  set fps(int v) => _setInt('fps', _fps = v == 30 ? 30 : 60);

  /// Debug section unlocked (password) on this phone.
  bool get debugOpen => _debugOpen;
  set debugOpen(bool v) => _setBool('debugOpen', _debugOpen = v);

  /// Debug: how many times faster than real time new sessions run.
  int get speed => _debugOpen ? _speed : 1;
  set speed(int v) => _setInt('speed', _speed = v.clamp(1, 600));

  void preset(int focus, int rest) {
    _focus = focus;
    _rest = rest;
    _prefs.setInt('focus', focus);
    _setInt('rest', rest);
  }

  void _setInt(String k, int v) {
    _prefs.setInt(k, v);
    notifyListeners();
  }

  void _setBool(String k, bool v) {
    _prefs.setBool(k, v);
    notifyListeners();
  }
}
