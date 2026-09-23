#!/bin/sh
set -e

# Xcode Cloud clones the repo but has no Flutter SDK. Install it, then run a
# config-only build so Generated.xcconfig (DART_DEFINES, pod install, etc.)
# is ready before Xcode's native archive step takes over.

git clone https://github.com/flutter/flutter.git -b stable "$HOME/flutter" --depth 1
export PATH="$PATH:$HOME/flutter/bin"

flutter precache --ios
flutter doctor

cd "$CI_PRIMARY_REPOSITORY_PATH/customer_app"
flutter pub get

# API_BASE_URL, SUPABASE_URL, SUPABASE_ANON_KEY must be set as Environment
# Variables on the Xcode Cloud workflow (App Store Connect > Xcode Cloud >
# this workflow > Environment) so they never live in the repo.
config_only_build() {
  flutter build ios --release --no-codesign --config-only \
    --dart-define=API_BASE_URL="$API_BASE_URL" \
    --dart-define=SUPABASE_URL="$SUPABASE_URL" \
    --dart-define=SUPABASE_ANON_KEY="$SUPABASE_ANON_KEY"
}

# Xcode Cloud disables automatic Swift Package resolution for every xcodebuild
# invocation, including the one `flutter build ios` runs internally — so the
# very first build here is expected to fail with "a resolved file is
# required..." the first time a new SPM-based plugin (e.g. firebase_core) is
# added, because that's also the step that makes Flutter register the
# package reference in Runner.xcodeproj in the first place. Let it fail,
# resolve explicitly now that the reference exists, then build again — this
# two-pass pattern is the standard workaround for Xcode Cloud + Flutter SPM
# plugins (see flutter/flutter and firebase/flutterfire issue trackers).
config_only_build || true

xcodebuild -resolvePackageDependencies \
  -workspace ios/Runner.xcworkspace \
  -scheme Runner

config_only_build

exit 0
