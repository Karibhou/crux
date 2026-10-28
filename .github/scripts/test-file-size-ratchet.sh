#!/usr/bin/env bash
# Exercises check-file-size-ratchet.sh against synthetic module trees: each
# case builds a throwaway directory of generated .go files plus a baseline,
# runs the gate there, and asserts the exit status and the message it prints.
#
# On the real tree the gate only ever passes, so every failure and notice
# branch (growth over baseline, new oversized file, test files exempt, shrink,
# drop under the limit, deleted file, malformed baseline) would otherwise run
# for the first time on the day it matters.
#
# Usage: bash .github/scripts/test-file-size-ratchet.sh   (from the module root)
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SCRIPT="${ROOT}/.github/scripts/check-file-size-ratchet.sh"
TMP="$(mktemp -d "${TMPDIR:-/tmp}/file-size-ratchet-test.XXXXXX")"
trap 'rm -rf "$TMP"' EXIT

failures=0
pass() { printf '  ok: %s\n' "$*"; }
bad() {
  printf '  FAIL: %s\n' "$*"
  failures=$((failures + 1))
}
# Here-strings, not pipes, so a grep that stops reading early cannot turn
# pipefail into a false FAIL.
assert_contains() {
  local haystack="$1" needle="$2" msg="$3"
  if grep -qF -- "$needle" <<<"$haystack"; then pass "$msg"; else bad "$msg (missing: $needle)"; fi
}
assert_not_contains() {
  local haystack="$1" needle="$2" msg="$3"
  if grep -qF -- "$needle" <<<"$haystack"; then bad "$msg (unexpected: $needle)"; else pass "$msg"; fi
}
assert_exit() {
  local want="$1" got="$2" msg="$3"
  if [ "$want" = "$got" ]; then pass "$msg (exit $got)"; else bad "$msg (want exit $want, got $got)"; fi
}

# gofile <path> <lines>: write a .go file of exactly <lines> lines.
gofile() {
  mkdir -p "$(dirname "$1")"
  seq "$2" | sed 's|^|// |' >"$1"
}

# new_case <name>: fresh tree in $TMP/<name> with a baseline holding only a
# comment and a blank line; populate it with gofile and baseline, then run.
case_dir=""
new_case() {
  case_dir="$TMP/$1"
  mkdir -p "$case_dir/.github"
  printf '# header comment\n\n' >"$case_dir/.github/go-file-size-ratchet.txt"
}
baseline() { printf '%s\n' "$@" >>"$case_dir/.github/go-file-size-ratchet.txt"; }
out="" rc=0
run() {
  out="$(cd "$case_dir" && bash "$SCRIPT" "$@" 2>&1)" && rc=0 || rc=$?
}

echo "case: tree at its baseline passes"
new_case at-baseline
gofile "$case_dir/big/big.go" 900
gofile "$case_dir/small.go" 800
baseline "900 big/big.go"
run
assert_exit 0 "$rc" "exact baseline and a file at the limit pass"
assert_contains "$out" "file-size ratchet: ok" "prints the ok line"
assert_not_contains "$out" "::notice" "no edit suggested when nothing changed"

echo "case: listed file grows past its baseline"
new_case growth
gofile "$case_dir/big/big.go" 901
baseline "900 big/big.go"
run
assert_exit 1 "$rc" "growth fails"
assert_contains "$out" "::error file=big/big.go::big/big.go has 901 lines, over its ratchet baseline of 900" "names the file and both counts"

echo "case: unlisted file over the limit"
new_case new-oversized
gofile "$case_dir/pkg/new.go" 801
run
assert_exit 1 "$rc" "new oversized file fails"
assert_contains "$out" "pkg/new.go has 801 lines, over the 800-line limit" "names the file and the limit"

echo "case: test files are exempt"
new_case test-files
gofile "$case_dir/pkg/huge_test.go" 5000
run
assert_exit 0 "$rc" "an oversized _test.go file passes"

echo "case: listed file shrinks but stays over the limit"
new_case shrink
gofile "$case_dir/big/big.go" 850
baseline "900 big/big.go"
run
assert_exit 0 "$rc" "shrinking passes"
assert_contains "$out" 'change "900 big/big.go" to "850 big/big.go"' "prints the exact line to lower"

echo "case: listed file drops under the limit"
new_case under-limit
gofile "$case_dir/big/big.go" 700
baseline "900 big/big.go"
run
assert_exit 0 "$rc" "dropping under the limit passes"
assert_contains "$out" "Remove this line from .github/go-file-size-ratchet.txt: 900 big/big.go" "prints the line to remove"

echo "case: listed file deleted, and its content moved to an unlisted path"
new_case renamed
gofile "$case_dir/big/renamed.go" 900
baseline "900 big/big.go"
run
assert_exit 1 "$rc" "a rename does not carry the grandfathering"
assert_contains "$out" "big/big.go no longer exists. Remove this line" "stale entry is reported"
assert_contains "$out" "big/renamed.go has 900 lines, over the 800-line limit" "renamed file is judged as new"

echo "case: malformed baseline"
new_case malformed
gofile "$case_dir/a.go" 10
baseline "lots big/big.go"
run
assert_exit 2 "$rc" "non-numeric count is a usage error"
assert_contains "$out" "malformed entry: lots big/big.go" "points at the bad line"

echo "case: duplicate baseline entry"
new_case duplicate
gofile "$case_dir/big/big.go" 900
baseline "900 big/big.go" "950 big/big.go"
run
assert_exit 2 "$rc" "duplicate path is a usage error"
assert_contains "$out" "duplicate entry for big/big.go" "names the duplicate"

echo "case: explicit baseline path"
new_case explicit
gofile "$case_dir/big/big.go" 900
printf '900 big/big.go\n' >"$case_dir/other-baseline.txt"
run other-baseline.txt
assert_exit 0 "$rc" "baseline argument is honoured"

echo "case: zero-byte baseline"
new_case empty-baseline
gofile "$case_dir/pkg/new.go" 801
: >"$case_dir/.github/go-file-size-ratchet.txt"
run
assert_exit 1 "$rc" "an empty baseline grandfathers nothing"
assert_contains "$out" "pkg/new.go has 801 lines, over the 800-line limit" "first file is judged, not read as a baseline entry"

echo "case: missing baseline"
new_case missing
run does-not-exist.txt
assert_exit 2 "$rc" "missing baseline is a usage error"

if [ "$failures" -ne 0 ]; then
  echo "test-file-size-ratchet: ${failures} assertion(s) failed" >&2
  exit 1
fi
echo "test-file-size-ratchet: all assertions passed"
