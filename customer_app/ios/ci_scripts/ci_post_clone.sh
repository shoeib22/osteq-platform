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
flutter build ios --release --no-codesign --config-only \
  --dart-define=API_BASE_URL="$API_BASE_URL" \
  --dart-define=SUPABASE_URL="$SUPABASE_URL" \
  --dart-define=SUPABASE_ANON_KEY="$SUPABASE_ANON_KEY"

# Xcode Cloud's archive action won't resolve Swift Package dependencies itself —
# it requires a Package.resolved already on disk. Resolve here, on the CI
# runner, so newly added SPM-based plugins (e.g. firebase_core) don't need a
# Package.resolved committed to the repo.
xcodebuild -resolvePackageDependencies \
  -workspace ios/Runner.xcworkspace \
  -scheme Runner

exit 0
