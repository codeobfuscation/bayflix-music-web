export const getProxyUrl = (url) => {
    return url;
};

// TIDAL URLs:
//   - `api.tidal.com` and `openapi.tidal.com` send `Access-Control-Allow-Origin: *`
//     directly, so we can call them with no proxy. (We used to bounce through
//     `tidal-proxy.monochrome.tf` for CORS, but that proxy now rate-limits
//     aggressively → 429s. Direct is both faster and more reliable.)
//   - `resources.tidal.com` (image CDN) does NOT send CORS; for fetch() reads
//     we proxy via our own nginx at `/proxy/tidal-images/`. <img src> works
//     directly (no CORS needed for passive embeds), so we leave those alone.
export const wrapTidalUrl = (url) => {
    if (!url || typeof url !== 'string') return url;
    return url;
};

// Used by utils.js when the app needs to fetch() the raw image bytes
// (cover metadata embedding, color extraction, etc).
export const wrapTidalImageFetchUrl = (url) => {
    if (!url || typeof url !== 'string') return url;
    return url.replace('https://resources.tidal.com/', '/proxy/tidal-images/');
};
