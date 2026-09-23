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
#
# ios/Runner.xcworkspace/xcshareddata/swiftpm/Package.resolved is committed
# to the repo (generated once via .github/workflows/resolve-spm.yml, since
# Xcode Cloud's runners refuse to resolve Swift Package dependencies
# themselves for a package with no existing lockfile). Keep that file in
# sync by re-running the workflow and committing its output whenever a
# plugin's SPM dependencies change — don't delete it.
flutter build ios --release --no-codesign --config-only \
  --dart-define=API_BASE_URL="$API_BASE_URL" \
  --dart-define=SUPABASE_URL="$SUPABASE_URL" \
  --dart-define=SUPABASE_ANON_KEY="$SUPABASE_ANON_KEY"

exit 0
