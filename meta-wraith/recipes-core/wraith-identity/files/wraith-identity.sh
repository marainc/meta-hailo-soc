#!/bin/sh
# wraith-identity — per-unit setup that cannot be baked into a shared image.
#
# Runs on every boot, idempotent. Two jobs:
#   1. Grow the rootfs to fill whatever SD card this image was written to.
#   2. Apply this drone's hostname and static IP, read from a config file on the
#      FAT boot partition (/boot) so it can be edited from any machine with an SD
#      card reader — no console, no network, no login needed.
#
# /boot/wraith-identity.conf:
#     NAME=harpy41
#     IP=10.33.0.41
#
# If the file is missing, a template is written there and nothing else changes.

CONF=/boot/wraith-identity.conf
DISK=/dev/mmcblk1
ROOTPART=/dev/mmcblk1p2
ROOTPARTNUM=2
LOG=/var/log/wraith-identity.log

log() { echo "$(date '+%Y-%m-%d %H:%M:%S') [wraith-identity] $*" >> "$LOG" 2>&1; }

# --- 1. grow rootfs to fill the card ------------------------------------------
grow_rootfs() {
    [ -b "$DISK" ] || { log "no $DISK, skipping grow"; return 0; }

    disk_end=$(( $(blockdev --getsz "$DISK") - 1 ))
    part_end=$(partx -o END -g -n "$ROOTPARTNUM" "$DISK" 2>/dev/null | tr -d ' ')
    [ -n "$part_end" ] || { log "could not read partition end, skipping grow"; return 0; }

    slack=$(( disk_end - part_end ))
    # Only act if more than ~1 GiB is unallocated, so this is a no-op on every
    # boot after the first.
    if [ "$slack" -lt 2097152 ]; then
        return 0
    fi

    log "growing rootfs: ${slack} unallocated sectors after p${ROOTPARTNUM}"
    echo ", +" | sfdisk -N "$ROOTPARTNUM" --no-reread --force "$DISK" >> "$LOG" 2>&1
    partx -u "$DISK" >> "$LOG" 2>&1
    resize2fs "$ROOTPART" >> "$LOG" 2>&1
    log "rootfs now: $(df -h / | tail -1)"
}

# --- 2. identity from the boot partition --------------------------------------
write_template() {
    cat > "$CONF" <<'TEMPLATE'
# wraith drone identity — edit, then reboot.
# Readable from any SD card reader; this is the FAT boot partition.
#
# NAME  hostname, matching the fleet name (harpy41, vulture42, stork43,
#       shrike44, shoebill45, phoenix0)
# IP    static address on the hangar link, 10.33.0.<sysid>
#       (bench unit phoenix0 = 10.33.0.10; hg2 holds 10.33.0.1)

NAME=
IP=
TEMPLATE
    log "no config found; wrote template to $CONF"
}

apply_identity() {
    if [ ! -f "$CONF" ]; then
        write_template
        return 0
    fi

    NAME=$(sed -n 's/^[[:space:]]*NAME=//p' "$CONF" | tr -d '[:space:]' | head -1)
    IP=$(sed -n 's/^[[:space:]]*IP=//p'   "$CONF" | tr -d '[:space:]' | head -1)

    if [ -n "$NAME" ] && [ "$(cat /etc/hostname 2>/dev/null)" != "$NAME" ]; then
        echo "$NAME" > /etc/hostname
        hostname "$NAME"
        log "hostname -> $NAME"
    fi

    if [ -n "$IP" ]; then
        want="auto lo
iface lo inet loopback

auto eth0
iface eth0 inet static
    address $IP
    netmask 255.255.255.0
"
        if [ "$(cat /etc/network/interfaces 2>/dev/null)" != "$want" ]; then
            printf '%s' "$want" > /etc/network/interfaces
            log "static IP -> $IP (applied on this boot's network start)"
        fi
    fi
}

grow_rootfs
apply_identity
exit 0
