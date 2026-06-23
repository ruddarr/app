#!/bin/sh

set -e

if [[ ! -n "$SENTRY_ORG" || ! -n "$SENTRY_PROJECT" || ! -n "$SENTRY_AUTH_TOKEN" ]]; then
  echo "SENTRY_* not set or empty."
  exit 1
fi

# Retry a command on transient (network) failures with linear backoff.
retry() {
  attempts=$1; shift
  count=0
  until "$@"; do
    count=$((count + 1))
    if [ "$count" -ge "$attempts" ]; then
      echo "Command failed after $count attempts: $*"
      return 1
    fi
    echo "Attempt $count failed. Retrying in $((count * 10))s..."
    sleep $((count * 10))
  done
}

if [[ -n $CI_ARCHIVE_PATH ]]; then
    export INSTALL_DIR=$PWD # Set Sentry CLI directory

    if [[ $(command -v sentry-cli) == "" ]]; then
        export HOMEBREW_NO_AUTO_UPDATE=1
        export HOMEBREW_NO_INSTALL_CLEANUP=1
        export HOMEBREW_FAKE_MACOS=26.0 # macOS 27 fix

        retry 5 brew install getsentry/tools/sentry-cli
    fi

    retry 5 sentry-cli \
      debug-files upload \
      --org $SENTRY_ORG \
      --project $SENTRY_PROJECT \
      --auth-token $SENTRY_AUTH_TOKEN \
      $CI_ARCHIVE_PATH
else
    echo "CI_ARCHIVE_PATH is not available. Unable to run dSYMs uploading script."
    exit 1
fi
