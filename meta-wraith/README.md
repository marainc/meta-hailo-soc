# meta-wraith

MARA wraith-fleet additions on top of the Hailo BSP. Everything MARA-specific lives
here so the vendor layers (`meta-hailo-*`) stay byte-identical to upstream and BSP
bumps rebase cleanly.

**Rule: never edit a vendor file.** Extend vendor recipes with `.bbappend` and config
fragments from this layer instead. Layer priority is 10, above every vendor layer
(highest vendor is 8), so our overrides win.

## Build

```
cd ~/hailo15-yocto/meta-hailo-soc
./kas/build-wraith.sh
```

Use the wrapper, not `kas build` / bare `kas-container`. It pins two things that
are load-bearing:

- **Containerized, not native.** poky kirkstone's `pseudo` can't intercept a modern
  host `tar`'s `*at()` syscalls, so native builds fail in `do_install`.
- **`KAS_IMAGE_VERSION=4.7`.** kas 5.3's container image is Debian trixie
  (Python 3.13), under which kirkstone-era bitbake dies mid-parse —
  `ParseError: Not all recipes parsed, parser thread killed/died?`, preceded by
  exceptions in unrelated meta-openembedded recipes (`freerdp`, `usbmuxd`,
  `tvheadend`). The 4.7 image is Debian bookworm (Python 3.11) and parses all
  2774 recipes with 0 errors. Confirmed by A/B — only the image version differed.

Machine is `hailo15-sbc` — confirmed to be what the boards actually run (the stock
Auvidea image's boot partition contains `swupdate-image-hailo15-sbc.ext4.gz`, and the
device tree reports `Hailo - Hailo15`). Output lands in
`build/tmp/deploy/images/hailo15-sbc/`.

## What this layer provides

| Recipe | Purpose |
|---|---|
| `linux-yocto-hailo.bbappend` + `wraith-usb.cfg` | `CONFIG_USB_ACM` (FC + mLRS get `/dev/ttyACM*` at all) and USB/IP, as a kernel config fragment |
| `v4l2loopback` | `/dev/video33` (`thermal-cam`), autoloaded at boot |
| `wraith-udev-rules` | `/dev/fc` and `/dev/mlrs` by vendor:product |
| `mavlink-router` | FC serial fan-out with per-endpoint filtering + tlog |
| `wraith-instrumentation` | health blackbox recorder, `temp` readout |
| `wraith-thermal-streamer` | publishes the onboard USB camera to `/dev/video33` |
| `wraith-identity` | per-drone hostname/IP + rootfs growth at boot |
| `python3-pymavlink` | on-board FC diagnostics |
| `packagegroup-wraith` | pulls all of the above into the image |

## Why the udev rules matter

`/dev/ttyACM*` numbering depends on USB enumeration order, and `/dev/serial/by-id/`
paths embed each board's **serial number** — so a config referencing either differs per
drone. Matching on vendor:product gives every drone identical `/dev/fc` and
`/dev/mlrs`, which is what lets `mavlink-router`'s config be baked into the image
unchanged across the whole fleet.

## Per-drone identity

The one thing that can't be baked. `wraith-identity` reads `/boot/wraith-identity.conf`
— on the **FAT** boot partition, so it's editable from any machine with an SD card
reader, no console or network needed:

```
NAME=harpy41
IP=10.33.0.41
```

Fleet: harpy41 · vulture42 · stork43 · shrike44 · shoebill45 · phoenix0 (bench).
Addresses are `10.33.0.<sysid>`; phoenix0 is `10.33.0.10`, hg2 holds `10.33.0.1`.
If the file is absent the service writes a template there and changes nothing else.

The same service grows the rootfs to fill whatever card the image was written to
(stock partition is 2.3 G of a 32 G card), so that stops being a manual step.

## What is deliberately NOT baked in

`falcon`, `onboard_navigator`, and the `.hef` model. They are iterated far too often to
justify an image rebuild each time, and they link against HailoRT — so they must be
built against the SDK from *this* BSP revision. They stay on the fast deploy path.

⚠️ **HailoRT ABI:** falcon's `NEEDED` entry is the fully-versioned `libhailort.so.5.0.0`.
This BSP (1.12.0) ships HailoRT **5.3.0**, so a falcon binary built against the old SDK
will not load. Order of operations after a BSP bump: build image → rebuild the SDK from
the same revision → rebuild falcon against it → deploy.
