#!/bin/sh
# Show the watcher log from the box. Usage: tools/log.sh [lines]   (-f to follow)
BOX=${BOX:-192.168.0.61:5555}
adb connect "$BOX" >/dev/null
if [ "$1" = "-f" ]; then
  adb -s "$BOX" shell tail -f /sdcard/Download/tvwatch/tvwatch.log
else
  adb -s "$BOX" shell tail -n "${1:-30}" /sdcard/Download/tvwatch/tvwatch.log
fi
