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
