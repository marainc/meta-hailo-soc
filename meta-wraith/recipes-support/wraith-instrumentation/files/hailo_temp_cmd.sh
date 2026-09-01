#!/bin/sh
# temp — live SoC temperature + uptime monitor for the Hailo-15 (°C and °F). Ctrl-C to stop.
# Method: hwmon / scmi_sensors (/sys/class/hwmon/hwmon0/temp1_input, temp2_input), milli-degC.
# temp1 = pvt-ts-0, temp2 = pvt-ts-1 (two on-die PVT sensors, different die locations).
# Uptime comes from /proc/uptime — useful next to the temperature because these
# boards reboot unexpectedly, and a low uptime explains a suddenly-cool reading.
# Install: /usr/bin/temp (chmod +x). Just type: temp
#
# Usage:
#   temp            live, one line per second (Ctrl-C to stop)
#   temp --once     print ONE line and exit
#
# ⚠️ Use --once from scripts. The default loop never exits, so `$(temp)` hangs
# forever — that stalled an ssh session during fleet_temp.py work (2026-08-19).

once=0
case "$1" in
    -1|--once|once) once=1 ;;
esac

fmt_uptime() {
    s=$(cut -d. -f1 /proc/uptime 2>/dev/null)
    [ -z "$s" ] && { printf "?"; return; }
    d=$((s / 86400)); h=$(((s % 86400) / 3600)); m=$(((s % 3600) / 60))
    if [ "$d" -gt 0 ]; then printf "%dd%02dh%02dm" "$d" "$h" "$m"
    elif [ "$h" -gt 0 ]; then printf "%dh%02dm" "$h" "$m"
    else printf "%dm%02ds" "$m" "$((s % 60))"
    fi
}

while true; do
    a=$(cat /sys/class/hwmon/hwmon0/temp1_input 2>/dev/null)
    b=$(cat /sys/class/hwmon/hwmon0/temp2_input 2>/dev/null)
    up=$(fmt_uptime)
    awk -v a="$a" -v b="$b" -v up="$up" 'BEGIN{
        c1 = a / 1000; c2 = b / 1000;
        printf "temp1=%.1fC/%.1fF  temp2=%.1fC/%.1fF  up=%s\n",
               c1, c1 * 9 / 5 + 32, c2, c2 * 9 / 5 + 32, up
    }'
    [ "$once" -eq 1 ] && break
    sleep 1
done
