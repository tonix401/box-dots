IS_DISABLED=$(tailscale status | grep Tailscale\ is\ stopped.)

if [ "$IS_DISABLED" ]; then
    echo down
else
    echo up
fi