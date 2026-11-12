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

// ---------- Email OTP (Gmail API + Workers KV) ----------
function normalizeEmail(value) {
    return typeof value === 'string' ? value.trim().toLowerCase() : '';
}

function validEmail(value) {
    return value.length <= 254 && /^[^\s@]+@[^\s@]+\.[^\s@]{2,}$/.test(value);
}

function base64Bytes(bytes) {
    let binary = '';
    for (const byte of bytes) binary += String.fromCharCode(byte);
    return btoa(binary);
}

function base64UrlUtf8(value) {
    return base64Bytes(new TextEncoder().encode(value))
        .replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/g, '');
}

function wrapBase64(value) {
    return value.match(/.{1,76}/g)?.join('\r\n') || '';
}

function encodeMimeHeader(value) {
    const bytes = new TextEncoder().encode(value);
    return `=?UTF-8?B?${base64Bytes(bytes)}?=`;
}

async function getGmailAccessToken(env) {
    if (!env.GMAIL_CLIENT_ID || !env.GMAIL_CLIENT_SECRET || !env.GMAIL_REFRESH_TOKEN) {
        throw new Error('gmail_oauth_not_configured');
    }
    const form = new URLSearchParams({
        client_id: env.GMAIL_CLIENT_ID,
        client_secret: env.GMAIL_CLIENT_SECRET,
        refresh_token: env.GMAIL_REFRESH_TOKEN,
        grant_type: 'refresh_token',
    });
    const response = await fetch('https://oauth2.googleapis.com/token', {
        method: 'POST',
        headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
        body: form.toString(),
    });
    const payload = await response.json().catch(() => ({}));
    if (!response.ok || typeof payload.access_token !== 'string') {
        throw new Error(`gmail_token_exchange_failed_${response.status}`);
    }
    return payload.access_token;
}

async function sendOtpEmail(env, to, subject, code) {
    if (!env.EMAIL_FROM) throw new Error('email_from_not_configured');
    const accessToken = await getGmailAccessToken(env);
    const safeCode = String(code).replace(/[^0-9]/g, '');
    const html = `<!doctype html>
<html lang="fa" dir="rtl">
<head><meta charset="UTF-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>${subject}</title></head>
<body style="margin:0;padding:32px 12px;background:#f7f1e3;font-family:Tahoma,Arial,sans-serif;color:#2b2620">
<table role="presentation" width="100%" cellspacing="0" cellpadding="0" style="max-width:560px;margin:0 auto;background:#fffdf7;border:1px solid #e2d8c2;border-radius:28px;overflow:hidden">
<tr><td style="padding:30px 28px 22px;text-align:center;background:#2b2620">
<div style="display:inline-block;padding:9px 22px;border:1px solid #766d5e;border-radius:22px;color:#f7f1e3;font-size:24px;font-weight:800;letter-spacing:-1px">سورن</div>
<p style="margin:12px 0 0;color:#d7cbb2;font-size:12px">واژه‌ها، یادگیری و نوشتار فارسی</p>
</td></tr>
<tr><td style="padding:34px 28px 30px;text-align:center">
<h1 style="margin:0 0 12px;font-size:21px;line-height:1.7;color:#2b2620">${subject}</h1>
<p style="margin:0 0 24px;font-size:14px;line-height:2;color:#746b5d">برای ادامهٔ کار در سورن، کد زیر را در برنامه یا وب‌سایت وارد کنید.</p>
<div style="display:inline-block;min-width:220px;padding:18px 24px;border-radius:18px;background:#efe7d4;border:1px solid #e2d8c2;color:#2b2620;font-size:34px;font-weight:800;letter-spacing:9px;direction:ltr">${safeCode}</div>
<p style="margin:18px 0 0;color:#8a8172;font-size:12px">این کد تا ۱۰ دقیقه معتبر است.</p>
<div style="height:1px;background:#e8dfcd;margin:28px 0 18px"></div>
<p style="margin:0;color:#8a8172;font-size:12px;line-height:2">اگر این درخواست از طرف شما نبوده، این پیام را نادیده بگیرید. برای امنیت حساب، این کد را با هیچ‌کس به اشتراک نگذارید.</p>
</td></tr>
<tr><td style="padding:16px 20px;text-align:center;background:#efe7d4;color:#8a8172;font-size:11px">سورن · همراه نوشتار و یادگیری شما</td></tr>
</table>
</body></html>`;
    const plain = `کد یک‌بارمصرف سورن: ${safeCode}
این کد تا ۱۰ دقیقه معتبر است. اگر این درخواست از طرف شما نبوده، این پیام را نادیده بگیرید.`;
    const mime = [
        `From: ${env.EMAIL_FROM}`,
        `To: ${to}`,
        `Subject: ${encodeMimeHeader(subject)}`,
        'MIME-Version: 1.0',
        'Content-Type: multipart/alternative; boundary="souren-otp-boundary"',
        '',
        '--souren-otp-boundary',
        'Content-Type: text/plain; charset=UTF-8',
        'Content-Transfer-Encoding: base64',
        '',
        wrapBase64(base64Bytes(new TextEncoder().encode(plain))),
        '--souren-otp-boundary',
        'Content-Type: text/html; charset=UTF-8',
        'Content-Transfer-Encoding: base64',
        '',
        wrapBase64(base64Bytes(new TextEncoder().encode(html))),
        '--souren-otp-boundary--',
        '',
    ].join('\\r\\n');
    const response = await fetch('https://gmail.googleapis.com/gmail/v1/users/me/messages/send', {
        method: 'POST',
        headers: {
            'Authorization': `Bearer ${accessToken}`,
            'Content-Type': 'application/json',
        },
        body: JSON.stringify({ raw: base64UrlUtf8(mime) }),
    });
    if (!response.ok) throw new Error(`gmail_send_failed_${response.status}`);
}

