/// Version shown in Settings and sent to the stores. Bump together with
/// pubspec.yaml's `version:` for every user-visible change.
class AppInfo {
  static const name = 'Sisyphus';
  static const version = '0.1.0';

  /// Play's "What's new" / TestFlight's "What to Test" for this build: one
  /// plain-words line (tool/play/whats_new.py reads it).
  static const latest =
      'First build: push the boulder while you focus, rest in the valley, '
      'reach the summit. Stats, poems and a few secrets.';
}
