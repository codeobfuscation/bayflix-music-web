#!/bin/bash
set -e

# Bootstraps PocketBase with the DB_users and public_playlists collections
# the frontend expects. Permissive rules (open access) — fine for dev2,
# lock down later for prod.

PB_URL="http://127.0.0.1:8095"
PB_EMAIL="$1"
PB_PASS="$2"

if [ -z "$PB_EMAIL" ] || [ -z "$PB_PASS" ]; then
    echo "usage: $0 <admin_email> <admin_password>"
    exit 1
fi

echo "=== authenticating as PocketBase superuser ==="
AUTH_RES=$(curl -s -X POST "$PB_URL/api/collections/_superusers/auth-with-password" \
    -H "Content-Type: application/json" \
    --data "{\"identity\":\"$PB_EMAIL\",\"password\":\"$PB_PASS\"}")

TOKEN=$(echo "$AUTH_RES" | python3 -c "import json,sys; print(json.load(sys.stdin).get('token',''))")
if [ -z "$TOKEN" ]; then
    echo "auth failed: $AUTH_RES"
    exit 1
fi
echo "OK"

create_collection() {
    local payload="$1"
    local name=$(echo "$payload" | python3 -c "import json,sys; print(json.load(sys.stdin)['name'])")
    echo "=== creating collection: $name ==="
    RES=$(curl -s -X POST "$PB_URL/api/collections" \
        -H "Authorization: $TOKEN" \
        -H "Content-Type: application/json" \
        --data "$payload")
    echo "$RES" | python3 -c "
import json,sys
d = json.load(sys.stdin)
if d.get('id'):
    print(f\"  ✓ created id={d['id']}\")
elif d.get('data', {}).get('name', {}).get('code') == 'validation_collection_name_exists':
    print('  (already exists, skipping)')
else:
    print(f\"  ✗ {json.dumps(d)[:300]}\")
"
}

# DB_users — main user profile + sync record
create_collection '{
    "name": "DB_users",
    "type": "base",
    "listRule": "",
    "viewRule": "",
    "createRule": "",
    "updateRule": "",
    "deleteRule": "",
    "fields": [
        {"name": "firebase_id", "type": "text", "required": true, "presentable": false},
        {"name": "username", "type": "text", "required": false},
        {"name": "display_name", "type": "text", "required": false},
        {"name": "avatar_url", "type": "url", "required": false, "options": {"exceptDomains": null, "onlyDomains": null}},
        {"name": "banner", "type": "url", "required": false, "options": {"exceptDomains": null, "onlyDomains": null}},
        {"name": "status", "type": "json", "required": false, "options": {"maxSize": 2000000}},
        {"name": "about", "type": "text", "required": false, "options": {"max": 2000}},
        {"name": "website", "type": "url", "required": false, "options": {"exceptDomains": null, "onlyDomains": null}},
        {"name": "lastfm_username", "type": "text", "required": false},
        {"name": "privacy", "type": "json", "required": false, "options": {"maxSize": 50000}},
        {"name": "favorite_albums", "type": "json", "required": false, "options": {"maxSize": 200000}},
        {"name": "library", "type": "json", "required": false, "options": {"maxSize": 20000000}},
        {"name": "history", "type": "json", "required": false, "options": {"maxSize": 20000000}},
        {"name": "user_playlists", "type": "json", "required": false, "options": {"maxSize": 20000000}},
        {"name": "user_folders", "type": "json", "required": false, "options": {"maxSize": 5000000}}
    ],
    "indexes": [
        "CREATE UNIQUE INDEX `idx_DB_users_firebase_id` ON `DB_users` (`firebase_id`)",
        "CREATE UNIQUE INDEX `idx_DB_users_username` ON `DB_users` (`username`) WHERE `username` != \"\""
    ]
}'

# public_playlists — shared playlists for the social/sharing features
create_collection '{
    "name": "public_playlists",
    "type": "base",
    "listRule": "",
    "viewRule": "",
    "createRule": "",
    "updateRule": "",
    "deleteRule": "",
    "fields": [
        {"name": "playlist_id", "type": "text", "required": true},
        {"name": "owner_firebase_id", "type": "text", "required": true},
        {"name": "title", "type": "text", "required": false},
        {"name": "description", "type": "text", "required": false},
        {"name": "tracks", "type": "json", "required": false, "options": {"maxSize": 20000000}},
        {"name": "cover_url", "type": "url", "required": false, "options": {"exceptDomains": null, "onlyDomains": null}},
        {"name": "is_public", "type": "bool", "required": false}
    ],
    "indexes": [
        "CREATE INDEX `idx_public_playlists_playlist_id` ON `public_playlists` (`playlist_id`)",
        "CREATE INDEX `idx_public_playlists_owner` ON `public_playlists` (`owner_firebase_id`)"
    ]
}'

echo
echo "=== final collection list ==="
curl -s "$PB_URL/api/collections" -H "Authorization: $TOKEN" | python3 -c "
import json,sys
d = json.load(sys.stdin)
for c in d.get('items', []):
    print(f\"  - {c['name']} ({c['type']}, {len(c.get('fields',[]))} fields)\")
"
