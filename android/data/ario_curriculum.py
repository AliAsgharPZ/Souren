"""Deterministic 1-100 dictionary levels and Ario curriculum generator.

Frequency is an explicitly labelled estimate, not a claim of measured corpus counts:
a few exact top-100 Riyadh List matches are anchored; common learner vocabulary
uses a curated ordering; all remaining ranks use transparent lexical heuristics.
Difficulty combines length, morphology, polysemy and semantic-domain load.
"""
import math

CORE_ORDER = [
  "سلام",
  "كتاب",
  "مدرسة",
  "طالب",
  "معلم",
  "انسان",
  "عمل",
  "حق",
  "سبب",
  "رئیس",
  "جواب",
  "سوال",
  "خبر",
  "اسم",
  "حال",
  "عالم",
  "دنيا",
  "سفر",
  "سلامت",
  "رابطه",
  "ارتباط",
  "اجازه",
  "احتمال",
  "احساس",
  "اختلاف",
  "اختيار",
  "اساس",
  "اصل",
  "اطلاع",
  "اطلاعات",
  "اعتماد",
  "افراد",
  "اقدام",
  "امتحان",
  "امکان",
  "انتخاب",
  "انتظار",
  "اهمیت",
  "بحث",
  "بنا",
  "بیان",
  "تاریخ",
  "تحقیق",
  "ترتیب",
  "تشکر",
  "تصمیم",
  "تصویر",
  "تعلیم",
  "تفاوت",
  "تمام",
  "تمرین",
  "توجه",
  "توضیح",
  "تولید",
  "جامعه",
  "جلسه",
  "جماعت",
  "جمعیت",
  "جنس",
  "جهت",
  "حرکت",
  "حساب",
  "حقیقت",
  "حکومت",
  "حمایت",
  "حیوان",
  "حرف",
  "حکم",
  "حمله",
  "خدمت",
  "خلاصه",
  "دلیل",
  "دین",
  "ذهن",
  "راحت",
  "رسم",
  "رضایت",
  "ساعت",
  "سرعت",
  "سطح",
  "شخص",
  "شرط",
  "شغل",
  "شکل",
  "صبر",
  "صحبت",
  "صورت",
  "صفحه",
  "صفت",
  "ضرر",
  "ضرورت",
  "ضعیف",
  "طبیعت",
  "طرف",
  "طلب",
  "طول",
  "ظاهر",
  "ظلم",
  "عادت",
  "عدالت",
  "عدد",
  "عشق",
  "عصر",
  "عقل",
  "علم",
  "عمر",
  "عنوان",
  "عید",
  "غریب",
  "غلط",
  "فرصت",
  "فساد",
  "فصل",
  "فضا",
  "فقط",
  "اثر",
  "اداره",
  "ادامه",
  "ادب",
  "ادعا",
  "اذیت",
  "اراده",
  "ارث",
  "اشاره",
  "اضافه",
  "اطاعت",
  "اظهار",
  "اعتراف",
  "اعتیاد",
  "ازدواج",
  "استفاده",
  "انتشار",
  "اضطراب",
  "اطمینان",
  "انعطاف",
  "اخلاق",
  "اخلاقی",
  "استراحت",
  "استقبال",
  "استقلال",
  "اقتصاد",
  "تجارت",
  "ثروت",
  "جهان",
  "زندگی"
]
RIYADH_TOP100 = {"عمل": 38, "رئیس": 39, "كتاب": 71, "حق": 74}
CATEGORY_PENALTY = {"health": 2, "edu": 2, "faith": 2, "state": 2, "money": 1, "work": 1, "lang": 1, "nature": 1, "home": 0, "mind": 1, "time": 0, "travel": 0, "general": 0}
PHASES = [
  "پایه و آشنایی",
  "زندگی روزمره",
  "ارتباط و بیان",
  "یادگیری و کار",
  "جامعه و جهان",
  "اندیشه و احساس",
  "فرهنگ و آیین",
  "مفاهیم و استدلال",
  "دانش و تخصص",
  "ظرافت‌های واژگانی"
]

def _round_positive(value):
    return int(value + 0.5)

