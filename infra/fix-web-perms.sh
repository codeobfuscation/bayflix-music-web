#!/bin/bash
set -e
echo "=== fix directory perms (755) ==="
find /srv/bayflix-music/web -type d -exec chmod 755 {} +
find /srv/bayflix-music/web -type f -exec chmod 644 {} +
ls -la /srv/bayflix-music/web/ | head -8
echo
echo "=== deep asset test ==="
asset_file=$(ls /srv/bayflix-music/web/assets/ 2>/dev/null | grep '\.js$' | head -1)
echo "Testing /assets/$asset_file"
curl -sI --max-time 10 "https://dev2.cwi-group.org/assets/$asset_file" 2>&1 | head -3
echo
echo "=== web-app-manifest-512 ==="
curl -sI --max-time 10 https://dev2.cwi-group.org/web-app-manifest-512x512.png 2>&1 | head -3
echo
echo "=== sw.js ==="
curl -sI --max-time 10 https://dev2.cwi-group.org/sw.js 2>&1 | head -3
echo
echo "=== bayflix.png ==="
curl -sI --max-time 10 https://dev2.cwi-group.org/assets/bayflix.png 2>&1 | head -3
