# /etc/nginx/sites-enabled/auth.bayflix.ms
# Bayflix better-auth — proxies to 127.0.0.1:8096

server {
    listen 80;
    listen [::]:80;
    server_name auth.bayflix.ms;
    server_tokens off;

    location / {
        return 301 https://$host$request_uri;
    }
}

server {
    listen 443 ssl http2;
    listen [::]:443 ssl http2;
    server_name auth.bayflix.ms;
    server_tokens off;

    ssl_certificate     /etc/ssl/cloudflare/bayflix.ms.pem;
    ssl_certificate_key /etc/ssl/cloudflare/bayflix.ms.key;

    include /etc/nginx/cloudflare.conf;
    deny all;

    ssl_client_certificate /etc/ssl/cloudflare/origin-pull-ca.pem;
    ssl_verify_client on;

    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_prefer_server_ciphers off;
    ssl_session_cache shared:SSL:10m;
    ssl_session_timeout 1d;
    ssl_session_tickets off;

    real_ip_header CF-Connecting-IP;

    access_log /var/log/nginx/auth.bayflix.ms.access.log;
    error_log  /var/log/nginx/auth.bayflix.ms.error.log;

    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header Referrer-Policy "strict-origin-when-cross-origin" always;

    client_max_body_size 2m;

    location / {
        proxy_pass http://127.0.0.1:8096;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP        $remote_addr;
        proxy_set_header X-Forwarded-For  $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto https;
        proxy_set_header X-Forwarded-Host $host;
        proxy_read_timeout 60s;
        proxy_buffering off;
    }
}
