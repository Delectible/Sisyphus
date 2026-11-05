# Sisyphus: notes for Claude

Focus (pomodoro) timer with a myth in it (Flutter). This page is the rules;
`docs/DEVELOPMENT.md` has setup, structure and how the scenes are drawn.
Same workflow as Darkroom (Delectible/Darkroom).

## How we work

- The owner tests on a Pixel 9 Pro and an iPhone, from his phone, often low
  on usage: short plain replies, stay focused, batch tweaks, run only the
  tests that matter (full suite once before committing a batch).
- Big changes: ask first. Open-ended visual changes: show 2–3 screenshot
  options before building (`SHOTS=dir flutter test test/screens_test.dart`).
- Work on the session branch; commit freely. **Only on "push"**:
  fast-forward onto `main` (`git fetch origin main && git merge-base
  --is-ancestor origin/main HEAD && git push origin HEAD:main`). Then
  send_later ~20 min, check the run, and once the `play` job has uploaded
  (+2 min) PushNotification: version, build, one line of what's new (or
  the failure).
- User-visible change: bump `pubspec.yaml` version+build and
  `AppInfo.version`; set `AppInfo.latest` (Play's "What's new", plain
  words). Unpushed changes share one version.
- Commit messages plain: no session links, no Co-Authored-By.
- Log requests in `docs/CHANGELOG.md` by number; new ideas go there too.
- Every ~3 main builds, remind him if the iPhone App Store is behind.

## Stores

- `main` → Play internal testing + TestFlight. Closed testing:
  `promote-closed.yml` when he says a build is stable.
- `appstore-release.yml` only on "release to iPhone", after checking App
  Store Connect; never cancel a submission in review.
- `play-listing.yml` only when asked.

## Never

- The Debug password; the upload key.
- Real brand names in the app or listings. Quotes: short lines only, credited.
- A Podfile; deleting `AndroidManifest.xml` / `android/app/build.gradle.kts`;
  changing `com.dingo.sisyphus`.
- Image assets for the scenes: they are drawn in code (`lib/scene/`) to
  keep the download small. The icon is generated (`tool/icon/make_icons.py`).
- Driving the scenes from a vsync Ticker: `SceneClock` runs at the
  Settings frame rate (60/30) and stops in the background; keep it that way
  (battery).

## Checks

`flutter analyze`, `flutter test` (SDK may be at `/tmp/flutter/bin`; set
`FLUTTER_ROOT`). `dart format -l 110` on changed files only. Screens:
`test/screens_test.dart`, `SHOTS=dir` for PNGs.
