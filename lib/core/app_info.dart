/// Version shown in Settings and sent to the stores. Bump together with
/// pubspec.yaml's `version:` for every user-visible change.
class AppInfo {
  static const name = 'Sisyphus';
  static const version = '0.1.1';

  /// Play's "What's new" / TestFlight's "What to Test" for this build: one
  /// plain-words line (tool/play/whats_new.py reads it).
  static const latest =
      'Pausing now brings Sisyphus to a gentle stop. The valley has more to see: ridges, pines, '
      'a stream, sheep and a little temple. Motivate as fast as you like, the ground keeps up.';
}
