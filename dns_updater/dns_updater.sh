#!/bin/sh
MAX_RETRIES=3
TIMEOUT=5

get_ip() {
    local retry_count=0
    local ip=""
    
    while [ $retry_count -lt $MAX_RETRIES ] && [ -z "$ip" ]; do
        # Try Google DNS
        ip=$(timeout $TIMEOUT nslookup -type=txt o-o.myaddr.l.google.com ns1.google.com 2>/dev/null | awk -F'"' 'NF>=2 {print $2; exit}')
        
        # If Google fails, try Cloudflare
        if [ -z "$ip" ]; then
            ip=$(curl -s https://1.1.1.1/cdn-cgi/trace | grep 'ip=' | sed 's/ip=//')
        fi
        
        if [ -z "$ip" ]; then
            echo "Attempt $((retry_count + 1)) failed. Retrying..." >&2
            retry_count=$((retry_count + 1))
            sleep 1
        else
            break
        fi
    done
    
    echo "$ip"
}

# Get current public IP
current_ip=$(get_ip)
previous_ip=$(cat /usr/src/app/dns/fresh.data)

# Read variables from file
source /usr/src/app/dns/canned.data

# Check if IP is stored
if [ "$previous_ip" == "" ]; then
    echo "0.0.0.0" > /usr/src/app/dns/fresh.data
# Check if IP changed
elif [ "$current_ip" != "$previous_ip" ]; then
    echo "IP changed from $previous_ip to $current_ip, updating DNS..."
    
    # Iterate through the list of domains
    IFS=',' # Set the Internal Field Separator to comma
    for dns_entry in $dns_list; do
        domain_name=$(echo "$dns_entry" | cut -d':' -f1)
        dns_record_id=$(echo "$dns_entry" | cut -d':' -f2)
        
        # Check if proxy setting is specified (third parameter)
        proxy_setting=$(echo "$dns_entry" | cut -d':' -f3)
        
        # Default to true (proxied) if not specified or if empty
        if [ -z "$proxy_setting" ]; then
            proxied="true"
        else
            # Convert to lowercase and validate
            proxy_setting=$(echo "$proxy_setting" | tr '[:upper:]' '[:lower:]')
            case "$proxy_setting" in
                "true"|"yes"|"1"|"on"|"proxy")
                    proxied="true"
                    ;;
                "false"|"no"|"0"|"off"|"noproxy")
                    proxied="false"
                    ;;
                *)
                    echo "Warning: Invalid proxy setting '$proxy_setting' for $domain_name. Defaulting to proxied."
                    proxied="true"
                    ;;
            esac
        fi
        
        echo "Updating $domain_name (proxied: $proxied)..."
        
        # Update the DNS record for the current domain
        curl --request PATCH \
            --url "https://api.cloudflare.com/client/v4/zones/$zone_id/dns_records/$dns_record_id" \
            --header "Content-Type: application/json" \
            --header "Authorization: Bearer $api_token" \
            --data "{\"content\": \"$current_ip\", \"name\": \"$domain_name\", \"proxied\": $proxied, \"type\": \"A\", \"ttl\": 3600}"
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
else
    echo "IP has not changed: $current_ip"
fi
