#!/usr/bin/env bash
# Linux / macOS: APK'yı yerelde derler.
set -e
cd "$(dirname "$0")"
flutter create --platforms=android --org com.shadex --project-name shadex_vpn .
flutter pub get
dart run flutter_launcher_icons
dart run tool/android_kur.dart
flutter build apk --release
echo
echo "APK hazır: build/app/outputs/flutter-apk/app-release.apk"
