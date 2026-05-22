// Runs on the VPS. Same logic as scripts/auth-node.mjs but writes
// the resulting .dev.vars to /tmp on the server. We then scp it back.

import { writeFile } from 'node:fs/promises';

const SCOPE = 'r_usr+w_usr+w_sub';
const AUTH = 'https://auth.tidal.com/v1/oauth2/device_authorization';
const TOKEN = 'https://auth.tidal.com/v1/oauth2/token';
const UA =
    'Mozilla/5.0 (Linux; Android 8.0.0; SM-G965F Build/R16NW) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/65.0.3325.109 Mobile Safari/537.36';
const GIST = 'https://api.github.com/gists/48d01f5a24b4b7b37f19443977c22cd6';

const basic = (id, sec) => 'Basic ' + Buffer.from(`${id}:${sec}`).toString('base64');

async function getCreds() {
    const r = await fetch(GIST, {
        headers: { accept: 'application/vnd.github+json', 'user-agent': 'bayflix' },
    });
    const g = await r.json();
    const parsed = JSON.parse(g.files['tidal-api-key.json'].content);
    return (parsed.keys ?? [])
        .filter(
            (k) =>
                k.valid === 'True' &&
                (k.formats ?? '').toLowerCase().includes('hifi') &&
                k.clientId &&
                k.clientSecret
        )
        .map((k) => ({ id: k.clientId, sec: k.clientSecret, formats: k.formats }));
}

async function deviceAuth(cred) {
    const r = await fetch(AUTH, {
        method: 'POST',
        headers: { 'content-type': 'application/x-www-form-urlencoded', 'user-agent': UA },
        body: new URLSearchParams({ client_id: cred.id, scope: SCOPE }),
    });
    return r.json();
}

async function pollOnce(cred, deviceCode) {
    const r = await fetch(TOKEN, {
        method: 'POST',
        headers: {
            authorization: basic(cred.id, cred.sec),
            'content-type': 'application/x-www-form-urlencoded',
            'user-agent': UA,
        },
        body: new URLSearchParams({
            client_id: cred.id,
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
        data = { raw: text.slice(0, 200) };
    }
    return { status: r.status, ok: r.ok, data };
}

const creds = await getCreds();
if (creds.length === 0) {
    console.error('No HiFi credentials found in gist.');
    process.exit(1);
}
const cred = creds[0];
console.log(`Using clientId=${cred.id.slice(0, 12)}… (formats: ${cred.formats})`);

const auth = await deviceAuth(cred);
if (!auth.deviceCode) {
    console.error('device_authorization failed:', JSON.stringify(auth));
    process.exit(1);
}
const verifyUrl = auth.verificationUriComplete.startsWith('http')
    ? auth.verificationUriComplete
    : `https://${auth.verificationUriComplete}`;
console.log('\n=================================');
console.log('OPEN IN BROWSER:', verifyUrl);
console.log('USER CODE:      ', auth.userCode);
console.log('=================================\n');

const intervalMs = (auth.interval ?? 5) * 1000;
const deadline = Date.now() + (auth.expiresIn ?? 300) * 1000;

while (Date.now() < deadline) {
    const r = await pollOnce(cred, auth.deviceCode);
    if (r.ok && r.data.access_token) {
        const lines = [
            `CLIENT_ID=${cred.id}`,
            `CLIENT_SECRET=${cred.sec}`,
            `REFRESH_TOKEN=${r.data.refresh_token}`,
            '',
        ];
        await writeFile('/tmp/bayflix-tidal.dev.vars', lines.join('\n'), { mode: 0o600 });
        console.log('\n✓ Wrote /tmp/bayflix-tidal.dev.vars');
        process.exit(0);
    }
    if (r.data.error === 'authorization_pending') process.stdout.write('.');
    else if (r.data.error === 'slow_down') process.stdout.write('s');
    else if (
        r.data.error === 'expired_token' ||
        r.data.error === 'access_denied'
    ) {
        console.error('\n✗ TIDAL:', r.data.error);
        process.exit(1);
    } else {
        console.error(
            `\n? Unexpected response HTTP ${r.status}:`,
            JSON.stringify(r.data).slice(0, 200)
        );
    }
    await new Promise((res) => setTimeout(res, intervalMs));
}
console.error('\n✗ Timed out waiting for approval.');
process.exit(1);
