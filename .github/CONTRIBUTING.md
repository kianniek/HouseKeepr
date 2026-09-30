# Contributing

Thanks for contributing to HouseKeepr!

## Ways to contribute
- Report bugs
- Propose improvements
- Improve docs
- Submit pull requests

## Before you start
- Do not commit secrets. The repository ignores `.env` files; keep API keys and service accounts out of commits.
- Search existing issues and discussions before opening a new one.

## Local development
Prereqs:
- Flutter SDK
- A configured Firebase project (for full functionality)

Typical workflow:
```powershell
flutter clean
flutter pub get
flutter test --reporter expanded
```

Running with build-time defines from `.env`:
```powershell
flutter run -d chrome --dart-define-from-file=.env
```

## Code style
- Keep changes focused and easy to review.
- Prefer small PRs.
- Run formatting and analysis:
```powershell
dart format .
flutter analyze
```

## Pull requests
- Describe *what* changed and *why*.
- Include screenshots for UI changes when practical.
- Add/adjust tests when behavior changes.

## Reporting bugs
When filing a bug, include:
- Steps to reproduce
- Expected vs actual behavior
- Platform (web/android/ios/windows) and Flutter version
- Logs (sanitized)
