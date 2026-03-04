#!/usr/bin/env bats
#
# Tests for `src/cmd.sh` `cmd::help`

# shellcheck disable=SC2030,SC2031,SC2034,SC2317,SC2329

setup() {
	load ../test_lib.sh

	load ../../src/cmd.sh

	function cmds::app_name() {
		echo 'my-app'
	}
	function cmds::app_version() {
		echo '0.1.2'
	}
}

###
# Root command help.
###

@test "prints help of root command by default" {
	run cmd::help
	assert_success
	assert_output - <<-'EOF'
		my-app 0.1.2

		Usage: my-app [command] [options] [arguments]
	EOF
}

@test "includes 'cmds::app_help' in root command help" {
	function cmds::app_help() {
		echo 'My app help.'
	}

	run cmd::help
	assert_success
	assert_output - <<-'EOF'
		my-app 0.1.2

		My app help.

		Usage: my-app [command] [options] [arguments]
	EOF
}

@test "prints help of root command with global options" {
	function cmds::global_args() {
		CMD_CFG_OPTS+=(g my-global '' 'My global opt help.')
	}

	run cmd::help
	assert_success
	assert_output - <<-'EOF'
		my-app 0.1.2

		Usage: my-app [command] [options] [arguments]

		Global options:
		  -g, --my-global           My global opt help.
	EOF
}

###
# Root command list.
###

@test "lists commands via 'cmds::list'" {
	function cmds::list() {
		echo 'foo'
		echo 'bar'
	}

	run cmd::help
	assert_success
	assert_output - <<-'EOF'
		my-app 0.1.2

		Usage: my-app [command] [options] [arguments]

		Commands:
		  foo
		  bar
	EOF
}

@test "lists commands via 'cmds::list' with custom categories" {
	function cmds::list() {
		echo 'Foobar:'
		echo 'foo'
		echo 'bar'
		echo 'Fizzbuzz:'
		echo 'fizz'
		echo 'buzz'
	}

	run cmd::help
	assert_success
	assert_output - <<-'EOF'
		my-app 0.1.2

		Usage: my-app [command] [options] [arguments]

		Foobar:
		  foo
		  bar

		Fizzbuzz:
		  fizz
		  buzz
	EOF
}

@test "lists commands with short help" {
	function cmds::list() {
		echo 'foo'
		echo 'bar'
	}
	function cmds::cmd:foo:help() {
		echo 'My foo command.'
	}
	function cmds::cmd:bar:help() {
		echo 'Some boo command.'
	}

	run cmd::help
	assert_success
	assert_output - <<-'EOF'
		my-app 0.1.2

		Usage: my-app [command] [options] [arguments]

		Commands:
		  foo                       My foo command.
		  bar                       Some boo command.
	EOF
}

@test "does not set '--long' flag for cmd help in command list" {
	function cmds::list() {
		echo 'foo'
	}
	function cmds::cmd:foo:help() {
		local long= && [[ ${1-} == '--long' ]] && long=1
		echo 'My foo command.'
		[[ ! $long ]] || echo "My extended description."
	}

	run cmd::help
	assert_success
	assert_output - <<-'EOF'
		my-app 0.1.2

		Usage: my-app [command] [options] [arguments]

		Commands:
		  foo                       My foo command.
	EOF
}

###
# Command help.
###

@test "fails when command does not exist" {
	run cmd::help foo
	assert_failure
	assert_output 'Error: Unknown command: foo'
}

@test "prints help for command" {
	function cmds::cmd:foo() {
		echo 'hello world'
	}

	run cmd::help foo
	assert_success
	assert_output - <<-'EOF'
		my-app foo

		Usage: my-app foo
	EOF

	test::it 'does not call cmd fn'
	refute_line 'hello world'
}

###
# Command help options.
###

@test "prints help for command with opts" {
	function cmds::cmd:foo:args() {
		CMD_CFG_OPTS+=(o my-opt OPT 'Some opt desc.')
	}
	function cmds::cmd:foo() {
		true
	}

	run cmd::help foo
	assert_success
	assert_output - <<-'EOF'
		my-app foo

		Usage: my-app foo [options]

		Options:
		  -o, --my-opt OPT          Some opt desc.
	EOF
}

@test "prints help for command with only global opts" {
	function cmds::global_args() {
		CMD_CFG_OPTS+=(g my-global '' 'My global opt help.')
	}
	function cmds::cmd:foo() {
		true
	}

	run cmd::help foo
	assert_success
	assert_output - <<-'EOF'
		my-app foo

		Usage: my-app foo [options]

		Global options:
		  -g, --my-global           My global opt help.
	EOF
}

@test "prints help for command with global & cmd opts" {
	function cmds::global_args() {
		CMD_CFG_OPTS+=(g my-global '' 'My global opt help.')
	}
	function cmds::cmd:foo:args() {
		CMD_CFG_OPTS+=(o my-opt OPT 'Some opt desc.')
	}
	function cmds::cmd:foo() {
		true
	}

	run cmd::help foo
	assert_success
	assert_output - <<-'EOF'
		my-app foo

		Usage: my-app foo [options]

		Global options:
		  -g, --my-global           My global opt help.

		Options:
		  -o, --my-opt OPT          Some opt desc.
	EOF
}

@test "relocates '[options]' in usage when 'CMD_CFG_ARGS_FWD_ALL=1'" {
	function cmds::global_args() {
		CMD_CFG_OPTS+=(g my-global '' 'My global opt help.')
	}
	function cmds::cmd:foo:args() {
		CMD_CFG_ARGS_FWD_ALL=1
	}
	function cmds::cmd:foo() {
		true
	}

	run cmd::help foo
	assert_success
	assert_output - <<-'EOF'
		my-app foo

		Usage: my-app [options] foo

		Global options:
		  -g, --my-global           My global opt help.
	EOF
}

