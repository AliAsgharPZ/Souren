// ===== تنظیمات گیت‌هاب =====
const GITHUB_TOKEN = 'ghp_توکن_خودت_اینجا';
const GITHUB_USER = 'AliAsgharPZ';
const GITHUB_REPO = 'dictionary-app';
const GITHUB_BRANCH = 'main'; // اگر ارور داد به master تغییر بده

// ===== سیستم احراز هویت =====
let admins = [];
let currentAdmin = null;

// ===== آپلود فایل در گیت‌هاب =====
async function uploadToGitHub(filename, data) {
    try {
        console.log(`📤 در حال آپلود ${filename}...`);
        
        const checkRes = await fetch(`https://api.github.com/repos/${GITHUB_USER}/${GITHUB_REPO}/contents/${filename}`, {
            headers: {
                'Authorization': `token ${GITHUB_TOKEN}`,
                'Accept': 'application/vnd.github.v3+json'
            }
        });
        
        let sha = null;
        if (checkRes.ok) {
            const fileData = await checkRes.json();
            sha = fileData.sha;
        }
        
        const content = btoa(unescape(encodeURIComponent(JSON.stringify(data, null, 2))));
        const body = {
            message: `آپدیت ${filename} - ${new Date().toLocaleString('fa-IR')}`,
            content: content,
            branch: GITHUB_BRANCH
        };
        
        if (sha) body.sha = sha;
        
        const uploadRes = await fetch(`https://api.github.com/repos/${GITHUB_USER}/${GITHUB_REPO}/contents/${filename}`, {
            method: 'PUT',
            headers: {
                'Authorization': `token ${GITHUB_TOKEN}`,
                'Content-Type': 'application/json',
                'Accept': 'application/vnd.github.v3+json'
            },
            body: JSON.stringify(body)
        });
        
        if (uploadRes.ok) {
            console.log(`✅ ${filename} آپلود شد!`);
            return { success: true };
        } else {
            const error = await uploadRes.json();
            console.log(`❌ خطا:`, error);
            return { success: false, error: error };
        }
    } catch (e) {
        console.log(`❌ خطا:`, e);
        return { success: false, error: e.message };
    }
}

// ===== بارگذاری از گیت‌هاب =====
async function loadFromGitHub(filename) {
    try {
        const response = await fetch(`https://raw.githubusercontent.com/${GITHUB_USER}/${GITHUB_REPO}/${GITHUB_BRANCH}/${filename}?t=${Date.now()}`);
        if (response.ok) {
            return await response.json();
        }
    } catch (e) {
        console.log('خطا:', e);
    }
    return null;
}

// ===== بارگذاری همه دیتا =====
async function loadAllData() {
    // بارگذاری دیکشنری
    const dictData = await loadFromGitHub('dictionary.json');
    if (dictData && dictData.dictionary) {
        dictionary = dictData.dictionary;
        console.log('✅ دیکشنری از گیت‌هاب:', dictionary.length);
    } else {
        try {
            const res = await fetch('dictionary.json?' + Date.now());
            const data = await res.json();
            dictionary = data.dictionary || [];
        } catch(e) {
            dictionary = [
                { arabic: "كتاب", meanings: ["کتاب", "دفتر"], concept: "مجموعه‌ای از برگه‌ها" },
                { arabic: "مدرسة", meanings: ["مدرسه", "آموزشگاه"], concept: "محل آموزش" }
            ];
        }
    }
    
    // بارگذاری ادمین‌ها
    const adminData = await loadFromGitHub('admins.json');
    if (adminData && adminData.admins) {
        admins = adminData.admins;
        console.log('✅ ادمین‌ها از گیت‌هاب:', admins.length);
    } else {
        try {
            const res = await fetch('admins.json?' + Date.now());
            const data = await res.json();
            admins = data.admins || [{ username: "AliAsgharPZ", password: "09199621557Aa" }];
        } catch(e) {
            admins = [{ username: "AliAsgharPZ", password: "09199621557Aa" }];
        }
    }
}

