#!/bin/sh

set -e

cd $CI_WORKSPACE/Ruddarr || exit 1

plutil -replace APNsKey -string $APNS_SECRET Info.plist
plutil -p Info.plist
