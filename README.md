# sleep-stream

Have the streaming box put itself and the TV to sleep when nobody's watching.

| Device | IP | Model |
|---|---|---|
| TV | 192.168.0.60 | Insignia Fire TV Edition `AFTJMST12`, Fire OS 6.7.1.1 (Android 7.1) |
| Box | 192.168.0.61 | onn 4K Streaming Box (Google TV, Android 14, 32-bit ARM) |

Both have DHCP reservations on the router.

## How it works

```
 box (onn)                                         TV (Fire TV)
 ┌──────────────────────────────────────┐          ┌─────────────────────┐
 │ Termux:Boot → tvwatch.sh             │   adb    │ adbd :5555          │
 │   every 60s, via adb → 127.0.0.1:5555│ ───────► └─────────────────────┘
 │   • media audio playing?             │ only at
 │   • remote input in last 60s?        │ shutoff
 │   30 idle ticks → countdown dialog   │
 │   (dev.local.tvoff)                  │
 │   expires → TV sleep, verify, disc.  │
 │          → box sleep                 │
 └──────────────────────────────────────┘
```

**Idle check** (`box/tvwatch.sh`), every `CHECK`=60s:
- *Audio*: `dumpsys audio` players in `state:started` with usage MEDIA/GAME/UNKNOWN.
  Works for DRM apps (Prime Video uses the offload output, SmartTube the mixer) and with
  the TV muted. UI click sounds are ignored. The AudioFlinger `Standby` flag is **not**
  used: offload output stays `Standby: no` after pausing.
- *Input*: `dumpsys power` → `lastUserActivityTime=… (N ms ago)`; active if N < CHECK.
- Neither → one sleep tick. Any active check resets to 0.
  `SLEEP_TIMEOUT / CHECK` (= 1800/60 = 30) consecutive ticks → countdown.
- Media session state is only logged (`[pkg:STATE]`), never decides; apps don't always
  publish one and they can go stale.
- Screenshots were tried first and dropped: HDMI/DRM video screenshots black, and the
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
This matters because the onn remote's power button *toggles* both; if only one is off
they flip in opposite directions forever.

## Gotchas learned the hard way

- **The TV accepts only one adb client at a time**, and won't even show the auth
  prompt for a new key while another client is connected. Disconnect the Mac
  (`adb disconnect 192.168.0.60:5555`) before anything else needs it. The watcher only
  connects at shutoff time for this reason.
- adb screenshots of the TV are black on HDMI input (hardware video plane).
- Termux's bootstrap ships an old `libc++`; `apt full-upgrade` before adb will run.
- Android 14 blocks background activity starts: Termux/Termux:API need
  `appops set <pkg> SYSTEM_ALERT_WINDOW allow` (done in setup).
- A stale adb connection to a sleeping TV hangs forever: every adb call in the watcher
  is wrapped in `timeout`.

## Box setup (`box/`)

Prereq: ADB debugging + network ADB enabled on both the TV and the box.


1. Install from GitHub releases (all three must come from the same source/signing key;
   box is 32-bit → `armeabi-v7a` build of termux-app): Termux, Termux:Boot, Termux:API.
2. `pm grant com.termux android.permission.{READ,WRITE}_EXTERNAL_STORAGE`,
   `appops set com.termux{,.api} SYSTEM_ALERT_WINDOW allow`,
   `dumpsys deviceidle whitelist +com.termux +com.termux.api +com.termux.boot`.
3. Open Termux once (bootstrap), run `bash /sdcard/Download/tvwatch/setup.sh`, then
   `yes | apt-get -y -o Dpkg::Options::=--force-confnew full-upgrade` (libc++ fix).
4. In Termux: `adb connect 127.0.0.1:5555` (allow on box) and, with the Mac
   disconnected from the TV, `adb connect 192.168.0.60:5555` (allow on TV). Tick
   "Always allow" both times.
5. Open Termux:Boot once so its boot receiver is active.
6. `app/build.sh && box/deploy.sh --apk`.

## Day-to-day

```sh
tools/log.sh            # last 30 log lines   (tools/log.sh -f to follow)
tools/audiocheck.sh     # live audio/media/focus snapshot of the box
box/deploy.sh           # push tvwatch.sh changes + restart watcher
box/deploy.sh --apk     # also reinstall the dialog app
app/build.sh            # rebuild the APK (bump versionCode first)
```

Tuning lives at the top of `box/tvwatch.sh`: `CHECK`, `SLEEP_TIMEOUT`, `COUNTDOWN`.
Log: `/sdcard/Download/tvwatch/tvwatch.log` on the box.

`app/debug.keystore` (password `android`) signs the APK; keep it so updates install
over the existing app.
