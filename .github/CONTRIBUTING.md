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

## Branching and release workflow

`main` is the production branch and `testing` is the staging/integration branch. Direct commits to either branch are prohibited; merge changes through pull requests.

- `feature/<short-desc>` and `fix/<short-desc>` branch from `testing` and merge back into `testing`.
- `release/<version>` branches from `testing`, then merge into `main`, receive an annotated version tag, and merge back into `testing`.
- `hotfix/<short-desc>` branches from `main` for critical production fixes and must merge into both `main` and `testing`.

Typical feature flow:

```powershell
git switch testing
git pull origin testing
git switch -c feature/auth-refresh
git add .
git commit -m "feat(auth): implement refresh token handling"
git push -u origin feature/auth-refresh
```

### Local Git hooks

The repository includes dependency-free PowerShell hooks for Windows. Configure them once per checkout:

```powershell
.\scripts\setup-hooks.ps1
```

The hooks block direct commits to `main` and `testing`, format staged Dart files, run `flutter analyze` and `flutter test`, and validate commit messages using Conventional Commits. Merge and revert commit messages are allowed automatically. Hooks are local Git configuration and do not replace CI validation.

Release example:

```powershell
git switch testing
git pull origin testing
git switch -c release/v1.1.0
# Update pubspec.yaml, then commit and test the release.
git switch main
git pull origin main
git merge --no-ff release/v1.1.0
git tag -a v1.1.0 -m "Release v1.1.0"
git push origin main --tags
git switch testing
git merge --no-ff release/v1.1.0
git push origin testing
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
