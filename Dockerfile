FROM alpine:latest

WORKDIR /usr/src/app

RUN apk add --no-cache curl jq

RUN url=$(curl -s https://api.github.com/repos/cloudflare/cloudflared/releases/latest | jq -r '.assets[] | select(.browser_download_url | endswith("cloudflared-linux-amd64")) | .browser_download_url') && \
    curl -L --output "cloudflared" $url && \
    chmod +x ./cloudflared && \
    mv ./cloudflared /usr/local/bin/

COPY cloudflared.sh ./cloudflared.sh
RUN chmod +x ./cloudflared.sh

COPY ./dns_updater ./dns
RUN chmod -R +x ./dns

ENTRYPOINT ["./dns/setup_dns_updater.sh"]