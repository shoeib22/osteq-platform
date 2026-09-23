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
# invocation, including `-resolvePackageDependencies` itself — so the plain
# resolve command fails with the same "a resolved file is required" error as
# the build does. -disableAutomaticPackageResolution NO overrides that for
# this one invocation, which is the only thing that can populate
# Package.resolved on a machine that has never resolved these packages
# before. The first config-only build is still expected to fail once: it's
# what makes Flutter register the new plugin's package reference in
# Runner.xcodeproj in the first place, before there's anything to resolve.
config_only_build || true

xcodebuild -resolvePackageDependencies \
  -workspace ios/Runner.xcworkspace \
  -scheme Runner \
  -disableAutomaticPackageResolution NO

config_only_build

exit 0
