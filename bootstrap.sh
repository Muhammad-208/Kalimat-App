#!/usr/bin/env bash
# bootstrap.sh — run once after cloning to generate the native platform folders
# (android/, ios/) and pin the published applicationId to com.kalimat.app.
#
# The repo holds only the Flutter source (lib/, assets/, pubspec). Platform
# folders are generated locally so they always match your Flutter version.
set -e

echo "→ generating android/ios platform folders..."
flutter create --org com.kalimat --project-name kalimat --platforms=android,ios .

echo "→ pinning applicationId = com.kalimat.app ..."
for f in android/app/build.gradle android/app/build.gradle.kts; do
  [ -f "$f" ] || continue
  # only the applicationId line (leave namespace / Kotlin package untouched)
  sed -i.bak -E 's/applicationId(\s*=?\s*)"com\.kalimat\.kalimat"/applicationId\1"com.kalimat.app"/' "$f"
  rm -f "$f.bak"
done

# flutter create drops a boilerplate widget test that instantiates MyApp — a
# class this project doesn't have (the root widget is KalimatApp). Left in
# place it fails `flutter analyze` and `flutter test` on a fresh bootstrap.
rm -f test/widget_test.dart

echo "→ applying release signing config ..."
# flutter create rewrites build.gradle.kts, so re-inject the signing wiring.
# Falls back to the debug key when android/key.properties is absent.
python3 tools/apply_signing.py

echo "→ flutter pub get ..."
flutter pub get

echo "✓ done. applicationId is com.kalimat.app"
echo "  next: flutterfire configure  (see SYNC_SETUP.md), then flutter run"
