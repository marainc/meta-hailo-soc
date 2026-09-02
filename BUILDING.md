# Building the wraith image

How to build `hailo15-sbc`'s `core-image-hailo-dev` from `kaiy/wraith` (currently
`9d26222`, kirkstone/BSP 1.8.0, HailoRT 5.0.0), on a fresh machine, without
rediscovering any of this.

## Status

First successful build completed 2026-09-02, on this exact commit. Not yet flashed or
verified on hardware. See "What's left" at the bottom.

## Host prerequisites

- **Docker.** Tested against Docker 29.1.3. Your user must be in the `docker` group
  (`getent group docker`) — if you were added to the group in this login session, `groups`
  may not show it yet without a fresh login/shell. Work around that with `sg docker -c
  '<command>'` rather than logging out, e.g.:
  ```sh
  sg docker -c "./kas/build-wraith.sh"
  ```
- **kas-container**, not `kas` directly. Install via pip (`pip install --user kas`
  installs both `kas` and `kas-container` to `~/.local/bin`). The plain `kas` CLI can be
  broken/unnecessary (`ModuleNotFoundError: No module named 'kas'`) — that's fine, only
  `kas-container` (a thin Docker wrapper) is used here.
- **RAM**: the build container is capped at 12 GB (`--memory=12g` in the wrapper script)
  so a parallel-heavy task can't OOM a small host; `lowmem.yml` caps
  `BB_NUMBER_THREADS`/`PARALLEL_MAKE` to match. A host with 16 GB+ total RAM is
  recommended so the cap has room to breathe alongside the rest of the system.
- **Disk**: budget **at least 200 GB free**. This exact build's `build/` directory
  reached **146 GB** after ~15 iterations (each iteration adds some sstate/tmp growth;
  a single clean build would likely be somewhat smaller, but not dramatically so — Yocto
  full-image builds are disk-hungry regardless).
- **CPU**: not version-sensitive; more cores just makes native tool builds faster within
  the parallelism cap above. This host has 32 cores.

## The one command

```sh
cd ~/hailo15-yocto/meta-hailo-soc
./kas/build-wraith.sh                       # full build
./kas/build-wraith.sh -c 'bitbake -p'       # parse-only smoke test (minutes, not hours)
```

Never call `kas-container` or `kas build` directly — the wrapper pins two things that
are load-bearing and must not be "cleaned up":

- **`KAS_IMAGE_VERSION=4.7`.** kas 5.3's container image is Debian trixie (Python 3.13);
  kirkstone-era bitbake dies partway through parsing under it
  (`ParseError: Not all recipes parsed, parser thread killed/died?`, preceded by
  exceptions in unrelated meta-openembedded recipes — `freerdp`, `usbmuxd`,
  `tvheadend`). kas 4.7's image is Debian bookworm (Python 3.11) and parses all 2781
  recipes with 0 errors. Established by A/B: same script, same layers, only the image
  version changed.
- **Do not build natively.** poky kirkstone's `pseudo` cannot intercept a modern host
  `tar`'s `*at()` syscalls, so native builds fail in `do_install`. Always build inside
  the container.

## Timing

A **fully cold** build (empty `build/`, no sstate) was never isolated in this session —
every iteration after the first benefited from a growing sstate-cache. The one data
point from a genuinely empty cache: 53 minutes reached ~56% of tasks (4330/7725) before
hitting the first real failure. Extrapolating (unevenly — later tasks aren't
necessarily proportional), **budget 1.5–2 hours for a clean build**, more if your host
is slower than this one (32 cores, 30 GB RAM). A rebuild after only source-file changes
(sstate mostly warm) can finish in **single-digit minutes**.

## Output

`build/tmp/deploy/images/hailo15-sbc/` — machine `hailo15-sbc` (what the Auvidea H100
carrier reports and boots), image `core-image-hailo-dev`:

- `core-image-hailo-dev-hailo15-sbc-<timestamp>.rootfs.ext4[.gz]` — the rootfs
- `fitImage` / `fitImage-linux.bin` — kernel 5.15.32 + device tree, FIT-wrapped
- `hailo15-sbc.dtb` + overlays (`hailo15-sbc-gyro.dtbo`, `hailo15-sbc-sensor-1.dtbo`)
- `bl31-hailo15.bin`/`.elf` (ARM Trusted Firmware), `hailo15_scu_bl.bin` (SCU
  bootloader), signing certs
- `fw_env.config-hailo15-sbc-2022.01-r0` — U-Boot env tool config
- **`hailo-update-image-hailo15-sbc.swu`** — the swupdate OTA bundle; this is almost
  certainly what you flash with, but see "What's left" below.

## Failure catalogue

Every failure hit building this tree to completion for the first time, in the order
encountered. Symptom → cause → fix. The corresponding commit has the full writeup;
this is the index.

