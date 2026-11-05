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
    _longRest = _prefs.getBool('longRest') ?? false;
    _longMinutes = _prefs.getInt('longMinutes') ?? 15;
    _longEvery = _prefs.getInt('longEvery') ?? 4;
    _sound = _prefs.getBool('sound') ?? false;
    _keepAwake = _prefs.getBool('keepAwake') ?? false;
    _countdown = _prefs.getBool('countdown') ?? true;
    _labels = _prefs.getStringList('labels') ?? const ['Study', 'Work', 'Writing'];
    _label = _prefs.getString('label');
    if (_label != null && !_labels.contains(_label)) _label = null;
    _skin = _prefs.getString('skin') ?? 'granite';
  }

  final SharedPreferences _prefs;

  static const minFocus = 1, maxFocus = 120;
  static const minRest = 1, maxRest = 60;
  static const minClimbs = 1, maxClimbs = 12;

  late int _focus, _rest, _climbs, _speed, _fps, _longMinutes, _longEvery;
  late bool _longRest, _sound, _keepAwake, _countdown;
  late List<String> _labels;
  String? _label;
  late String _skin;
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

  /// A longer rest after every [longEvery] climbs.
  bool get longRest => _longRest;
  set longRest(bool v) => _setBool('longRest', _longRest = v);

  static const minLong = 5, maxLong = 60;
  int get longMinutes => _longMinutes;
  set longMinutes(int v) => _setInt('longMinutes', _longMinutes = v.clamp(minLong, maxLong));

  int get longEvery => _longEvery;
  set longEvery(int v) => _setInt('longEvery', _longEvery = v.clamp(2, 6));

  /// Ambient sound (wind on the climb, the stream in the valley).
  bool get sound => _sound;
  set sound(bool v) => _setBool('sound', _sound = v);

  /// Keep the screen on during a session.
  bool get keepAwake => _keepAwake;
  set keepAwake(bool v) => _setBool('keepAwake', _keepAwake = v);

  /// Android: a live countdown in the notification shade during a session.
  bool get countdown => _countdown;
  set countdown(bool v) => _setBool('countdown', _countdown = v);

  /// Session labels, and the one picked for the next session (null = none).
  List<String> get labels => List.unmodifiable(_labels);
  String? get label => _label;
  set label(String? v) {
    _label = v;
    if (v == null) {
      _prefs.remove('label');
    } else {
      _prefs.setString('label', v);
    }
    notifyListeners();
  }

  void addLabel(String name) {
    final n = name.trim();
    if (n.isEmpty || _labels.contains(n) || _labels.length >= 12) return;
    _labels = [..._labels, n.length > 18 ? n.substring(0, 18) : n];
    _prefs.setStringList('labels', _labels);
    label = _labels.last;
  }

  void removeLabel(String name) {
    _labels = [..._labels]..remove(name);
    _prefs.setStringList('labels', _labels);
    if (_label == name) {
      label = null;
    } else {
      notifyListeners();
    }
  }

  /// The boulder's stone (a laurel reward; 'granite' is everyone's).
  String get skin => _skin;
  set skin(String v) {
    _skin = v;
    _prefs.setString('skin', v);
    notifyListeners();
  }

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
