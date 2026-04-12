#!/usr/bin/env bash
set -euo pipefail

WORK="$HOME/.cache/yearneros-qemu"
ROOT="$WORK/root"
IMAGE="$WORK/yearneros.cpio.gz"

rm -rf "$WORK"
mkdir -p "$ROOT"

cp -a rootfs/. "$ROOT/"

mkdir -p \
    "$ROOT/bin" "$ROOT/usr/bin" \
    "$ROOT/lib" "$ROOT/lib64" "$ROOT/usr/lib" \
    "$ROOT/proc" "$ROOT/sys" "$ROOT/dev/pts" \
    "$ROOT/tmp" "$ROOT/run" "$ROOT/root"

# Static BusyBox: no libc/libm/loader nonsense during early boot.
cp /usr/bin/busybox.static "$ROOT/bin/busybox"
chmod +x "$ROOT/bin/busybox"

ln -sf busybox "$ROOT/bin/sh"

for app in \
    mount mkdir hostname ifconfig udhcpc ln setsid cttyhack \
    clear cat echo grep sed cut stty ps ls sleep kill uname id pwd
do
    if /usr/bin/busybox.static --list | grep -qx "$app"; then
        ln -sf busybox "$ROOT/bin/$app"
    fi
done


# Copy Fastfetch if installed on the host.
if command -v fastfetch >/dev/null 2>&1; then
    FASTFETCH="$(command -v fastfetch)"
    cp -L "$FASTFETCH" "$ROOT/usr/bin/fastfetch"
    chmod +x "$ROOT/usr/bin/fastfetch"

    ldd "$FASTFETCH" 2>/dev/null |
    awk '/=> \// {print $3} /^\// {print $1}' |
    sort -u |
    while read -r lib; do
        [ -e "$lib" ] || continue
        mkdir -p "$ROOT$(dirname "$lib")"
        cp -L "$lib" "$ROOT$lib"
        cp -L "$lib" "$ROOT/usr/lib/$(basename "$lib")" 2>/dev/null || true
        cp -L "$lib" "$ROOT/lib/$(basename "$lib")" 2>/dev/null || true
    done

    interp="$(
        readelf -l "$FASTFETCH" 2>/dev/null |
        sed -n 's/.*Requesting program interpreter: \(.*\)]/\1/p'
    )"

    if [ -n "$interp" ] && [ -e "$interp" ]; then
        mkdir -p "$ROOT$(dirname "$interp")"
        cp -L "$interp" "$ROOT$interp"
    fi
fi

# Copy Bash plus every library it actually needs.
BASHBIN="$(command -v bash)"
cp -L "$BASHBIN" "$ROOT/usr/bin/bash"
chmod +x "$ROOT/usr/bin/bash"
ln -sf ../usr/bin/bash "$ROOT/bin/bash"

ldd "$BASHBIN" |
awk '/=> \// {print $3} /^\// {print $1}' |
sort -u |
while read -r lib; do
    [ -e "$lib" ] || continue
    mkdir -p "$ROOT$(dirname "$lib")"
    cp -L "$lib" "$ROOT$lib"

    # Void/glibc early userspace may not have ld.so.cache yet.
    cp -L "$lib" "$ROOT/usr/lib/$(basename "$lib")" 2>/dev/null || true
    cp -L "$lib" "$ROOT/lib/$(basename "$lib")" 2>/dev/null || true
done

interp="$(
    readelf -l "$BASHBIN" |
    sed -n 's/.*Requesting program interpreter: \(.*\)]/\1/p'
)"

if [ -n "$interp" ]; then
    mkdir -p "$ROOT$(dirname "$interp")"
    cp -L "$interp" "$ROOT$interp"
fi

# If cttyhack somehow isn't in the static build, don't let that stop us.
if ! /usr/bin/busybox.static --list | grep -qx cttyhack; then
    sed -i \
      's|exec setsid cttyhack /usr/bin/bash --login|exec /usr/bin/bash --login|' \
      "$ROOT/init"
fi

chmod +x "$ROOT/init"

(
    cd "$ROOT"
    find . -print0 |
        cpio --null -o --format=newc 2>/dev/null |
        gzip -1
) > "$IMAGE"

KERNEL="$(
    find /boot -maxdepth 1 -type f -name 'vmlinuz-*' |
    sort -V |
    tail -1
)"

echo
echo "booting yearnerOS"
echo "quit: Ctrl+A, then X"
echo

exec qemu-system-x86_64 \
    -m 512M \
    -kernel "$KERNEL" \
    -initrd "$IMAGE" \
    -append "console=ttyS0 rdinit=/init loglevel=3" \
    -nographic \
    -no-reboot \
    -nic none
