import 'dart:async';

import 'package:flutter/foundation.dart';

/// Drives the scenes at a modest frame rate (not the display's 60-120 Hz),
/// and only while running: the painters read [t] (seconds).
class SceneClock extends ChangeNotifier {
  // ignore: prefer_initializing_formals
  SceneClock({int fps = 60}) : _fps = fps;

  int _fps;

  /// Frames per second while moving. Still mode redraws once a second.
  int get fps => _fps;
  set fps(int v) {
    if (v == _fps) return;
    _fps = v;
    if (_running) _arm();
  }

  final _watch = Stopwatch();
  double _offset = 0;
  Timer? _timer;
  bool _still = false;
  bool _running = false;

  double get t => _offset + _watch.elapsedMicroseconds / 1e6;

  /// Tests and previews: a fixed time.
  set t(double v) {
    _offset = v - _watch.elapsedMicroseconds / 1e6;
    notifyListeners();
  }

  bool get still => _still;
  set still(bool v) {
    if (v == _still) return;
    _still = v;
    if (_running) _arm();
  }

  void start() {
    if (_running) return;
    _running = true;
    _watch.start();
    _arm();
  }

  void stop() {
    _running = false;
    _watch.stop();
    _timer?.cancel();
    _timer = null;
  }

  void _arm() {
    _timer?.cancel();
    final ms = _still ? 1000 : (1000 / fps).round();
    _timer = Timer.periodic(Duration(milliseconds: ms), (_) => notifyListeners());
  }

  @override
  void dispose() {
    stop();
    super.dispose();
  }
}
