FROM cloudflare/cloudflared:latest

COPY ./dns_updater /usr/src/app/dns_updater

