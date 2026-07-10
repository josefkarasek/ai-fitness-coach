# Client Flutter

This directory now contains a lightweight Flutter app shell for the AI Fitness Coach client.

The shell is intentionally thin:

- Firebase Auth in the client
- Backend-driven training logic
- Workout import/upload UI
- Imported workout history UI
- Backend-generated workout explanation UI
- Backend-generated training plan UI
- Render coaching plans returned by Go APIs

## Current State

The project files in this directory were scaffolded manually because the current shell environment does not have `flutter`, `dart`, or `flutterfire` installed.

That means these generated Flutter platform folders are not present yet:

- `android/`
- `ios/`
- `linux/`
- `macos/`
- `web/`
- `windows/`

## Next Steps

After installing Flutter locally, run these commands inside `client_flutter/`:

```bash
flutter create .
flutter pub get
dart pub global activate flutterfire_cli
flutterfire configure
```

If `flutterfire` is already installed globally and on your `PATH`, you can skip the activation step.

## Firebase Packages

This app shell already declares:

- `firebase_core`
- `firebase_auth`

Versions were chosen from current pub.dev package pages on July 8, 2026:

- `firebase_core: ^4.11.0`
- `firebase_auth: ^6.5.4`

Sources:

- https://pub.dev/packages/firebase_core
- https://pub.dev/packages/firebase_auth
