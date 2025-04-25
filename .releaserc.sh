#!/bin/bash
#
# Release configuration injection for tildepot.

# Enable strict mode
set -euo pipefail

function release_rc::main() {
  local cfg
  cfg="$(<./.releaserc)"

  while read -r filename; do
    local bundle
    bundle="$(basename "$filename" '.sh')"
    cfg="$(
      jq ".packages += [{
        \"package\": \"${bundle}-bundle\",
        \"assets\": [\"bundles/${bundle}.sh\"]
      }]" <<<"$cfg"
    )"
  done < <(find "./bundles" -type f -name '*.sh' -mindepth 1 -maxdepth 1)

  echo "$cfg"
}

release_rc::main "$@"
