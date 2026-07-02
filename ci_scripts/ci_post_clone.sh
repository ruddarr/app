#!/bin/sh

set -e

cd .. || exit 1

if [[ -z "$CROWDIN_TOKEN" ]]; then
  echo "CROWDIN_TOKEN not set or empty."
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

export HOMEBREW_NO_AUTO_UPDATE=1
export HOMEBREW_NO_INSTALL_CLEANUP=1
export HOMEBREW_FAKE_MACOS=26.0 # macOS 27 fix

retry 5 brew install crowdin yq

EXPORTED=(en $(yq '.export_languages[]' crowdin.yml))

# Convert Crowdin codes to Apple language codes
EXPORTED=("${EXPORTED[@]/es-ES/es}")
EXPORTED=("${EXPORTED[@]/zh-CN/zh-Hans}")

# Download translations
FLAGS=($(yq -r '.export_languages[] | "--language="+.' crowdin.yml))
retry 5 crowdin download translations --plain "${FLAGS[@]}"

cd Ruddarr

# macOS: Set `CFBundleLocalizations` in `Info.plist`
if [[ "$CI_PRODUCT_PLATFORM" == "macOS" ]]; then
  plutil -remove CFBundleLocalizations Info.plist 2>/dev/null || true
  plutil -insert CFBundleLocalizations -array Info.plist
  for lang in "${EXPORTED[@]}"; do
    plutil -insert CFBundleLocalizations -string "$lang" -append Info.plist
  done
fi

# Remove languages that are not exported from *.xcstrings catalogs
for file in Localizable.xcstrings AppShortcuts.xcstrings InfoPlist.xcstrings; do
  for lang in $(jq -r '.strings[].localizations | keys[]' "$file" | sort -u); do
    if [[ " ${EXPORTED[*]} " != *" $lang "* ]]; then
      jq "del(.strings[].localizations.\"${lang}\")" "$file" > "${file}.json"
      mv "${file}.json" "$file"
    fi
  done
done
