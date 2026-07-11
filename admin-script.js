// ===== سیستم احراز هویت =====
let admins = [];
let currentAdmin = null;

// ===== بارگذاری اجباری از admins.json =====
async function loadAdmins() {
    try {
        // کش رو کاملاً غیرفعال میکنیم
        const response = await fetch('admins.json?' + Date.now(), {
            cache: 'no-store',
            headers: {
                'Cache-Control': 'no-cache, no-store, must-revalidate',
                'Pragma': 'no-cache',
                'Expires': '0'
            }
        });
        
        if (!response.ok) {
            throw new Error('فایل پیدا نشد');
        }
        
        const data = await response.json();
        
        // چک میکنیم که data.admins وجود داره و آرایه هست
        if (data && Array.isArray(data.admins) && data.admins.length > 0) {
            admins = data.admins;
        } else {
            // اگر فایل خالی یا بی‌فایده بود، از پیش‌فرض استفاده کن
            admins = [
                { username: "AliAsgharPZ", password: "09199621557Aa" }
            ];
        }
        
        console.log('✅ ادمین‌ها با موفقیت بارگذاری شدند:');
        console.log('📋 تعداد:', admins.length);
        console.log('📋 لیست:', admins);
        
        // ذخیره در localStorage برای مواقعی که اینترنت قطع هست
        try {
            localStorage.setItem('admins_backup', JSON.stringify(admins));
        } catch(e) {}
        
    } catch (e) {
        console.log('❌ خطا در بارگذاری admins.json:', e);
        
        // اگر نتونست از فایل بخونه، از localStorage یا پیش‌فرض استفاده کن
        try {
            const backup = localStorage.getItem('admins_backup');
            if (backup) {
                admins = JSON.parse(backup);
                console.log('📋 از localStorage بارگذاری شد:', admins);
            } else {
                admins = [
                    { username: "AliAsgharPZ", password: "09199621557Aa" }
                ];
            }
        } catch(e) {
            admins = [
                { username: "AliAsgharPZ", password: "09199621557Aa" }
            ];
        }
    }
    
    // حتماً یه چیزی برگردون
    return admins;
}

// ===== بارگذاری دوباره ادمین‌ها (برای رفرش) =====
async function refreshAdmins() {
    await loadAdmins();
    renderAdminList();
    showAdminMessage('✅ لیست ادمین‌ها بروزرسانی شد.', 'success');
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
    }, 4000);
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
                `<button class="btn-danger" data-index="${index}">❌ حذف</button>` : 
                '<span style="color:#0984e3;">🌟 مدیر اصلی</span>'}
        </div>
    `).join('');

    document.querySelectorAll('.admin-item .btn-danger').forEach(btn => {
        btn.addEventListener('click', function() {
            const index = parseInt(this.dataset.index);
            if (confirm(`آیا از حذف ادمین "${admins[index].username}" مطمئن هستید؟`)) {
                admins.splice(index, 1);
                renderAdminList();
                showAdminMessage('✅ ادمین با موفقیت حذف شد.', 'success');
                showAdminMessage('⚠️ برای ذخیره دائمی، فایل رو دانلود و در گیت‌هاب آپلود کن.', 'success');
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
                showAdminMessage(`✅ کلمه "${word.arabic}" با موفقیت حذف شد.`, 'success');
            }
        });
    });
}

// ===== توابع مدیریت =====
function addNewWord() {
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
        showAdminMessage('این کلمه قبلاً در دیتابیس وجود دارد.', 'error');
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
    showAdminMessage(`✅ کلمه "${word}" با موفقیت افزوده شد.`, 'success');
}

function addNewAdmin() {
    if (!currentAdmin) {
        showAdminMessage('لطفاً ابتدا وارد شوید.', 'error');
        return;
    }

    if (currentAdmin.username !== 'AliAsgharPZ') {
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
    showAdminMessage(`✅ ادمین "${username}" با موفقیت اضافه شد.`, 'success');
    showAdminMessage('⚠️ برای ذخیره دائمی، روی دکمه دانلود کلیک و فایل رو در گیت‌هاب آپلود کن.', 'success');
}

// ===== سیستم لاگین =====
function login() {
    const username = loginUsername.value.trim();
    const password = loginPassword.value.trim();

    console.log('🔍 لیست ادمین‌های موجود:', admins);
    console.log('🔍 تلاش برای ورود با:', username);

    // پیدا کردن ادمین
    const admin = admins.find(a => a.username === username && a.password === password);
    
    if (admin) {
        currentAdmin = admin;
        loginSection.style.display = 'none';
        adminContent.style.display = 'block';
        showAdminMessage(`✅ خوش آمدید ${admin.username}`, 'success');
        renderAdminList();
        renderTable(dictionary);
        loadLogo();
        console.log('✅ ورود موفق');
    } else {
        showLoginMessage('❌ نام کاربری یا رمز عبور اشتباه است.', 'error');
        console.log('❌ ادمین با این مشخصات پیدا نشد');
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

// ===== دانلود فایل‌ها =====
function downloadAdminsFile() {
    if (!currentAdmin) {
        showAdminMessage('لطفاً ابتدا وارد شوید.', 'error');
        return;
    }

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
    
    showAdminMessage('✅ فایل admins.json دانلود شد. حالا توی گیت‌هاب آپلودش کن.', 'success');
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
}

// ===== رویدادها =====
document.addEventListener('DOMContentLoaded', async function() {
    console.log('🚀 شروع بارگذاری...');
    
    // بارگذاری ادمین‌ها از سرور
    await loadAdmins();
    await loadDictionary();
    
    console.log('📋 لیست نهایی ادمین‌ها:', admins);
    console.log('📊 تعداد:', admins.length);
    
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
