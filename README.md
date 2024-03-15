CFlareder: Cloudflared with Dynamic DNS Updater
====================

This container image is based on the official CloudFlared image with an added script designed to automatically update DNS records on Cloudflare when your public IP address changes. It runs a script periodically (every 5 minutes by default) that checks if the public IP has changed, and if so, updates the DNS records for the specified domains on Cloudflare.

How to use
----------

1. Build the container image (or use "sub0pt1mal/cflareder"):
   docker build -t cflareder .

2. Run the container with the required environment variables:
   docker run -d --name cflareder \
              -e ZONE_ID=<your_cloudflare_zone_id> \
              -e API_TOKEN=<your_cloudflare_api_token> \
              -e DNS_LIST="<domain1:dns_record_id1>,<domain2:dns_record_id2>,..." \
              -e EXTRA_COMMAND="<optional_extra_command>" \
              cflareder

Required Environment Variables
------------------------------

- `ZONE_ID`: Your Cloudflare zone ID. This is the ID of the Cloudflare zone where your domains are hosted.

- `API_TOKEN`: Your Cloudflare API token. This is used to authenticate with the Cloudflare API for updating DNS records.

- `DNS_LIST`: A comma-separated list of domain names and their corresponding DNS record IDs in the format `"domain1:dns_record_id1,domain2:dns_record_id2,..."`. For example: `"example.com:abc123,example.net:def456"`.

Optional Environment Variable
----------------------------

- `EXTRA_COMMAND`: An optional command that will be executed after the DNS records are updated successfully. This can be used for additional actions, such as sending notifications or triggering other processes.

How it works
------------

1. The container runs a script that retrieves the current public IP address using `curl ifconfig.me`.

2. It reads the last known public IP address from a file (`fresh.data`).

3. If the current public IP is different from the last known IP, the script updates the DNS records for all domains specified in the `DNS_LIST` with the new IP address using the Cloudflare API.

4. After updating the DNS records, it executes the optional `EXTRA_COMMAND` if provided.

5. Finally, it updates the `fresh.data` file with the new public IP address.

6. The script is set up to run every 5 minutes using a cron job inside the container.

Notes
-----

All domains added muts be in the same Zone as the script only iterates trough the "domain:domain_id" list and uses the same zone id for all of them.