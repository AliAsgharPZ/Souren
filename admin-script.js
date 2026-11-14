// ===== تنظیمات گیت‌هاب =====
// آپلودها از مسیر /api/upload روی خود سایت انجام می‌شوند؛ توکن گیت‌هاب به‌صورت Secret
// در Worker کلادفلر نگه‌داری می‌شود و هرگز به مرورگر نمی‌رسد.

const ADMIN_API_BASE = 'https://souren.aliasgharpanahizare.workers.dev';

// ===== سیستم احراز هویت =====
let currentAdmin = null;

// ===== آپلود فایل در گیت‌هاب (از مسیر امن سایت) =====
async function uploadToGitHub(filename, data) {
    if (!currentAdmin) return { success: false, error: { message: 'ابتدا وارد شوید.' } };
    if (filename !== 'dictionary.json') return { success: false, error: { message: 'فقط دیکشنری قابل انتشار است.' } };
    try {
        const res = await fetch(ADMIN_API_BASE + '/api/upload', { method: 'POST', credentials: 'include', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ filename, data }) });
        const out = await res.json().catch(() => ({ success: false, error: 'bad_response' }));
        if (res.ok && out.success) return { success: true };
        return { success: false, error: { message: out.error === 'unauthorized' ? 'نشست مدیریت منقضی شده؛ دوباره وارد شوید.' : (out.error || 'خطای سرور') } };
    } catch (_) { return { success: false, error: { message: 'ارتباط امن با سرور برقرار نشد.' } }; }
}
// ===== بارگذاری دیکشنری =====
async function loadAllData() {
    try {
        const response = await fetch(ADMIN_API_BASE + '/api/dictionary', { credentials: 'include', cache: 'no-store' });
        if (response.ok) { const data = await response.json(); if (Array.isArray(data.dictionary)) { dictionary = data.dictionary; return; } }
    } catch (_) { /* fallback به فایل عمومی دیکشنری */ }
    try {
        const response = await fetch('dictionary.json?' + Date.now(), { cache: 'no-store' });
        if (!response.ok) throw new Error('dictionary_unavailable');
        const data = await response.json(); dictionary = Array.isArray(data.dictionary) ? data.dictionary : [];
    } catch (_) { dictionary = []; }
}
// ===== انتشار دیکشنری =====
async function publishChanges() {
    if (!currentAdmin) { showAdminMessage('لطفاً ابتدا وارد شوید.', 'error'); return; }
    showAdminMessage('⏳ در حال انتشار دیکشنری...', 'success');
    const result = await uploadToGitHub('dictionary.json', { dictionary });
    if (result.success) showAdminMessage('✅ دیکشنری با موفقیت ذخیره شد.', 'success');
    else showAdminMessage('❌ انتشار انجام نشد: ' + (result.error?.message || 'خطای نامشخص'), 'error');
}
// ===== DOM Elements =====
const loginSection = document.getElementById('loginSection');
const adminContent = document.getElementById('adminContent');
const loginUsername = document.getElementById('loginUsername');
const loginPassword = document.getElementById('loginPassword');
const loginBtn = document.getElementById('loginBtn');
const loginMessage = document.getElementById('loginMessage');
const logoutBtn = document.getElementById('logoutBtn');

const newWord = document.getElementById('newWord');
const newMeaning = document.getElementById('newMeaning');
const newConcept = document.getElementById('newConcept');
const addBtn = document.getElementById('addBtn');
const adminMessage = document.getElementById('adminMessage');


const tableBody = document.getElementById('tableBody');
const tableSearch = document.getElementById('tableSearch');
const refreshTableBtn = document.getElementById('refreshTableBtn');

const svgInput = document.getElementById('svgInput');
const uploadSvgBtn = document.getElementById('uploadSvgBtn');
const resetLogoBtn = document.getElementById('resetLogoBtn');
const logoPreview = document.getElementById('logoPreview');
const logoMessage = document.getElementById('logoMessage');

// ===== توابع کمکی =====
function showAdminMessage(text, type = 'success') {
    adminMessage.style.display = 'block';
    adminMessage.className = `message ${type}`;
    adminMessage.textContent = text;
    setTimeout(() => {
        adminMessage.style.display = 'none';
    }, 6000);
}

function showLoginMessage(text, type = 'error') {
    loginMessage.style.display = 'block';
    loginMessage.className = `message ${type}`;
    loginMessage.textContent = text;
    setTimeout(() => {
        loginMessage.style.display = 'none';
    }, 4000);
}

