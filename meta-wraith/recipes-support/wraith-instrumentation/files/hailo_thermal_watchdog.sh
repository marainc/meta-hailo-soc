#!/bin/sh
# Hailo-15 blackbox recorder (persistent, power-cut-safe).
# Extends the original thermal watchdog: logs temp + supply voltage + power +
# free memory + free disk + load + CPU freq every INTERVAL seconds to the
# ROOTFS, and snapshots dmesg per boot. Goal: when the board spontaneously
# reboots, leave a trail to tell WHY — thermal / brownout / OOM / watchdog-hang.
#
# No RTC on this board (clock resets), so we use a persistent boot counter +
# /proc/uptime instead of wall-clock time. `sync` after every write so a hard
# power cut doesn't lose the last samples.
#
# Deploy: scp to /home/root/, chmod +x, start on boot (see block at bottom).
# Output dir: /home/root/blackbox/   (health.log = CSV, dmesg_boot<N>.log per boot)

DIR=/home/root/blackbox
LOG=$DIR/health.log
BOOTC=$DIR/.bootcount
INTERVAL=10          # seconds between samples
DMESG_EVERY=6        # snapshot dmesg every Nth sample (~60 s)
KEEP_BOOTS=8         # keep this many per-boot dmesg files
MAXLINES=300000      # trim health.log past this

mkdir -p "$DIR"

# --- persistent boot counter + boot marker ---
n=$(cat "$BOOTC" 2>/dev/null || echo 0); n=$((n + 1)); echo "$n" > "$BOOTC"; sync
{
  echo "==== BOOT #$n  (uptime resets to 0) ===="
  echo "# watchdog: $(ls /dev/watchdog* 2>/dev/null | tr '\n' ' ')(kernel watchdogd pets it -> a hang causes a HW reset)"
  echo "# mem: $(grep -e MemTotal -e SwapTotal /proc/meminfo | tr '\n' ' ')"
  echo "# units: z*=milli-degC, vin=in0_input(raw, mV-ish), pwr=power1_input(raw uW if present), mem/disk=KB, freq=Hz"
} >> "$LOG"; sync

rd() { cat "$1" 2>/dev/null; }   # read file or empty

i=0
while true; do
    up=$(cut -d' ' -f1 /proc/uptime 2>/dev/null)
    z0=$(rd /sys/class/thermal/thermal_zone0/temp)
    z1=$(rd /sys/class/thermal/thermal_zone1/temp)
    vin=$(rd /sys/class/hwmon/hwmon0/in0_input)
    pwr=$(rd /sys/class/hwmon/hwmon0/power1_input)
    mem=$(awk '/MemAvailable/{print $2}' /proc/meminfo 2>/dev/null)
    dfk=$(df -k / 2>/dev/null | awk 'NR==2{print $4}')
    ld=$(cut -d' ' -f1 /proc/loadavg 2>/dev/null)
    fq=$(rd /sys/devices/system/cpu/cpu0/cpufreq/scaling_cur_freq)
    echo "boot=$n up=${up}s z0=${z0} z1=${z1} vin=${vin} pwr=${pwr} memAvailKB=${mem} diskFreeKB=${dfk} load1=${ld} freq=${fq}" >> "$LOG"
    sync                                   # power-cut safety: flush now

    i=$((i + 1))

    # per-boot dmesg snapshot (catches kernel oops/usb/oom/thermal before a cut)
    if [ $((i % DMESG_EVERY)) -eq 0 ]; then
        dmesg 2>/dev/null | tail -n 400 > "$DIR/dmesg_boot${n}.log"; sync
        old=$((n - KEEP_BOOTS))
        [ "$old" -gt 0 ] && rm -f "$DIR/dmesg_boot${old}.log" 2>/dev/null
    fi

    # bounded health.log
    if [ $((i % 500)) -eq 0 ]; then
        lines=$(wc -l < "$LOG" 2>/dev/null || echo 0)
        if [ "$lines" -gt "$MAXLINES" ]; then
            tail -n $((MAXLINES / 2)) "$LOG" > "$LOG.tmp" && mv "$LOG.tmp" "$LOG"; sync
        fi
    fi
    sleep "$INTERVAL"
done

# ---------------------------------------------------------------------------
# START ON BOOT (pick the init this image uses; check `ls -l /sbin/init`):
# SysV/busybox (this image has /etc/rc5.d/*.sh):
#   cp hailo_thermal_watchdog.sh /home/root/ && chmod +x /home/root/hailo_thermal_watchdog.sh
#   printf '#!/bin/sh\ncase "$1" in start) /home/root/hailo_thermal_watchdog.sh >/dev/null 2>&1 & ;; stop) pkill -f hailo_thermal_watchdog.sh ;; esac\n' > /etc/init.d/blackbox
#   chmod +x /etc/init.d/blackbox && ln -sf ../init.d/blackbox /etc/rc5.d/S51blackbox
# systemd (if /sbin/init -> systemd):
#   [Unit] Description=Hailo blackbox / [Service] ExecStart=/home/root/hailo_thermal_watchdog.sh, Restart=always / [Install] WantedBy=multi-user.target
#   systemctl enable --now blackbox
# ---------------------------------------------------------------------------
