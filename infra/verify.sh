#!/bin/bash
set -e
echo === reload nginx ===
systemctl reload nginx
echo
echo === Check 1: direct-IP TLS handshake should be REFUSED by AOP ===
for host in bayflix.ms auth.bayflix.ms data.bayflix.ms; do
    echo "--- $host (direct, no AOP client cert) ---"
    curl -skI --max-time 10 --resolve $host:443:127.0.0.1 https://$host/ 2>&1 | head -3
done
echo
echo === Check 2: through Cloudflare ===
for host in bayflix.ms auth.bayflix.ms data.bayflix.ms; do
    echo "--- $host (via CF) ---"
    curl -sI --max-time 15 https://$host/ 2>&1 | head -4
done
echo
echo === Specific endpoint smoke ===
echo "--- auth.bayflix.ms /api/auth/get-session ---"
curl -s --max-time 15 https://auth.bayflix.ms/api/auth/get-session | head -c 200
echo
echo "--- data.bayflix.ms /api/health ---"
curl -s --max-time 15 https://data.bayflix.ms/api/health | head -c 200
echo