async function handleRequestOtp(request, env) {
    let body;
    try { body = await request.json(); }
    catch { return json(request, { error: 'درخواست نامعتبر است' }, 400); }

    const email = normalizeEmail(body.email);
    const purpose = ['register', 'login', 'link', 'reset'].includes(body.purpose)
        ? body.purpose : 'register';
    if (!validEmail(email)) return json(request, { error: 'نشانی ایمیل معتبر نیست' }, 400);
    if (!env.GMAIL_CLIENT_ID || !env.GMAIL_CLIENT_SECRET || !env.GMAIL_REFRESH_TOKEN || !env.EMAIL_FROM) {
        return json(request, { error: 'email_service_not_configured' }, 503);
    }

    let session = null;
    if (purpose === 'link') {
        session = await getSessionUser(request, env);
        if (!session) return json(request, { error: 'وارد نشده‌اید' }, 401);
    }
    if (purpose === 'reset') {
        const username = await env.USERS.get(`email:${email}`);
        const user = username ? await env.USERS.get(`user:${username}`, 'json') : null;
        if (!user || user.email !== email || user.emailVerified !== true) {
            return json(request, { error: 'حسابی با این ایمیل تأییدشده پیدا نشد' }, 404);
        }
    }
    if (purpose === 'register' && await env.USERS.get(`email:${email}`)) {
        return json(request, { error: 'این ایمیل قبلاً به یک حساب متصل شده است' }, 409);
    }
    if (purpose === 'link') {
        const owner = await env.USERS.get(`email:${email}`);
        if (owner && owner !== session.rec.username) {
            return json(request, { error: 'این ایمیل به حساب دیگری متصل است' }, 409);
        }
    }

    const rateKey = `otp:rate:${purpose}:${email}`;
    if (await env.USERS.get(rateKey)) {
        return json(request, { error: 'برای ارسال کد جدید کمی صبر کنید' }, 429);
    }
    await env.USERS.put(rateKey, '1', { expirationTtl: 60 });

    const code = String(crypto.getRandomValues(new Uint32Array(1))[0] % 1000000).padStart(6, '0');
    const salt = b64(crypto.getRandomValues(new Uint8Array(16)));
    const codeHash = await hashPassword(code, salt);
    const otpKey = `otp:${purpose}:${email}`;
    await env.USERS.put(otpKey, JSON.stringify({
        salt,
        codeHash,
        username: purpose === 'link' ? session.rec.username : null,
        createdAt: Date.now(),
    }), { expirationTtl: 600 });
    await env.USERS.delete(`otp:attempt:${purpose}:${email}`);

    const subject = purpose === 'login'
        ? 'کد ورود به سورن'
        : purpose === 'register' ? 'تأیید ایمیل برای ساخت حساب سورن'
        : purpose === 'reset' ? 'کد بازیابی گذرواژهٔ سورن' : 'تأیید ایمیل حساب سورن';
    try {
        await sendOtpEmail(env, email, subject, code);
    } catch (error) {
        await env.USERS.delete(otpKey);
        await env.USERS.delete(rateKey);
        const reason = String(error?.message || error);
        return json(request, {
            error: reason === 'gmail_oauth_not_configured' || reason === 'email_from_not_configured'
                ? 'email_service_not_configured'
                : 'ارسال ایمیل انجام نشد؛ اتصال Gmail API را بررسی کنید',
        }, 502);
    }
    return json(request, { success: true, message: 'کد تأیید ارسال شد' });
}

