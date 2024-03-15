#!/bin/sh

# Get current public IP
current_ip=$(curl -s ifconfig.me)

# Read variables from file
source canned.data

# Check if IP changed
if [ "$current_ip" != "$(cat fresh.data)" ]; then
    # Iterate through the list of domains
    IFS=',' read -ra dns_list <<< "$dns_list"
    for dns_entry in "${dns_list[@]}"; do
        domain_name=$(echo "$dns_entry" | cut -d':' -f1)
        dns_record_id=$(echo "$dns_entry" | cut -d':' -f2)

        # Update the DNS record for the current domain
        curl --request PATCH \
             --url "https://api.cloudflare.com/client/v4/zones/$zone_id/dns_records/$dns_record_id" \
             --header "Content-Type: application/json" \
             --header "Authorization: Bearer $api_token" \
             --data "{\"content\": \"$current_ip\", \"name\": \"$domain_name\", \"proxied\": false, \"type\": \"A\", \"ttl\": 3600}"
    done

    # Execute extra command
    eval "$extra_command"

    # Update the fresh.data file with the new IP
    echo "$current_ip" > fresh.data
fi