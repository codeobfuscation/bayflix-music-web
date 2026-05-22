#!/bin/bash
set -e
chown bayflix:bayflix /srv/bayflix-music/auth/auth.js /srv/bayflix-music/auth/server.js
echo "=== run migration against auth.js (does not start server) ==="
cd /srv/bayflix-music/auth
set -a
source .env
set +a
yes | npx --yes @better-auth/cli@latest migrate -y --config /srv/bayflix-music/auth/auth.js 2>&1 | tail -25
chown -R bayflix:bayflix /srv/bayflix-music/auth/data
echo
echo "=== schema after migration ==="
sqlite3 /srv/bayflix-music/auth/data/auth.db ".tables" 2>&1 || node -e "
import('better-sqlite3').then(m => {
  const db = new m.default('/srv/bayflix-music/auth/data/auth.db', {readonly:true});
  const rows = db.prepare(\"SELECT name FROM sqlite_master WHERE type='table' ORDER BY name\").all();
  console.log(rows.map(r=>r.name).join(' '));
});
"
echo
echo "=== restart auth ==="
systemctl restart bayflix-auth
sleep 3
systemctl --no-pager status bayflix-auth | head -8
