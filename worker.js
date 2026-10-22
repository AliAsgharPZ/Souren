// Worker سورن: سرو فایل‌های استاتیک + مسیر آپلود پنل ادمین.
// توکن گیت‌هاب فقط همین‌جا، به‌صورت Secret (GITHUB_TOKEN) نگه‌داری می‌شود و هرگز به مرورگر نمی‌رسد.
const GH_USER = 'AliAsgharPZ';
const GH_REPO = 'Souren';
const GH_BRANCH = 'main';
const ALLOWED_FILES = new Set(['dictionary.json', 'admins.json']);

function json(obj, status = 200) {
    return new Response(JSON.stringify(obj), {
        status,
        headers: { 'Content-Type': 'application/json' },
    });
}

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

async function isAdmin(env, username, password) {
    const res = await gh(env, 'admins.json');
    if (!res.ok) return false;
    const file = await res.json();
    const data = JSON.parse(b64decodeUtf8(file.content));
    return (data.admins || []).some((a) => a.username === username && a.password === password);
}

async function handleUpload(request, env) {
    if (request.method !== 'POST') return json({ success: false, error: 'method_not_allowed' }, 405);
    if (!env.GITHUB_TOKEN) return json({ success: false, error: 'server_token_missing' }, 500);

    let body;
    try {
        body = await request.json();
    } catch {
        return json({ success: false, error: 'bad_json' }, 400);
    }

    const { filename, data, username, password } = body || {};
    if (!ALLOWED_FILES.has(filename)) return json({ success: false, error: 'file_not_allowed' }, 403);
    if (!username || !password || !(await isAdmin(env, username, password))) {
        return json({ success: false, error: 'unauthorized' }, 401);
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
        return json({ success: false, error: err.message || 'github_error' }, 502);
    }
    return json({ success: true });
}

export default {
    async fetch(request, env) {
        const url = new URL(request.url);
        if (url.pathname === '/api/upload') return handleUpload(request, env);
        return env.ASSETS.fetch(request);
    },
};
