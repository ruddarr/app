#!/bin/sh

set -e

if [[ ! -n "$SENTRY_ORG" || ! -n "$SENTRY_PROJECT" || ! -n "$SENTRY_AUTH_TOKEN" ]]; then
  echo "SENTRY_* not set or empty."
  exit 1
fi

if [[ -n $CI_ARCHIVE_PATH ]]; then
    export INSTALL_DIR=$PWD # Set Sentry CLI directory

    if [[ $(command -v sentry-cli) == "" ]]; then
        curl -sL https://sentry.io/get-cli/ | bash
    fi

    $CI_PRIMARY_REPOSITORY_PATH/ci_scripts/sentry-cli \
      debug-files upload \
      --org $SENTRY_ORG \
      --project $SENTRY_PROJECT \
      --auth-token $SENTRY_AUTH_TOKEN \
      $CI_ARCHIVE_PATH
else
    echo "CI_ARCHIVE_PATH is not available. Unable to run dSYMs uploading script."
    exit 1
fi