| # | Symptom | Cause | Fix | Commit |
|---|---|---|---|---|
| 1 | kas parse: `ERROR: The following layer directories do not exist: .../meta-hailo-tappas` | `meta-hailo-tappas` was added as its own top-level kas repo, but it's a subdirectory *inside* the `meta-hailo` clone (like `meta-hailo-libhailort`/`meta-hailo-vpu`) | Nested it under `meta-hailo:`'s `layers:` | `afd0d5a` |
| 2 | `ERROR: No recipes in default available for: .../hailort-server_%.bbappend` | Orphaned bbappend (vendor commit v1.10.0) targets a recipe (`hailort-server`, a GenAI/tokenizer lib) no longer shipped in `meta-hailo@kirkstone_v5.0.0` | `BBMASK` the dead bbappend | `95aa072` |
| 3 | `ERROR: Nothing RPROVIDES 'hailort-server-staticdev'` | Same dead package, different path: `meta-hailo-media-library`'s `layer.conf` globally `INHERIT`s `medialib-sdk.bbclass`, which unconditionally appends it to `TOOLCHAIN_TARGET_TASK`, folded into the image by `core-image-hailo-dev`'s own bbappend from that layer | `TOOLCHAIN_TARGET_TASK:remove` | `95aa072` |
| 4 | `ERROR: Nothing PROVIDES 'libhailopp'` | `hailo-analytics-api` (Hailo's own CLIP/face-landmarks/LPR demo apps) unconditionally needs a HailoRT C++ binding that only ships with a newer HailoRT than this branch's 5.0.0 pin — a real version boundary, not a bug | Dropped `hailo-analytics-api` from the image (wraith/falcon never uses it); revisit on the 1.12/5.3 branch | `95aa072` |
| 5 | `QA Issue: ... version went backwards ... [version-going-backwards]` (rapidjson, later perf) | This `build/` directory carried sstate-cache/buildhistory left over from a different, incompatible prior build config (predates this session) | Cleared the specific stale buildhistory + sstate entries for the affected recipe, rather than wiping the whole `build/` dir | — (not a source fix) |
| 6 | `libgsthailotools`/`tappas-tracers` `do_install` fails: `mv`/`find` on a path that doesn't exist | Vendor's `core/hailo/meson.build` hardcodes a Debian-multiarch install path (`/usr/lib/aarch64-linux-gnu/...`) unless `target_platform == 'imx8'`; this project sets `TARGET_PLATFORM:hailo15 = "hailo15"`, which doesn't match. (First attempt tried forcing `-Dlibdir` via `EXTRA_OEMESON` — wrong, meson.bbclass already passes `--libdir` automatically and refuses both forms at once.) | Source patch (via our own bbappend, not a hand-edit of the vendor tree) extending the `arch_dir` exception to `hailo15`; applied to all 3 recipes sharing that source tree (`libgsthailotools`, `tappas-tracers`, `hailo-post-processes`) | `5a0bb1b`, `b72b88f` (26660ed was the wrong first attempt, superseded) |
| 7 | `mavlink-router`: `installed-vs-shipped` QA error, `/usr/lib` | `rm -rf .../systemd` (dropping the unused systemd unit) left the parent `${nonarch_libdir}` behind, empty | `rmdir --ignore-fail-on-non-empty` after the `rm -rf` | `15ae6ee` |
| 8 | `python3-pymavlink`: `ModuleNotFoundError: No module named 'Cython'` | `setup.py` imports `Cython.Build.cythonize` directly at build time; recipe was missing that native build dependency | Added `python3-cython-native` to `DEPENDS` | `87bd45b` |
| 9 | `mavlink-router`: `[empty-dirs]` QA error, installs into `/var/volatile` | `/var/log` is a symlink to tmpfs-backed `/var/volatile/log` on this rootfs; baking a real directory there violates the "volatile dirs stay empty in the image" rule | Ship a `/etc/default/volatiles/99_mavlink-router` fragment instead, so `populate-volatile.sh` (initscripts) creates it at boot | `9d26222` |

**Self-inflicted, not a recipe bug:** editing a tracked source file *while* a build is
running can produce a spurious `the metadata is not deterministic` / taskhash-mismatch
error — bitbake reparses metadata mid-run, and a file changing under it confuses the
hash cache. Always wait for the container to fully exit (`docker ps -a` shows nothing)
before touching any file, and rerun after.

## Flashing and verifying — NOT YET ESTABLISHED

No board in this fleet has ever been flashed from a custom-built image before (all
current boards are hand-provisioned). This is the acknowledged gap. What's known:

- The build produces `hailo-update-image-hailo15-sbc.swu`, a standard swupdate OTA
  bundle — this is the mechanism, but the exact delivery path (network swupdate daemon
  vs. local/USB application, dry-run first or not) has not been exercised on this
  fleet and needs to be worked out on real hardware.
- Once flashed, the boot-fix verification protocol **is** established (from Task 3's
  addendum work): with the FC attached to `ttyS1` and streaming from before power-up,
  - cheap non-invasive check, no serial cable: `cat /sys/class/net/<iface>/speed` on
    the host — `10` means still stuck in U-Boot, `1000` means Linux booted;
  - sending the stop string (`CONFIG_AUTOBOOT_STOP_STR = "wraithstop"`) over serial
    during the boot window should still drop to a U-Boot prompt (serial recovery
    preserved, unlike the menu-off-only approach this branch moved away from);
  - `/proc/consoles` should show a valid console, `/dev/console` openable.
- Functional checks beyond boot: thermal streamer reaching `/dev/video33`,
  `mavlink-router` starting and staying up (needs `/dev/fc`/`/dev/mlrs` from
  `wraith-udev-rules` — absent on hand-provisioned boards, so this is the first image
  where they'd actually exist), `temp`/blackbox logging.

## What's left

- Flash + verify on real hardware (next planned step, board connected over PoE).
- Task 3's `CONFIG_AUTOBOOT_KEYED` switch (`bfeca5f`) is untested on hardware — the
  prior menu-off/`bootdelay=-2` approach (`edb84b6`) was also never flashed.
- Addendum 1 (921600 baud on `ttyS1` for 200 Hz IMU headroom) — not started. Two real
  blockers documented in `CUSTOM_IMAGE_HANDOFF.md`: the console currently owns the
  pinned baud, and there is no DMA on any UART in the devicetree at all.
- BSP 1.12.0 / HailoRT 5.3.0 migration — authorized as a deliberate follow-on, kept out
  of this 1.8.0/5.0.0 build on purpose. `hailo-analytics-api` (dropped here, failure
  #4 above) is the component that actually needs it.
