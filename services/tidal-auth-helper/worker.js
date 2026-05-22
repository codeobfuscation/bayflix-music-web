// Temporary throwaway worker — runs the TIDAL device-authorization flow from
// CF edge so the CloudFront WAF's TLS fingerprint check doesn't bounce us.
// Endpoints:
//   GET  /start   → fetches HiFi cred from gist, calls /device_authorization,
//                   returns JSON { clientId, clientSecret, deviceCode, userCode, verifyUrl, expiresIn, interval }
//   POST /poll    → body { clientId, clientSecret, deviceCode }; one poll attempt;
//                   returns { state: "pending" | "ok" | "error", refresh_token?, error? }
//
// Delete after use (`wrangler delete bayflix-tidal-auth-helper`).

const SCOPE = 'r_usr+w_usr+w_sub';
const AUTH = 'https://auth.tidal.com/v1/oauth2/device_authorization';
const TOKEN = 'https://auth.tidal.com/v1/oauth2/token';
const GIST = 'https://api.github.com/gists/48d01f5a24b4b7b37f19443977c22cd6';
const UA =
    'Mozilla/5.0 (Linux; Android 8.0.0; SM-G965F Build/R16NW) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/65.0.3325.109 Mobile Safari/537.36';

function basic(id, sec) {
    return 'Basic ' + btoa(`${id}:${sec}`);
}

async function pickHifiCred() {
    const r = await fetch(GIST, {
        headers: { accept: 'application/vnd.github+json', 'user-agent': 'bayflix' },
    });
    const g = await r.json();
    const parsed = JSON.parse(g.files['tidal-api-key.json'].content);
    const hifi = (parsed.keys ?? []).filter(
        (k) =>
            k.valid === 'True' &&
            (k.formats ?? '').toLowerCase().includes('hifi') &&
            k.clientId &&
            k.clientSecret
    );
    if (!hifi.length) throw new Error('No HiFi creds in gist');
    return { id: hifi[0].clientId, sec: hifi[0].clientSecret, formats: hifi[0].formats };
}

async function startFlow() {
    const cred = await pickHifiCred();
    const r = await fetch(AUTH, {
        method: 'POST',
        headers: { 'content-type': 'application/x-www-form-urlencoded', 'user-agent': UA },
        body: new URLSearchParams({ client_id: cred.id, scope: SCOPE }),
    });
    const data = await r.json();
    if (!data.deviceCode) {
        return Response.json({ error: 'device_auth_failed', tidal: data }, { status: 500 });
    }
    const verifyUrl = data.verificationUriComplete.startsWith('http')
        ? data.verificationUriComplete
        : `https://${data.verificationUriComplete}`;
    return Response.json({
        clientId: cred.id,
        clientSecret: cred.sec,
        formats: cred.formats,
        deviceCode: data.deviceCode,
        userCode: data.userCode,
        verifyUrl,
        expiresIn: data.expiresIn,
        interval: data.interval,
    });
}

async function pollFlow(req) {
    const body = await req.json();
    const { clientId, clientSecret, deviceCode } = body;
    if (!clientId || !clientSecret || !deviceCode) {
        return Response.json({ state: 'error', error: 'missing params' }, { status: 400 });
    }
    const r = await fetch(TOKEN, {
        method: 'POST',
        headers: {
            authorization: basic(clientId, clientSecret),
            'content-type': 'application/x-www-form-urlencoded',
            'user-agent': UA,
        },
        body: new URLSearchParams({
            client_id: clientId,
            scope: SCOPE,
            device_code: deviceCode,
            grant_type: 'urn:ietf:params:oauth:grant-type:device_code',
        }),
    });
    const text = await r.text();
    let data;
    try {
        data = JSON.parse(text);
    } catch {
        return Response.json(
            { state: 'error', httpStatus: r.status, error: 'non_json', raw: text.slice(0, 300) },
            { status: 502 }
        );
    }
    if (r.ok && data.access_token) {
        return Response.json({
            state: 'ok',
            refresh_token: data.refresh_token,
            access_token_preview: data.access_token.slice(0, 12) + '…',
            scope: data.scope,
            quality: data.quality ?? data.user?.audioQuality,
        });
    }
    if (data.error === 'authorization_pending') {
        return Response.json({ state: 'pending' });
    }
    return Response.json(
        { state: 'error', httpStatus: r.status, error: data.error ?? 'unknown', detail: data },
        { status: r.status }
    );
}

export default {
    async fetch(request) {
        const url = new URL(request.url);
        try {
            if (request.method === 'GET' && url.pathname === '/start') return startFlow();
            if (request.method === 'POST' && url.pathname === '/poll') return pollFlow(request);
            return new Response('bayflix-tidal-auth-helper. GET /start, POST /poll.', {
                status: 200,
            });
        } catch (err) {
            return Response.json({ error: String(err) }, { status: 500 });
        }
    },
};
