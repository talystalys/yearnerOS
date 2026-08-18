# yearnerOS

yearnerOS is a tiny Linux userspace/rootfs experiment built around a deliberately unserious theme: boot into a minimal shell, play music, render terminal animations, and keep the environment small enough that the entire personality of the system is visible in a few files.

It is **not a from-scratch kernel or independent Linux distribution**. The repository contains the custom root filesystem overlay and user-facing scripts/configuration that define yearnerOS. The original build environment also assembled upstream components such as the Linux kernel, BusyBox, Bash, ALSA utilities, mpg123, pacman, Fastfetch and GRUB; that historical build pipeline is not currently preserved in this repository, so this README does not claim that the present tree can reproduce those binaries from source.

The project started as a joke and an experiment. The code is intentionally rough in places, but the boot path and userspace are real and small enough to inspect end-to-end.

```text
     @@@@     @@@@
   @@@@@@   @@@@@@
  @@@@@@@@ @@@@@@@@
  @@@@@@@@@@@@@@@@@@
   @@@@@@@@@@@@@@@@
    @@@@@@@@@@@@@@
      @@@@@@@@@@
        @@@@@@
          @@

   yearnerOS
```

## What is actually in this repository

- `rootfs/init` — PID 1 startup script. Mounts proc/sys/devtmpfs/devpts/tmpfs, configures basic networking/audio, prepares stdio symlinks, prints the boot banner and hands the console to Bash.
- `rootfs/usr/bin/yearn` — music/search/lyrics CLI with terminal animations and mpg123 playback.
- `rootfs/usr/bin/pleasehearmeout` — ALSA volume-control TUI.
- `rootfs/etc/*` — hostname, shell profile, pacman configuration, audio defaults and yearnerOS metadata.
- `rootfs/usr/share/yearn/*` — lyrics/demo content used by the `yearn` command.

See [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) for a technical walkthrough.

## Boot model

The runtime model is intentionally simple:

```text
firmware / QEMU
    -> GRUB
    -> Linux kernel
    -> rootfs/init (PID 1)
    -> mount virtual filesystems
    -> configure basic network/audio
    -> setsid + cttyhack
    -> bash --login
```

The rootfs assumes a Linux x86-64 kernel and a userspace containing the binaries referenced by the scripts. This repository tracks the custom overlay/configuration rather than all compiled upstream binaries.

## Commands

| Command | What it does |
|---|---|
| `yearn now` | plays the configured default track and lyric animation |
| `yearn search <query>` | searches public audio sources and offers playable results |
| `yearn play <url>` | plays a direct audio URL |
| `yearn --list` | lists configured songs |
| `pleasehearmeout` | interactive ALSA volume control |
| `fastfetch` | displays the yearnerOS system profile |

The command names and UI are intentionally stupid. That is part of the project.

## Runtime assumptions

The checked-in scripts expect several utilities to exist in the assembled rootfs, including Bash, BusyBox-style networking tools, ALSA utilities, mpg123, wget, sed, grep, Fastfetch and supporting shared libraries. Audio expects an ALSA-visible device; the original QEMU setup used an HDA device.

`yearn search` talks to Internet Archive endpoints and `lyrics.ovh`, so search/online lyric functionality depends on network access and those services remaining compatible.

## Validation

Run the repository-level structural checks with:

```bash
bash scripts/check-rootfs.sh
```

The script checks executable entrypoints, shell syntax, required configuration files, stale naming mistakes and basic rootfs invariants. It does **not** replace a full boot test in QEMU.

## Known limitations

- No preserved, reproducible image/kernel build pipeline is currently checked in.
- The networking setup assumes an `eth0`-style interface and BusyBox-compatible `udhcpc`/`ifconfig` behavior.
- Audio setup is deliberately simple and ALSA-centric.
- `yearn` is a large Bash script and uses text tools to process remote API responses; it is a hobby implementation, not a hardened media client.
- There is no package/release lifecycle or compatibility promise.

## Why this exists

Because making Linux boot into a heart-themed shell that can scream song lyrics across the terminal was funny enough to justify building it.

That is the whole thesis.
