DEV=wlan1
STATE=$(iwctl device $DEV show | grep Powered | awk '{print $4}')
if [ "$STATE" = "on" ]; then
    iwctl device $DEV set-property Powered off
else
    iwctl device $DEV set-property Powered on
fi