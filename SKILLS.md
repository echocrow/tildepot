## Bash Compatibility

- **Bash Version**: Code must be compatible with Bash **version 3.2**. (Do **not** use associative arrays (`declare -A`, `local -A`), namerefs, `coproc`, `mapfile`, or other features exclusive to Bash 4+.)
- **Portability**: All functionality must work on both **Linux** and **macOS** Bash 3.2. Either avoid features/commands that differ or are only available on one platform, or write a thin wrapper function to abstract platform differences.
- **Parameter Expansion**: Prefer Bash parameter expansion (`${var%pattern}`, `${var#pattern}`, etc.) for string manipulation instead of subshells or external commands when easily possible and readable.

---

## Code Testing

This repository uses [bats](https://github.com/bats-core/bats-core) for testing.

### Test Commands

- `make test`: runs all tests.
- `make test TESTS="test/<path-to-bats-file>"`: run only a specific test file.

To run only a specific test, prepend the `@test` function with

```bash
# bats test_tags=bats:focus
```

then run `make test` or `make test TESTS="test/<path-to-bats-file>"`.

### Bats Documentation

- Tutorial: https://bats-core.readthedocs.io/en/stable/tutorial.html
- CLI Usage: https://bats-core.readthedocs.io/en/stable/usage.html
- Writing Tests: https://bats-core.readthedocs.io/en/stable/writing-tests.html
- Gotchas: https://bats-core.readthedocs.io/en/stable/gotchas.html