async function handleVerifyOtp(request, env) {
    let body;
    try { body = await request.json(); }
    catch { return json(request, { error: 'درخواست نامعتبر است' }, 400); }
    const email = normalizeEmail(body.email);
    const purpose = ['register', 'login', 'link', 'reset'].includes(body.purpose)
        ? body.purpose : 'login';
    const code = typeof body.code === 'string' ? body.code.trim() : '';
    if (!validEmail(email) || !/^\d{6}$/.test(code)) {
        return json(request, { error: 'ایمیل یا کد تأیید نامعتبر است' }, 400);
    }

    const otpKey = `otp:${purpose}:${email}`;
    const attemptKey = `otp:attempt:${purpose}:${email}`;
    const record = await env.USERS.get(otpKey, 'json');
    if (!record || Date.now() - Number(record.createdAt || 0) > 10 * 60 * 1000) {
        return json(request, { error: 'کد تأیید منقضی شده است؛ کد تازه بگیرید' }, 400);
    }
    const attempts = Number(await env.USERS.get(attemptKey) || 0);
    if (attempts >= 5) {
        await env.USERS.delete(otpKey);
        return json(request, { error: 'تعداد تلاش‌ها بیش از حد مجاز است؛ کد تازه بگیرید' }, 429);
    }
    await env.USERS.put(attemptKey, String(attempts + 1), { expirationTtl: 600 });
    const candidate = await hashPassword(code, record.salt);
    if (candidate !== record.codeHash) {
        if (attempts + 1 >= 5) await env.USERS.delete(otpKey);
        return json(request, { error: 'کد تأیید نادرست است' }, 401);
    }
    await env.USERS.delete(otpKey);
    await env.USERS.delete(attemptKey);

    if (purpose === 'register') {
        if (await env.USERS.get(`email:${email}`)) {
            return json(request, { error: 'این ایمیل قبلاً استفاده شده است' }, 409);
        }
        const verificationToken = randomToken();
        await env.USERS.put(`email-verified:${verificationToken}`, JSON.stringify({ email }), { expirationTtl: 900 });
        return json(request, { success: true, verificationToken });
    }

    if (purpose === 'reset') {
        const username = await env.USERS.get(`email:${email}`);
        const user = username ? await env.USERS.get(`user:${username}`, 'json') : null;
        if (!user || user.email !== email || user.emailVerified !== true) {
            return json(request, { error: 'حسابی با این ایمیل تأییدشده پیدا نشد' }, 404);
        }
        const resetToken = randomToken();
        await env.USERS.put(`password-reset:${resetToken}`, JSON.stringify({ username, email }), { expirationTtl: 900 });
        return json(request, { success: true, passwordResetToken: resetToken });
    }

    if (purpose === 'link') {
        const session = await getSessionUser(request, env);
        if (!session || session.rec.username !== record.username) {
            return json(request, { error: 'نشست حساب معتبر نیست' }, 401);
        }
        const owner = await env.USERS.get(`email:${email}`);
        if (owner && owner !== session.rec.username) {
            return json(request, { error: 'این ایمیل به حساب دیگری متصل است' }, 409);
        }
        if (session.rec.email && session.rec.email !== email) {
            await env.USERS.delete(`email:${session.rec.email}`);
        }
        session.rec.email = email;
        session.rec.emailVerified = true;
        await env.USERS.put(`user:${session.rec.username}`, JSON.stringify(session.rec));
        await env.USERS.put(`email:${email}`, session.rec.username);
        return json(request, { success: true, user: publicUser(session.rec) });
    }

    const username = await env.USERS.get(`email:${email}`);
    const user = username ? await env.USERS.get(`user:${username}`, 'json') : null;
    if (!user || user.email !== email || user.emailVerified !== true) {
        return json(request, { error: 'حسابی با این ایمیل تأییدشده پیدا نشد' }, 404);
    }
    const token = randomToken();
    await env.USERS.put(`sess:${token}`, JSON.stringify({ username }), { expirationTtl: SESSION_TTL });
    return json(request, { user: publicUser(user) }, 200, { 'Set-Cookie': sessionCookie(token, SESSION_TTL) });
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
    return {
        username: rec.username,
        displayName: rec.displayName || rec.username,
        email: rec.email || null,
        emailVerified: rec.emailVerified === true,
        favorites: rec.favorites || [],
        likes: rec.likes || [],
        passwordSetupRequired: rec.passwordSetupRequired === true,
    };
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
    return `${SESSION_COOKIE}=${token}; Path=/; HttpOnly; Secure; SameSite=None; Partitioned; Max-Age=${maxAge}`;
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
    const email = normalizeEmail(body.email);
    const verificationToken = typeof body.emailVerificationToken === 'string'
        ? body.emailVerificationToken : '';
    if (!validUsername(username)) return json(request, { error: 'نام کاربری باید ۳ تا ۲۴ نویسه و بدون فاصله باشد' }, 400);
    if (password && (typeof password !== 'string' || password.length < 6)) {
        return json(request, { error: 'گذرواژه باید دست‌کم ۶ نویسه باشد' }, 400);
    }
    if (!validEmail(email) || !verificationToken) {
        return json(request, { error: 'ابتدا ایمیل خود را با کد یک‌بارمصرف تأیید کنید' }, 400);
    }
    const verified = await env.USERS.get(`email-verified:${verificationToken}`, 'json');
    if (!verified || verified.email !== email) {
        return json(request, { error: 'تأیید ایمیل معتبر نیست؛ دوباره کد بگیرید' }, 401);
    }
    const key = `user:${username}`;
    if (await env.USERS.get(key)) return json(request, { error: 'این نام کاربری گرفته شده است' }, 409);
    if (await env.USERS.get(`email:${email}`)) return json(request, { error: 'این ایمیل قبلاً استفاده شده است' }, 409);
    const salt = b64(crypto.getRandomValues(new Uint8Array(16)));
    // New OTP registrations receive a random undisclosed password. They set
    // their own password later through the dedicated email recovery flow.
    const initialPassword = password || randomToken();
    const rec = {
        username,
        displayName,
        email,
        emailVerified: true,
        salt,
        pw: await hashPassword(initialPassword, salt),
        favorites: [],
        likes: [],
        createdAt: Date.now(),
        passwordSetupRequired: !password,
    };
    await env.USERS.put(key, JSON.stringify(rec));
    await env.USERS.put(`email:${email}`, username);
    await env.USERS.delete(`email-verified:${verificationToken}`);
    const token = randomToken();
    await env.USERS.put(`sess:${token}`, JSON.stringify({ username }), { expirationTtl: SESSION_TTL });
    return json(request, { user: publicUser(rec), passwordSetupRequired: !password }, 201,
        { 'Set-Cookie': sessionCookie(token, SESSION_TTL) });
}

