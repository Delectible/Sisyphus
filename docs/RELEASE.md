# Release roadmap

O = the owner in a console / on a phone, C = Claude in the repo.

## 1. Repo and CI (C, done in the first push)

- [x] Build workflow: analyze + test, APK + AAB, iPhone build, GitHub
  release, Play internal testing, TestFlight (+ external testers).
- [x] Hand-run workflows: promote to closed testing, App Store release,
  Play listing, remove old builds.

## 2. Secrets (O, repo Settings > Secrets and variables > Actions)

- [ ] `ANDROID_KEYSTORE_BASE64`, `ANDROID_KEYSTORE_PASSWORD`: a new upload
  key for Sisyphus (alias `upload`). Without it builds use the public test key.
- [ ] `DEBUG_PASSWORD`.
- [ ] `PLAY_SERVICE_ACCOUNT_JSON`: the Darkroom service account can be
  reused (invite it to the new app in Play Console > Users and permissions).
- [ ] `APPSTORE_KEY_ID`, `APPSTORE_ISSUER_ID`, `APPSTORE_KEY`,
  `APPLE_TEAM_ID`: the same App Store Connect key as Darkroom works.
- [ ] Repo variable `PLAY_RELEASE_STATUS=draft` until the app's first
  release is out of draft in the Play Console.

## 3. Google Play (O)

- [ ] Create the app `com.dingo.sisyphus`; upload the first `.aab` by hand
  (from a CI run's Release... the .aab is a 1-day artifact; or ask C).
- [ ] Store listing from `fastlane/metadata/android/en-AU` (or run
  `play-listing.yml`), privacy policy URL (docs/PRIVACY.md), Data safety:
  no data collected; content rating; target audience.
- [ ] Internal testing, then closed testing (12 testers / 14 days), then production.

## 4. App Store (O)

- [ ] App ID `com.dingo.sisyphus` + app in App Store Connect.
- [ ] TestFlight from CI; listing, screenshots, App Privacy "Data Not Collected".
