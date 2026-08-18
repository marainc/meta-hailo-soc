#!/bin/sh
# temp — live SoC temperature monitor for the Hailo-15 (°C and °F). Ctrl-C to stop.
# Method: hwmon / scmi_sensors (/sys/class/hwmon/hwmon0/temp1_input, temp2_input), milli-degC.
# temp1 = pvt-ts-0, temp2 = pvt-ts-1 (two on-die PVT sensors, different die locations).
# Install: /usr/bin/temp (chmod +x). Just type: temp
while true; do
    a=$(cat /sys/class/hwmon/hwmon0/temp1_input 2>/dev/null)
    b=$(cat /sys/class/hwmon/hwmon0/temp2_input 2>/dev/null)
    awk -v a="$a" -v b="$b" 'BEGIN{c1=a/1000; c2=b/1000; printf "temp1=%.1fC/%.1fF  temp2=%.1fC/%.1fF\n", c1, c1*9/5+32, c2, c2*9/5+32}'
    sleep 1
done