async function handlePasswordReset(request, env) {
    let body;
    try { body = await request.json(); } catch { return json(request, { error: 'درخواست نامعتبر است' }, 400); }
    const email = normalizeEmail(body.email);
    const token = typeof body.passwordResetToken === 'string' ? body.passwordResetToken : '';
    const password = typeof body.password === 'string' ? body.password : '';
    if (!validEmail(email) || !token || password.length < 6 || password.length > 256) {
        return json(request, { error: 'ایمیل، کد بازیابی یا گذرواژه نامعتبر است' }, 400);
    }
    const verified = await env.USERS.get(`password-reset:${token}`, 'json');
    if (!verified || verified.email !== email) {
        return json(request, { error: 'مهلت بازیابی پایان یافته است؛ دوباره کد بگیرید' }, 401);
    }
    const rec = await env.USERS.get(`user:${verified.username}`, 'json');
    if (!rec || rec.email !== email) {
        await env.USERS.delete(`password-reset:${token}`);
        return json(request, { error: 'حساب کاربری پیدا نشد' }, 404);
    }
    const salt = b64(crypto.getRandomValues(new Uint8Array(16)));
    rec.salt = salt;
    rec.pw = await hashPassword(password, salt);
    delete rec.passwordSetupRequired;
    await env.USERS.put(`user:${verified.username}`, JSON.stringify(rec));
    await env.USERS.delete(`password-reset:${token}`);
    return json(request, { success: true, message: 'گذرواژه با موفقیت تغییر کرد' });
}

