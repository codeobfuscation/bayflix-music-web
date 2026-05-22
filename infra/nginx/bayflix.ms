# /etc/nginx/sites-enabled/bayflix.ms
# Bayflix Music PROD — static SPA, Cloudflare-fronted, AOP-hardened.

server {
    listen 80;
    listen [::]:80;
    server_name bayflix.ms www.bayflix.ms;
    server_tokens off;

    location / {
        return 301 https://bayflix.ms$request_uri;
    }
}

server {
    listen 443 ssl http2;
    listen [::]:443 ssl http2;
    server_name www.bayflix.ms;
    server_tokens off;

    ssl_certificate     /etc/ssl/cloudflare/bayflix.ms.pem;
    ssl_certificate_key /etc/ssl/cloudflare/bayflix.ms.key;

    # Cloudflare-only origin: reject direct-IP traffic
    include /etc/nginx/cloudflare.conf;
    deny all;

    # Authenticated Origin Pulls: require Cloudflare's edge client cert
    ssl_client_certificate /etc/ssl/cloudflare/origin-pull-ca.pem;
    ssl_verify_client on;

    ssl_protocols TLSv1.2 TLSv1.3;

    return 301 https://bayflix.ms$request_uri;
}

server {
    listen 443 ssl http2;
    listen [::]:443 ssl http2;
    server_name bayflix.ms;
    server_tokens off;

    ssl_certificate     /etc/ssl/cloudflare/bayflix.ms.pem;
    ssl_certificate_key /etc/ssl/cloudflare/bayflix.ms.key;

    # Cloudflare-only origin: reject direct-IP traffic
    include /etc/nginx/cloudflare.conf;
    deny all;

    # Authenticated Origin Pulls: require Cloudflare's edge client cert
    ssl_client_certificate /etc/ssl/cloudflare/origin-pull-ca.pem;
    ssl_verify_client on;

    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_prefer_server_ciphers off;
    ssl_session_cache shared:SSL:10m;
    ssl_session_timeout 1d;
    ssl_session_tickets off;

    resolver 1.1.1.1 1.0.0.1 valid=300s ipv6=off;
    resolver_timeout 5s;

    real_ip_header CF-Connecting-IP;

    access_log /var/log/nginx/bayflix.ms.access.log;
    error_log  /var/log/nginx/bayflix.ms.error.log;

    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header Referrer-Policy "strict-origin-when-cross-origin" always;

    root /srv/bayflix-music/web;
    index index.html;

    # CORP-bypass proxies (same as dev2 — artistgrid + qobuz + tidal images)
    location ^~ /proxy/artistgrid/ {
        proxy_pass https://assets.artistgrid.cx/;
        proxy_set_header Host assets.artistgrid.cx;
        proxy_set_header User-Agent "bayflix-music-proxy";
        proxy_ssl_server_name on;
        proxy_ssl_verify off;
        proxy_hide_header Cross-Origin-Resource-Policy;
        proxy_hide_header Access-Control-Allow-Origin;
        add_header Cross-Origin-Resource-Policy "cross-origin" always;
        add_header Access-Control-Allow-Origin "*" always;
        add_header Cache-Control "public, max-age=604800" always;
        proxy_intercept_errors on;
        proxy_read_timeout 30s;
    }
    location ^~ /proxy/artistgrid-r2/ {
        proxy_pass https://r2.artistgrid.cx/;
        proxy_set_header Host r2.artistgrid.cx;
        proxy_set_header User-Agent "bayflix-music-proxy";
        proxy_ssl_server_name on;
        proxy_ssl_verify off;
        proxy_hide_header Cross-Origin-Resource-Policy;
        proxy_hide_header Access-Control-Allow-Origin;
        add_header Cross-Origin-Resource-Policy "cross-origin" always;
        add_header Access-Control-Allow-Origin "*" always;
        add_header Cache-Control "public, max-age=604800" always;
        proxy_intercept_errors on;
        proxy_read_timeout 30s;
    }
    location ^~ /proxy/trackerapi-1/ {
        proxy_pass https://trackerapi-1.artistgrid.cx/;
        proxy_set_header Host trackerapi-1.artistgrid.cx;
        proxy_set_header User-Agent "bayflix-music-proxy";
        proxy_ssl_server_name on;
        proxy_ssl_verify off;
        proxy_hide_header Cross-Origin-Resource-Policy;
        proxy_hide_header Access-Control-Allow-Origin;
        add_header Cross-Origin-Resource-Policy "cross-origin" always;
        add_header Access-Control-Allow-Origin "*" always;
        add_header Cache-Control "public, max-age=300" always;
        proxy_intercept_errors on;
        proxy_read_timeout 30s;
    }
    location ^~ /proxy/trackerapi-2/ {
        proxy_pass https://trackerapi-2.artistgrid.cx/;
        proxy_set_header Host trackerapi-2.artistgrid.cx;
        proxy_set_header User-Agent "bayflix-music-proxy";
        proxy_ssl_server_name on;
        proxy_ssl_verify off;
        proxy_hide_header Cross-Origin-Resource-Policy;
        proxy_hide_header Access-Control-Allow-Origin;
        add_header Cross-Origin-Resource-Policy "cross-origin" always;
        add_header Access-Control-Allow-Origin "*" always;
        add_header Cache-Control "public, max-age=300" always;
        proxy_intercept_errors on;
        proxy_read_timeout 30s;
    }
    location ^~ /proxy/trackerapi-3/ {
        proxy_pass https://trackerapi-3.artistgrid.cx/;
        proxy_set_header Host trackerapi-3.artistgrid.cx;
        proxy_set_header User-Agent "bayflix-music-proxy";
        proxy_ssl_server_name on;
        proxy_ssl_verify off;
        proxy_hide_header Cross-Origin-Resource-Policy;
        proxy_hide_header Access-Control-Allow-Origin;
        add_header Cross-Origin-Resource-Policy "cross-origin" always;
        add_header Access-Control-Allow-Origin "*" always;
        add_header Cache-Control "public, max-age=300" always;
        proxy_intercept_errors on;
        proxy_read_timeout 30s;
    }
    location ^~ /proxy/qobuz-monochrome/ {
        proxy_pass https://qdl-api.monochrome.tf/;
        proxy_set_header Host qdl-api.monochrome.tf;
        proxy_set_header User-Agent "bayflix-music-proxy";
        proxy_ssl_server_name on;
        proxy_ssl_verify off;
        proxy_hide_header Cross-Origin-Resource-Policy;
        proxy_hide_header Access-Control-Allow-Origin;
        add_header Cross-Origin-Resource-Policy "cross-origin" always;
        add_header Access-Control-Allow-Origin "*" always;
        add_header Cache-Control "public, max-age=300" always;
        proxy_intercept_errors on;
        proxy_read_timeout 30s;
    }
    location ^~ /proxy/tidal-images/ {
        proxy_pass https://resources.tidal.com/;
        proxy_set_header Host resources.tidal.com;
        proxy_set_header User-Agent "bayflix-music-proxy";
        proxy_ssl_server_name on;
        proxy_ssl_verify off;
        proxy_hide_header Cross-Origin-Resource-Policy;
        proxy_hide_header Access-Control-Allow-Origin;
        add_header Cross-Origin-Resource-Policy "cross-origin" always;
        add_header Access-Control-Allow-Origin "*" always;
        add_header Cache-Control "public, max-age=604800" always;
        proxy_intercept_errors on;
        proxy_read_timeout 30s;
    }

    # SW + workbox MUST always revalidate
    location = /sw.js {
        try_files $uri =404;
        add_header Cache-Control "no-cache, no-store, must-revalidate" always;
    }
    location ^~ /workbox- {
        try_files $uri =404;
        add_header Cache-Control "no-cache, no-store, must-revalidate" always;
    }
    location = /index.html {
        try_files $uri =404;
        add_header Cache-Control "no-cache, no-store, must-revalidate" always;
    }
    location = / {
        try_files /index.html =404;
        add_header Cache-Control "no-cache, no-store, must-revalidate" always;
    }

    location ~* \.(?:css|js|mjs|map|json|wasm|mp3|flac|wav|ogg|png|jpg|jpeg|svg|webp|ico|gz|br|utf|ttf|woff2?)$ {
        try_files $uri =404;
        expires 30d;
        add_header Cache-Control "public, immutable";
    }

    location / {
        try_files $uri $uri/ /index.html;
    }
}
