#!/usr/bin/env bash
# Daily PostgreSQL dump of the Umami database, keeps the last 14 days.
# Cron: 15 3 * * *  /home/ubuntu/site-analytics/scripts/backup.sh
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p backups
docker compose exec -T db pg_dump -U umami umami | gzip > "backups/umami-$(date +%F).sql.gz"
find backups -name 'umami-*.sql.gz' -mtime +14 -delete
