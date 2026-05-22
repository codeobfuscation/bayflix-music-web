#!/bin/bash
echo "=== 1. Direct upstream alive? ==="
curl -sI --max-time 5 https://assets.artistgrid.cx/drake.webp | grep -iE "^HTTP|content-type" | head -3
echo

echo "=== 2. Hit nginx via 127.0.0.1 with proper AOP client cert ==="
# Need to pass AOP cert + key. The cwi-aop.conf requires a client cert.
# Cloudflare's edge has the cert; we need to simulate by skipping AOP for this test.
# Just test the location matching with insecure skip:
curl -skI --max-time 10 --resolve dev2.cwi-group.org:443:127.0.0.1 \
    https://dev2.cwi-group.org/proxy/artistgrid/drake.webp 2>&1 | head -5
echo

echo "=== 3. Tail nginx error log while we probe via CF ==="
tail -n 0 -F /var/log/nginx/dev2.cwi-group.org.error.log /var/log/nginx/dev2.cwi-group.org.access.log &
TAIL_PID=$!
sleep 1
curl -sI --max-time 10 https://dev2.cwi-group.org/proxy/artistgrid/drake.webp 2>&1 | head -3
sleep 2
kill $TAIL_PID 2>/dev/null
echo

echo "=== 4. nginx -T to show effective config for the proxy block ==="
nginx -T 2>/dev/null | grep -A 20 'proxy/artistgrid/ ' | head -25
echo

echo "=== 5. cloudflare ip list head ==="
head -3 /etc/nginx/cloudflare.conf
echo

echo "=== 6. recent access log entries for proxy paths ==="
grep '/proxy/' /var/log/nginx/dev2.cwi-group.org.access.log | tail -3 || echo "(no entries — request never reached nginx)"
