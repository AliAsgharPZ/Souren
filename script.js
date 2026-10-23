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
        .replace(/"/g, '&quot;')
        .replace(/'/g, '&#39;');
}

// ===== واکشی با سقف زمانی تا هنگِ شبکه آغاز صفحه را قفل نکند =====
async function fetchWithTimeout(url, options, timeoutMs) {
    const ms = typeof timeoutMs === 'number' ? timeoutMs : 12000;
    if (!('AbortController' in window)) return fetch(url, options);
    const ctrl = new AbortController();
    const timer = setTimeout(() => ctrl.abort(), ms);
    try {
        return await fetch(url, { ...(options || {}), signal: ctrl.signal });
    } finally {
        clearTimeout(timer);
    }
}

// ===== فراخوانی API ورکر =====
async function api(path, options) {
    const res = await fetchWithTimeout(API_BASE + path, {
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
            const res = await fetchWithTimeout('dictionary.json?' + Date.now());
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
    renderCurrent();
}

// ===== نرمال‌سازی عربی (همان رفتار نسخهٔ پیشین) =====
function normalizeArabic(text) {
    const map = {
        'ك': 'ک', 'ي': 'ی', 'ة': 'ه', 'ۀ': 'هٔ', 'أ': 'ا', 'إ': 'ا', 'آ': 'ا',
        'ٱ': 'ا', 'ؤ': 'و', 'ـ': '',
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
            for (let m of (entry.meanings || [])) {
                // نرمال‌سازی یکدست: «كتاب» با ک عربی هم برابر فارسی را پیدا کند
                const mNorm = normalizeArabic(m);
                if (qNorm && (mNorm.includes(qNorm) || qNorm.includes(mNorm))) {
                    score = 60;
                    break;
                }
            }
        }

        if (score < 50 && entry.concept) {
            if (qNorm && normalizeArabic(entry.concept).includes(qNorm)) {
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
            body: JSON.stringify({ displayName: currentUser.displayName, favorites, likes })
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
    updateRowUi(word);
}

// به‌روزرسانی موضعیِ ردیف یک واژه در فهرست (بدون بازسازی کل فهرست ۵۵۲ ردیفی):
// نشانِ «نشان‌شده» و دکمهٔ پسندِ همان ردیف.
function paintRowLikeBtn(btn, word) {
    btn.classList.toggle('active', isLiked(word));
    btn.innerHTML = HEART_SVG + (likeCount(word) ? '<span class="like-count">' + faNum(likeCount(word)) + '</span>' : '');
}

function updateRowUi(word) {
    if (!word || !currentWords) return;
    const idx = currentWords.findIndex((w) => w.arabic === word.arabic);
    if (idx < 0) return;
    const row = document.querySelector('.dict-row[data-index="' + idx + '"]');
    if (!row) return;
    const firstCell = row.firstElementChild;
    if (firstCell) {
        const badge = firstCell.querySelector('.row-fav');
        if (isFavorite(word) && !badge) {
            firstCell.insertAdjacentHTML('beforeend', '<span class="row-fav">' + BOOKMARK_SVG + '</span>');
        } else if (!isFavorite(word) && badge) {
            badge.remove();
        }
    }
    const likeBtn = row.querySelector('.row-like');
    if (likeBtn) paintRowLikeBtn(likeBtn, word);
}

// رنگ‌کردن موضعیِ دکمه‌های پسندِ همهٔ ردیف‌های نمایان (مثلاً وقتی شمارهای
// همگانی دیرتر از رندر فهرست می‌رسند) — بدون بازسازی ردیف‌ها.
function updateAllRowLikeUis() {
    document.querySelectorAll('.dict-row').forEach((row) => {
        const word = currentWords && currentWords[parseInt(row.dataset.index, 10)];
        if (!word) return;
        const likeBtn = row.querySelector('.row-like');
        if (likeBtn) paintRowLikeBtn(likeBtn, word);
    });
}

const BOOKMARK_SVG = '<svg width="17" height="17" viewBox="0 0 24 24" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M6 3.5h12V21l-6-4.2L6 21Z"/></svg>';

function paintFavBtn(btn, word) {
    const active = isFavorite(word);
    btn.classList.toggle('active', active);
    btn.innerHTML = BOOKMARK_SVG + '<span>' + (active ? 'نشان‌شده' : 'نشان‌کردن') + '</span>';
}


// ===== پسندها (لایک‌ها) =====
// مانند نشان‌شده‌ها: برای مهمان در localStorage می‌ماند و با ورود یکی می‌شود.
// شمار همگانی از GET /api/likes خوانده می‌شود؛ پسند کاربر واردشده با
// POST /api/likes ثبت می‌شود (همان‌جا شمار همگانی و فهرست کاربر به‌روز می‌شود)
// و با PUT /api/auth/profile (فیلد likes) نیز همگام می‌شود.
let likes = loadLocalLikes();
let likeCounts = {};

function loadLocalLikes() {
    try {
        const raw = localStorage.getItem('souren_likes');
        const arr = raw ? JSON.parse(raw) : [];
        return Array.isArray(arr) ? arr.filter((x) => typeof x === 'string') : [];
    } catch (e) {
        return [];
    }
}

function saveLocalLikes() {
    try { localStorage.setItem('souren_likes', JSON.stringify(likes)); } catch (e) {}
}

function isLiked(word) {
    return likes.includes(word.arabic);
}

function likeCount(word) {
    const n = likeCounts[word.arabic];
    return (typeof n === 'number' && n > 0) ? n : 0;
}

async function loadLikeCounts() {
    try {
        const { res, data } = await api('/api/likes');
        if (res.ok && data && data.counts && typeof data.counts === 'object') {
            likeCounts = data.counts;
            updateAllRowLikeUis();
        }
    } catch (e) { /* بدون شمار همگانی ادامه می‌دهیم؛ شمارها صفر می‌مانند */ }
}

async function syncLikes() {
    saveLocalLikes();
    if (!currentUser) return;
    try {
        await api('/api/auth/profile', {
            method: 'PUT',
            body: JSON.stringify({ displayName: currentUser.displayName, favorites, likes })
        });
    } catch (e) { /* نسخهٔ محلی نگه داشته شد */ }
}

const HEART_SVG = '<svg width="17" height="17" viewBox="0 0 24 24" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M12 20.7C6.4 17 3 13.6 3 9.9 3 7.2 5 5 7.7 5c1.7 0 3.3.9 4.3 2.4C13 5.9 14.6 5 16.3 5 19 5 21 7.2 21 9.9c0 3.7-3.4 7.1-9 10.8Z"/></svg>';

// پیام «نشست تمام شده» برای پسند فقط یک بار نشان داده می‌شود
let sessionExpiredNotified = false;

function askToLoginForLike() {
    switchAuthTab(false);
    showModal('authModal');
    showMsg('loginMsg', 'برای ثبت پسندِ همگانی، نخست وارد شوید. پسند شما روی همین دستگاه نگه داشته شد.', false);
}

async function toggleLike(word) {
    const likedNow = !isLiked(word);
    if (likedNow) {
        likes.push(word.arabic);
        likeCounts[word.arabic] = likeCount(word) + 1;
    } else {
        likes = likes.filter((w) => w !== word.arabic);
        likeCounts[word.arabic] = Math.max(0, likeCount(word) - 1);
    }
    saveLocalLikes();
    refreshLikeUi(word);
    if (!currentUser) return;
    try {
        const { res, data } = await api('/api/likes', {
            method: 'POST',
            body: JSON.stringify({ ar: word.arabic, liked: likedNow })
        });
        if (res.status === 401) {
            // نشست منقضی شده است: خروج نرم تا کاربر «واردشده» نماند و
            // مودال ورود با هر کلیک روی قلب از نو باز نشود؛ پیام فقط یک بار.
            currentUser = null;
            updateAccountUi();
            if (!sessionExpiredNotified) {
                sessionExpiredNotified = true;
                askToLoginForLike();
            }
            return;
        }
        if (res.ok && data) {
            if (typeof data.count === 'number') likeCounts[word.arabic] = data.count;
            if (Array.isArray(data.likes)) {
                likes = data.likes;
                saveLocalLikes();
            }
            refreshLikeUi(word);
        }
    } catch (e) { /* پسند محلی نگه داشته شد و با ورود بعدی همگام می‌شود */ }
}

function refreshLikeUi(word) {
    const btn = document.getElementById('likeBtn');
    if (btn && word && btn.dataset.word === word.arabic) {
        paintLikeBtn(btn, word);
    }
    updateRowUi(word);
}

function paintLikeBtn(btn, word) {
    const active = isLiked(word);
    const count = likeCount(word);
    btn.classList.toggle('active', active);
    btn.innerHTML = HEART_SVG + '<span>' + (active ? 'پسندیده' : 'پسند') + '</span>' +
        (count ? '<span class="like-count">' + faNum(count) + '</span>' : '');
}

// ===== دسته‌بندی‌ها =====
// داده از categories.json در ریشه (کپیِ android/assets/db/categories.json):
// { "cats": { "health": ["واژهٔ عربی", ...], ... } } — کلید، واژهٔ عربی است.
const CATEGORY_TITLES = {
    health: 'پزشکی و تندرستی',
    work: 'پیشه و کار',
    money: 'پول و بازار',
    edu: 'آموزش و دانش',
    lang: 'سخن و نوشتار',
    home: 'خانه و خانواده',
    nature: 'طبیعت و گیتی',
    faith: 'باور و آیین',
    state: 'کشور و داد',
    mind: 'دل و اندیشه',
    time: 'زمان و سنجش',
    travel: 'سفر و جابه‌جایی',
    general: 'همگانی'
};
const CATEGORY_ORDER = ['health', 'work', 'money', 'edu', 'lang', 'home', 'nature', 'faith', 'state', 'mind', 'time', 'travel'];

let categoryMap = null; // Map: واژهٔ عربی (و شکل نرمال‌شده‌اش) ← Set از کلید دسته‌ها
let activeCategory = 'all';
let currentQuery = '';

async function loadCategories() {
    try {
        const res = await fetchWithTimeout('categories.json');
        if (!res.ok) throw new Error('categories.json: ' + res.status);
        const data = await res.json();
        const cats = (data && data.cats) || {};
        const map = new Map();
        Object.keys(cats).forEach((key) => {
            (cats[key] || []).forEach((ar) => {
                [ar, normalizeArabic(ar)].forEach((k) => {
                    if (!map.has(k)) map.set(k, new Set());
                    map.get(k).add(key);
                });
            });
        });
        categoryMap = map;
    } catch (e) {
        categoryMap = null; /* اگر نیامد، فقط چیپ «همه» می‌ماند */
    }
    renderCategoryChips();
    renderCurrent();
}

function wordCategories(word) {
    if (!categoryMap) return null;
    return categoryMap.get(word.arabic) || categoryMap.get(normalizeArabic(word.arabic)) || null;
}

function filterByCategory(words) {
    if (activeCategory === 'all' || !categoryMap) return words;
    if (activeCategory === 'general') {
        return words.filter((w) => !wordCategories(w));
    }
    return words.filter((w) => {
        const set = wordCategories(w);
        return set && set.has(activeCategory);
    });
}

function renderCategoryChips() {
    const wrap = document.getElementById('categoryChips');
    if (!wrap) return;
    const keys = categoryMap ? [...CATEGORY_ORDER, 'general'] : [];
    const all = [{ key: 'all', title: 'همه' },
        ...keys.map((k) => ({ key: k, title: CATEGORY_TITLES[k] || k }))];
    wrap.innerHTML = all.map((c) =>
        `<button type="button" class="cat-chip${activeCategory === c.key ? ' active' : ''}" data-cat="${esc(c.key)}">${esc(c.title)}</button>`
    ).join('');
    wrap.querySelectorAll('.cat-chip').forEach((chip) => {
        chip.addEventListener('click', () => {
            activeCategory = chip.dataset.cat || 'all';
            renderCategoryChips();
            renderCurrent();
            const listWrap = document.querySelector('.dict-list-wrap');
            if (listWrap) listWrap.scrollTop = 0;
        });
    });
}

// رندر فهرست جاری با حفظ وضعیت جستجو و فیلتر دسته‌بندی
function renderCurrent() {
    const base = currentQuery.trim() ? searchDictionary(currentQuery) : dictionary;
    const title = currentQuery.trim() ? 'نتیجه‌های جستجو' : 'پرکاربردترین واژگان فارسی';
    renderList(filterByCategory(base), title);
}

// بازرندر فهرست فعلی (پس از تغییر نشان/پسند/نشست) با حفظ جای پیمایش
function refreshListUi() {
    const listEl = document.getElementById('dictList');
    if (!listEl || !currentWords) return;
    const wrap = document.querySelector('.dict-list-wrap');
    const top = wrap ? wrap.scrollTop : 0;
    renderList(currentWords, currentTitle);
    const wrap2 = document.querySelector('.dict-list-wrap');
    if (wrap2) wrap2.scrollTop = top;
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
        updateListMask();
        return;
    }

    // انیمیشن ورود ردیف‌ها فقط برای نخستین رندر؛ رندرهای بعدی (جستجو،
    // پالایه) نباید با هر کلید از نو چشمک بزنند.
    const intro = !renderList._introPlayed;
    renderList._introPlayed = true;

    listEl.innerHTML = currentWords.map((item, i) => `
        <div class="dict-row${intro ? ' row-in' : ''}" role="listitem" data-index="${i}"${intro ? ` style="animation-delay:${Math.min(i, 12) * 30}ms"` : ''}>
            <span>${meaningsHtml(item.meanings, 'row-fa') || '<span class="row-none">برابر فارسی ثبت نشده</span>'}${isFavorite(item) ? `<span class="row-fav">${BOOKMARK_SVG}</span>` : ''}</span>
            <span class="row-side">
                <button type="button" class="row-like${isLiked(item) ? ' active' : ''}" data-like-index="${i}" aria-label="پسندِ ${esc(item.arabic)}" title="پسند">${HEART_SVG}${likeCount(item) ? `<span class="like-count">${faNum(likeCount(item))}</span>` : ''}</button>
                <span class="row-ar">${esc(item.arabic)}</span>
            </span>
        </div>
    `).join('');

    listEl.querySelectorAll('.dict-row').forEach((row) => {
        row.addEventListener('click', function () {
            const word = currentWords[parseInt(this.dataset.index, 10)];
            if (word) openModal(word);
        });
    });
    listEl.querySelectorAll('.row-like').forEach((btn) => {
        btn.addEventListener('click', function (e) {
            e.stopPropagation();
            const word = currentWords[parseInt(this.dataset.likeIndex, 10)];
            if (word) toggleLike(word);
        });
    });
    updateListMask();
}

// محو لبه‌های فهرست فقط وقتی معنا دارد: محوِ بالا پس از اسکرول و
// محوِ پایین وقتی هنوز ادامه‌ای هست؛ در سکونِ بالای فهرست، ردیف اول
// نباید نیمه‌محو دیده شود.
function updateListMask() {
    const wrap = document.querySelector('.dict-list-wrap');
    if (!wrap) return;
    wrap.classList.toggle('fade-top', wrap.scrollTop > 4);
    wrap.classList.toggle('fade-bottom', wrap.scrollTop + wrap.clientHeight < wrap.scrollHeight - 4);
}

function initListMask() {
    const wrap = document.querySelector('.dict-list-wrap');
    if (wrap) wrap.addEventListener('scroll', updateListMask, { passive: true });
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
        <div class="modal-actions">
            <button class="fav-btn" id="favBtn" type="button" data-word="${esc(word.arabic)}"></button>
            <button class="fav-btn like-btn" id="likeBtn" type="button" data-word="${esc(word.arabic)}"></button>
        </div>
    `;

    const btn = document.getElementById('favBtn');
    paintFavBtn(btn, word);
    btn.addEventListener('click', () => toggleFavorite(word));
    const likeBtn = document.getElementById('likeBtn');
    paintLikeBtn(likeBtn, word);
    likeBtn.addEventListener('click', () => toggleLike(word));

    showModal('wordModal');
}

function closeModal() {
    hideModal('wordModal');
}

// ===== عملکرد جستجو =====
function performSearch() {
    const searchBox = document.getElementById('searchBox');
    currentQuery = searchBox ? searchBox.value : '';
    renderCurrent();
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
            const serverLikes = Array.isArray(data.user.likes) ? data.user.likes : [];
            const guestLikes = likes.filter((w) => !serverLikes.includes(w));
            likes = [...new Set([...serverLikes, ...likes])];
            saveLocalLikes();
            // پسندهای مهمان که سرور ندارد با POST ثبت می‌شوند تا شمار همگانی هم درست شود؛
            // سپس فهرست نهایی با PUT همگام می‌شود.
            for (const ar of guestLikes) {
                try {
                    await api('/api/likes', {
                        method: 'POST',
                        body: JSON.stringify({ ar, liked: true })
                    });
                } catch (e) { /* همگام‌سازی بعدی دوباره تلاش می‌شود */ }
            }
            // اگر مجموعهٔ یکی‌شده با سرور فرق دارد، پروفایل PUT شود؛
            // پیش‌تر فقط وقتی مهمان پسند داشت این اتفاق می‌افتاد و
            // نشان‌شده‌های تنها هرگز به سرور نمی‌رسیدند.
            const mergedDiffers =
                favorites.length !== serverFavs.length ||
                favorites.some((w) => !serverFavs.includes(w)) ||
                likes.length !== serverLikes.length ||
                likes.some((w) => !serverLikes.includes(w));
            if (mergedDiffers) {
                await syncFavorites();
            }
            if (guestLikes.length) {
                loadLikeCounts();
            }
            // باگ ب: پس از یکی‌کردن نشست، فهرست جاری باید تازه رندر شود تا
            // نشان‌ها و پسندها بدون رندر بعدی دیده شوند (با حفظ وضعیت جستجو).
            if (dictionary.length) renderCurrent();
            else refreshListUi();
        }
    } catch (e) { /* بدون نشست ادامه می‌دهیم */ }
    updateAccountUi();
}

function afterAuth(user) {
    currentUser = { username: user.username, displayName: user.displayName };
    sessionExpiredNotified = false;
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
            // باگ الف: register کوکیِ نشست نمی‌دهد؛ بلافاصله با همان مشخصات
            // وارد می‌شویم تا نشست ساخته شود (دقیقاً مانند برنامهٔ اندروید).
            let sessionUser = data.user;
            try {
                const login = await api('/api/auth/login', {
                    method: 'POST',
                    body: JSON.stringify({ username, password })
                });
                if (login.res.ok && login.data && login.data.user) {
                    sessionUser = login.data.user;
                }
            } catch (e) { /* اگر ورودِ بی‌درنگ نشد، کاربر می‌تواند دستی وارد شود */ }
            hideModal('authModal');
            afterAuth(sessionUser);
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
    // دادهٔ حساب روی این دستگاه نباید بماند: نه در حافظه و نه در
    // localStorage؛ وگرنه قلب‌ها و نشان‌های حساب دیده می‌شوند و با
    // ورود حساب بعدی به آن حساب یکی می‌شوند.
    favorites = [];
    likes = [];
    try {
        localStorage.removeItem('souren_favorites');
        localStorage.removeItem('souren_likes');
    } catch (e) {}
    sessionExpiredNotified = false;
    updateAccountUi();
    hideModal('profileModal');
    refreshListUi();
}

function openProfile() {
    if (!currentUser) return;
    document.getElementById('profileUsername').value = currentUser.username;
    document.getElementById('profileDisplayName').value = currentUser.displayName || '';
    document.getElementById('profileFavCount').textContent = faNum(favorites.length);
    const likeCountEl = document.getElementById('profileLikeCount');
    if (likeCountEl) likeCountEl.textContent = faNum(likes.length);
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
            body: JSON.stringify({ displayName, favorites, likes })
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
        const res = await fetchWithTimeout('https://api.github.com/repos/AliAsgharPZ/Souren/releases/latest', null, 10000);
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
document.addEventListener('DOMContentLoaded', function () {
    window.__sourenBooted = true;
    initReveal();
    initNavSpy();
    initAuth();
    initListMask();

    // شنونده‌ها مستقل از بارگذاری داده وصل می‌شوند تا تایپ در باکس
    // جستجو از همان لحظهٔ نخست کار کند، نه پس از آمدن دیکشنری.
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

    // بارگذاری داده‌ها؛ هرکدام هر وقت رسیدند، نمای خود را تازه می‌کنند.
    renderCategoryChips();
    resolveLatestApk();
    loadSession();
    loadLikeCounts();
    loadDictionary();
    loadCategories();
});
