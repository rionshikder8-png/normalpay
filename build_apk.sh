#!/usr/bin/env bash
set -euo pipefail

if ! command -v flutter >/dev/null 2>&1; then
  echo "Flutter SDK not found. Install Flutter stable and run flutter doctor first." >&2
  exit 1
fi

flutter pub get

# Flutter SDK templates supply the Gradle wrapper JAR. This package intentionally
# does not ship that binary; create a temporary official Flutter scaffold if needed.
if [[ ! -f android/gradle/wrapper/gradle-wrapper.jar ]]; then
  seed="$(mktemp -d)"
  trap 'rm -rf "$seed"' EXIT
  flutter create --platforms=android --project-name normal_pay_sms_reader "$seed/wrapper_seed" >/dev/null
  cp "$seed/wrapper_seed/android/gradlew" android/gradlew
  cp "$seed/wrapper_seed/android/gradlew.bat" android/gradlew.bat
  cp "$seed/wrapper_seed/android/gradle/wrapper/gradle-wrapper.jar" android/gradle/wrapper/gradle-wrapper.jar
  chmod +x android/gradlew
fi

flutter analyze
flutter build apk --release
echo "APK: build/app/outputs/flutter-apk/app-release.apk"
