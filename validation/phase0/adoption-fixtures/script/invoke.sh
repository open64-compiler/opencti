#!/bin/sh
# Argument contract: selected test name.
test "$1" = case.txt || exit 42
cat case.txt
exit 7