###
# Command help arguments.
###

@test "appends '[arguments]' to usage for command with params count" {
	function cmds::cmd:foo:args() {
		CMD_CFG_PARAMS_COUNT=1
	}
	function cmds::cmd:foo() {
		true
	}

	run cmd::help foo
	assert_success
	assert_output - <<-'EOF'
		my-app foo

		Usage: my-app foo [arguments]
	EOF
}

@test "omits '[arguments]' from usage when 'CMD_CFG_PARAMS_COUNT=0'" {
	function cmds::cmd:foo:args() {
		CMD_CFG_PARAMS_COUNT=0
	}
	function cmds::cmd:foo() {
		true
	}

	run cmd::help foo
	assert_success
	assert_output - <<-'EOF'
		my-app foo

		Usage: my-app foo
	EOF
}

@test "appends '\$CMD_CFG_PARAMS_HELP' to usage when set" {
	function cmds::cmd:foo:args() {
		CMD_CFG_PARAMS_HELP='MY PARAMS'
	}
	function cmds::cmd:foo() {
		true
	}

	run cmd::help foo
	assert_success
	assert_output - <<-'EOF'
		my-app foo

		Usage: my-app foo MY PARAMS
	EOF
}

@test "appends '\$CMD_CFG_PARAMS_HELP' to usage regardless of '\$CMD_CFG_PARAMS_COUNT'" {
	function cmds::cmd:foo:args() {
		CMD_CFG_PARAMS_HELP='MY PARAMS'
		CMD_CFG_PARAMS_COUNT=2
	}
	function cmds::cmd:foo() {
		true
	}

	run cmd::help foo
	assert_success
	assert_output - <<-'EOF'
		my-app foo

		Usage: my-app foo MY PARAMS
	EOF
}

###
# Command help description.
###

@test "prints cmd help for command" {
	function cmds::cmd:foo:help() {
		echo 'My foo command.'
	}
	function cmds::cmd:foo() {
		true
	}

	run cmd::help foo
	assert_success
	assert_output - <<-'EOF'
		my-app foo

		My foo command.

		Usage: my-app foo
	EOF
}

@test "sets '--long' flag for cmd help" {
	function cmds::cmd:foo:help() {
		local long= && [[ ${1-} == '--long' ]] && long=1
		echo 'My foo command.'
		[[ ! $long ]] || echo "My extended description."
	}
	function cmds::cmd:foo() {
		true
	}

	run cmd::help foo
	assert_success
	assert_output - <<-'EOF'
		my-app foo

		My foo command.
		My extended description.

		Usage: my-app foo
	EOF
}

###
# Internal command.
###

@test "formats command name with underscore as space" {
	function cmds::list() {
		echo 'foo_bar'
	}
	function cmds::cmd:foo_bar() {
		true
	}

	test::it 'prints command name with space in commands list'
	run cmd::help
	assert_success
	assert_line --partial 'foo bar'
	refute_line --partial 'foo_bar'

	test::it 'prints command name with space in command help'
	run cmd::help foo_bar
	assert_success
	assert_line --partial 'foo bar'
	refute_line --partial 'foo_bar'
}

@test "prints help for command name with underscore" {
	function cmds::cmd:foo_bar:help() {
		echo 'My help.'
	}
	function cmds::cmd:foo_bar() {
		true
	}

	test::it 'prints help for command with underscore'
	run cmd::help foo_bar
	assert_success
	assert_line --partial 'foo bar'
	refute_line --partial 'foo_bar'
	assert_line 'My help.'

	test::it 'prints help for command with space'
	run cmd::help foo bar
	assert_success
	assert_line --partial 'foo bar'
	refute_line --partial 'foo_bar'
	assert_line 'My help.'
}

@test "persists leading underscores in command names" {
	function cmds::list() {
		echo '_foo-bar'
	}
	function cmds::cmd:_foo-bar() {
		true
	}

	test::it 'prints command name with space in commands list'
	run cmd::help
	assert_success
	assert_line --partial '_foo-bar'
	refute_line --partial ' foo-bar'
	refute_line --partial 'foo bar'

	test::it 'prints command name with space in command help'
	run cmd::help _foo-bar
	assert_success
	assert_line --partial '_foo-bar'
	refute_line --partial ' foo-bar'
	refute_line --partial 'foo bar'

	test::it 'requires leading underscore'
	run cmd::help foo-bar
	assert_failure
	assert_output 'Error: Unknown command: foo-bar'
}

@test "persists leading underscores in 2nd half of command names" {
	function cmds::list() {
		echo 'foo__bar'
	}
	function cmds::cmd:foo__bar() {
		true
	}

	test::it 'prints command name with space in commands list'
	run cmd::help
	assert_success
	assert_line --partial 'foo _bar'
	refute_line --partial 'foo bar'

	test::it 'prints command name with space in command help'
	run cmd::help foo _bar
	assert_success
	assert_line --partial 'foo _bar'
	refute_line --partial 'foo bar'

	test::it 'requires leading underscore (separate args)'
	run cmd::help foo bar
	assert_failure
	assert_output 'Error: Unknown command: foo bar'

	test::it 'requires leading underscore (single arg)'
	run cmd::help 'foo bar'
	assert_failure
	assert_output 'Error: Unknown command: foo bar'
}
