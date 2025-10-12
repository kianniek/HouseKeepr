# housekeepr

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## Build-time Firebase configuration

This project reads Firebase configuration from Dart environment defines so you can avoid hard-coding values into source files. You can provide these at build time using `--dart-define`.

Local example (web):

```powershell
flutter run -d chrome \
	--dart-define=FIREBASE_WEB_API_KEY=AIza... \
	--dart-define=FIREBASE_PROJECT_ID=your-project-id \
	--dart-define=FIREBASE_AUTH_DOMAIN=your-app.firebaseapp.com \
	--dart-define=FIREBASE_APP_ID=1:... \
	--dart-define=FIREBASE_MEASUREMENT_ID=G-...
```

Platform-specific keys are also supported; set `FIREBASE_ANDROID_API_KEY`, `FIREBASE_IOS_API_KEY`, etc., if needed.

CI / GitHub Actions

Create repository secrets (Settings → Secrets) for the values you need (example names below), then use the provided workflow to build the web app with defines.

- FIREBASE_WEB_API_KEY
- FIREBASE_PROJECT_ID
- FIREBASE_AUTH_DOMAIN
- FIREBASE_APP_ID
- FIREBASE_MEASUREMENT_ID

The included workflow `.github/workflows/build-web.yml` demonstrates how to pass these secrets into the `flutter build web` command using `--dart-define`.

Note: Client Firebase API keys are not secret in the sense that they are embedded in the client bundle for web/mobile; these measures are mostly for preventing accidental commits and for convenient build-time configuration.
