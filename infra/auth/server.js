import { toNodeHandler } from 'better-auth/node';
import { createServer } from 'node:http';
import { auth, ALLOWED_ORIGINS } from './auth.js';

const handler = toNodeHandler(auth);
const port = Number(process.env.PORT || 8096);

function applyCors(req, res) {
    const origin = req.headers.origin;
    if (origin && ALLOWED_ORIGINS.has(origin)) {
        res.setHeader('Access-Control-Allow-Origin', origin);
        res.setHeader('Access-Control-Allow-Credentials', 'true');
        res.setHeader('Vary', 'Origin');
    }
    res.setHeader(
        'Access-Control-Allow-Methods',
        'GET, POST, OPTIONS, DELETE, PUT, PATCH'
    );
    res.setHeader(
        'Access-Control-Allow-Headers',
        'Content-Type, Authorization, Cookie, X-Requested-With'
    );
    res.setHeader('Access-Control-Max-Age', '3600');
}

createServer(async (req, res) => {
    try {
        applyCors(req, res);
        if (req.method === 'OPTIONS') {
            res.statusCode = 204;
            res.end();
            return;
        }
        await handler(req, res);
    } catch (err) {
        console.error('auth error', err);
        if (!res.headersSent) {
            res.statusCode = 500;
            res.end('internal');
        }
    }
}).listen(port, '127.0.0.1', () => {
    console.log(
        `bayflix-auth listening on 127.0.0.1:${port} (baseURL=${process.env.BETTER_AUTH_URL})`
    );
});
