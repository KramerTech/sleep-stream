# sleep-stream

This is pretty niche right? Why would you be running a streaming stick on a smart tv? Well, my fire tv is kind of old and laggy and I don't really care for its remote. My GoogleTV streaming stick is much better. But it'd just stay on forever because something about the sleep settings between the ONN and the Fire don't play nice together. Enter: this repo. Through a bit of ADB chicanery, both device go to sleep properly.

Built and tested with an onn 4K Streaming Box (Google TV, Android 14, 32-bit ARM) on
top of an Insignia Fire TV Edition (`AFTJMST12`, Fire OS 6.7.1.1 / Android 7.1). It
should work with any Android/Google TV box driving any TV that accepts
`input keyevent KEYCODE_SLEEP` over network adb.

## Requirements

- **Static IPs for both the TV and the box.** The watcher on the box reaches the TV by
  IP, and the scripts on your computer reach the box by IP. Set up a DHCP reservation
  for each device's MAC address on your router (or a static IP in each device's network
  settings), then reboot both so they pick up the new addresses.
- Developer options → ADB debugging (and network/wireless ADB on port 5555) enabled on
  both devices.
- On your computer: `adb`, and to build the app, a JDK plus the Android SDK
  (build-tools and a platform `android.jar`; `ANDROID_HOME` or `~/Library/Android/sdk`).

## Configure

```sh
cp config.example config     # gitignored
$EDITOR config               # set TV_IP and BOX_IP (and timings if you like)
```

```sh
TV_IP=192.168.0.60      # the TV (target that gets turned off)
BOX_IP=192.168.0.61     # the streaming box (runs the watcher)
ADB_PORT=5555
CHECK=60                # seconds between idle checks (also the remote-input lookback)
SLEEP_TIMEOUT=1800      # seconds of no audio + no input before the countdown
COUNTDOWN=30            # seconds shown in the countdown dialog
```

Every script on your computer reads `config`. `box/deploy.sh` copies it to the box as
`~/tvwatch.conf` (in Termux), where the watcher and `setup.sh` read it. After editing,
run `box/deploy.sh` to apply it.

## How it works

```
 box                                               TV
 ┌──────────────────────────────────────┐          ┌─────────────────────┐
 │ Termux:Boot → tvwatch.sh             │   adb    │ adbd :5555          │
 │   every CHECK s, adb → 127.0.0.1     │ ───────► └─────────────────────┘
 │   • media audio playing?             │ only at
 │   • remote input in last CHECK s?    │ shutoff
 │   SLEEP_TIMEOUT/CHECK idle ticks     │
 │     → countdown dialog (tvoff app)   │
 │   expires → TV sleep, verify, disc.  │
 │          → box sleep                 │
 └──────────────────────────────────────┘
```

**Idle check** (`box/tvwatch.sh`), every `CHECK` seconds:
- *Audio*: `dumpsys audio` players in `state:started` with usage MEDIA/GAME/UNKNOWN.
  Works for DRM apps (Prime Video uses the offload output, SmartTube the mixer) and with
  the TV muted. UI click sounds are ignored. The AudioFlinger `Standby` flag is **not**
  used: offload output stays `Standby: no` after pausing.
- *Input*: `dumpsys power` → `lastUserActivityTime=… (N ms ago)`; active if N < CHECK.
- Neither → one sleep tick. Any active check resets to 0.
  `SLEEP_TIMEOUT / CHECK` consecutive ticks (30 with the defaults) → countdown.
- Media session state is only logged (`[pkg:STATE]`), never decides; apps don't always
  publish one and they can go stale.
- Screenshots were tried first and dropped: DRM video screenshots black, and the
  Google TV home carousel changes ~70% of the screen while idle.

**Countdown dialog** (`app/`, package `dev.local.tvoff`): "TV sleeping in: 30…0", no
buttons. Any remote key → "Activity detected. Sleep cancelled." with **Dismiss** and
**Postpone sleep for: 1/2/3 hours** (the key that cancels is swallowed so it can't also
hit Dismiss; volume keys still change volume). Results go to
`/sdcard/Android/data/dev.local.tvoff/files/`:
- `result`: `pending` | `off` | `cancel`
- `postpone_until`: unix seconds; the watcher skips checks until then

**Shutoff order**: connect to TV → `KEYCODE_SLEEP` → confirm `mWakefulness=Asleep` (3
tries) → disconnect → only then sleep the box. If the TV won't turn off the box stays on.
This matters with remotes whose power button *toggles* both devices: if only one is
off, they flip in opposite directions forever.

## Setup

1. **Configure** as above.
2. **Build the app**: `app/build.sh`. The first run generates your own signing key at
   `app/release.keystore` (gitignored). Keep it: updates must be signed with the same
   key to install over the app. A prebuilt `app/tvoff.apk` is included if you'd rather
   skip building; if you later switch to your own build, uninstall the app first.
3. **Install Termux on the box** from GitHub releases: Termux, Termux:Boot, Termux:API.
   All three must come from the same source (they share a signing key). Pick the
   termux-app build matching the box's ABI (`adb shell getprop ro.product.cpu.abilist`).
4. **Grant permissions** (from your computer, `adb -s <BOX_IP>:5555 shell …`):
   ```sh
   pm grant com.termux android.permission.READ_EXTERNAL_STORAGE
   pm grant com.termux android.permission.WRITE_EXTERNAL_STORAGE
   appops set com.termux SYSTEM_ALERT_WINDOW allow
   appops set com.termux.api SYSTEM_ALERT_WINDOW allow
   dumpsys deviceidle whitelist +com.termux +com.termux.api +com.termux.boot
   ```
5. **Push files**: `box/deploy.sh --apk --no-restart`.
6. **Run setup in Termux** on the box: open Termux once (it bootstraps), then
   `bash /sdcard/Download/tvwatch/setup.sh`. It upgrades packages, installs adb, copies
   the watcher + config into place and connects to the box itself and to the TV.
   Accept both "Allow debugging?" prompts (tick "Always allow"): the box's shows over
   HDMI, the TV's on the TV itself. **Disconnect any other adb client from the TV
   first** (see gotchas).
7. **Open Termux:Boot once** so its boot receiver is active.
8. **Start it**: `box/deploy.sh`. From then on Termux:Boot starts it at every boot.

## Day-to-day

```sh
tools/log.sh            # last 30 log lines   (tools/log.sh -f to follow)
tools/audiocheck.sh     # live audio/media/focus snapshot of the box
box/deploy.sh           # push tvwatch.sh + config changes, restart watcher
box/deploy.sh --apk     # also reinstall the dialog app
app/build.sh            # rebuild the APK (bump versionCode first)
```

Log: `/sdcard/Download/tvwatch/tvwatch.log` on the box.

## Gotchas learned the hard way

- **The Fire TV accepts only one adb client at a time**, and won't even show the auth
  prompt for a new key while another client is connected. Run
  `adb disconnect <TV_IP>:5555` on your computer when you're done with the TV. The
  watcher only connects at shutoff time for this reason.
- adb screenshots of the TV are black on HDMI input (hardware video plane).
- Termux's bootstrap ships an old `libc++`; adb won't run until packages are upgraded
  (`setup.sh` does this).
- Android 14 blocks background activity starts: Termux/Termux:API need
  `SYSTEM_ALERT_WINDOW` (setup step 4).
- A stale adb connection to a sleeping TV hangs forever: every adb call in the watcher
  is wrapped in `timeout`.
