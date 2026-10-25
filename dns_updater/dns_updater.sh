#!/bin/sh
MAX_RETRIES=3
TIMEOUT=5

is_valid_ipv4() {
    case "$1" in
        ""|0.0.0.0)
            return 1
            ;;
    esac

    printf '%s\n' "$1" | grep -Eq '^((25[0-5]|2[0-4][0-9]|1[0-9][0-9]|[1-9][0-9]|[0-9])\.){3}(25[0-5]|2[0-4][0-9]|1[0-9][0-9]|[1-9][0-9]|[0-9])$'
}

get_ip() {
    local retry_count=0
    local ip=""
    local raw=""

    while [ "$retry_count" -lt "$MAX_RETRIES" ]; do
        # Try Google DNS
        ip=$(timeout "$TIMEOUT" nslookup -type=txt o-o.myaddr.l.google.com ns1.google.com 2>/dev/null | awk -F'"' 'NF>=2 {print $2; exit}')
        ip=$(printf '%s' "$ip" | tr -d '[:space:]')

        if is_valid_ipv4 "$ip"; then
            printf '%s\n' "$ip"
            return 0
        fi

        # If Google fails, try Cloudflare
        raw=$(timeout "$TIMEOUT" curl -fsS --max-time "$TIMEOUT" https://1.1.1.1/cdn-cgi/trace 2>/dev/null)

        if [ "$?" -eq 0 ]; then
            ip=$(printf '%s\n' "$raw" | sed -n 's/^ip=//p' | head -n 1)
            ip=$(printf '%s' "$ip" | tr -d '[:space:]')

            if is_valid_ipv4 "$ip"; then
                printf '%s\n' "$ip"
                return 0
            fi
        fi

        if [ "$retry_count" -lt "$((MAX_RETRIES - 1))" ]; then
            echo "Attempt $((retry_count + 1)) failed. Retrying..." >&2
        fi

        retry_count=$((retry_count + 1))
        sleep 1
    done

    return 1
}

# Get current public IP
current_ip=$(get_ip)
if [ "$?" -ne 0 ] || [ -z "$current_ip" ] || ! is_valid_ipv4 "$current_ip"; then
    echo "Could not determine a valid public IP. Skipping update and leaving fresh.data unchanged." >&2
    exit 0
fi

previous_ip=$(cat /usr/src/app/dns/fresh.data 2>/dev/null)

# Read variables from file
source /usr/src/app/dns/canned.data

# Check if IP is stored
if [ "$previous_ip" = "" ]; then
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
