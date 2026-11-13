#!/bin/sh
# Push the watcher (and optionally the APK) to the box and restart it.
# Usage: box/deploy.sh [--apk]
# Restarting works by typing into Termux on the box, so the box must be awake.
set -e
cd "$(dirname "$0")"
BOX=${BOX:-192.168.0.61:5555}
B() { adb -s "$BOX" "$@"; }

adb connect "$BOX" >/dev/null
[ "$1" = "--apk" ] && B install -r ../app/tvoff.apk
B shell mkdir -p /sdcard/Download/tvwatch
B push tvwatch.sh start-tvwatch setup.sh /sdcard/Download/tvwatch/ >/dev/null

B shell input keyevent KEYCODE_WAKEUP
B shell am start -n com.termux/.app.TermuxActivity >/dev/null 2>&1
sleep 2
B shell "input text 'clear;cp%s/sdcard/Download/tvwatch/tvwatch.sh%s~/tvwatch.sh;cp%s/sdcard/Download/tvwatch/start-tvwatch%s~/.termux/boot/;sh%s~/.termux/boot/start-tvwatch'"
B shell input keyevent KEYCODE_ENTER
sleep 3
B shell input keyevent KEYCODE_HOME
B shell 'ps -A -o PID,ARGS | grep tvwatch.sh | grep -v grep; grep "tvwatch started" /sdcard/Download/tvwatch/tvwatch.log | tail -1'
