#!/bin/sh
# Persistent thermal camera streamer for the Hailo-15.
# Owns the onboard USB camera (any USB device advertising YUYV) and republishes
# it to a STABLE v4l2loopback node /dev/video33 ("thermal-cam") so consumers (falcon)
# open /dev/video33 regardless of the raw node number (which wanders across reboots).
# Pumps everything including the per-open black warm-up (consumers tolerate it).
# Warm-up is cam-specific: MINI2 (3474:43e1) blacks out ~15 s / ~450 frames at
# EVERY open; MINI3 (3474:43e2) only ~34 frames / 0.57 s at cold start, and
# nothing on subsequent opens (measured 2026-09-10).
# See THERMAL_STREAM_DAEMON_SOW.md.

LOOPBACK_NR=33
LOOP=/dev/video33
LOG=/home/root/thermal-streamer.log

log() { echo "$(date '+%Y-%m-%d %H:%M:%S') [thermal-streamer] $*" >> "$LOG" 2>&1; }

log "=== thermal_streamer.sh launched (pid $$ ppid $PPID) PATH=$PATH ==="

# ensure /dev/video33 v4l2loopback exists.
# NOTE: the module may already be loaded with 0 (or other) devices; a plain insmod
# then fails and no node appears. So if /dev/video33 is missing, reload cleanly.
# The v4l2loopback module is autoloaded at boot with video_nr=33 by the
# kernel-module-v4l2loopback package (KERNEL_MODULE_AUTOLOAD + module_conf), so
# the node normally exists before we start. modprobe is a fallback for the case
# where we race udev on a cold boot.
ensure_loopback() {
    [ -e "$LOOP" ] && return 0
    modprobe v4l2loopback 2>/dev/null
    i=0; while [ ! -e "$LOOP" ] && [ $i -lt 10 ]; do sleep 1; i=$((i+1)); done
    [ -e "$LOOP" ] || log "WARNING: $LOOP still absent after modprobe"
}

# resolve the physical cam node: first USB (not on-die ISP) device on the hub that
# advertises YUYV capture. Not pinned to a specific hub port (e.g. 1-1.3) — port
# wiring differs across units/hubs, so this just takes whichever USB cam is present.
resolve_cam() {
    for vsys in /sys/class/video4linux/video*; do
        [ -e "$vsys/device" ] || continue
        case "$(readlink -f "$vsys/device")" in
            */usb*/*)
                node="/dev/$(basename "$vsys")"
                v4l2-ctl -d "$node" --list-formats-ext 2>/dev/null | grep -q YUYV && { echo "$node"; return 0; }
                ;;
        esac
    done
    return 1
}

# Ask the cam for 60 fps, when it offers it, BEFORE the pipeline starts.
#
# Measured 2026-09-10 on the MINI3 (3474:43e2, 640x512, offers 60 and 30): the
# uncapped pipeline below delivered 30 fps on one boot and 60 fps on the next
# with no change to this script -- v4l2src with no framerate in its caps
# inherits whatever rate the DEVICE currently holds, so the streamer's output
# rate was inherited, sticky and non-deterministic. /dev/video33's own
# reported rate is not a witness either: it read 30 while passing 60.
#
# Setting the rate on the device rather than pinning `framerate=60/1` on the
# src pad, for two reasons:
#   - rigid src caps hit not-negotiated errors (see the pipeline comment below)
#   - this daemon also runs on cams that cannot do 60 (the interim Realtek
#     units are 256x192@25), where pinning 60 fails outright
# A cam that does not enumerate 60 simply keeps its own rate.
request_rate() {
    cam="$1"
    if ! v4l2-ctl -d "$cam" --list-formats-ext 2>/dev/null | grep -q "(60.000 fps)"; then
        log "$cam does not offer 60 fps; leaving its rate as-is"
        return 0
    fi
    v4l2-ctl -d "$cam" --set-parm=60 >/dev/null 2>&1
    log "$cam requested 60 fps, device now reports: $(v4l2-ctl -d "$cam" --get-parm 2>/dev/null | sed -n "s/.*Frames per second: *//p")"
}

ensure_loopback

while true; do
    CAM=$(resolve_cam)
    if [ -z "$CAM" ]; then
        log "no USB YUYV camera found on the hub; retry in 3s"
        sleep 3; continue
    fi
    request_rate "$CAM"
    log "streaming $CAM -> $LOOP"
    # Let v4l2src negotiate the cam's native caps (colorimetry/interlace vary); videoconvert
    # normalizes to YUY2 for the loopback. Forcing rigid src caps hits not-negotiated errors.
    gst-launch-1.0 -e v4l2src device="$CAM" ! videoconvert ! video/x-raw,format=YUY2 ! v4l2sink device="$LOOP" >> "$LOG" 2>&1
    log "pipeline exited ($?); restarting in 1s"
    sleep 1
done