def level_dictionary(entries, categories):
    category_of = {word: category for category, words in categories.items() for word in words}
    core_rank = {word: index + 1 for index, word in enumerate(CORE_ORDER)}
    scored = []
    for entry in entries:
        word = entry["ar"]
        length = len(word)
        prefix = int(word.startswith(("است", "ان", "الت", "اضم")))
        rare = sum(1 for char in "ثذظضغخق" if char in word)
        category_penalty = CATEGORY_PENALTY.get(category_of.get(word, "general"), 0)
        frequency_rank = RIYADH_TOP100.get(word)
        if frequency_rank is None:
            frequency_rank = 100 + core_rank[word] if word in core_rank else min(5000, 260 + length * 48 + prefix * 170 + rare * 22 + category_penalty * 35)
        frequency_score = _round_positive(100 * math.log1p(frequency_rank) / math.log1p(5000))
        difficulty = min(100, 8 + length * 4 + prefix * 11 + rare * 2 + max(0, len(entry.get("fa", [])) - 1) * 3 + category_penalty * 4)
        score = frequency_score * 0.62 + difficulty * 0.38
        method = "riyadh_top100" if word in RIYADH_TOP100 else "curated_core" if word in core_rank else "lexical_estimate"
        band = "بسیار رایج" if frequency_rank <= 100 else "رایج" if frequency_rank <= 500 else "میانه" if frequency_rank <= 1500 else "کم‌کاربرد" if frequency_rank <= 3000 else "نادر"
        metadata = {"frequencyRankEstimate": frequency_rank, "difficultyScore": difficulty, "frequencyMethod": method, "frequencyBand": band}
        scored.append((score, frequency_rank, difficulty, word, metadata))
    ordered = sorted(scored, key=lambda row: (row[0], row[1], row[2], row[3]))
    levels = {row[3]: min(100, (index * 100) // len(ordered) + 1) for index, row in enumerate(ordered)}
    metadata_by_word = {row[3]: row[4] for row in scored}
    result = []
    for entry in entries:
        enriched = dict(entry)
        enriched.update(metadata_by_word[entry["ar"]])
        enriched["level"] = levels[entry["ar"]]
        result.append(enriched)
    return result

def build_curriculum(entries):
    by_level = {level: [] for level in range(1, 101)}
    for entry in entries:
        by_level[entry["level"]].append(entry["ar"])
    stages = []
    for level in range(1, 101):
        words = by_level[level]
        phase = (level - 1) // 10
        exercises = []
        for index, word in enumerate(words, 1):
            exercises.extend([
                {"id": f"s{level}-e{index}-ar-fa", "type": "arabic_to_persian_choice", "entryId": word},
                {"id": f"s{level}-e{index}-fa-ar", "type": "persian_to_arabic_recall", "entryId": word},
                {"id": f"s{level}-e{index}-meaning", "type": "meaning_recall", "entryId": word},
            ])
        stages.append({
            "id": f"stage-{level:03d}", "level": level, "title": f"مرحلهٔ {level}",
            "phase": phase + 1, "phaseTitle": PHASES[phase],
            "units": [{
                "id": f"unit-{level:03d}", "title": f"واحد {level}",
                "lessons": [{
                    "id": f"lesson-{level:03d}", "title": f"درس {level}",
                    "sections": [
                        {"id": "learn", "title": "آشنایی با واژه‌ها", "type": "learn", "entryIds": words},
                        {"id": "recall", "title": "یادآوری و بازیابی", "type": "recall", "entryIds": words},
                        {"id": "practice", "title": "تمرین و سنجش", "type": "practice", "entryIds": words, "exercises": exercises},
                    ],
                }],
            }],
        })
    return {
        "version": 1, "source": "Generated from the shared 552-entry leveled dictionary; every stage maps to exactly one dictionary level.",
        "levelCount": 100, "entryCount": len(entries),
        "phases": [{"id": i + 1, "title": title, "firstLevel": i * 10 + 1, "lastLevel": (i + 1) * 10} for i, title in enumerate(PHASES)],
        "stages": stages,
    }
