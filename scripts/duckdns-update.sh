#!/usr/bin/env bash
# Keeps the DuckDNS hostname pointed at this VM's current public IP.
# Cron: */30 * * * *  /home/ubuntu/site-analytics/scripts/duckdns-update.sh
set -euo pipefail
cd "$(dirname "$0")/.."
set -a; . ./.env; set +a
curl -fsS "https://www.duckdns.org/update?domains=${DUCKDNS_SUBDOMAIN}&token=${DUCKDNS_TOKEN}&ip=" -o /dev/null
