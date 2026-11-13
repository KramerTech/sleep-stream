#!/data/data/com.termux/files/usr/bin/bash
# One-time Termux setup on the box. Run inside Termux after box/deploy.sh has
# pushed the files:  bash /sdcard/Download/tvwatch/setup.sh
set -e
exec > >(tee $HOME/setup.log) 2>&1
SRC=/sdcard/Download/tvwatch

# Termux's bootstrap ships an old libc++ that the current adb can't link against
yes | pkg update -y
yes | apt-get -y -o Dpkg::Options::=--force-confnew full-upgrade
pkg install -y android-tools termux-api

cp $SRC/tvwatch.conf $HOME/tvwatch.conf
cp $SRC/tvwatch.sh $HOME/tvwatch.sh
mkdir -p $HOME/.termux/boot
cp $SRC/start-tvwatch $HOME/.termux/boot/start-tvwatch
chmod +x $HOME/tvwatch.sh $HOME/.termux/boot/start-tvwatch

. $HOME/tvwatch.conf
# Each of these triggers an "Allow debugging?" prompt (tick "Always allow").
# The TV only accepts one adb client at a time: disconnect any other client first.
adb connect 127.0.0.1:${ADB_PORT:-5555} || true
adb connect $TV_IP:${ADB_PORT:-5555} || true
echo SETUP_DONE
