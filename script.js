// ===== سورن — اسکریپت سایت (وانیلا، بدون وابستگی) =====
// قرارداد دادهٔ دیکشنری: { "dictionary": [ { "arabic": "...", "meanings": ["..."], "concept": "..." } ] }
// ترتیب خواندن: نخست API ورکر، و اگر نشد فایل محلی dictionary.json
// (همان فایلی که پنل مدیریت روی سرور به‌روز می‌کند).

const API_BASE = 'https://souren.aliasgharpanahizare.workers.dev';

let dictionary = [];
let currentWords = [];
let currentTitle = '';
let currentUser = null; // { username, displayName } وقتی وارد شده

// ===== ارقام فارسی =====
function faNum(n) {
    const d = ['۰', '۱', '۲', '۳', '۴', '۵', '۶', '۷', '۸', '۹'];
    return String(n).replace(/[0-9]/g, (c) => d[+c]).replace(/,/g, '٬');
}

// ===== گریز از HTML برای داده‌های دیکشنری =====
function esc(s) {
    return String(s == null ? '' : s)
        .replace(/&/g, '&amp;')
        .replace(/</g, '&lt;')
        .replace(/>/g, '&gt;')
        .replace(/"/g, '&quot;');
}

// ===== فراخوانی API ورکر =====
async function api(path, options) {
    const res = await fetch(API_BASE + path, {
        credentials: 'include',
        headers: { 'Content-Type': 'application/json' },
        ...(options || {})
    });
    let data = null;
    try { data = await res.json(); } catch (e) { /* بدنهٔ خالی */ }
    return { res, data };
}

// ===== بارگذاری دیکشنری: API ورکر ← فایل محلی =====
async function loadDictionary() {
    // ۱) API ورکر
    try {
        const r = await api('/api/dictionary');
        if (r.res.ok && r.data && Array.isArray(r.data.dictionary)) {
            dictionary = r.data.dictionary;
        }
    } catch (e) { /* به جایگزین محلی می‌رویم */ }

    // ۲) فایل محلی dictionary.json
    if (!dictionary.length) {
        try {
            const res = await fetch('dictionary.json?' + Date.now());
            if (!res.ok) throw new Error('dictionary.json: ' + res.status);
            const data = await res.json();
            dictionary = data.dictionary || [];
        } catch (e) { /* به نمونهٔ توکار می‌رویم */ }
    }

    // ۳) چند واژهٔ نمونه تا صفحه خالی نماند
    if (!dictionary.length) {
        dictionary = [
            { arabic: "كتاب", meanings: ["کتاب", "دفتر"], concept: "مجموعه‌ای از برگه‌ها" },
            { arabic: "مدرسة", meanings: ["مدرسه", "آموزشگاه"], concept: "محل آموزش" },
            { arabic: "طالب", meanings: ["دانش‌آموز", "محصل"], concept: "شخصی که به دنبال علم است" },
            { arabic: "معلم", meanings: ["معلم", "آموزگار"], concept: "کسی که علم را آموزش می‌دهد" },
            { arabic: "سلام", meanings: ["سلام", "درود", "صلح"], concept: "درود و تحیت" }
        ];
    }

    const countEl = document.getElementById('wordCount');
    if (countEl) countEl.textContent = faNum(dictionary.length);
    renderList(dictionary, 'پرکاربردترین واژگان فارسی');
}

// ===== نرمال‌سازی عربی (همان رفتار نسخهٔ پیشین) =====
function normalizeArabic(text) {
    const map = {
        'ك': 'ک', 'ي': 'ی', 'ة': 'ه', 'أ': 'ا', 'إ': 'ا', 'آ': 'ا',
        'َ': '', 'ُ': '', 'ِ': '', 'ّ': '', 'ْ': '', 'ً': '', 'ٍ': '', 'ٌ': ''
    };
    return String(text || '').split('').map((ch) => map[ch] || ch).join('');
}

// ===== جستجوی هوشمند (همان امتیازدهی نسخهٔ پیشین) =====
function searchDictionary(query) {
    if (!query.trim()) return [];
    const q = query.trim();
    const qNorm = normalizeArabic(q);
    const results = [];

    for (let entry of dictionary) {
        let score = 0;
        const arabicNorm = normalizeArabic(entry.arabic);

        if (arabicNorm === qNorm) {
            score = 100;
        } else if (arabicNorm.includes(qNorm) || qNorm.includes(arabicNorm)) {
            score = 80;
        }

        if (score < 70) {
            for (let m of entry.meanings) {
                if (m.includes(q) || q.includes(m)) {
                    score = 60;
                    break;
                }
            }
        }

        if (score < 50 && entry.concept) {
            if (entry.concept.includes(q) || q.includes(entry.concept)) {
                score = 30;
            }
        }

        if (score > 0) {
            results.push({ ...entry, score });
        }
    }

    results.sort((a, b) => b.score - a.score);
    return results;
}

// ===== نشان‌شده‌ها (علاقه‌مندی‌ها) =====
// وقتی وارد نشده‌اید در localStorage می‌ماند؛ با ورود، از حساب خوانده و
// با PUT /api/auth/profile همگام می‌شود. هر عضو، واژهٔ عربیِ مدخل است.
let favorites = loadLocalFavorites();

function loadLocalFavorites() {
    try {
        const raw = localStorage.getItem('souren_favorites');
        const arr = raw ? JSON.parse(raw) : [];
        return Array.isArray(arr) ? arr.filter((x) => typeof x === 'string') : [];
    } catch (e) {
        return [];
    }
}

function saveLocalFavorites() {
    try { localStorage.setItem('souren_favorites', JSON.stringify(favorites)); } catch (e) {}
}

async function syncFavorites() {
    saveLocalFavorites();
    if (!currentUser) return;
    try {
        await api('/api/auth/profile', {
            method: 'PUT',
            body: JSON.stringify({ displayName: currentUser.displayName, favorites })
        });
    } catch (e) { /* نسخهٔ محلی نگه داشته شد؛ همگام‌سازی بعدی دوباره تلاش می‌شود */ }
}

function isFavorite(word) {
    return favorites.includes(word.arabic);
}

async function toggleFavorite(word) {
    if (isFavorite(word)) {
        favorites = favorites.filter((w) => w !== word.arabic);
    } else {
        favorites.push(word.arabic);
    }
    await syncFavorites();
    refreshFavoriteUi(word);
}

function refreshFavoriteUi(word) {
    const btn = document.getElementById('favBtn');
    if (btn && btn.dataset.word === word.arabic) {
        paintFavBtn(btn, word);
    }
    // بازرندر فهرست با حفظ جای پیمایش
    const wrap = document.querySelector('.dict-list-wrap');
    const top = wrap ? wrap.scrollTop : 0;
    renderList(currentWords, currentTitle);
    if (wrap) wrap.scrollTop = top;
}

const BOOKMARK_SVG = '<svg width="17" height="17" viewBox="0 0 24 24" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M6 3.5h12V21l-6-4.2L6 21Z"/></svg>';

function paintFavBtn(btn, word) {
    const active = isFavorite(word);
    btn.classList.toggle('active', active);
    btn.innerHTML = BOOKMARK_SVG + '<span>' + (active ? 'نشان‌شده' : 'نشان‌کردن') + '</span>';
}

// ===== رندر فهرست واژه‌ها =====
// سلسله‌مراتب برنامه: برابر فارسی پررنگ و درشت، واژهٔ عربی کوچک و کم‌رنگ.
function meaningsHtml(meanings, mainClass) {
    if (!meanings || meanings.length === 0) return '';
    const parts = meanings.map((m, i) =>
        i === 0
            ? `<span>${esc(m)}</span>`
            : `<span class="fa-alt">، ${esc(m)}</span>`
    );
    return `<span class="${mainClass}">${parts.join('')}</span>`;
}

function renderList(words, title) {
    currentWords = words || [];
    if (title) currentTitle = title;
    const listEl = document.getElementById('dictList');
    const titleEl = document.getElementById('listTitle');
    if (!listEl) return;
    if (titleEl && title) titleEl.textContent = title;

    if (!currentWords.length) {
        listEl.innerHTML = '<div class="dict-empty">واژه‌ای پیدا نشد</div>';
        return;
    }

    listEl.innerHTML = currentWords.map((item, i) => `
        <div class="dict-row" role="listitem" data-index="${i}" style="animation-delay:${Math.min(i, 12) * 30}ms">
            <span>${meaningsHtml(item.meanings, 'row-fa') || '<span class="row-none">برابر فارسی ثبت نشده</span>'}${isFavorite(item) ? `<span class="row-fav">${BOOKMARK_SVG}</span>` : ''}</span>
            <span class="row-ar">${esc(item.arabic)}</span>
        </div>
    `).join('');

    listEl.querySelectorAll('.dict-row').forEach((row) => {
        row.addEventListener('click', function () {
            const word = currentWords[parseInt(this.dataset.index, 10)];
            if (word) openModal(word);
        });
    });
}

// ===== مودال‌ها =====
function showModal(id) {
    const m = document.getElementById(id);
    if (!m) return;
    m.style.display = 'block';
    m.setAttribute('aria-hidden', 'false');
    document.body.style.overflow = 'hidden';
}

function hideModal(id) {
    const m = document.getElementById(id);
    if (!m) return;
    m.style.display = 'none';
    m.setAttribute('aria-hidden', 'true');
    document.body.style.overflow = '';
}

function openModal(word) {
    const modalBody = document.getElementById('modalBody');
    if (!modalBody) return;

    modalBody.innerHTML = `
        ${meaningsHtml(word.meanings, 'modal-fa') || `<div class="modal-fa">${esc(word.arabic)}</div>`}
        <div class="modal-ar">واژهٔ عربی: ${esc(word.arabic)}</div>
        ${word.concept ? `
            <div class="modal-concept">
                <strong>مفهوم</strong>
                ${esc(word.concept)}
            </div>
        ` : ''}
        <button class="fav-btn" id="favBtn" type="button" data-word="${esc(word.arabic)}"></button>
    `;

    const btn = document.getElementById('favBtn');
    paintFavBtn(btn, word);
    btn.addEventListener('click', () => toggleFavorite(word));

    showModal('wordModal');
}

function closeModal() {
    hideModal('wordModal');
}

// ===== عملکرد جستجو =====
function performSearch() {
    const searchBox = document.getElementById('searchBox');
    const query = searchBox ? searchBox.value : '';
    if (query.trim()) {
        renderList(searchDictionary(query), 'نتیجه‌های جستجو');
    } else {
        renderList(dictionary, 'پرکاربردترین واژگان فارسی');
    }
    const wrap = document.querySelector('.dict-list-wrap');
    if (wrap) wrap.scrollTop = 0;
}

// ===== حساب کاربری =====
function showMsg(id, text, ok) {
    const el = document.getElementById(id);
    if (!el) return;
    el.textContent = text;
    el.className = 'form-msg ' + (ok ? 'success' : 'error');
    el.hidden = false;
}

function errText(data, fallback) {
    return (data && typeof data.error === 'string' && data.error) ? data.error : fallback;
}

function updateAccountUi() {
    const out = document.getElementById('accountLoggedOut');
    const inn = document.getElementById('accountLoggedIn');
    const name = document.getElementById('navUserName');
    if (!out || !inn) return;
    if (currentUser) {
        out.hidden = true;
        inn.hidden = false;
        if (name) name.textContent = currentUser.displayName || currentUser.username;
    } else {
        out.hidden = false;
        inn.hidden = true;
        if (name) name.textContent = '';
    }
}

// بازیابی نشست هنگام بارگذاری (کوکی نشست با credentials خوانده می‌شود)
async function loadSession() {
    try {
        const { res, data } = await api('/api/auth/me');
        if (res.ok && data && data.user) {
            currentUser = { username: data.user.username, displayName: data.user.displayName };
            const serverFavs = Array.isArray(data.user.favorites) ? data.user.favorites : [];
            // یکی‌کردن نشان‌شده‌های سرور با نسخهٔ محلی تا چیزی از دست نرود
            favorites = [...new Set([...serverFavs, ...favorites])];
            saveLocalFavorites();
        }
    } catch (e) { /* بدون نشست ادامه می‌دهیم */ }
    updateAccountUi();
}

function afterAuth(user) {
    currentUser = { username: user.username, displayName: user.displayName };
    updateAccountUi();
    // نشان‌شده‌های حساب را تازه می‌خوانیم و با محلی یکی می‌کنیم
    loadSession();
}

async function doLogin(e) {
    e.preventDefault();
    const username = document.getElementById('loginUsername').value.trim();
    const password = document.getElementById('loginPassword').value;
    try {
        const { res, data } = await api('/api/auth/login', {
            method: 'POST',
            body: JSON.stringify({ username, password })
        });
        if (res.ok && data && data.user) {
            hideModal('authModal');
            afterAuth(data.user);
        } else {
            showMsg('loginMsg', errText(data, 'ورود ناموفق بود. نام کاربری و گذرواژه را بررسی کنید.'), false);
        }
    } catch (err) {
        showMsg('loginMsg', 'خطا در ارتباط با سرور. دوباره تلاش کنید.', false);
    }
}

async function doRegister(e) {
    e.preventDefault();
    const displayName = document.getElementById('registerDisplayName').value.trim();
    const username = document.getElementById('registerUsername').value.trim();
    const password = document.getElementById('registerPassword').value;
    try {
        const { res, data } = await api('/api/auth/register', {
            method: 'POST',
            body: JSON.stringify({ username, password, displayName })
        });
        if ((res.status === 201 || res.ok) && data && data.user) {
            hideModal('authModal');
            afterAuth(data.user);
        } else {
            showMsg('registerMsg', errText(data, 'ثبت‌نام ناموفق بود. دوباره تلاش کنید.'), false);
        }
    } catch (err) {
        showMsg('registerMsg', 'خطا در ارتباط با سرور. دوباره تلاش کنید.', false);
    }
}

async function doLogout() {
    try {
        await api('/api/auth/logout', { method: 'POST' });
    } catch (e) { /* حتی با خطای شبکه، از دید کاربر خارج می‌شویم */ }
    currentUser = null;
    updateAccountUi();
    hideModal('profileModal');
}

function openProfile() {
    if (!currentUser) return;
    document.getElementById('profileUsername').value = currentUser.username;
    document.getElementById('profileDisplayName').value = currentUser.displayName || '';
    document.getElementById('profileFavCount').textContent = faNum(favorites.length);
    const msg = document.getElementById('profileMsg');
    if (msg) msg.hidden = true;
    showModal('profileModal');
}

async function saveProfile(e) {
    e.preventDefault();
    if (!currentUser) return;
    const displayName = document.getElementById('profileDisplayName').value.trim();
    try {
        const { res, data } = await api('/api/auth/profile', {
            method: 'PUT',
            body: JSON.stringify({ displayName, favorites })
        });
        if (res.ok && data && data.user) {
            currentUser = { username: data.user.username, displayName: data.user.displayName };
            updateAccountUi();
            showMsg('profileMsg', 'پروفایل ذخیره شد.', true);
        } else {
            showMsg('profileMsg', errText(data, 'ذخیرهٔ پروفایل ناموفق بود.'), false);
        }
    } catch (err) {
        showMsg('profileMsg', 'خطا در ارتباط با سرور. دوباره تلاش کنید.', false);
    }
}

function switchAuthTab(register) {
    document.getElementById('tabLogin').classList.toggle('active', !register);
    document.getElementById('tabRegister').classList.toggle('active', register);
    document.getElementById('loginForm').hidden = register;
    document.getElementById('registerForm').hidden = !register;
}

function initAuth() {
    const openBtn = document.getElementById('authOpenBtn');
    if (openBtn) {
        openBtn.addEventListener('click', () => {
            switchAuthTab(false);
            showModal('authModal');
        });
    }
    const tabLogin = document.getElementById('tabLogin');
    const tabRegister = document.getElementById('tabRegister');
    if (tabLogin) tabLogin.addEventListener('click', () => switchAuthTab(false));
    if (tabRegister) tabRegister.addEventListener('click', () => switchAuthTab(true));

    const loginForm = document.getElementById('loginForm');
    const registerForm = document.getElementById('registerForm');
    if (loginForm) loginForm.addEventListener('submit', doLogin);
    if (registerForm) registerForm.addEventListener('submit', doRegister);

    const profileBtn = document.getElementById('profileOpenBtn');
    if (profileBtn) profileBtn.addEventListener('click', openProfile);
    const logoutBtn = document.getElementById('logoutBtn');
    if (logoutBtn) logoutBtn.addEventListener('click', doLogout);
    const profileLogoutBtn = document.getElementById('profileLogoutBtn');
    if (profileLogoutBtn) profileLogoutBtn.addEventListener('click', doLogout);
    const profileForm = document.getElementById('profileForm');
    if (profileForm) profileForm.addEventListener('submit', saveProfile);

    document.querySelectorAll('[data-close-auth]').forEach((b) =>
        b.addEventListener('click', () => hideModal('authModal')));
    document.querySelectorAll('[data-close-profile]').forEach((b) =>
        b.addEventListener('click', () => hideModal('profileModal')));
    ['authModal', 'profileModal'].forEach((id) => {
        const m = document.getElementById(id);
        if (m) {
            m.addEventListener('click', function (e) {
                if (e.target === this) hideModal(id);
            });
        }
    });
}

// ===== پیدا شدن نرم بخش‌ها هنگام پیمایش =====
function initReveal() {
    const items = document.querySelectorAll('.reveal');
    if (!('IntersectionObserver' in window)) {
        items.forEach((el) => el.classList.add('visible'));
        return;
    }
    const io = new IntersectionObserver((entries) => {
        entries.forEach((e) => {
            if (e.isIntersecting) {
                e.target.classList.add('visible');
                io.unobserve(e.target);
            }
        });
    }, { threshold: 0.12 });
    items.forEach((el) => io.observe(el));
}

// ===== برجسته‌کردن پیوند بخش جاری در ناوبری =====
function initNavSpy() {
    const links = document.querySelectorAll('.nav-link');
    if (!links.length || !('IntersectionObserver' in window)) return;
    const map = {};
    links.forEach((l) => { map[l.getAttribute('href')] = l; });
    const io = new IntersectionObserver((entries) => {
        entries.forEach((e) => {
            if (e.isIntersecting) {
                links.forEach((l) => l.classList.remove('active'));
                const link = map['#' + e.target.id];
                if (link) link.classList.add('active');
            }
        });
    }, { rootMargin: '-40% 0px -55% 0px' });
    ['home', 'dictionary', 'features', 'download'].forEach((id) => {
        const el = document.getElementById(id);
        if (el) io.observe(el);
    });
}

// ===== یافتن تازه‌ترین APK از انتشارهای گیت‌هاب =====
// در صورت خطا، دکمه‌ها همان پیوند صفحهٔ انتشارها را نگه می‌دارند.
async function resolveLatestApk() {
    try {
        const res = await fetch('https://api.github.com/repos/AliAsgharPZ/Souren/releases/latest');
        if (!res.ok) return;
        const rel = await res.json();
        const asset = (rel.assets || []).find((a) => a.name && a.name.toLowerCase().endsWith('.apk'));
        if (asset && asset.browser_download_url) {
            document.querySelectorAll('.apk-btn').forEach((b) => {
                b.setAttribute('href', asset.browser_download_url);
            });
        }
        if (rel.tag_name) {
            const ver = 'نسخهٔ ' + faNum(String(rel.tag_name).replace(/^v/i, ''));
            const apkVersion = document.getElementById('apkVersion');
            if (apkVersion) apkVersion.textContent = '— ' + ver;
            const footerVersion = document.getElementById('footerVersion');
            if (footerVersion) footerVersion.textContent = 'نسخهٔ کنونی اندروید: ' + ver;
        }
    } catch (e) {
        /* پیوند جایگزین (صفحهٔ انتشارها) سر جایش می‌ماند */
    }
}

// ===== رویدادها =====
document.addEventListener('DOMContentLoaded', async function () {
    initReveal();
    initNavSpy();
    initAuth();
    resolveLatestApk();
    loadSession();
    await loadDictionary();

    const searchBox = document.getElementById('searchBox');
    const searchBtn = document.getElementById('searchBtn');

    if (searchBox) {
        searchBox.addEventListener('input', performSearch);
        searchBox.addEventListener('keydown', function (e) {
            if (e.key === 'Enter') {
                e.preventDefault();
                performSearch();
            }
        });
    }
    if (searchBtn) {
        searchBtn.addEventListener('click', performSearch);
    }

    const modal = document.getElementById('wordModal');
    const closeBtn = document.querySelector('#wordModal .close-modal');
    if (closeBtn) closeBtn.addEventListener('click', closeModal);
    if (modal) {
        modal.addEventListener('click', function (e) {
            if (e.target === this) closeModal();
        });
    }
    document.addEventListener('keydown', function (e) {
        if (e.key === 'Escape') {
            closeModal();
            hideModal('authModal');
            hideModal('profileModal');
        }
    });
});
