import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';

class Ambience {
  Ambience._();
  static final instance = Ambience._();

  static const _volume = 0.55;
  AudioPlayer? _player;
  bool _on = false;
  double _vol = 0;
  Timer? _fade;
  Future<String>? _file;
  int _token = 0;

  /// Fades the wind in ([on]) or out. Repeated calls are free.
  Future<void> play(bool on) async {
    if (on == _on) return;
    final token = ++_token;
    _on = on;
    try {
      final player = _player ??= await _makePlayer();
      if (!on) {
        await _fadeTo(0, const Duration(milliseconds: 1200));
        if (token == _token) await player.stop();
        return;
      }
      final path = await (_file ??= _render());
      if (token != _token) return;
      await player.setSource(DeviceFileSource(path, mimeType: 'audio/wav'));
      await player.resume();
      await _fadeTo(_volume, const Duration(milliseconds: 2500));
    } catch (_) {
      // Sound is a nicety; a device that can't play it just stays quiet.
    }
  }

  /// App hidden / shown.
  Future<void> suspend(bool hidden) async {
    final p = _player;
    if (p == null || !_on) return;
    try {
      hidden ? await p.pause() : await p.resume();
    } catch (_) {}
  }

  Future<AudioPlayer> _makePlayer() async {
    final p = AudioPlayer();
    await p.setReleaseMode(ReleaseMode.loop);
    await p.setVolume(0);
    await p.setAudioContext(
      AudioContextConfig(focus: AudioContextConfigFocus.mixWithOthers, respectSilence: true).build(),
    );
    return p;
  }

  Future<void> _fadeTo(double target, Duration over) {
    _fade?.cancel();
    final done = Completer<void>();
    final from = _vol;
    const step = Duration(milliseconds: 50);
    final n = math.max(1, over.inMilliseconds ~/ step.inMilliseconds);
    var i = 0;
    _fade = Timer.periodic(step, (t) {
      i++;
      _vol = from + (target - from) * (i / n);
      _player?.setVolume(_vol.clamp(0.0, 1.0));
      if (i >= n) {
        t.cancel();
        if (!done.isCompleted) done.complete();
      }
    });
    return done.future;
  }

  Future<String> _render() async {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/sisyphus_wind_v2.wav');
    if (await file.exists()) return file.path;
    final bytes = await Isolate.run(synthesize);
    await file.writeAsBytes(bytes, flush: true);
    return file.path;
  }
}

const _rate = 22050;

/// The WAV bytes of a seamless wind loop (public for tests).
///
/// Brown noise (integrated white noise, kept centred), trimmed below ~80 Hz
/// so phone speakers can play it, through a gentle low-pass whose
/// brightness drifts a little, with a slowly wandering loudness (a few dB):
/// slow sines at unrelated rates plus smoothed random gusts, so the swell
/// never repeats in a way the ear can catch within the minute-long loop.
Uint8List synthesize({double seconds = 60}) {
  final n = (seconds * _rate).round();
  const fadeN = _rate * 3;
  final total = n + fadeN;
  final s = Float64List(total);
  final rnd = math.Random(11);

  // Smoothed random gusts: a few control points per second, eased between.
  const gustRate = 0.35; // points per second
  final points = List<double>.generate((total / _rate * gustRate).ceil() + 3, (_) => rnd.nextDouble());

  double gustAt(double t) {
    final x = t * gustRate;
    final i = x.floor();
    final f = x - i;
    final e = f * f * (3 - 2 * f);
    return points[i] + (points[i + 1] - points[i]) * e;
  }

  var brown = 0.0, lp1 = 0.0, lp2 = 0.0, hp = 0.0, prev = 0.0;
  for (var i = 0; i < total; i++) {
    final t = i / _rate;
    final white = rnd.nextDouble() * 2 - 1;
    // Brown noise with a slow leak so it never drifts off centre.
    brown = brown * 0.9985 + white * 0.035;
    final swell =
        0.78 +
        0.07 * math.sin(2 * math.pi * t / 23.0) +
        0.05 * math.sin(2 * math.pi * t / 9.7 + 1.1) +
        0.03 * math.sin(2 * math.pi * t / 4.3 + 2.3) +
        0.16 * (gustAt(t) - 0.5);
    // A touch brighter as it swells (cutoff ~700-1300 Hz): one gentle pole
    // keeps the natural brown slope, a softer second pole tames hiss.
    final cutoff = 700 + 600 * swell.clamp(0.0, 1.0);
    final a = 1 - math.exp(-2 * math.pi * cutoff / _rate);
    lp1 += (brown - lp1) * a;
    lp2 += (lp1 - lp2) * (1 - math.exp(-2 * math.pi * 2600 / _rate));
    // High-pass (~80 Hz): phone speakers can't play the deep rumble, and
    // it would only eat loudness.
    hp = 0.9775 * (hp + lp2 - prev);
    prev = lp2;
    s[i] = hp * swell;
  }
  // Seamless loop: the tail crossfades into the head (equal power).
  for (var i = 0; i < fadeN; i++) {
    final a = i / fadeN;
    s[i] = s[i] * math.sqrt(a) + s[n + i] * math.sqrt(1 - a);
  }
  // Normalise to a gentle peak and write 16-bit mono.
  var peak = 1e-9;
  for (var i = 0; i < n; i++) {
    peak = math.max(peak, s[i].abs());
  }
  final pcm = Int16List(n);
  for (var i = 0; i < n; i++) {
    pcm[i] = (s[i] / peak * 0.8 * 32767).round();
  }
  return _wav(pcm);
}

Uint8List _wav(Int16List pcm) {
  final data = pcm.buffer.asUint8List();
  final out = BytesBuilder();
  void str(String v) => out.add(v.codeUnits);
  void u32(int v) => out.add((ByteData(4)..setUint32(0, v, Endian.little)).buffer.asUint8List());
  void u16(int v) => out.add((ByteData(2)..setUint16(0, v, Endian.little)).buffer.asUint8List());
  str('RIFF');
  u32(36 + data.length);
  str('WAVE');
  str('fmt ');
  u32(16);
  u16(1);
  u16(1);
  u32(_rate);
  u32(_rate * 2);
  u16(2);
  u16(16);
  str('data');
  u32(data.length);
  out.add(data);
  return out.toBytes();
}
