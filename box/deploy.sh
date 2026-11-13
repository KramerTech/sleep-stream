#!/bin/sh
# Push the watcher + config (and optionally the APK) to the box and restart it.
# Usage: box/deploy.sh [--apk] [--no-restart]
#   --apk         also install app/tvoff.apk
#   --no-restart  only push files (use for first-time setup, before Termux is set up)
# Restarting works by typing into Termux on the box, so it briefly takes over the screen.
set -e
. "$(dirname "$0")/../tools/config.sh"
cd "$ROOT"
B() { adb -s "$BOX" "$@"; }

APK=0; RESTART=1
for a in "$@"; do
  case "$a" in --apk) APK=1 ;; --no-restart) RESTART=0 ;; esac
done

adb connect "$BOX" >/dev/null
[ "$APK" = 1 ] && B install -r app/tvoff.apk
B shell mkdir -p /sdcard/Download/tvwatch
B push box/tvwatch.sh box/start-tvwatch box/setup.sh /sdcard/Download/tvwatch/ >/dev/null
B push config /sdcard/Download/tvwatch/tvwatch.conf >/dev/null
echo "pushed files to $BOX"
[ "$RESTART" = 1 ] || exit 0

B shell input keyevent KEYCODE_WAKEUP
B shell am start -n com.termux/.app.TermuxActivity >/dev/null 2>&1
sleep 2
B shell "input text 'clear;cp%s/sdcard/Download/tvwatch/tvwatch.conf%s~/;cp%s/sdcard/Download/tvwatch/tvwatch.sh%s~/;cp%s/sdcard/Download/tvwatch/start-tvwatch%s~/.termux/boot/;sh%s~/.termux/boot/start-tvwatch'"
B shell input keyevent KEYCODE_ENTER
sleep 3
B shell input keyevent KEYCODE_HOME
B shell 'ps -A -o PID,ARGS | grep tvwatch.sh | grep -v grep; tail -1 /sdcard/Download/tvwatch/tvwatch.log'
