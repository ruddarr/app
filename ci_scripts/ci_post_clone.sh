#!/bin/sh

set -e

brew install yq jq

yq '.project_id' crowdin.yml
