#!/bin/sh

set -e

echo $PATH

curl https://github.com/mikefarah/yq/releases/latest/download/yq_darwin_arm64 -O /usr/bin/yq \
  && chmod +x /usr/bin/yq

yq '.project_id' crowdin.yml
