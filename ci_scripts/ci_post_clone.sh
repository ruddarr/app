#!/bin/sh

set -e

# for future reference
# https://developer.apple.com/documentation/xcode/environment-variable-reference

echo $(pwd)
echo $CI_XCODE_PROJECT
echo $CI_WORKSPACE_PATH
echo $CI_PROJECT_FILE_PATH
echo $CI_PRIMARY_REPOSITORY_PATH
echo $CI_DERIVED_DATA_PATH

cd ../Ruddarr/
# cd $CI_WORKSPACE/Ruddarr || exit 1

echo $(pwd)

plutil -replace APNsKey -string "$APNS_SECRET" Info.plist
plutil -p Info.plist
