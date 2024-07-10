#!/bin/sh

# Get current public IP
current_ip=$(curl -s ifconfig.me)
previous_ip=$(cat /usr/src/app/dns/fresh.data)

# Read variables from file
source /usr/src/app/dns/canned.data

# Check if IP changed
if [ "$current_ip" != "$previous_ip" ]; then
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
    
	# Replace the variables in the extra command
    old_ip="$previous_ip"
    new_ip="$current_ip"
    updated_command="${extra_command//\(\$old_ip\)/$old_ip}"
    updated_command="${updated_command//\(\$new_ip\)/$new_ip}"
	# Execute extra command
	eval "$updated_command"
    
	# Update the fresh.data file with the new IP
    echo "$current_ip" > /usr/src/app/dns/fresh.data
fi