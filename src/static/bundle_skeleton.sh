#!/usr/bin/env bash
#
# Custom "#<<BUNDLE_NAME>>" bundle.
#
# Bundle files may contain any of the following functions:
# - SKIP: Conditionally skip all other functions of this bundle.
# - INSTALL_SKIP: Conditionally skip the "install" step.
# - INSTALL: Run "install" steps.
# - UPDATE_SKIP: Conditionally skip the "update" step.
# - UPDATE: Run "update" steps.
# - SAVE_SKIP: Conditionally skip the "save" step.
# - SAVE: Run "save" steps.
# - RESTORE_SKIP: Conditionally skip the "restore" step.
# - RESTORE: Run "restore" steps.
#
# Every one of these functions is optional and may be omitted when not needed.
# For example, a valid bundle file could be as basic as a single "INSTALL"
# function.
#
# For the "SKIP" and all "*_SKIP" functions, returning either non-zero exit code
# or printing any message to stdout will evaluate that skip as truthy,
# consequently skipping other associated functions.
#
# Available global variables:
# - "$BUNDLE_STATE_DIR": Path to an ephemeral state directory dedicated to this
#   bundle.
# - "$BUNDLE_PREV_STATE_DIR": Path to the version-controlled state directory
#   dedicated to this bundle. Use this if you e.g. need to custom-merge current
#   system state and previously stored state. Otherwise use "$BUNDLE_STATE_DIR".
#
# Available global functions:
# - tilde::info: Format & print an info title.
# - tilde::echo: Format & print a plain message.
# - tilde::success: Format & print a success message.
# - tilde::warning: Format & print a warning.
# - tilde::error: Format & print an error message
# - tilde::abort: Format & print an error message and exit with exit code 1.
# - tilde::cmd_exists: Check if a command exists.

MY_STATE_FILE="$BUNDLE_STATE_DIR/my-state.txt"

#<<EXTEND>>
function SKIP() {
	# Simple step that returns a non-zero exit code will skip:
	[[ $(hostname -s) == 'MyOtherMachine' ]]

	# Alternatively skip with a custom message:
	[[ $(hostname -s) == 'MyOtherMachine' ]] &&
		echo 'Omitting all steps on [MyOtherMachine].'
}

function INSTALL_SKIP() {
	! tilde::cmd_exists my_dependency && echo 'Omitting without [my_dependency].'
}
function INSTALL() {
	# My install commands.
	tilde::success "My install-success message."
}

function UPDATE_SKIP() {
	! tilde::cmd_exists my_dependency && echo 'Omitting without [my_dependency].'
}
function UPDATE() {
	# My update commands.
	tilde::success "My update-success message."
}

function SAVE_SKIP() {
	! tilde::cmd_exists date && echo '[date] command is required.'
}
function SAVE() {
	{
		echo -n 'Saved at '
		date
	} >"$MY_STATE_FILE"
}

function RESTORE_SKIP() {
	[[ ! -f $MY_STATE_FILE ]] && echo "Missing [$MY_STATE_FILE]."
}
function RESTORE() {
	tilde::info 'Previous state'
	cat "$MY_STATE_FILE"

	tilde::info 'My Caveats'
	tilde::echo 'My additional notes to display after a [succesful restore]:'
	tilde::echo '  1. Read'
	tilde::echo '  2. Comprehend'
	tilde::echo '  3. ???'
	tilde::echo '  4. [Profit]'
}
