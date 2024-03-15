FROM cloudflare/cloudflared:latest

COPY ./dns_updater /usr/src/app/dns

#RUN chmod -R +x /usr/src/app/dns

ENTRYPOINT ["/usr/src/app/dns/setup_dns_updater.sh", "&&", "cloudflared", "--no-autoupdate"]
CMD ["version"]