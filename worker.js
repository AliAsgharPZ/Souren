// Worker سورن: بک‌اند پروژه روی Cloudflare —
//  • GET  /api/dictionary   خواندن دیکشنری زنده از گیت‌هاب
//  • POST /api/upload       آپلود پنل ادمین (توکن گیت‌هاب فقط Secret این‌جاست)
//  • /api/auth/*            ورود و پروفایل کاربران — رایگان، روی Workers KV
// سایت روی Cloudflare Pages میزبانی می‌شود؛ این ورکر فقط API است.
// Binding لازم: KV namespace با نام متغیر USERS و Secret به نام GITHUB_TOKEN.
const GH_USER = 'AliAsgharPZ';
const GH_REPO = 'Souren';
const GH_BRANCH = 'main';
const ALLOWED_FILES = new Set(['dictionary.json', 'admins.json']);
const SESSION_COOKIE = 'souren_session';
const SESSION_TTL = 60 * 60 * 24 * 30; // ۳۰ روز

// ---------- CORS (سایت روی pages.dev است، API روی workers.dev) ----------
function allowedOrigin(request) {
    const origin = request.headers.get('Origin') || '';
    try {
        const host = new URL(origin).hostname;
        if (host === 'souren.pages.dev' || host.endsWith('.souren.pages.dev')) return origin;
        if (host === 'souren.aliasgharpanahizare.workers.dev') return origin;
        if (host === 'localhost' || host === '127.0.0.1') return origin;
    } catch { /* ignore */ }
    return null;
}

function corsHeaders(request) {
    const origin = allowedOrigin(request);
    if (!origin) return {};
    return {
        'Access-Control-Allow-Origin': origin,
        'Access-Control-Allow-Credentials': 'true',
        'Access-Control-Allow-Methods': 'GET, POST, PUT, OPTIONS',
        'Access-Control-Allow-Headers': 'Content-Type',
        'Vary': 'Origin',
    };
}

function json(request, obj, status = 200, extra = {}) {
    return new Response(JSON.stringify(obj), {
        status,
        headers: {
            'Content-Type': 'application/json',
            ...corsHeaders(request),
            ...extra,
        },
    });
}

// ---------- GitHub helpers ----------
function gh(env, path, options = {}) {
    return fetch(`https://api.github.com/repos/${GH_USER}/${GH_REPO}/contents/${path}`, {
        ...options,
        headers: {
            'Authorization': `Bearer ${env.GITHUB_TOKEN}`,
            'Accept': 'application/vnd.github+json',
            'User-Agent': 'souren-worker',
            ...(options.headers || {}),
        },
    });
}

function b64encodeUtf8(str) {
    const bytes = new TextEncoder().encode(str);
    let bin = '';
    bytes.forEach((b) => { bin += String.fromCharCode(b); });
    return btoa(bin);
}

function b64decodeUtf8(b64) {
    const bin = atob(String(b64).replace(/\s/g, ''));
    const bytes = Uint8Array.from(bin, (c) => c.charCodeAt(0));
    return new TextDecoder().decode(bytes);
}

// ---------- Admin upload (از نسخهٔ اول، بدون تغییر رفتار) ----------
async function isAdmin(env, username, password) {
    const res = await gh(env, 'admins.json');
    if (!res.ok) return false;
    const file = await res.json();
    const data = JSON.parse(b64decodeUtf8(file.content));
    return (data.admins || []).some((a) => a.username === username && a.password === password);
}

async function handleUpload(request, env) {
    if (request.method !== 'POST') return json(request, { success: false, error: 'method_not_allowed' }, 405);
    if (!env.GITHUB_TOKEN) return json(request, { success: false, error: 'server_token_missing' }, 500);

    let body;
    try {
        body = await request.json();
    } catch {
        return json(request, { success: false, error: 'bad_json' }, 400);
    }

    const { filename, data, username, password } = body || {};
    if (!ALLOWED_FILES.has(filename)) return json(request, { success: false, error: 'file_not_allowed' }, 403);
    if (!username || !password || !(await isAdmin(env, username, password))) {
        return json(request, { success: false, error: 'unauthorized' }, 401);
    }

    let sha = null;
    const check = await gh(env, filename);
    if (check.ok) sha = (await check.json()).sha;

    const putBody = {
        message: `آپدیت ${filename} - ${new Date().toLocaleString('fa-IR')}`,
        content: b64encodeUtf8(JSON.stringify(data, null, 2)),
        branch: GH_BRANCH,
    };
    if (sha) putBody.sha = sha;

    const put = await gh(env, filename, {
        method: 'PUT',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(putBody),
    });
    if (!put.ok) {
        const err = await put.json().catch(() => ({}));
        return json(request, { success: false, error: err.message || 'github_error' }, 502);
    }
    return json(request, { success: true });
}

