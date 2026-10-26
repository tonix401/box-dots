#!/usr/bin/env bash
# Prints one line of JSON describing the current network state (iwd + sysfs).
# Polled every second while the sidebar is open, so it sticks to bash builtins, one awk and as few
# iwctl calls as it can (one while Wi-Fi is on).
# first wireless and first wired physical interface (wlan1/eno1 on Arch, wlan0 on NixOS)
WIFI=wlan0 ETH=eno1 wifis=()
for dev in /sys/class/net/*; do
  [ -e "$dev/wireless" ] && wifis+=("${dev##*/}")
done
[ ${#wifis[@]} -gt 0 ] && WIFI=${wifis[0]}
# The USB Wi-Fi dongle comes up as wlan0 or wlan1, and when it re-enumerates at boot (USB 2 -> 3) a stale
# second netdev can stay on the same radio: with more than one, ask iwd which it manages (the device
# list rows with a MAC). A single adapter skips the extra iwctl call.
if [ ${#wifis[@]} -gt 1 ]; then
  dev=$(iwctl device list 2>/dev/null | awk '{ gsub(/\x1b\[[0-9;]*m/, "") } $2 ~ /^([0-9a-f]{2}:){5}/ { print $1; exit }')
  [ -n "$dev" ] && WIFI=$dev
fi
for dev in /sys/class/net/*; do
  [ -e "$dev/device" ] && [ ! -e "$dev/wireless" ] && { ETH=${dev##*/}; break; }
done

# Prints the JSON and exits. `iwctl station show` output (or nothing) on stdin fills in the
# Wi-Fi fields; without it they keep their defaults.
emit() { # state ifname [ip]
  local rx=0 tx=0
  read -r rx < "/sys/class/net/$2/statistics/rx_bytes" 2>/dev/null
  read -r tx < "/sys/class/net/$2/statistics/tx_bytes" 2>/dev/null
  awk -v state="$1" -v ifname="$2" -v ip="${3:-}" -v rx="${rx:-0}" -v tx="${tx:-0}" '
    function str(s) { gsub(/\\/, "\\\\", s); gsub(/"/, "\\\"", s); return "\"" s "\"" }
    { gsub(/\x1b\[[0-9;]*m/, ""); sub(/^ +/, ""); sub(/ +$/, ""); key = val = "" }
    # "Connected network     Das Netz": the value starts after the first run of 2+ spaces
    match($0, /  +/) { key = substr($0, 1, RSTART - 1); val = substr($0, RSTART + RLENGTH) }
    key == "Connected network" { ssid = val }
    key == "IPv4 address" && ip == "" { ip = val }
    key == "Frequency" { freq = val + 0 }
    key == "Security" { security = val }
    key == "RSSI" { rssi = val + 0; hasRssi = 1 }
    key == "TxBitrate" { bitrate = val + 0 }
    END {
      if (!hasRssi) rssi = -90
      signal = int((rssi + 90) * 100 / 60); if (signal > 100) signal = 100; if (signal < 0) signal = 0
      printf "{\"state\":%s,\"ifname\":%s,\"ssid\":%s,\"rssi\":%d,\"rx\":%.0f,\"tx\":%.0f,\"ip\":%s,\"freq\":%d,\"security\":%s,\"bitrate\":%d,\"signal\":%d}\n",
        str(state), str(ifname), str(ssid), rssi, rx, tx, str(ip), freq, str(security), bitrate, signal
    }'
  exit 0
}

carrier=
read -r carrier < "/sys/class/net/$ETH/carrier" 2>/dev/null
if [ "$carrier" = 1 ]; then
  ip=$(ip -4 -o addr show dev "$ETH" 2>/dev/null)
  ip=${ip#*inet } ip=${ip%%/*}
  [[ $ip == *" "* ]] && ip=
  emit ethernet "$ETH" "$ip" < /dev/null
fi

# Only a powered device has a station, so the device itself is asked only when this fails.
if info=$(iwctl station "$WIFI" show 2>/dev/null); then
  [[ $info =~ State[[:space:]]+connected ]] && emit wifi "$WIFI" <<< "$info"
  emit disconnected "$WIFI" < /dev/null
fi
[[ $(iwctl device "$WIFI" show 2>/dev/null) =~ Powered[[:space:]]+on ]] && emit disconnected "$WIFI" < /dev/null
emit disabled "$WIFI" < /dev/null
