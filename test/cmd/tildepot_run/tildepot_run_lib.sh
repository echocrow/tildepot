#!/usr/bin/env bash
#
# Bats helpers for tildepot run hook tests

# Setup
mkdir "$TILDEPOT_HOME"
mkdir "$TILDEPOT_HOME/bundles"

function test::mock_bundle() {
	local bundle="${1?}"
	local body
	local path
	if [[ $# -lt 3 ]]; then
		body="${2-}"
		path=""
	else
		path="$2"
		body="$3"
	fi

	if [[ $path != *.sh ]]; then
		if [[ $path == */ || -z $path ]]; then
			path+="$bundle.sh"
		elif [[ $path == */* ]]; then
			path+="/$bundle.sh"
		else
			path+=".sh"
		fi
	fi
	if [[ $path != */* ]]; then
		path="$TILDEPOT_HOME/bundles/$path"
	fi

	if [[ ! -f $path ]]; then
		echo "#!/usr/bin/env bash" >"$path"
		echo "# Mock bundle file" >>"$path"
	fi

	if [[ -n $body ]]; then
		echo "${body//'<BUNDLE>'/$bundle}" >>"$path"
	fi
}

function test::mock_hook_fn() {
	local hook="${1?}"
	local body="${2:-"echo \"[TEST] Invoking hook [<BUNDLE>/$hook]\""}"
	local extra_body="${3-}"

	local hook_fn
	hook_fn="$(echo "$hook" | tr '[:lower:]' '[:upper:]')"
	cat <<-EOF
		function ${hook_fn}() {
			$body
			$extra_body
		}
	EOF
}

function test::mock_hook() {
	local bundle="${1?}"
	local hook="${2?}"
	local fn_body="${3-}"
	local file_body="${4-}"

	test::mock_bundle "$bundle" "
		$(test::mock_hook_fn "$hook" "$fn_body")
		$file_body
	"
}

function test::mock_hook_skip() {
	local bundle="${1?}"
	local hook="${2?}"
	local skip_body="${3?}"

	test::mock_hook "$bundle" "$hook" '' "
		$(test::mock_hook_fn "${hook}_skip" "$skip_body")
	"
}

function test::mock_bundle_skip() {
	local bundle="${1?}"
	local skip_body="${2?}"

	test::mock_bundle "$bundle" "
		function SKIP() {
			$skip_body
		}
	"
}

function test::assert_bundle_output() {
	local all_bundles=()
	local last_bundle=
	local all_hooks=()
	local last_hook=

	local omit_success_msg=

	local want=''
	local gap=
	local _gap=
	local opts=()
	while [[ $# -gt 0 ]]; do
		_gap="$gap"
		gap=
		case "$1" in
		--partial)
			opts+=(--partial)
			omit_success_msg=1
			;;
		--skip)
			bundle="$2" && shift
			[[ -n $_gap ]] && want+=$'\n'
			want+="=> Skipping $bundle"$'\n'
			gap=1
			;;
		--skip-reason)
			reason="$2" && shift
			want+="$reason"$'\n'
			;;
		--hook)
			bundle="$2" && shift
			hook="$2" && shift
			[[ -n $_gap ]] && want+=$'\n'
			want+="=> Running $bundle $hook..."$'\n'
			want+="[TEST] Invoking hook [$bundle/$hook]"$'\n'
			gap=1
			[[ $bundle != "$last_bundle" ]] && all_bundles+=("$bundle")
			last_bundle="$bundle"
			[[ $hook != "$last_hook" ]] && all_hooks+=("$hook")
			last_hook="$hook"
			;;
		--hook-run)
			bundle="$2" && shift
			hook="$2" && shift
			[[ -n $_gap ]] && want+=$'\n'
			want+="=> Running $bundle $hook..."$'\n'
			gap=1
			;;
		--hook-exec)
			bundle="$2" && shift
			hook="$2" && shift
			want+="[TEST] Invoking hook [$bundle/$hook]"$'\n'
			;;
		--hook-skip)
			bundle="$2" && shift
			hook="$2" && shift
			reason="$2" && shift
			[[ -n $_gap ]] && want+=$'\n'
			want+="=> Skipping $bundle $hook"$'\n'
			[[ $reason ]] && want+="$reason"$'\n'
			gap=1
			[[ $bundle != "$last_bundle" ]] && all_bundles+=("$bundle")
			last_bundle="$bundle"
			[[ $hook != "$last_hook" ]] && all_hooks+=("$hook")
			last_hook="$hook"
			;;
		--failure)
			omit_success_msg=1
			;;
		*)
			want+="$1"$'\n'
			;;
		esac
		shift
	done

	if [[ ! $omit_success_msg ]]; then
		local hook_msg="${#all_hooks[@]} hooks"
		((${#all_hooks[@]} == 1)) && hook_msg="${all_hooks[0]}"
		local bundle_msg="${#all_bundles[@]} bundles"
		((${#all_bundles[@]} == 1)) && bundle_msg="${all_bundles[0]}"

		want+=$'\n'
		want+="✔︎ Completed ${hook_msg} for ${bundle_msg}."$'\n'
	fi

	assert_output "${opts[@]---}" "${want:0:${#want}-1}"
}
