#!/bin/sh
# Argument contract: unit source directory.
test -d "$1" || exit 41
printf "case.txt\n"
