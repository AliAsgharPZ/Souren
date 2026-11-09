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
            'Content-Type': 'application/json; charset=utf-8',
            'Cache-Control': 'no-store',
            'X-Content-Type-Options': 'nosniff',
            'Referrer-Policy': 'no-referrer',
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
        s.rec.favorites = [...new Set(body.favorites
            .filter((f) => typeof f === 'string' && f.trim().length > 0 && f.length <= 512)
            .map((f) => f.trim()))].slice(0, 5000);
    }
    if (Array.isArray(body.likes)) {
        s.rec.likes = [...new Set(body.likes
            .filter((f) => typeof f === 'string' && f.trim().length > 0 && f.length <= 512)
            .map((f) => f.trim()))].slice(0, 5000);
    }
    await env.USERS.put(`user:${s.rec.username}`, JSON.stringify(s.rec));
    return json(request, { user: publicUser(s.rec) });
}

// ---------- Likes (per-user only; no public/global counters) ----------
async function handleLike(request, env) {
    const s = await getSessionUser(request, env);
    if (!s) return json(request, { error: 'وارد نشده‌اید' }, 401);
    let body;
    try { body = await request.json(); }
    catch { return json(request, { error: 'درخواست نامعتبر است' }, 400); }

    const key = typeof body.key === 'string'
        ? body.key.trim()
        : (typeof body.ar === 'string' ? body.ar.trim() : '');
    if (!key || key.length > 512) {
        return json(request, { error: 'شناسهٔ محتوا نامعتبر است' }, 400);
    }

    const likes = new Set(Array.isArray(s.rec.likes) ? s.rec.likes : []);
    const liked = body.liked === true;
    if (liked) likes.add(key);
    else likes.delete(key);
    s.rec.likes = [...likes].slice(0, 5000);
    await env.USERS.put(`user:${s.rec.username}`, JSON.stringify(s.rec));
    return json(request, { key, liked, likes: s.rec.likes });
}

// ---------- Opt-in anonymous correction learning ----------
async function handleLearning(request, env) {
    const declaredLength = Number(request.headers.get('Content-Length') || 0);
    if (declaredLength > 32 * 1024) {
        return json(request, { error: 'payload_too_large' }, 413);
    }
    let body;
    try { body = await request.json(); }
    catch { return json(request, { error: 'bad_json' }, 400); }

    const samples = Array.isArray(body.samples) ? body.samples.slice(0, 20) : [];
    if (samples.length === 0) return json(request, { accepted: 0 });

    let accepted = 0;
    for (const sample of samples) {
        const clean = (value, max) => typeof value === 'string'
            ? value.trim().replace(/[\r\n\t]/g, ' ').slice(0, max)
            : '';
        const from = clean(sample.from, 48);
        const to = clean(sample.to, 64);
        const left = clean(sample.left, 48);
        const right = clean(sample.right, 48);
        if (!from || !to || from === to || / {2,}/.test(from) || / {2,}/.test(to)) continue;

        // Store only adjacent tokens and the user's selected equivalent.
        // No full sentence, account identifier, clipboard or IP address is kept.
        const canonical = [from, left, right, to].join('|');
        const digest = await crypto.subtle.digest(
            'SHA-256', new TextEncoder().encode(canonical));
        const hash = [...new Uint8Array(digest)]
            .map((b) => b.toString(16).padStart(2, '0')).join('');
        const key = `learning:v1:${hash}`;
        const previous = await env.USERS.get(key, 'json') || {
            from, left, right, to, count: 0,
        };
        previous.count = Math.min((Number(previous.count) || 0) + 1, 1000000);
        previous.updatedAt = Date.now();
        await env.USERS.put(key, JSON.stringify(previous));
        accepted++;
    }
    return json(request, { accepted });
}

// ---------- Router ----------
export default {
    async fetch(request, env) {
        const url = new URL(request.url);
        if (request.method === 'OPTIONS' && url.pathname.startsWith('/api/')) {
            return new Response(null, { status: 204, headers: corsHeaders(request) });
        }
        const methodNotAllowed = () =>
            json(request, { error: 'method_not_allowed' }, 405);
        switch (url.pathname) {
            case '/api/upload': return request.method === 'POST'
                ? handleUpload(request, env) : methodNotAllowed();
            case '/api/dictionary': return request.method === 'GET'
                ? handleDictionary(request, env) : methodNotAllowed();
            case '/api/auth/register': return request.method === 'POST'
                ? handleRegister(request, env) : methodNotAllowed();
            case '/api/auth/login': return request.method === 'POST'
                ? handleLogin(request, env) : methodNotAllowed();
            case '/api/auth/logout': return request.method === 'POST'
                ? handleLogout(request, env) : methodNotAllowed();
            case '/api/auth/me': return request.method === 'GET'
                ? handleMe(request, env) : methodNotAllowed();
            case '/api/auth/profile': return request.method === 'PUT'
                ? handleProfile(request, env) : methodNotAllowed();
            case '/api/likes': return request.method === 'POST'
                ? handleLike(request, env) : methodNotAllowed();
            case '/api/learning': return request.method === 'POST'
                ? handleLearning(request, env) : methodNotAllowed();
            case '/api/health': return request.method === 'GET'
                ? json(request, {
                    service: 'souren-worker',
                    apiVersion: 2,
                    status: 'ok',
                    timestamp: new Date().toISOString(),
                })
                : methodNotAllowed();
            default: break;
        }
        // سایت روی Pages میزبانی می‌شود؛ هر مسیر غیر API به همان مسیر در pages.dev ریدایرکت می‌شود.
        return Response.redirect('https://souren.pages.dev' + url.pathname + url.search, 301);
    },
};
