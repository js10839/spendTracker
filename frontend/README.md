# Spending Tracker Flutter App

This directory is the iOS and Android Flutter app. The previous React/Vite scaffold has been replaced. Product behavior and screen requirements are defined in [Spending-tracker.md](../Spending-tracker.md).

## Run locally

Install Flutter, then run from this directory:

```bash
flutter pub get
flutter run
```

For the current scaffold, verify changes with:

```bash
flutter analyze
flutter test
```

`lib/main.dart` currently contains only a minimal launch screen. Feature screens, Supabase Auth, and FastAPI integration have not been added yet. App data must go through FastAPI; the mobile app may call Supabase directly only for Auth.

Before a store release, replace the generated `com.example` Android application ID and iOS bundle identifier with the team's chosen identifiers.
