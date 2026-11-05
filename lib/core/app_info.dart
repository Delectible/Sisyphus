/// Version shown in Settings and sent to the stores. Bump together with
/// pubspec.yaml's `version:` for every user-visible change.
class AppInfo {
  static const name = 'Sisyphus';
  static const version = '0.2.0';

  /// Play's "What's new" / TestFlight's "What to Test" for this build: one
  /// plain-words line (tool/play/whats_new.py reads it).
  static const latest =
      'Laurels to earn and new stones for your boulder, labels for your sessions, an optional long rest, '
      'ambient sound, a live countdown in Android notifications, a shareable summit card and a '
      'stormier, more detailed climb. Pausing now eases Sisyphus to a stop.';
}
