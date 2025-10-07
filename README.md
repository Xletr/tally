# Tally

Tally is a budgeting app built for ease of use. Everything is handled locally, data never leaves the device.


## Layout
```
lib/
├─ src/core/         # bootstrap, theme, helpers
├─ src/data/         # Hive models, repositories, isolates, notifications
├─ src/domain/       # entities, Riverpod providers, business logic
├─ src/presentation/ # UI screens and widgets
└─ test/             # basic widget test
```

## Getting started
1. Install Flutter 3.22 or newer
2. Fetch packages: `flutter pub get`
3. Optional sanity check:
   ```bash
   dart format lib test
   flutter analyze
   flutter test
   ```

## Running the app
- **Android / desktop / web:** `flutter run`
- **iOS:** requires macOS. On a Mac, run:
  ```bash
  cd ios
  pod install
  cd ..
  flutter run -d ios
  ```
  For release/TestFlight builds, open `ios/Runner.xcworkspace` in Xcode, pick your signing team, and archive from the menu.

> Without a Mac you can’t build/sign the iOS version yourself. Use a cloud mac or CI service.

## Release builds
- Android APK: `flutter build apk --release`
- Android App Bundle: `flutter build appbundle`
- iOS archive: `flutter build ios --release` (then archive in Xcode)