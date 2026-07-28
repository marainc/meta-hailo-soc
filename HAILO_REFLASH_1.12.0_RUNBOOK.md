# Hailo-15 Reflash Runbook — BSP 1.8.0 → 1.12.0 (HailoRT 5.0.0 → 5.3.0)

**Status:** PLANNED — not executed. Companion to `HAILO15_CHANGELOG.md` (replication log) and
`HAILO_SEEKER_PLAN.md` (onboard plan). Do not start the flash until the three unknowns in Phase 1/2 are resolved.

**Why bump:** 1.12.0 (latest maintained BSP; kernel stays `5.15.32`/kirkstone) brings, relevant to us:
`ramoops` (persistent kernel-crash logs in DDR — reboot forensics), a `hailo-usb-current-supply` service
(matches our USB-brownout theory), ISP/DSP fixes (segfault-on-video-close, FE-timeout-on-stream-toggle,
hardware letterbox in `dsp_frontend_process`), and HailoRT **5.3.0** — which *aligns* the runtime with the
DFC 5.3.0 our models are already compiled with (today's board runs 5.3.0-built HEFs on a 5.0.0 runtime).

**Branch state (done):** `kaiy/ghost_v3` rebased onto `1.12.0`.
- `f3f6b4d` kernel: USB/IP + CDC-ACM + lowmem overlay (clean)
- `e1df760` v4l2loopback recipe (packagegroup conflict resolved)
- HailoRT pin dropped → 1.12.0's `kirkstone_v5.3.0` used.
- Rollback branch: `ghost_v3_pre_1.12` (old 1.8.0 tip `325be05`).

---

## Phase 0 · Pre-flight (host, zero board impact)
- [x] Branch rebased onto 1.12.0 (see above).
- [x] Working `.hef` blobs backed up + md5-verified → `/home/kaiy/hailo-hefs/board-deployed-backup-2026-07-27/`
      (`yolo_v3n_comb_thermal.hef` md5 `78b57c60f01793bb04b7730aae61a012`). This is the ONLY copy of the
      falcon model — its compile recipe/provenance is unrecorded (see changelog).
- [ ] Confirm the **full raw SD-image backup** (external SSD) is current — this is the *board* rollback. Re-image if stale.

## Phase 1 · Build image (host, ~hours)
- Build from `kaiy/ghost_v3` with the lowmem overlay (`kas/lowmem.yml` caps BB/make parallelism to fit the 14 GB host).
- ⚠️ **UNKNOWN #1:** exact `kas` target for a flashable `.wic`. SDK build was `bitbake core-image-minimal -c populate_sdk`;
  a flashable *image* is a different target, and 1.12.0 renamed image recipes (`core-image-hailo` / `-dev` / `-minimal`).
  Resolve on host before flashing.
- Output: `.wic` under `build/tmp/deploy/images/<machine>/`.

## Phase 2 · Flash (board)
- Board boots from SD (`mmcblk1`); original method = write the raw image to the SD card.
- ⚠️ **UNKNOWN #2 (biggest):** 1.12.0 overhauled swupdate (A/B images, *signed* SWU, "removed update-wic from boot
  menu — load only via swupdate") and changed `sd.wks.in` partitioning. A plain `dd` of the `.wic` may no longer be
  supported. Verify direct-SD-dd vs signed-swupdate before flashing.
- Post-flash root is stock (~2.3 G) → resize (Phase 3.1).

## Phase 3 · Re-deploy board-only artifacts (scp; see changelog for exact commands)
NOTE: v4l2loopback + USB CDC-ACM/usbip are now **baked into the image** (recipe + defconfig on the branch) — no
longer manual. Remaining manual steps:
1. **Resize rootfs → 30 G.** ⚠️ **UNKNOWN #3:** exact command unrecorded (likely `growpart /dev/mmcblk1 2` then
   `resize2fs /dev/mmcblk1p2`, UNVERIFIED). Stock tiny root = models/logs won't fit.
2. Network: `/etc/network/interfaces` (eth0 DHCP + `10.0.0.1` alias).
3. Boost `.so.1.78.0` libs → `/usr/lib` + `ldconfig`.
4. Models → `/home/root/models/` (from the Phase-0 backup).
5. `falcon` + `onboard_navigator` → `/home/root/` + `chmod +x`.
6. `falcon_config/feathers/` → `/home/root/`.
7. `field_test.conf` → `/home/root/` — **fix `camera` → `/dev/video33` and `mavlink_port` → `/dev/ttyACM1`**
   (both wrong on the current board).
8. Blackbox (`S51blackbox`), `temp` (`/usr/bin/temp`), thermal daemon (`S52thermal-streamer`).

## Phase 4 · Validate on 5.3.0
- `hailortcli fw-control identify` → Firmware **5.3.0**.
- Working `.hef` `parse-hef` + `hailortcli run` clean (matched DFC↔runtime — expected pass).
- falcon: loads model, opens `/dev/video33`, connects FC on `/dev/ttyACM1`.
- `/dev/ttyACM*` present (baked CDC-ACM); `/dev/video33` real frames (baked v4l2loopback + daemon).
- **New 1.12.0 wins — enable/verify:** `ramoops` (reboot forensics), `hailo-usb-current-supply`, `hailo-thermal-service`.
- Blackbox writing; `temp` prints.

## Phase 5 · Rollback
- If 5.3.0 regresses: reflash the 1.8.0 raw SD backup; `ghost_v3_pre_1.12` rebuilds the old image.

---

## Open decisions
- **Unknowns #1–#3** gate the flash — resolve host-side / on a spare SD before touching the live board.
- **Optimal vs. fast for Phase 3:** the scp re-deploy works, but the optimal path is to **bake the instrumentation
  into the image as recipes** (network, blackbox, temp, thermal daemon, models, resize) so a flash reproduces the
  whole board with zero manual steps. More upfront work; pays off on every future flash. Suggested: scp for the
  first 1.12.0 flash to validate, then convert to recipes.