function showLogoMessage(text, type = 'success') {
    logoMessage.style.display = 'block';
    logoMessage.className = `message ${type}`;
    logoMessage.textContent = text;
    setTimeout(() => {
        logoMessage.style.display = 'none';
    }, 4000);
}

// ===== مدیریت ادمین‌ها =====
function renderTable(words) {
    if (!tableBody) return;

    if (!words || words.length === 0) {
        tableBody.innerHTML = `<tr><td colspan="5" style="text-align:center;padding:30px;">📚 هیچ کلمه‌ای در دیکشنری وجود ندارد</td></tr>`;
        return;
    }

    let html = '';
    words.forEach((item, index) => {
        const meaningsHtml = item.meanings.map(m => `<span>${m}</span>`).join(' ');
        html += `
            <tr>
                <td>${index + 1}</td>
                <td><strong>${item.arabic}</strong></td>
                <td><div class="meanings-list">${meaningsHtml}</div></td>
                <td>${item.concept ? `<span class="concept-text" title="${item.concept}">${item.concept}</span>` : '-'}</td>
                <td>
                    <div class="action-buttons">
                        <button class="btn-danger delete-word" data-index="${index}">🗑️ حذف</button>
                    </div>
                </td>
            </tr>
        `;
    });

    tableBody.innerHTML = html;

    document.querySelectorAll('.delete-word').forEach(btn => {
        btn.addEventListener('click', function() {
            const index = parseInt(this.dataset.index);
            const word = dictionary[index];
            if (confirm(`آیا از حذف کلمه "${word.arabic}" مطمئن هستید؟`)) {
                dictionary.splice(index, 1);
                renderTable(dictionary);
                showAdminMessage(`✅ کلمه "${word.arabic}" حذف شد. برای ذخیره روی انتشار کلیک کن.`, 'success');
            }
        });
    });
}

// ===== توابع مدیریت =====
async function addNewWord() {
    if (!currentAdmin) {
        showAdminMessage('لطفاً ابتدا وارد شوید.', 'error');
        return;
    }

    const word = newWord.value.trim();
    const meaningsRaw = newMeaning.value.trim();
    const concept = newConcept.value.trim();

    if (!word || !meaningsRaw) {
        showAdminMessage('لطفاً کلمه عربی و معنی فارسی را وارد کنید.', 'error');
        return;
    }

    if (dictionary.some(entry => entry.arabic === word)) {
        showAdminMessage('این کلمه قبلاً وجود دارد.', 'error');
        return;
    }

    const meanings = meaningsRaw.split(',').map(m => m.trim()).filter(m => m);
    if (meanings.length === 0) {
        showAdminMessage('حداقل یک معنی وارد کنید.', 'error');
        return;
    }

    dictionary.push({
        arabic: word,
        meanings: meanings,
        concept: concept || ''
    });

    newWord.value = '';
    newMeaning.value = '';
    newConcept.value = '';
    
    renderTable(dictionary);
    showAdminMessage(`✅ کلمه "${word}" اضافه شد. برای ذخیره روی انتشار کلیک کن.`, 'success');
}

// ===== سیستم لاگین =====
async function login() {
    const username = loginUsername.value.trim(); const password = loginPassword.value;
    if (!username || !password) { showLoginMessage('نام کاربری و گذرواژه را وارد کنید.', 'error'); return; }
    loginBtn.disabled = true;
    try {
        const response = await fetch(ADMIN_API_BASE + '/api/admin/login', { method: 'POST', credentials: 'include', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ username, password }) });
        const result = await response.json().catch(() => ({}));
        if (!response.ok || !result.success || !result.admin) { showLoginMessage(result.error === 'admin_auth_not_configured' ? 'احراز هویت مدیریت هنوز روی سرور پیکربندی نشده است.' : 'نام کاربری یا گذرواژه نادرست است.', 'error'); return; }
        currentAdmin = { username: result.admin.username }; loginPassword.value = '';
        loginSection.style.display = 'none'; adminContent.style.display = 'block';
        showAdminMessage('خوش آمدید ' + currentAdmin.username, 'success'); renderTable(dictionary); loadLogo();
    } catch (_) { showLoginMessage('ارتباط امن با سرور برقرار نشد.', 'error'); }
    finally { loginBtn.disabled = false; }
}

async function logout() {
    try { await fetch(ADMIN_API_BASE + '/api/admin/logout', { method: 'POST', credentials: 'include', headers: { 'Content-Type': 'application/json' }, body: '{}' }); } catch (_) {}
    currentAdmin = null; loginSection.style.display = 'flex'; adminContent.style.display = 'none';
    loginUsername.value = ''; loginPassword.value = ''; showLoginMessage('از پنل خارج شدید.', 'success');
}
function filterTable() {
    const query = tableSearch.value.trim().toLowerCase();
    if (!query) {
        renderTable(dictionary);
        return;
    }

    const filtered = dictionary.filter(item => 
        item.arabic.includes(query) ||
        item.meanings.some(m => m.includes(query)) ||
        (item.concept && item.concept.includes(query))
    );
    renderTable(filtered);
}

