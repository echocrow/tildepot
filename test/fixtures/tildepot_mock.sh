#!/bin/bash
#
# Mock tildepot

case ${1-} in
version) echo 0.0.0-mock ;;
*) echo "Unsupported mock command: ${1-}" >&2 && exit 1 ;;
esac
