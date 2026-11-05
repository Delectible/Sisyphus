# Developer guide

## Setup

Flutter stable 3.47+. `flutter create --org com.dingo --project-name
sisyphus --platforms android,ios .` fills in the platform boilerplate we
don't keep (CI does the same), then `flutter pub get`.

## Structure

- `lib/core/session.dart`: the session as pure logic on wall-clock times.
  Ascent, rest, ... ascent, then the summit. `update(now)` catches up on
  everything that happened while the app was closed. Pause / skip /
  abandon credit focus time as it's earned.
- `lib/core/expedition.dart`: owns the running session; ticks once a second
  while the app is open, saves it (shared_preferences), reschedules alerts,
  writes stats.
- `lib/core/alerts.dart`: phase-end notifications scheduled ahead
  (flutter_local_notifications). Exact on Android only when the user allows
  alarms (Settings > On-time alerts).
- `lib/core/stats.dart`: lifetime totals, focus per day, recent sessions.
- `lib/core/poems.dart`: summit poems by mood, owl lines, Motivate cheers.
- `lib/scene/`: `CustomPainter`s for the three scenes, driven by
  `SceneClock` (a plain timer at the Settings frame rate, stopped when the
  app is hidden; Still scenes redraws once a second). `kit.dart` has the
  shared bits (boulder shading, clouds, stars, Greek key).
- `lib/screens/`: the screens. `AppScope` hands settings / stats /
  expedition down.

## Easter eggs

Motivate (shove), 7 quick taps on the boulder (it slips), the owl (advice),
Breathe at rest, long-press the title / the mountain count, a rare lightning
strike, version x7 in Settings (Debug, password).

## Debug

CI passes `--dart-define=DEBUG_KEY=<sha256 of "sisyphus-debug:" + password>`
from the `DEBUG_PASSWORD` secret. Debug has a time speed for new sessions
(10x / 60x / 300x), a summit preview and stats reset. Local debug builds
open it with any password.

## Icon

`python3 tool/icon/make_icons.py` (Pillow + numpy) writes every launcher,
store and social image from one drawing.