async function handleLogin(request, env) {
  try { return await loginInner(request, env); }
  catch (e) { return json(request, { error: 'server_error', detail: String((e && e.message) || e) }, 500); }
}

async function loginInner(request, env) {
    let body;
    try { body = await request.json(); } catch { return json(request, { error: 'درخواست نامعتبر است' }, 400); }
    const identifier = (body.username || body.email || '').trim();
    const password = body.password || '';
    const username = identifier.includes('@')
        ? await env.USERS.get(`email:${normalizeEmail(identifier)}`)
        : identifier;
    const rec = username ? await env.USERS.get(`user:${username}`, 'json') : null;
    if (!rec || typeof password !== 'string' || !password) {
        return json(request, { error: 'نام کاربری، ایمیل یا گذرواژه نادرست است' }, 401);
    }
    const hash = await hashPassword(password, rec.salt);
    if (hash !== rec.pw) return json(request, { error: 'نام کاربری، ایمیل یا گذرواژه نادرست است' }, 401);
    const token = randomToken();
    await env.USERS.put(`sess:${token}`, JSON.stringify({ username }), { expirationTtl: SESSION_TTL });
    return json(request, { user: publicUser(rec), passwordSetupRequired: rec.passwordSetupRequired === true }, 200,
        { 'Set-Cookie': sessionCookie(token, SESSION_TTL) });
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

async function handleLearningModel(request, env) {
    const cacheKey = new Request(new URL('/api/learning/model', request.url).toString());
    const cached = await caches.default.match(cacheKey);
    if (cached) return cached;

    const listed = await env.USERS.list({ prefix: 'learning:v1:', limit: 1000 });
    const pairs = [];
    for (const item of listed.keys) {
        const record = await env.USERS.get(item.name, 'json');
        if (!record || Number(record.count) < 3) continue;
        pairs.push({
            from: record.from,
            left: record.left || '',
            right: record.right || '',
            to: record.to,
            count: Number(record.count),
        });
    }
    pairs.sort((a, b) => b.count - a.count);
    const response = json(request, {
        version: 1,
        pairs: pairs.slice(0, 500),
    }, 200, {
        'Cache-Control': 'public, max-age=600',
        'Access-Control-Allow-Origin': '*',
    });
    await caches.default.put(cacheKey, response.clone());
    return response;
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
            case '/api/auth/request-otp': return request.method === 'POST'
                ? handleRequestOtp(request, env) : methodNotAllowed();
            case '/api/auth/verify-otp': return request.method === 'POST'
                ? handleVerifyOtp(request, env) : methodNotAllowed();
            case '/api/auth/login': return request.method === 'POST'
                ? handleLogin(request, env) : methodNotAllowed();
            case '/api/auth/reset-password': return request.method === 'POST'
                ? handlePasswordReset(request, env) : methodNotAllowed();
            case '/api/auth/logout': return request.method === 'POST'
                ? handleLogout(request, env) : methodNotAllowed();
            case '/api/auth/me': return request.method === 'GET'
                ? handleMe(request, env) : methodNotAllowed();
            case '/api/auth/profile': return request.method === 'PUT'
                ? handleProfile(request, env) : methodNotAllowed();
            case '/api/likes': return request.method === 'POST'
                ? handleLike(request, env) : methodNotAllowed();
            case '/api/learning/model': return request.method === 'GET'
                ? handleLearningModel(request, env) : methodNotAllowed();
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
