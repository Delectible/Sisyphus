import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';

/// The soundscapes. Each is generated in code (no audio files in the app),
/// written once to the cache folder as a WAV loop and played on repeat.
enum Soundscape { climb, valleyDay, valleyNight, summit }

/// Ambient sound: wind on the climb, the stream and birds (or crickets) in
/// the valley, a high breeze at the summit. Mixes with other audio and
/// respects the iPhone's silent switch.
class Ambience {
  Ambience._();
  static final instance = Ambience._();

  static const _volume = 0.55;
  AudioPlayer? _player;
  Soundscape? _current;
  double _vol = 0;
  Timer? _fade;
  final Map<Soundscape, Future<String>> _files = {};
  int _token = 0;

  /// Plays [scape], crossfading from whatever was playing. Null fades out.
  Future<void> play(Soundscape? scape) async {
    if (scape == _current) return;
    final token = ++_token;
    _current = scape;
    try {
      final player = _player ??= await _makePlayer();
      if (_vol > 0) await _fadeTo(0, const Duration(milliseconds: 900));
      if (token != _token) return;
      if (scape == null) {
        await player.stop();
        return;
      }
      final path = await (_files[scape] ??= _render(scape));
      if (token != _token) return;
      await player.setSource(DeviceFileSource(path, mimeType: 'audio/wav'));
      await player.resume();
      await _fadeTo(_volume, const Duration(milliseconds: 1600));
    } catch (_) {
      // Sound is a nicety; a device that can't play it just stays quiet.
    }
  }

  /// App hidden / shown.
  Future<void> suspend(bool hidden) async {
    final p = _player;
    if (p == null || _current == null) return;
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

  Future<String> _render(Soundscape scape) async {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/sisyphus_${scape.name}_v1.wav');
    if (await file.exists()) return file.path;
    final bytes = await Isolate.run(() => synthesize(scape));
    await file.writeAsBytes(bytes, flush: true);
    return file.path;
  }
}

const _rate = 22050;

/// The WAV bytes of a seamless loop for [scape] (public for tests).
Uint8List synthesize(Soundscape scape, {double seconds = 24}) {
  final n = (seconds * _rate).round();
  const fadeN = _rate * 2;
  final s = Float64List(n + fadeN);
  final rnd = math.Random(scape.index + 7);
  switch (scape) {
    case Soundscape.climb:
      _wind(s, rnd, gain: 1.0, whistle: 0.35);
    case Soundscape.summit:
      _wind(s, rnd, gain: 0.55, whistle: 0.18);
    case Soundscape.valleyDay:
      _stream(s, rnd, gain: 0.5);
      _birds(s, rnd);
    case Soundscape.valleyNight:
      _stream(s, rnd, gain: 0.35);
      _crickets(s, rnd);
  }
  // Seamless loop: the tail crossfades into the head.
  for (var i = 0; i < fadeN; i++) {
    final a = math.sqrt(i / fadeN);
    s[i] = s[i] * a + s[n + i] * math.sqrt(1 - i / fadeN);
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

/// A two-pole band-pass filter (RBJ biquad), retunable per sample.
class _BandPass {
  double _x1 = 0, _x2 = 0, _y1 = 0, _y2 = 0;
  double _b0 = 0, _b2 = 0, _a1 = 0, _a2 = 0;

  void tune(double freq, double q) {
    final w = 2 * math.pi * freq / _rate;
    final alpha = math.sin(w) / (2 * q);
    final a0 = 1 + alpha;
    _b0 = alpha / a0;
    _b2 = -alpha / a0;
    _a1 = -2 * math.cos(w) / a0;
    _a2 = (1 - alpha) / a0;
  }

  double run(double x) {
    final y = _b0 * x + _b2 * _x2 - _a1 * _y1 - _a2 * _y2;
    _x2 = _x1;
    _x1 = x;
    _y2 = _y1;
    _y1 = y;
    return y;
  }
}

void _wind(Float64List s, math.Random rnd, {required double gain, required double whistle}) {
  var brown = 0.0, lp = 0.0;
  final bp = _BandPass();
  for (var i = 0; i < s.length; i++) {
    final t = i / _rate;
    final white = rnd.nextDouble() * 2 - 1;
    brown = (brown + 0.02 * white) * 0.998;
    lp += (brown - lp) * 0.08;
    final gust =
        0.5 +
        0.25 * math.sin(2 * math.pi * 0.05 * t) +
        0.15 * math.sin(2 * math.pi * 0.13 * t + 1.3) +
        0.1 * math.sin(2 * math.pi * 0.31 * t + 0.4);
    if (i % 64 == 0) bp.tune(420 + 260 * gust + 60 * math.sin(t * 0.7), 9);
    final whistleTone = bp.run(white) * whistle * gust * gust;
    s[i] = (lp * 6 * gust) * gain + whistleTone * gain;
  }
}

void _stream(Float64List s, math.Random rnd, {required double gain}) {
  final a = _BandPass(), b = _BandPass();
  var f1 = 1200.0, f2 = 2400.0;
  for (var i = 0; i < s.length; i++) {
    if (i % 32 == 0) {
      f1 = (f1 + (rnd.nextDouble() - 0.5) * 120).clamp(700, 1900);
      f2 = (f2 + (rnd.nextDouble() - 0.5) * 200).clamp(1800, 3400);
      a.tune(f1, 3);
      b.tune(f2, 5);
    }
    final w = rnd.nextDouble() * 2 - 1;
    final flutter =
        0.7 + 0.3 * math.sin(i / _rate * 2 * math.pi * 3.1) * math.sin(i / _rate * 2 * math.pi * 0.37);
    s[i] += (a.run(w) * 0.6 + b.run(w) * 0.35) * flutter * gain;
  }
}

void _birds(Float64List s, math.Random rnd) {
  var t = 1.0;
  final end = s.length / _rate - 1.5;
  while (t < end) {
    final notes = 2 + rnd.nextInt(5);
    final base = 2300 + rnd.nextDouble() * 1600;
    final rise = (rnd.nextDouble() - 0.3) * 1800;
    var at = t;
    for (var k = 0; k < notes; k++) {
      final dur = 0.05 + rnd.nextDouble() * 0.09;
      final start = (at * _rate).round();
      final len = (dur * _rate).round();
      var phase = 0.0;
      for (var j = 0; j < len && start + j < s.length; j++) {
        final u = j / len;
        final f = base + rise * u + 300 * math.sin(u * math.pi * 6);
        phase += 2 * math.pi * f / _rate;
        final env = math.sin(math.pi * u);
        s[start + j] += math.sin(phase) * env * env * 0.22;
      }
      at += dur + 0.03 + rnd.nextDouble() * 0.08;
    }
    t = at + 1.8 + rnd.nextDouble() * 4;
  }
}

void _crickets(Float64List s, math.Random rnd) {
  for (final (freq, period, offset, amp) in [(4400.0, 0.9, 0.0, 0.16), (4950.0, 1.27, 0.4, 0.11)]) {
    for (var i = 0; i < s.length; i++) {
      final t = i / _rate + offset;
      final cycle = t % period;
      // Three quick pulses, then quiet.
      if (cycle > 0.12) continue;
      final pulse = (cycle * 30) % 1.0;
      final env = pulse < 0.6 ? math.sin(math.pi * pulse / 0.6) : 0.0;
      s[i] += math.sin(2 * math.pi * freq * i / _rate) * env * amp;
    }
  }
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
