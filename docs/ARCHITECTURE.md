# yearnerOS architecture

## Scope

yearnerOS is a custom Linux root filesystem/userspace experiment, not a new kernel. The Linux kernel and bootloader provide the machine-level boot/runtime substrate; the code in this repository defines the custom userspace behavior that begins at PID 1.

The repository intentionally keeps the architecture small enough to audit manually.

## PID 1 and boot handoff

`rootfs/init` is the userspace entrypoint. Its responsibilities are deliberately narrow:

1. mount kernel-backed virtual filesystems (`proc`, `sysfs`, `devtmpfs`, `devpts`)
2. mount tmpfs instances for `/tmp` and `/run`
3. establish the hostname and base environment
4. create conventional `/dev/fd`, `/dev/stdin`, `/dev/stdout`, and `/dev/stderr` symlinks
5. bring up `eth0` when present and request DHCP with `udhcpc`
6. unmute common ALSA mixer controls when an audio device exists
7. print the yearnerOS boot banner
8. transfer the controlling terminal to a login Bash using `setsid cttyhack`

There is no service manager. That is intentional: this is a tiny interactive environment, not a general-purpose multi-service distribution.

## Root filesystem layout

The repository stores the custom rootfs overlay:

```text
rootfs/
├── init
├── etc/
│   ├── asound.conf
│   ├── fastfetch/
│   ├── fstab
│   ├── group
│   ├── hostname
│   ├── hosts
│   ├── makepkg.conf
│   ├── os-release
│   ├── pacman.conf
│   ├── passwd
│   ├── profile
│   ├── shadow
│   └── yearn.conf
└── usr/
    ├── bin/
    │   ├── yearn
    │   └── pleasehearmeout
    └── share/
        └── yearn/
```

Many utility paths under `rootfs/usr/bin` are symlinks into the assembled userspace and are not independent implementations.

## `yearn`

`yearn` is a Bash media/terminal UI program. It combines several concerns because the project optimizes for inspectability and fun rather than reusable library boundaries.

The major behaviors are:

- parse global (`/etc/yearn.conf`) and per-user (`~/.yearnrc`) song definitions
- list and select configured tracks
- accept direct audio URLs
- search Internet Archive-backed sources
- attempt online lyric retrieval
- download remote audio to a temporary file
- spawn `mpg123` and track its PID
- render lyric/ASCII animations while playback is alive
- clean up child processes and temporary files on interruption

The implementation deliberately uses ordinary shell tools rather than introducing a runtime such as Python or Node solely for this command.

### Tradeoffs

This keeps the deployed environment conceptually simple, but it also means:

- parsing JSON with text utilities is brittle
- network APIs are external compatibility dependencies
- a large shell program is harder to unit-test than a small typed program
- terminal control depends on ANSI escape semantics and available TTY dimensions

Those are known design compromises rather than claims of production hardening.

## `pleasehearmeout`

`pleasehearmeout` is a small Bash front end around `amixer`. It provides both command-oriented volume operations and a simple interactive TUI.

It reads mixer state, clamps volume changes to 0–100%, handles mute toggling and displays device information from `/proc/asound/cards` when available.

## Network model

`init` checks for `/sys/class/net/eth0`, brings it up using `ifconfig`, and runs `udhcpc` in the background. DNS is initialized with a simple `/etc/resolv.conf` entry.

This is sufficient for the QEMU-oriented environment the project targeted, but it is not a general network-management stack. Interface naming, DHCP behavior, DNS configuration and link hotplug are intentionally not abstracted.

## Audio model

Audio is ALSA-first. `init` attempts to unmute common mixer controls, while user-facing controls use `amixer` and playback uses `mpg123`.

The setup is intentionally direct and avoids a persistent userspace audio server inside yearnerOS.

## Build provenance

The historical development environment assembled upstream components such as Linux, BusyBox, Bash, ALSA utilities, mpg123, pacman, Fastfetch and GRUB. Those upstream projects are not authored by yearnerOS.

More importantly, the scripts/configuration used to assemble the complete boot image are not currently preserved in this repository. The tracked tree should therefore be treated as the custom rootfs/userspace layer, not as a presently reproducible source distribution.

If the build pipeline is reconstructed later, it should be committed explicitly with pinned upstream versions/checksums and an automated QEMU smoke test rather than described as reproducible before that evidence exists.

## Security and robustness notes

This project assumes a disposable/hobby VM-style environment. Several choices would be inappropriate for a production system, including passwordless local account metadata, permissive package-signature configuration, static DNS setup and shell-based parsing of untrusted remote responses.

Those choices should be read in the context of the project's scope. yearnerOS is useful as a boot/userspace exercise and as an inspectable Linux experiment; it is not intended as a hardened operating system.
