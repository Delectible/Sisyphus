/// Version shown in Settings and sent to the stores. Bump together with
/// pubspec.yaml's `version:` for every user-visible change.
class AppInfo {
  static const name = 'Sisyphus';
  static const version = '0.1.1';

  /// Play's "What's new" / TestFlight's "What to Test" for this build: one
  /// plain-words line (tool/play/whats_new.py reads it).
  static const latest =
      'Motivate as fast as you like: the ground now rushes past smoothly instead of jumping back.';
}
