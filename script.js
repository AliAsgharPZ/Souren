// ===== سورن — اسکریپت صفحهٔ معرفی (فقط نمایش؛ هیچ قابلیت تعاملی‌ای نیست) =====
// کارها: انیمیشن پیدا شدن بخش‌ها و خواندن تازه‌ترین نسخهٔ اندروید از
// انتشارهای گیت‌هاب تا دکمهٔ دانلود همیشه به تازه‌ترین APK برسد.

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

// ===== ارقام فارسی =====
function faNum(n) {
    const d = ['۰', '۱', '۲', '۳', '۴', '۵', '۶', '۷', '۸', '۹'];
    return String(n).replace(/[0-9]/g, (c) => d[+c]).replace(/,/g, '٬');
}

// ===== یافتن تازه‌ترین APK از انتشارهای گیت‌هاب =====
// در صورت خطا، دکمه‌ها همان پیوند صفحهٔ انتشارها را نگه می‌دارند.
async function resolveLatestApk() {
    try {
        const ctrl = ('AbortController' in window) ? new AbortController() : null;
        const timer = ctrl ? setTimeout(() => ctrl.abort(), 10000) : null;
        const res = await fetch('https://api.github.com/repos/AliAsgharPZ/Souren/releases/latest',
            ctrl ? { signal: ctrl.signal } : undefined);
        if (timer) clearTimeout(timer);
        if (!res.ok) return;
        const rel = await res.json();
        const asset = (rel.assets || []).find((a) => a.name && a.name.toLowerCase().endsWith('.apk'));
        if (asset && asset.browser_download_url) {
            document.querySelectorAll('.apk-btn').forEach((b) => {
                b.setAttribute('href', asset.browser_download_url);
            });
        }
        if (rel.tag_name) {
            const ver = 'نسخهٔ ' + faNum(String(rel.tag_name).replace(/^v/i, '')).replace(/\./g, '٫');
            const apkVersion = document.getElementById('apkVersion');
            if (apkVersion) apkVersion.textContent = '— ' + ver;
            const footerVersion = document.getElementById('footerVersion');
            if (footerVersion) footerVersion.textContent = 'نسخهٔ کنونی اندروید: ' + ver;
        }
    } catch (e) {
        /* پیوند جایگزین (صفحهٔ انتشارها) سر جایش می‌ماند */
    }
}

document.addEventListener('DOMContentLoaded', function () {
    window.__sourenBooted = true;
    initReveal();
    resolveLatestApk();
});
