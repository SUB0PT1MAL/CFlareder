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

# First DNS update forced
echo "Getting DNS up to date..."
# Get current IP and save it
current_ip=$(curl -s ifconfig.me)
echo "$current_ip" > /usr/src/app/dns/fresh.data
# Iterate through the list of domains
IFS=',' # Set the Internal Field Separator to comma
for dns_entry in $dns_list; do
    domain_name=$(echo "$dns_entry" | cut -d':' -f1)
    dns_record_id=$(echo "$dns_entry" | cut -d':' -f2)
    # Update the DNS record for the current domain
    curl --request PATCH \
        --url "https://api.cloudflare.com/client/v4/zones/$zone_id/dns_records/$dns_record_id" \
        --header "Content-Type: application/json" \
        --header "Authorization: Bearer $api_token" \
        --data "{\"content\": \"$current_ip\", \"name\": \"$domain_name\", \"proxied\": true, \"type\": \"A\", \"ttl\": 3600}"
done
echo "DNS updater setup completed."

# Start CloudFlared
echo "Starting CloudFlared Tunnel..."
./cloudflared.sh