// ---------- Dictionary (منبع زنده: همان فایلی که ادمین آپدیت می‌کند) ----------
async function handleDictionary(request, env) {
    if (!env.GITHUB_TOKEN) return json(request, { error: 'server_token_missing' }, 500);
    const res = await gh(env, 'dictionary.json');
    if (!res.ok) return json(request, { error: 'dictionary_unavailable' }, 502);
    const file = await res.json();
    const text = b64decodeUtf8(file.content);
    return new Response(text, {
        status: 200,
        headers: {
            'Content-Type': 'application/json',
            'Cache-Control': 'public, max-age=300',
            ...corsHeaders(request),
        },
    });
}

// ---------- Auth (KV) — هش PBKDF2 و نشست تصادفی ----------
function b64(bytes) {
    let bin = '';
    new Uint8Array(bytes).forEach((b) => { bin += String.fromCharCode(b); });
    return btoa(bin);
}

function unb64(s) {
    const bin = atob(s);
    return Uint8Array.from(bin, (c) => c.charCodeAt(0));
}

async function hashPassword(password, saltB64) {
    const key = await crypto.subtle.importKey(
        'raw', new TextEncoder().encode(password), 'PBKDF2', false, ['deriveBits']);
    const bits = await crypto.subtle.deriveBits(
        { name: 'PBKDF2', salt: unb64(saltB64), iterations: 60000, hash: 'SHA-256' },
        key, 256);
    return b64(bits);
}

function randomToken() {
    const bytes = new Uint8Array(32);
    crypto.getRandomValues(bytes);
    return [...bytes].map((b) => b.toString(16).padStart(2, '0')).join('');
}

function validUsername(u) {
    return typeof u === 'string' && u.length >= 3 && u.length <= 24 && !/\s/.test(u);
}

function publicUser(rec) {
    return { username: rec.username, displayName: rec.displayName || rec.username, favorites: rec.favorites || [], likes: rec.likes || [] };
}

async function getSessionUser(request, env) {
    const cookie = request.headers.get('Cookie') || '';
    const m = cookie.match(new RegExp(`${SESSION_COOKIE}=([0-9a-f]{64})`));
    if (!m) return null;
    const data = await env.USERS.get(`sess:${m[1]}`, 'json');
    if (!data || !data.username) return null;
    const rec = await env.USERS.get(`user:${data.username}`, 'json');
    return rec ? { token: m[1], rec } : null;
}

function sessionCookie(token, maxAge) {
    return `${SESSION_COOKIE}=${token}; Path=/; HttpOnly; Secure; SameSite=None; Max-Age=${maxAge}`;
}

async function handleRegister(request, env) {
  try { return await registerInner(request, env); }
  catch (e) { return json(request, { error: 'server_error', detail: String((e && e.message) || e) }, 500); }
}

async function registerInner(request, env) {
    let body;
    try { body = await request.json(); } catch { return json(request, { error: 'درخواست نامعتبر است' }, 400); }
    const username = (body.username || '').trim();
    const password = body.password || '';
    const displayName = (body.displayName || '').trim() || username;
    if (!validUsername(username)) return json(request, { error: 'نام کاربری باید ۳ تا ۲۴ نویسه و بدون فاصله باشد' }, 400);
    if (typeof password !== 'string' || password.length < 6) {
        return json(request, { error: 'گذرواژه باید دست‌کم ۶ نویسه باشد' }, 400);
    }
    const key = `user:${username}`;
    if (await env.USERS.get(key)) return json(request, { error: 'این نام کاربری گرفته شده است' }, 409);
    const salt = b64(crypto.getRandomValues(new Uint8Array(16)));
    const rec = {
        username,
        displayName,
        salt,
        pw: await hashPassword(password, salt),
        favorites: [],
        likes: [],
        createdAt: Date.now(),
    };
    await env.USERS.put(key, JSON.stringify(rec));
    return json(request, { user: publicUser(rec) }, 201);
}

async function handleLogin(request, env) {
  try { return await loginInner(request, env); }
  catch (e) { return json(request, { error: 'server_error', detail: String((e && e.message) || e) }, 500); }
}

