#!/bin/sh

set -e

# SwiftLint
defaults write com.apple.dt.Xcode IDESkipPackagePluginFingerprintValidatation -bool YES
defaults write com.apple.dt.Xcode IDESkipMacroFingerprintValidation -bool YES

cd ../Ruddarr/ || exit 1

if [[ ! -n "$APNS_SECRET" ]]; then
  echo "APNS_SECRET not set or empty."
  exit 1
fi

plutil -replace APNsKey -string "$APNS_SECRET" Info.plist
plutil -insert CI_BRANCH -string "$CI_BRANCH" Info.plist
