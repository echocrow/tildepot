#!/usr/bin/env bash
#
# Set up test environment

# Install packages
packages=(
  expect
  git
  zip
)
# Speed up install by disabling man-db auto-update
rm /var/lib/man-db/auto-update
# Install with corresponding package manager
if command -v apk >/dev/null 2>&1; then
  apk add \
    "${packages[@]}"
elif command -v apt-get >/dev/null 2>&1; then
  apt-get install -y --no-install-recommends \
    "${packages[@]}"
else
  echo "No supported package manager found" >&2
  exit 1
fi
