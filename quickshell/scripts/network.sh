#!/usr/bin/env bash
# Prints one line of JSON describing the current network state (iwd + sysfs).
WIFI=wlan1
ETH=eno1

strip() { sed 's/\x1b\[[0-9;]*m//g'; }

emit() { # state ifname [ssid] [rssi]
  local rx tx
  rx=$(cat "/sys/class/net/$2/statistics/rx_bytes" 2>/dev/null || echo 0)
  tx=$(cat "/sys/class/net/$2/statistics/tx_bytes" 2>/dev/null || echo 0)
  jq -cn --arg state "$1" --arg ifname "$2" --arg ssid "${3:-}" --argjson rssi "${4:--90}" \
    --argjson rx "$rx" --argjson tx "$tx" \
    '{state: $state, ifname: $ifname, ssid: $ssid, rssi: $rssi, rx: $rx, tx: $tx,
      signal: ([0, ([100, (($rssi + 90) * 100 / 60)] | min)] | max | floor)}'
  exit 0
}

[ "$(cat /sys/class/net/$ETH/carrier 2>/dev/null)" = "1" ] && emit ethernet "$ETH"

powered=$(iwctl device $WIFI show 2>/dev/null | strip | awk '/Powered/ {print $NF}')
[ "$powered" = "on" ] || emit disabled "$WIFI"

info=$(iwctl station $WIFI show 2>/dev/null | strip)
[ "$(awk '$1 == "State" {print $2}' <<< "$info")" = "connected" ] || emit disconnected "$WIFI"

ssid=$(sed -n 's/^ *Connected network *\(.*[^ ]\) *$/\1/p' <<< "$info")
rssi=$(awk '$1 == "RSSI" {print $2}' <<< "$info")
emit wifi "$WIFI" "$ssid" "$rssi"