// ===== انتشار تغییرات =====
async function publishChanges() {
    if (!currentAdmin) {
        showAdminMessage('لطفاً ابتدا وارد شوید.', 'error');
        return;
    }
    
    showAdminMessage('⏳ در حال انتشار به گیت‌هاب...', 'success');
    
    const dictResult = await uploadToGitHub('dictionary.json', { dictionary: dictionary });
    const adminResult = await uploadToGitHub('admins.json', { admins: admins });
    
    if (dictResult.success && adminResult.success) {
        showAdminMessage('✅ دیکشنری و ادمین‌ها در گیت‌هاب ذخیره شد!', 'success');
        showAdminMessage('⏳ کلادفلر خودکار دیپلوی میکنه (حداکثر ۲ دقیقه)', 'success');
    } else {
        let errorMsg = '❌ خطا در انتشار!\n';
        if (!dictResult.success) errorMsg += `دیکشنری: ${dictResult.error?.message || 'نامشخص'}\n`;
        if (!adminResult.success) errorMsg += `ادمین‌ها: ${adminResult.error?.message || 'نامشخص'}`;
        showAdminMessage(errorMsg, 'error');
    }
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

const newAdminUsername = document.getElementById('newAdminUsername');
const newAdminPassword = document.getElementById('newAdminPassword');
const addAdminBtn = document.getElementById('addAdminBtn');
const adminListDiv = document.getElementById('adminList');

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
function renderAdminList() {
    if (!adminListDiv) return;
    
    if (!admins || admins.length === 0) {
        adminListDiv.innerHTML = '<div style="padding:20px;text-align:center;color:#636e72;">هیچ ادمینی ثبت نشده</div>';
        return;
    }
    
    adminListDiv.innerHTML = admins.map((admin, index) => `
        <div class="admin-item">
            <span>👤 ${admin.username}</span>
            ${admin.username !== 'AliAsgharPZ' ? 
                `<button class="btn-danger delete-admin" data-index="${index}">❌ حذف</button>` : 
                '<span style="color:#0984e3;">🌟 مدیر اصلی</span>'}
        </div>
    `).join('');

    document.querySelectorAll('.delete-admin').forEach(btn => {
        btn.addEventListener('click', function() {
            const index = parseInt(this.dataset.index);
            if (confirm(`آیا از حذف ادمین "${admins[index].username}" مطمئن هستید؟`)) {
                admins.splice(index, 1);
                renderAdminList();
                showAdminMessage('✅ ادمین حذف شد. برای ذخیره روی انتشار کلیک کن.', 'success');
            }
        });
    });
}

// ===== رندر جدول =====
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

async function addNewAdmin() {
    if (!currentAdmin || currentAdmin.username !== 'AliAsgharPZ') {
        showAdminMessage('تنها مدیر اصلی می‌تواند ادمین جدید اضافه کند.', 'error');
        return;
    }

    const username = newAdminUsername.value.trim();
    const password = newAdminPassword.value.trim();

    if (!username || !password) {
        showAdminMessage('لطفاً نام کاربری و رمز عبور را وارد کنید.', 'error');
        return;
    }

    if (admins.some(a => a.username === username)) {
        showAdminMessage('این نام کاربری قبلاً وجود دارد.', 'error');
        return;
    }

    admins.push({ username, password });
    newAdminUsername.value = '';
    newAdminPassword.value = '';
    
    renderAdminList();
    showAdminMessage(`✅ ادمین "${username}" اضافه شد. برای ذخیره روی انتشار کلیک کن.`, 'success');
}

// ===== سیستم لاگین =====
function login() {
    const username = loginUsername.value.trim();
    const password = loginPassword.value.trim();

    const admin = admins.find(a => a.username === username && a.password === password);
    
    if (admin) {
        currentAdmin = admin;
        loginSection.style.display = 'none';
        adminContent.style.display = 'block';
        showAdminMessage(`✅ خوش آمدید ${admin.username}`, 'success');
        renderAdminList();
        renderTable(dictionary);
        loadLogo();
    } else {
        showLoginMessage('❌ نام کاربری یا رمز عبور اشتباه است.', 'error');
    }
}

function logout() {
    currentAdmin = null;
    loginSection.style.display = 'flex';
    adminContent.style.display = 'none';
    loginUsername.value = '';
    loginPassword.value = '';
    showAdminMessage('🚪 شما خارج شدید.', 'success');
}

// ===== توابع جستجوی جدول =====
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
function downloadAdminsFile() {
    const data = { admins: admins };
    const blob = new Blob([JSON.stringify(data, null, 2)], { type: 'application/json' });
    const url = URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = 'admins.json';
    document.body.appendChild(a);
    a.click();
    document.body.removeChild(a);
    URL.revokeObjectURL(url);
    showAdminMessage('✅ فایل admins.json دانلود شد.', 'success');
}

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
    
    console.log('📋 لیست نهایی:', { admins: admins.length, dictionary: dictionary.length });
    
    loadLogo();
    setupCollapsibleSections();

    loginBtn.addEventListener('click', login);
    loginPassword.addEventListener('keypress', function(e) {
        if (e.key === 'Enter') login();
    });

    logoutBtn.addEventListener('click', logout);
    addBtn.addEventListener('click', addNewWord);
    addAdminBtn.addEventListener('click', addNewAdmin);
    
    uploadSvgBtn.addEventListener('click', uploadLogo);
    resetLogoBtn.addEventListener('click', resetLogo);
    
    const downloadDictBtn = document.getElementById('downloadDictBtn');
    if (downloadDictBtn) {
        downloadDictBtn.addEventListener('click', downloadDictionaryFile);
    }
    
    const downloadAdminsBtn = document.getElementById('downloadAdminsBtn');
    if (downloadAdminsBtn) {
        downloadAdminsBtn.addEventListener('click', downloadAdminsFile);
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
