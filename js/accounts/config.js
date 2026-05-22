// js/accounts/config.js
import { createAuthClient } from 'https://esm.sh/better-auth/client';

const getBaseURL = () => {
    const local =
        localStorage.getItem('bayflix-auth-url') ||
        localStorage.getItem('monochrome-auth-url');
    if (local) return local;

    if (window.__AUTH_URL__) return window.__AUTH_URL__;

    // Bayflix prod everywhere. Localhost dev still uses prod auth so OAuth
    // returnTo works without redirect-URI gymnastics.
    return 'https://auth.bayflix.ms';
};

export const authClient = createAuthClient({
    baseURL: getBaseURL(),
});

export { authClient as auth };
