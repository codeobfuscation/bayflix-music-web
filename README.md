# Bayflix Music

> Hi-Res lossless музикален стриминг в чист, фокусиран уеб интерфейс.

Bayflix Music е едно-страничен (SPA) уеб клиент за висококачествена музика, хостнат на `https://bayflix.ms`.

Поддръжка: [@Necrosis](https://github.com/codeobfuscation) · Discord: [discord.gg/bayflix](https://discord.gg/bayflix)

---

## Какво представлява

- Стриминг на **lossless / Hi-Res FLAC** аудио.
- Метаданни (албуми, корици, текстове, артисти, плейлисти) от TIDAL.
- Аудио чрез Qobuz `qdl` бридж.
- **Локални акаунти**, **Google** и **Discord** логин през собствен `better-auth` бекенд.
- Синхронизация на профили, любими и история в собствен **PocketBase** инстанс.
- Собствен **Cloudflare Worker** за TIDAL прокси (`api.bayflix.ms`).
- Работи като **PWA** (инсталируемо, офлайн кеш).
- Тема в **червен Bayflix цвят** (`#e50914`) и собствено брандиране.

---

## Стек

| Слой | Технология |
|------|------------|
| Фронтенд | Vanilla JS + Vite 7 + `vite-plugin-pwa` (Workbox) |
| Стилове | Чист CSS, custom properties за тема |
| Аудио | `shaka-player`, `hls.js`, `@ffmpeg/ffmpeg` |
| Метаданни прокси | Cloudflare Worker (`services/hifi-api/`) |
| Auth | `better-auth` + Express, Google / Discord / email |
| Sync DB | PocketBase 0.26+ |
| Инфраструктура | nginx + Cloudflare (Full strict TLS, Authenticated Origin Pulls) |
| Мобилно | Capacitor (Android / iOS пакетите са в `android/` и `ios/`) |

---

## Бърз старт (локален dev)

Изисквания:
- **Bun** (или Node 22+) за фронтенда
- **Node 22+** за `infra/auth/` (better-auth)
- **PocketBase** binary, ако искаш да тестваш sync локално

```bash
# 1. Инсталирай зависимостите
bun install

# 2. Копирай .env шаблона и попълни ключовете
cp .env.example .env
#    -> Cloudflare token, Google OAuth, Discord OAuth, PocketBase admin, better-auth secret

# 3. Стартирай dev сървъра
bun run dev
#    -> http://localhost:5173
```

В dev режим, фронтендът сочи към production бекендите (`auth.bayflix.ms`, `data.bayflix.ms`, `api.bayflix.ms`). За пълно локално развитие виж `infra/`.

---

## Production деплой

Production живее на `https://bayflix.ms`. Цялата конфигурация е документирана в [`infra/`](infra/):

| Хост | Сървър | Какво | nginx vhost |
|------|--------|-------|-------------|
| `bayflix.ms` | VPS | Статичен SPA build | `infra/nginx/bayflix.ms` |
| `auth.bayflix.ms` | VPS | better-auth (Node, port 8096) | `infra/nginx/auth.bayflix.ms` |
| `data.bayflix.ms` | VPS | PocketBase (Go, port 8095) | `infra/nginx/data.bayflix.ms` |
| `api.bayflix.ms` | Cloudflare | TIDAL Worker | n/a |

### Сигурностен модел

- **Cloudflare Full (strict)** SSL — origin не приема plain HTTP.
- **Cloudflare Origin Cert** (15 години, RSA-2048) за `bayflix.ms` + `*.bayflix.ms` на `/etc/ssl/cloudflare/`.
- **Authenticated Origin Pulls (AOP)** — nginx изисква клиентски сертификат подписан от CF Origin Pull CA. Директни заявки към IP-то получават `400`.
- **CF IP allowlist** на ниво nginx vhost (`/etc/nginx/cloudflare.conf` + `deny all`) — само CF IPv4 ranges могат да достъпват порт 443.
- **HSTS** `max-age=31536000; includeSubDomains` за всички подмени.

### Build & deploy на фронтенда

```bash
bun run build         # генерира dist/
# rsync dist/ root@VPS:/srv/bayflix-music/web/
```

nginx vhost-ите служат `dist/` директно и proxy-ват `/api/auth/*` → 127.0.0.1:8096, `/api/*` (PocketBase) → 127.0.0.1:8095, и няколко `/proxy/*` маршрута за изображения и аудио (виж файловете в `infra/nginx/`).

### TIDAL Worker

Хи-Фи API-то живее в отделен репо и се деплойва с `wrangler deploy` от папката си. Worker secrets:

```bash
cd services/hifi-api
wrangler secret put CLIENT_ID
wrangler secret put CLIENT_SECRET
wrangler secret put REFRESH_TOKEN
wrangler deploy
```

---

## Конфигурация

Всички runtime ключове живеят в `.env` (gitignored). Виж [`.env.example`](.env.example) за пълния списък. Накратко:

- `CLOUDFLARE_API_TOKEN`, `CLOUDFLARE_ACCOUNT_ID`, `CLOUDFLARE_ZONE_ID` — за infra скриптове.
- `GOOGLE_CLIENT_ID` / `GOOGLE_CLIENT_SECRET` — Google OAuth. Redirect URI: `https://auth.bayflix.ms/api/auth/callback/google`.
- `DISCORD_CLIENT_ID` / `DISCORD_CLIENT_SECRET` — Discord OAuth. Redirect URI: `https://auth.bayflix.ms/api/auth/callback/discord`.
- `BETTER_AUTH_SECRET` — random 48 байта. Генерирай с `openssl rand -base64 48`.
- `PB_ADMIN_EMAIL` / `PB_ADMIN_PASS` — PocketBase superuser.

---

## Структура

```
.
├── index.html                # SPA entry
├── js/                       # цялата UI логика
│   ├── api.js                # TIDAL + Qobuz + enrichment
│   ├── tracker.js            # unreleased / leak integration
│   ├── accounts/             # auth + PocketBase клиенти
│   └── ...
├── styles.css                # глобални стилове + Bayflix тема (червен)
├── public/                   # статични asset-и (favicon, лого, иконки, manifest)
├── infra/
│   ├── nginx/                # production vhost конфигурации
│   └── auth/                 # better-auth Node сървър
├── services/
│   ├── hifi-api/             # TIDAL Cloudflare Worker (отделен репо)
│   └── tidal-auth-helper/    # CLI за TIDAL device-code OAuth
├── android/, ios/            # Capacitor mobile проекти
└── .env.example              # шаблон за конфигурация
```

---

## Лиценз

Apache License 2.0. Виж [`LICENSE`](LICENSE).