// ===== بخش‌های قابل جمع شدن =====
function setupCollapsibleSections() {
    document.querySelectorAll('.toggle-section').forEach(btn => {
        btn.addEventListener('click', function() {
            const section = this.closest('.admin-section');
            const body = section.querySelector('.section-body');
            body.classList.toggle('collapsed');
            this.textContent = body.classList.contains('collapsed') ? '▶' : '▼';
        });
    });
}

// ===== مدیریت لوگو =====
function uploadLogo() {
    if (!currentAdmin) {
        showLogoMessage('لطفاً ابتدا وارد شوید.', 'error');
        return;
    }

    const svgCode = svgInput.value.trim();
    if (!svgCode) {
        showLogoMessage('لطفاً کد SVG را وارد کنید.', 'error');
        return;
    }

    if (!svgCode.startsWith('<svg') && !svgCode.startsWith('<?xml')) {
        showLogoMessage('کد SVG نامعتبر است.', 'error');
        return;
    }

    const dataUrl = 'data:image/svg+xml;charset=utf-8,' + encodeURIComponent(svgCode);
    saveLogo(dataUrl);
    loadLogo();
    
    if (logoPreview) {
        logoPreview.src = dataUrl;
    }
    
    showLogoMessage('✅ لوگو با موفقیت آپلود شد.', 'success');
}

function resetLogo() {
    if (!currentAdmin) {
        showLogoMessage('لطفاً ابتدا وارد شوید.', 'error');
        return;
    }

    localStorage.removeItem('logo_data');
    const defaultLogo = 'logo.png';
    const logoImg = document.getElementById('logoImage');
    if (logoImg) {
        logoImg.src = defaultLogo;
    }
    if (logoPreview) {
        logoPreview.src = defaultLogo;
    }
    showLogoMessage('✅ لوگو به حالت پیش‌فرض بازگشت.', 'success');
}

function saveLogo(svgData) {
    try {
        localStorage.setItem('logo_data', svgData);
    } catch (e) {}
}

function loadLogo() {
    try {
        const savedLogo = localStorage.getItem('logo_data');
        if (savedLogo) {
            const logoImg = document.getElementById('logoImage');
            if (logoImg) {
                logoImg.src = savedLogo;
            }
        }
    } catch (e) {}
}

// ===== دانلود فایل‌ها (برای پشتیبان) =====
function downloadDictionaryFile() {
    const data = { dictionary: dictionary };
    const blob = new Blob([JSON.stringify(data, null, 2)], { type: 'application/json' });
    const url = URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = 'dictionary.json';
    document.body.appendChild(a);
    a.click();
    document.body.removeChild(a);
    URL.revokeObjectURL(url);
    showAdminMessage('✅ فایل dictionary.json دانلود شد.', 'success');
}

// ===== رویدادها =====
document.addEventListener('DOMContentLoaded', async function() {
    console.log('🚀 شروع بارگذاری...');
    
    await loadAllData();
    
    console.log('📋 دیکشنری بارگذاری شد:', dictionary.length);
    
    loadLogo();
    setupCollapsibleSections();

    loginBtn.addEventListener('click', login);
    loginPassword.addEventListener('keypress', function(e) {
        if (e.key === 'Enter') login();
    });

    logoutBtn.addEventListener('click', () => { void logout(); });
    addBtn.addEventListener('click', addNewWord);
    
    uploadSvgBtn.addEventListener('click', uploadLogo);
    resetLogoBtn.addEventListener('click', resetLogo);
    
    const downloadDictBtn = document.getElementById('downloadDictBtn');
    if (downloadDictBtn) {
        downloadDictBtn.addEventListener('click', downloadDictionaryFile);
    }
    
    
    const publishBtn = document.getElementById('publishBtn');
    if (publishBtn) {
        publishBtn.addEventListener('click', publishChanges);
    }
    
    if (refreshTableBtn) {
        refreshTableBtn.addEventListener('click', function() {
            renderTable(dictionary);
            showAdminMessage('✅ جدول بروزرسانی شد.', 'success');
        });
    }

    if (tableSearch) {
        tableSearch.addEventListener('input', filterTable);
    }
    
    console.log('✅ بارگذاری کامل شد!');
});
