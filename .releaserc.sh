#!/usr/bin/env bash
#
# Release configuration injection for tildepot.

# Enable strict mode
set -euo pipefail

function release_rc::main() {
	local cfg="${1?}"

	while read -r filename; do
		local bundle
		bundle="$(basename "$filename" '.sh')"
		cfg="$(
			jq '.packages += [{
				"name": "'"${bundle}-bundle"'",
				"scope": "'"${bundle}-bundle"'|every-bundle",
				"assets": ["'"bundles/${bundle}.sh"'"],
				"auxiliary": true
			}]' <<<"$cfg"
		)"
	done < <(find "./bundles" -mindepth 1 -maxdepth 1 -type f -name '*.sh')

	echo "$cfg"
}

release_rc::main "$@"
