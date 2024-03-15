#!/bin/sh

# Check if required variables exist
if [ -z "$ZONE_ID" ] || [ -z "$API_TOKEN" ] || [ -z "$DNS_RECORD_ID" ]; then
    echo "Error: ZONE_ID, API_TOKEN, and DNS_LIST environment variables must be set."
    exit 1
fi

# Set up the canned.data file
echo "zone_id=$ZONE_ID" > canned.data
echo "api_token=$API_TOKEN" >> canned.data
echo "dns_list=$DNS_RECORD_ID" >> canned.data
echo "extra_command='$EXTRA_COMMAND'" >> canned.data

# Add main script to crontab
crontab -l | { cat; echo "*/5 * * * * /usr/src/app/dns/dns_updater.sh"; } | crontab -

# Start CloudFlared
/bin/sh ./cloudflared.sh