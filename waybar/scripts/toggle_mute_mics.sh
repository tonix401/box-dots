mapfile -t NODE_NUMBERS < <(wpctl list | grep alsa_input | awk '{print $1}')

for NODE in "${NODE_NUMBERS[@]}"; do
    wpctl set-mute $NODE toggle
done