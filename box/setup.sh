#!/data/data/com.termux/files/usr/bin/bash
set -e
exec > >(tee $HOME/setup.log) 2>&1
yes | pkg update -y
pkg install -y android-tools termux-api
cp /sdcard/Download/tvwatch/tvwatch.sh $HOME/tvwatch.sh
mkdir -p $HOME/.termux/boot
cp /sdcard/Download/tvwatch/start-tvwatch $HOME/.termux/boot/start-tvwatch
chmod +x $HOME/tvwatch.sh $HOME/.termux/boot/start-tvwatch
adb connect 127.0.0.1:5555 || true
adb connect 192.168.0.60:5555 || true
echo SETUP_DONE
