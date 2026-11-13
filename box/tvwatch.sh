#!/data/data/com.termux/files/usr/bin/bash
# tvwatch: every CHECK seconds, if no media audio is playing and there was no
# remote input since the last check, count a "sleep tick". After
# SLEEP_TIMEOUT/CHECK consecutive ticks, show the countdown dialog; if it runs
# out, turn the TV off (connect -> sleep -> verify -> disconnect), then sleep
# the box. Any active check resets the count.

BOX=127.0.0.1:5555
TV=192.168.0.60:5555
CHECK=60            # seconds between checks (also the input lookback window)
SLEEP_TIMEOUT=1800  # seconds of no audio + no input before the countdown (30 ticks)
COUNTDOWN=30        # seconds shown in the dialog
TICKS_NEEDED=$(( SLEEP_TIMEOUT / CHECK ))

LOG=/sdcard/Download/tvwatch/tvwatch.log
APPDIR=/sdcard/Android/data/dev.local.tvoff/files
RESULT=$APPDIR/result
POSTPONE=$APPDIR/postpone_until

log() { echo "$(date '+%F %T') $*" >> "$LOG"; }
box() { timeout 15 adb -s "$BOX" "$@"; }
tv()  { timeout 8  adb -s "$TV"  "$@"; }

box_ok() { # local adb to the box itself, reconnect if stale
  box shell true >/dev/null 2>&1 && return 0
  adb disconnect "$BOX" >/dev/null 2>&1
  timeout 8 adb connect "$BOX" >/dev/null 2>&1
  box shell true >/dev/null 2>&1
}

postponed() {
  local until
  until=$(box shell cat "$POSTPONE" 2>/dev/null | tr -dc '0-9')
  [ -n "$until" ] && [ "$(date +%s)" -lt "$until" ]
}

# One adb round-trip that reports everything we need for a check:
#   AWAKE=0/1  PLAYERS=<n media/game players started>  IDLE_MS=<ms since input>  SESSION=<summary>
probe() {
  box shell '
    w=$(dumpsys power)
    echo "$w" | grep -q "mWakefulness=Awake" && echo AWAKE=1 || echo AWAKE=0
    echo "IDLE_MS=$(echo "$w" | grep -m1 -o "lastUserActivityTime=[0-9]* ([0-9]* ms ago" | grep -o "([0-9]*" | tr -d "(")"
    echo "PLAYERS=$(dumpsys audio | grep "AudioPlaybackConfiguration" | grep "state:started" | grep -c -E "usage=USAGE_(MEDIA|GAME|UNKNOWN)")"
    echo "SESSION=$(dumpsys media_session | grep -E "^ +package=|state=PlaybackState" | sed "s/.*package=//;s/.*state=PlaybackState {state=//;s/(.*//" | paste -d: - - | grep -v -E "bluetooth|:NONE|:ERROR" | tr "\n" " ")"
  ' 2>/dev/null | tr -d '\r'
}

# Connect to the TV only for this, verify it's asleep, then disconnect.
tv_off() {
  local try
  for try in 1 2 3; do
    adb disconnect "$TV" >/dev/null 2>&1
    if timeout 8 adb connect "$TV" 2>&1 | grep -q 'connected to'; then
      tv shell input keyevent KEYCODE_SLEEP >/dev/null 2>&1
      sleep 2
      if tv shell dumpsys power 2>/dev/null | grep -q 'mWakefulness=Asleep'; then
        adb disconnect "$TV" >/dev/null 2>&1
        log "TV off (attempt $try)"
        return 0
      fi
      log "TV not asleep after attempt $try"
    else
      log "could not connect to TV (attempt $try)"
    fi
    sleep 2
  done
  adb disconnect "$TV" >/dev/null 2>&1
  return 1
}

countdown() { # live countdown dialog app; returns 0 = turn off, 1 = cancelled
  local r i
  box shell "rm -f $RESULT" >/dev/null 2>&1
  box shell am start -n dev.local.tvoff/.CountdownActivity --ei seconds "$COUNTDOWN" >/dev/null 2>&1
  for ((i=0; i<COUNTDOWN+15; i++)); do
    sleep 1
    r=$(box shell cat "$RESULT" 2>/dev/null | tr -d '\r\n')
    case "$r" in
      off)    log "countdown: turn off"; return 0 ;;
      cancel) log "countdown: cancelled"; return 1 ;;
    esac
  done
  box shell am force-stop dev.local.tvoff >/dev/null 2>&1
  log "countdown: no answer from dialog - not turning off"
  return 1
}

log "tvwatch started (check ${CHECK}s, sleep after ${SLEEP_TIMEOUT}s = ${TICKS_NEEDED} ticks, countdown ${COUNTDOWN}s)"
adb disconnect "$TV" >/dev/null 2>&1
ticks=0
was_postponed=0
while true; do
  if ! box_ok; then
    ticks=0
  elif postponed; then
    [ "$was_postponed" = 1 ] || log "postponed until $(date -d @"$(box shell cat "$POSTPONE" | tr -dc '0-9')" '+%H:%M')"
    was_postponed=1
    ticks=0
  else
    [ "$was_postponed" = 1 ] && log "postponement over"
    was_postponed=0

    out=$(probe)
    AWAKE=$(echo "$out"   | sed -n 's/^AWAKE=//p')
    IDLE_MS=$(echo "$out" | sed -n 's/^IDLE_MS=//p')
    PLAYERS=$(echo "$out" | sed -n 's/^PLAYERS=//p')
    SESSION=$(echo "$out" | sed -n 's/^SESSION=//p')
    IDLE_MS=${IDLE_MS:-0}; PLAYERS=${PLAYERS:-0}

    if [ "$AWAKE" != 1 ]; then
      ticks=0                                   # box asleep: nothing to do
    elif [ "$PLAYERS" -gt 0 ]; then
      [ "$ticks" -gt 0 ] && log "audio playing - reset (was $ticks) [$SESSION]"
      ticks=0
    elif [ "$IDLE_MS" -lt $(( CHECK * 1000 )) ]; then
      [ "$ticks" -gt 0 ] && log "remote input ${IDLE_MS}ms ago - reset (was $ticks)"
      ticks=0
    else
      ticks=$(( ticks + 1 ))
      log "sleep tick $ticks/$TICKS_NEEDED (no audio, input ${IDLE_MS}ms ago) [$SESSION]"
      if [ "$ticks" -ge "$TICKS_NEEDED" ]; then
        if countdown; then
          if tv_off; then
            box shell input keyevent KEYCODE_SLEEP && log "box put to sleep"
          else
            log "TV did not turn off - leaving box on"
          fi
        fi
        ticks=0
      fi
    fi
  fi
  sleep "$CHECK"
done
