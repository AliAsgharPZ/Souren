// ===== دیتابیس =====
let dictionary = [];

// ===== بارگذاری لغات از dictionary.json =====
async function loadDictionary() {
    try {
        const response = await fetch('dictionary.json');
        const data = await response.json();
        
        if (data.dictionary && data.dictionary.length > 0) {
            dictionary = data.dictionary;
        } else {
            dictionary = [
                { arabic: "كتاب", meanings: ["کتاب", "دفتر"], concept: "مجموعه‌ای از برگه‌های نوشته شده که به هم صحافی شده‌اند." },
                { arabic: "مدرسة", meanings: ["مدرسه", "آموزشگاه"], concept: "محلی برای آموزش و یادگیری دانش‌آموزان." },
                { arabic: "طالب", meanings: ["دانش‌آموز", "محصل", "طلب‌کننده"], concept: "شخصی که به دنبال علم یا چیزی می‌گردد." },
                { arabic: "معلم", meanings: ["معلم", "آموزگار"], concept: "کسی که علم و دانش را به دیگران می‌آموزد." },
                { arabic: "سلام", meanings: ["سلام", "درود", "صلح"], concept: "درود و تحیت، همچنین به معنای صلح و امنیت." }
            ];
        }
    } catch (e) {
        console.log('خطا در بارگذاری dictionary.json:', e);
        dictionary = [
            { arabic: "كتاب", meanings: ["کتاب", "دفتر"], concept: "مجموعه‌ای از برگه‌های نوشته شده که به هم صحافی شده‌اند." },
            { arabic: "مدرسة", meanings: ["مدرسه", "آموزشگاه"], concept: "محلی برای آموزش و یادگیری دانش‌آموزان." },
            { arabic: "طالب", meanings: ["دانش‌آموز", "محصل", "طلب‌کننده"], concept: "شخصی که به دنبال علم یا چیزی می‌گردد." },
            { arabic: "معلم", meanings: ["معلم", "آموزگار"], concept: "کسی که علم و دانش را به دیگران می‌آموزد." },
            { arabic: "سلام", meanings: ["سلام", "درود", "صلح"], concept: "درود و تحیت، همچنین به معنای صلح و امنیت." }
        ];
    }
    return dictionary;
}

function normalizeArabic(text) {
    const map = {
        'ك': 'ک', 'ي': 'ی', 'ة': 'ه', 'أ': 'ا', 'إ': 'ا', 'آ': 'ا',
        'َ': '', 'ُ': '', 'ِ': '', 'ّ': '', 'ْ': '', 'ً': '', 'ٍ': '', 'ٌ': ''
    };
    return text.split('').map(ch => map[ch] || ch).join('');
}

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

function renderCards(words) {
    const resultsDiv = document.getElementById('results');
    if (!resultsDiv) return;

    if (!words || words.length === 0) {
        resultsDiv.innerHTML = `<div class="no-result">🔍 نتیجه‌ای یافت نشد</div>`;
        resultsDiv.classList.add('active');
        return;
    }

    let html = '';
    words.forEach((item, index) => {
        const meaningsHtml = item.meanings.map(m => `<span>${m}</span>`).join(' ');
        html += `
            <div class="card-item" data-index="${index}">
                <div class="card-word">${item.arabic}</div>
                <div class="card-meanings">${meaningsHtml}</div>
                ${item.concept ? `<div class="card-concept">${item.concept}</div>` : ''}
            </div>
        `;
    });

    resultsDiv.innerHTML = html;
    resultsDiv.classList.add('active');

    document.querySelectorAll('.card-item').forEach((card) => {
        card.addEventListener('click', function() {
            const index = parseInt(this.dataset.index);
            const word = words[index];
            if (word) {
                openModal(word);
            }
        });
    });
}

function openModal(word) {
    const modal = document.getElementById('wordModal');
    const modalBody = document.getElementById('modalBody');
    
    const meaningsHtml = word.meanings.map(m => `<span>${m}</span>`).join(' ');
    modalBody.innerHTML = `
        <div class="modal-word">${word.arabic}</div>
        <div class="modal-meanings">${meaningsHtml}</div>
        ${word.concept ? `
            <div class="modal-concept">
                <strong>📘 مفهوم:</strong><br>
                ${word.concept}
            </div>
        ` : ''}
    `;
    
    modal.style.display = 'block';
}

function closeModal() {
    document.getElementById('wordModal').style.display = 'none';
}

function performSearch() {
    const searchBox = document.getElementById('searchBox');
    const searchWrapper = document.getElementById('searchWrapper');
    const resultsDiv = document.getElementById('results');
    const query = searchBox.value;
    
    if (query.trim()) {
        searchWrapper.classList.add('move-up');
        const results = searchDictionary(query);
        renderCards(results);
    } else {
        searchWrapper.classList.remove('move-up');
        resultsDiv.innerHTML = '';
        resultsDiv.classList.remove('active');
    }
}

function saveLogo(svgData) {
    try {
        localStorage.setItem('logo_data', svgData);
    } catch (e) {
        console.log('ذخیره لوگو ممکن نیست.');
    }
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
    } catch (e) {
        console.log('بارگذاری لوگو ممکن نیست.');
    }
}

document.addEventListener('DOMContentLoaded', async function() {
    await loadDictionary();
    loadLogo();
    
    const searchBox = document.getElementById('searchBox');
    const searchBtn = document.getElementById('searchBtn');
    const resultsDiv = document.getElementById('results');
    
    resultsDiv.innerHTML = '';
    resultsDiv.classList.remove('active');

    searchBox.addEventListener('input', function() {
        performSearch();
    });

    searchBtn.addEventListener('click', function() {
        performSearch();
    });

    searchBox.addEventListener('keypress', function(e) {
        if (e.key === 'Enter') {
            e.preventDefault();
            performSearch();
        }
    });

    const modal = document.getElementById('wordModal');
    const closeBtn = document.querySelector('.close-modal');
    
    if (closeBtn) {
        closeBtn.addEventListener('click', closeModal);
    }
    
    if (modal) {
        modal.addEventListener('click', function(e) {
            if (e.target === this) {
                closeModal();
            }
        });
    }
});
