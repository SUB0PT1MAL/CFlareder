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
    
    # Execute extra command

	# Replace the placeholders in the command
	updated_command="${EXTRA_COMMAND//\($old_ip\)/$previous_ip}"
	updated_command="${updated_command//\($new_ip\)/$current_ip}"

	# Log the command (optional, remove in production if sensitive)
	echo "Executing command: $updated_command"

	# Execute the updated command
	eval "$updated_command"
    
	# Update the fresh.data file with the new IP
    echo "$current_ip" > /usr/src/app/dns/fresh.data
fi

