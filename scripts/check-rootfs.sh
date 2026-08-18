#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
rootfs="$repo_root/rootfs"

failures=0

fail() {
    printf 'FAIL: %s\n' "$*" >&2
    failures=$((failures + 1))
}

pass() {
    printf 'ok:   %s\n' "$*"
}

require_file() {
    local path="$1"
    if [[ -f "$path" ]]; then
        pass "${path#$repo_root/} exists"
    else
        fail "${path#$repo_root/} is missing"
    fi
}

require_executable() {
    local path="$1"
    if [[ -x "$path" ]]; then
        pass "${path#$repo_root/} is executable"
    else
        fail "${path#$repo_root/} is not executable"
    fi
}

require_file "$rootfs/init"
require_file "$rootfs/etc/os-release"
require_file "$rootfs/etc/passwd"
require_file "$rootfs/etc/group"
require_file "$rootfs/etc/profile"
require_file "$rootfs/etc/yearn.conf"
require_file "$rootfs/usr/bin/yearn"
require_file "$rootfs/usr/bin/pleasehearmeout"

require_executable "$rootfs/init"
require_executable "$rootfs/usr/bin/yearn"
require_executable "$rootfs/usr/bin/pleasehearmeout"

for script in \
    "$rootfs/usr/bin/yearn" \
    "$rootfs/usr/bin/pleasehearmeout"; do
    if bash -n "$script"; then
        pass "${script#$repo_root/} passes bash -n"
    else
        fail "${script#$repo_root/} has Bash syntax errors"
    fi
done

if sh -n "$rootfs/init"; then
    pass "rootfs/init passes sh -n"
else
    fail "rootfs/init has POSIX shell syntax errors"
fi

if grep -q '^NAME="yearnerOS"$' "$rootfs/etc/os-release"; then
    pass "os-release identifies yearnerOS"
else
    fail "os-release does not identify yearnerOS"
fi

if grep -q 'HeartOS' "$rootfs/etc/passwd" "$rootfs/etc/group" "$rootfs/etc/profile" 2>/dev/null; then
    fail "stale HeartOS naming remains in core account/profile files"
else
    pass "no stale HeartOS naming in core account/profile files"
fi

if grep -q '^root:x:0:0:' "$rootfs/etc/passwd"; then
    pass "root account metadata is present"
else
    fail "root account metadata is malformed or missing"
fi

if grep -q '^user:x:1000:1000:' "$rootfs/etc/passwd"; then
    pass "user account metadata is present"
else
    fail "user account metadata is malformed or missing"
fi

if grep -q '^exec setsid cttyhack /usr/bin/bash --login$' "$rootfs/init"; then
    pass "PID 1 hands the console to login Bash"
else
    fail "expected PID 1 shell handoff is missing"
fi

if (( failures > 0 )); then
    printf '\n%d check(s) failed.\n' "$failures" >&2
    exit 1
fi

printf '\nrootfs structural checks passed.\n'
