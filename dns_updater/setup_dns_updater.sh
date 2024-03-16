#!/bin/sh

# Check if required variables exist
if [ -z "$ZONE_ID" ] || [ -z "$API_TOKEN" ] || [ -z "$DNS_RECORD_ID" ]; then
    echo "Error: ZONE_ID, API_TOKEN, and DNS_LIST environment variables must be set."
    exit 1
fi

# Set up the canned.data file
echo "Creating canned.data file..."
echo "zone_id=$ZONE_ID" > ./dns/canned.data
echo "api_token=$API_TOKEN" >> ./dns/canned.data
echo "dns_list=$DNS_RECORD_ID" >> ./dns/canned.data
echo "extra_command='$EXTRA_COMMAND'" >> ./dns/canned.data

# Add main script to crontab
echo "Configuring crontab for dns updater"
crontab -l | { cat; echo "*/5 * * * * /usr/src/app/dns/dns_updater.sh"; } | crontab -
crond

# First DNS update forced run
echo "Getting DNS up to date..."
/usr/src/app/dns/dns_updater.sh

echo "DNS updater setup completed."

# Start CloudFlared
echo "Starting CloudFlared Tunnel..."
./cloudflared.sh