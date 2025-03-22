#!/bin/sh

set -e

cd .. || exit 1

brew install crowdin yq

EXPORTED=(en $(yq '.export_languages[]' crowdin.yml))

# Convert to Apple language codes
EXPORTED=("${EXPORTED[@]/es-ES/es}")

# Download translations
FLAGS=$(yq '.export_languages[]' crowdin.yml | awk '{printf "--language=%s ", $0}')
crowdin download translations --plain ${FLAGS}

cd Ruddarr

# Remove languages that are not exported from *.xcstrings catalogs
for file in Localizable.xcstrings AppShortcuts.xcstrings; do
  for lang in $(jq -r '.strings[].localizations | keys[]' $file | sort -u); do
    if [[ ! ${EXPORTED[@]} =~ $lang ]]; then
      jq "del(.strings[].localizations.${lang})" $file > "${file}.json"
      mv "${file}.json" $file
    fi
  done
done
