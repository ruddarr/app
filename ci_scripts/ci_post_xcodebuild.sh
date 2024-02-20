#!/bin/sh

set -e

if [[ -n $CI_ARCHIVE_PATH ]]; then
    # Set Sentry CLI directory
    export INSTALL_DIR=$PWD

    if [[ $(command -v sentry-cli) == "" ]]; then
        curl -sL https://sentry.io/get-cli/ | bash
    fi

    $CI_PRIMARY_REPOSITORY_PATH/ci_scripts/sentry-cli \
      upload-dif \
      --org $SENTRY_ORG \
      --project $SENTRY_PROJECT \
      --auth-token $SENTRY_AUTH_TOKEN \
      $CI_ARCHIVE_PATH
else
    echo "CI_ARCHIVE_PATH is not available. Unable to run dSYMs uploading script."
    exit 1
fi
