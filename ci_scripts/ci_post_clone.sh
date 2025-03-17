#!/bin/sh

set -e

cd ../Ruddarr/ || exit 1

plutil -replace APNsKey -string "$APNS_SECRET" Info.plist
plutil -insert CI_BRANCH -string "$CI_BRANCH" Info.plist
