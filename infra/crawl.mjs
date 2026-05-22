// Autonomous Bayflix.MS smoke crawl.
// - Opens https://bayflix.ms/
// - Captures every console msg and network failure across N routes
// - Groups by error pattern + originating URL
// - Prints a structured report

import { chromium } from 'playwright';

const BASE = process.env.BAYFLIX_BASE || 'https://bayflix.ms';
const ROUTES = [
    '/',
    '/library',
    '/recent',
    '/unreleased',
    '/donate',
    '/about',
    '/settings',
    '/search',
];

const KNOWN_NOISE = [
    /plausible/i,
    /lrclib\.net/i,
    /lyrics-api\.binimum/i,
    /unison\.boidu/i,
    /lyricsplus-seven/i,
    /lyrics\.geeked/i,
    /lyricsplus\.prjktla/i,
    /lyrics-plus-backend/i,
    /am-lyrics/i, // bundled third-party
];

function isKnownNoise(text) {
    if (!text) return false;
    return KNOWN_NOISE.some((re) => re.test(text));
}

(async () => {
    const browser = await chromium.launch({ headless: true });
    const ctx = await browser.newContext({
        viewport: { width: 1280, height: 800 },
        userAgent:
            'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130.0.0.0 Safari/537.36',
    });
    const page = await ctx.newPage();
    const allConsole = [];
    const allFailures = [];

    page.on('console', (msg) => {
        const type = msg.type();
        const text = msg.text();
        if (type === 'error' || type === 'warning') {
            allConsole.push({ route: page.url(), type, text });
        }
    });
    page.on('pageerror', (err) => {
        allConsole.push({ route: page.url(), type: 'pageerror', text: String(err) });
    });
    page.on('requestfailed', (req) => {
        allFailures.push({
            route: page.url(),
            url: req.url(),
            method: req.method(),
            failure: req.failure()?.errorText ?? 'unknown',
            resourceType: req.resourceType(),
        });
    });
    page.on('response', (resp) => {
        const status = resp.status();
        if (status >= 400) {
            allFailures.push({
                route: page.url(),
                url: resp.url(),
                method: resp.request().method(),
                failure: `HTTP ${status}`,
                resourceType: resp.request().resourceType(),
            });
        }
    });

    for (const route of ROUTES) {
        const url = BASE + route;
        console.log(`\n--- visiting ${url} ---`);
        try {
            await page.goto(url, { waitUntil: 'networkidle', timeout: 30000 });
        } catch (e) {
            console.log(`  navigation: ${e.message.slice(0, 120)}`);
        }
        // Let any deferred fetches happen
        await page.waitForTimeout(2500);
    }

    // Try the search box
    try {
        await page.goto(BASE + '/', { waitUntil: 'networkidle', timeout: 20000 });
        const search = await page.$('input[placeholder*="Search"], input[type="search"]');
        if (search) {
            console.log('\n--- typing search query ---');
            await search.fill('daft punk');
            await page.waitForTimeout(3000);
        }
    } catch {
        /* ignore */
    }

    await browser.close();

    // Group + summarise
    const groupByPattern = (list, keyFn) => {
        const m = new Map();
        for (const item of list) {
            const k = keyFn(item);
            if (!m.has(k)) m.set(k, []);
            m.get(k).push(item);
        }
        return m;
    };

    const consoleByText = groupByPattern(allConsole, (e) => e.text.slice(0, 160));
    const failuresByHost = groupByPattern(allFailures, (f) => {
        try {
            return new URL(f.url).host + ' ' + f.failure;
        } catch {
            return f.url.slice(0, 80) + ' ' + f.failure;
        }
    });

    console.log('\n========================================');
    console.log('CONSOLE ERRORS / WARNINGS (grouped, top 25)');
    console.log('========================================');
    const consoleSorted = [...consoleByText.entries()].sort((a, b) => b[1].length - a[1].length);
    for (const [text, items] of consoleSorted.slice(0, 25)) {
        const noise = isKnownNoise(text) ? '  [known noise]' : '';
        console.log(`\n[${items[0].type} ×${items.length}]${noise}`);
        console.log(`  ${text}`);
        const routes = [...new Set(items.map((i) => new URL(i.route).pathname))];
        console.log(`  on: ${routes.join(', ')}`);
    }

    console.log('\n========================================');
    console.log('NETWORK FAILURES (grouped by host+status)');
    console.log('========================================');
    const failSorted = [...failuresByHost.entries()].sort((a, b) => b[1].length - a[1].length);
    for (const [key, items] of failSorted) {
        const noise = isKnownNoise(key) ? '  [known noise]' : '';
        console.log(`\n×${items.length}  ${key}${noise}`);
        const routes = [...new Set(items.map((i) => new URL(i.route).pathname))];
        console.log(`  on: ${routes.join(', ')}`);
        const sample = items[0].url;
        if (sample.length < 200) console.log(`  sample: ${sample}`);
    }

    console.log('\n========================================');
    console.log(
        `TOTAL: console errors+warnings = ${allConsole.length}, network failures = ${allFailures.length}`
    );
    console.log('========================================');
})();
