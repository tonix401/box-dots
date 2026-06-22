IS_DISABLED=$(tailscale status | grep Tailscale\ is\ stopped.)

if [ "$IS_DISABLED" ]; then
    tailscale up
else
    tailscale down
fi