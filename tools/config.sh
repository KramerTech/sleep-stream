# Sourced by the Mac-side scripts: loads ../config and sets BOX / TV adb serials.
ROOT=$(cd "$(dirname "$0")/.." && pwd)
if [ ! -f "$ROOT/config" ]; then
  echo "Missing $ROOT/config - run: cp config.example config, then edit the IPs." >&2
  exit 1
fi
. "$ROOT/config"
: "${TV_IP:?TV_IP not set in config}" "${BOX_IP:?BOX_IP not set in config}"
ADB_PORT=${ADB_PORT:-5555}
BOX="$BOX_IP:$ADB_PORT"
TV="$TV_IP:$ADB_PORT"
