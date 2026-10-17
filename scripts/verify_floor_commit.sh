#!/bin/sh
# Verify floor manifest commits only touch allowlisted paths.
set -e
root=$(git rev-parse --show-toplevel)
cd "$root"
allow='^(Package\.swift|README\.md|CONTRIBUTING\.md|VERSIONING\.md|Example/.+\.pbxproj)$'
fail=0
for ref in "$@"; do
  [ -n "$ref" ] || continue
  msg=$(git log -1 --format=%s "$ref")
  case "$msg" in
    Release\ *) ;;
    snappy*|hexacolor*) ;;
  esac
  files=$(git diff-tree --no-commit-id --name-only -r "$ref" 2>/dev/null || true)
  [ -n "$files" ] || continue
  for f in $files; do
    if ! echo "$f" | grep -Eq "$allow"; then
      echo "verify_floor_commit: $msg touches disallowed file: $f"
      fail=1
    fi
  done
done
exit $fail