async function loginInner(request, env) {
    let body;
    try { body = await request.json(); } catch { return json(request, { error: 'درخواست نامعتبر است' }, 400); }
    const username = (body.username || '').trim();
    const password = body.password || '';
    const rec = await env.USERS.get(`user:${username}`, 'json');
    if (!rec) return json(request, { error: 'نام کاربری یا گذرواژه نادرست است' }, 401);
    const hash = await hashPassword(password, rec.salt);
    if (hash !== rec.pw) return json(request, { error: 'نام کاربری یا گذرواژه نادرست است' }, 401);
    const token = randomToken();
    await env.USERS.put(`sess:${token}`, JSON.stringify({ username }), { expirationTtl: SESSION_TTL });
    return json(request, { user: publicUser(rec) }, 200, { 'Set-Cookie': sessionCookie(token, SESSION_TTL) });
}

async function handleLogout(request, env) {
    const s = await getSessionUser(request, env);
    if (s) await env.USERS.delete(`sess:${s.token}`);
    return json(request, {}, 200, { 'Set-Cookie': sessionCookie('', 0) });
}

async function handleMe(request, env) {
    const s = await getSessionUser(request, env);
    if (!s) return json(request, { error: 'وارد نشده‌اید' }, 401);
    return json(request, { user: publicUser(s.rec) });
}

async function handleProfile(request, env) {
    const s = await getSessionUser(request, env);
    if (!s) return json(request, { error: 'وارد نشده‌اید' }, 401);
    let body;
    try { body = await request.json(); } catch { return json(request, { error: 'درخواست نامعتبر است' }, 400); }
    if (typeof body.displayName === 'string' && body.displayName.trim()) {
        s.rec.displayName = body.displayName.trim().slice(0, 40);
    }
    if (Array.isArray(body.favorites)) {
        s.rec.favorites = body.favorites.filter((f) => typeof f === 'string').slice(0, 500);
    }
    if (Array.isArray(body.likes)) {
        s.rec.likes = body.likes.filter((f) => typeof f === 'string').slice(0, 500);
    }
    await env.USERS.put(`user:${s.rec.username}`, JSON.stringify(s.rec));
    return json(request, { user: publicUser(s.rec) });
}

// ---------- Likes (شمارندهٔ همگانی پسندها) ----------
async function handleLikeCounts(request, env) {
    const counts = (await env.USERS.get('likes:counts', 'json')) || {};
    return new Response(JSON.stringify({ counts }), {
        status: 200,
        headers: { 'Content-Type': 'application/json', 'Cache-Control': 'public, max-age=60', ...corsHeaders(request) },
    });
}

async function handleLike(request, env) {
    const s = await getSessionUser(request, env);
    if (!s) return json(request, { error: 'وارد نشده‌اید' }, 401);
    let body;
    try { body = await request.json(); } catch { return json(request, { error: 'درخواست نامعتبر است' }, 400); }
    const ar = typeof body.ar === 'string' ? body.ar.trim() : '';
    if (!ar || ar.length > 60) return json(request, { error: 'واژه نامعتبر است' }, 400);
    const want = body.liked === true;
    const likes = new Set(s.rec.likes || []);
    const has = likes.has(ar);
    const counts = (await env.USERS.get('likes:counts', 'json')) || {};
    let count = counts[ar] || 0;
    if (want && !has) { likes.add(ar); count += 1; }
    if (!want && has) { likes.delete(ar); count = Math.max(0, count - 1); }
    counts[ar] = count;
    s.rec.likes = [...likes];
    await env.USERS.put(`user:${s.rec.username}`, JSON.stringify(s.rec));
    await env.USERS.put('likes:counts', JSON.stringify(counts));
    return json(request, { ar, count, likes: s.rec.likes });
}

// ---------- Router ----------
export default {
    async fetch(request, env) {
        const url = new URL(request.url);
        if (request.method === 'OPTIONS' && url.pathname.startsWith('/api/')) {
            return new Response(null, { status: 204, headers: corsHeaders(request) });
        }
        switch (url.pathname) {
            case '/api/upload': return handleUpload(request, env);
            case '/api/dictionary': return handleDictionary(request, env);
            case '/api/auth/register': return handleRegister(request, env);
            case '/api/auth/login': return handleLogin(request, env);
            case '/api/auth/logout': return handleLogout(request, env);
            case '/api/auth/me': return handleMe(request, env);
            case '/api/auth/profile': return handleProfile(request, env);
            case '/api/likes': return request.method === 'POST' ? handleLike(request, env) : handleLikeCounts(request, env);
            default: break;
        }
        if (env.ASSETS) return env.ASSETS.fetch(request);
        return json(request, { error: 'not_found' }, 404);
    },
};
