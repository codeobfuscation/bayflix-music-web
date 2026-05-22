import { betterAuth } from 'better-auth';
import Database from 'better-sqlite3';
import { mkdirSync } from 'node:fs';

mkdirSync('./data', { recursive: true });

export const ALLOWED_ORIGINS = new Set([
    'https://bayflix.ms',
    'https://www.bayflix.ms',
    'http://localhost:5173',
    'http://localhost:4173',
]);

export const auth = betterAuth({
    database: new Database('./data/auth.db'),
    secret: process.env.BETTER_AUTH_SECRET,
    baseURL: process.env.BETTER_AUTH_URL,
    emailAndPassword: {
        enabled: true,
        requireEmailVerification: false,
    },
    socialProviders: {
        google: {
            clientId: process.env.GOOGLE_CLIENT_ID,
            clientSecret: process.env.GOOGLE_CLIENT_SECRET,
        },
        discord: {
            clientId: process.env.DISCORD_CLIENT_ID,
            clientSecret: process.env.DISCORD_CLIENT_SECRET,
            scope: ['identify', 'email', 'guilds.join'],
        },
    },
    account: {
        accountLinking: {
            enabled: true,
            trustedProviders: ['google', 'discord', 'email-password'],
        },
    },
    trustedOrigins: Array.from(ALLOWED_ORIGINS),
    advanced: {
        // Cookies need the right domain so the SPA on bayflix.ms can see a
        // session set by auth.bayflix.ms. better-auth uses the configured
        // baseURL to derive the right cookie domain automatically when
        // crossSubDomainCookies.domain is omitted, so we leave it dynamic.
        crossSubDomainCookies: {
            enabled: true,
        },
        defaultCookieAttributes: {
            secure: true,
            sameSite: 'lax',
            httpOnly: true,
        },
    },
});
