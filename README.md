# sleep-stream

This is pretty niche right? Why would you be running a streaming stick on a smart tv? Well, my fire tv is kind of old and laggy and I don't really care for its remote. My GoogleTV streaming stick is much better. But it'd just stay on forever because something about the sleep settings between the ONN and the Fire don't play nice together. Enter: this repo. Through a bit of ADB chicanery, both device go to sleep properly.

Built and tested with an onn 4K Streaming Box (Google TV, Android 14) on an Insignia
Fire TV Edition (Fire OS 6). Should work with any Android TV box on any TV that takes
`input keyevent KEYCODE_SLEEP` over network adb.

## How it works

A watcher runs on the box in Termux. Every `CHECK` seconds it asks the box (over adb to
itself) whether media audio is playing or the remote was used since the last check.
If neither, that's a sleep tick; anything else resets the count. After
`SLEEP_TIMEOUT` seconds of ticks, a countdown dialog appears:

- No input → the TV is turned off over adb (and confirmed asleep), then the box sleeps.
- Any remote button → sleep is cancelled, with options to **Dismiss** or
  **Postpone sleep** for 1, 2 or 3 hours.

## Requirements

- **Static IPs for the TV and the box** (DHCP reservations on your router). Reboot both
  after setting them.
- ADB debugging with network adb (port 5555) enabled on both devices.
- On your computer: `adb`. To build the app: a JDK and the Android SDK.

## Configure

```sh
cp config.example config
```

Then set `TV_IP` and `BOX_IP` in `config`. Timings live there too:

```sh
TV_IP=192.168.0.60
BOX_IP=192.168.0.61
CHECK=60            # seconds between checks
SLEEP_TIMEOUT=1800  # idle seconds before the countdown
COUNTDOWN=30        # seconds on the countdown dialog
```

`box/deploy.sh` copies `config` to the box, so redeploy after any change.

## Setup

1. `app/build.sh` builds the countdown app. The first run generates your own signing key
   at `app/release.keystore`; keep it, because updates must use the same key. A
   prebuilt `app/tvoff.apk` is included if you'd rather skip this.
2. On the box, install **Termux**, **Termux:Boot** and **Termux:API** from their GitHub
   releases, all three from the same source.
3. Grant permissions from your computer (`adb -s <BOX_IP>:5555 shell …`):
   ```sh
   pm grant com.termux android.permission.READ_EXTERNAL_STORAGE
   pm grant com.termux android.permission.WRITE_EXTERNAL_STORAGE
   appops set com.termux SYSTEM_ALERT_WINDOW allow
   appops set com.termux.api SYSTEM_ALERT_WINDOW allow
   dumpsys deviceidle whitelist +com.termux +com.termux.api +com.termux.boot
   ```
4. `box/deploy.sh --apk --no-restart` pushes the app, the scripts and your config.
5. Open Termux on the box and run `bash /sdcard/Download/tvwatch/setup.sh`. Accept the
   two "Allow debugging?" prompts (box, then TV) and tick "Always allow".
6. Open Termux:Boot once, so the watcher starts at every boot.
7. `box/deploy.sh` starts the watcher.

## Usage

```sh
tools/log.sh            # recent watcher log (-f to follow)
tools/audiocheck.sh     # what the box is playing right now
box/deploy.sh           # push script/config changes and restart the watcher
box/deploy.sh --apk     # also reinstall the app
```

## Gotcha

Fire TVs accept only one adb client at a time, and won't show the authorization prompt
for a new one while another is connected. Run `adb disconnect <TV_IP>:5555` on your
computer when you're done with the TV, or the watcher can't turn it off.
