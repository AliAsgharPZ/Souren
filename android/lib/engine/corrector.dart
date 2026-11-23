/// Souren correction engine v2 (Dart mirror of the Android IME engine).
///
/// Orthography rules (researched from Persian orthography references —
/// academy-style ZWNJ rules):
///  1. Arabic-script letters normalized to Persian (ي ك ة أ إ …).
///  2. «می/نمی» + verb stem joined with ZWNJ (guarded by a stem list so
///     nouns like میدان/میراث are untouched): میرم → می‌رم، میخام → می‌خوام.
///  3. Superlative/comparative suffixes with ZWNJ: عالیترین → عالی‌ترین،
///     گرمتر → گرم‌تر — except the five fused words بهتر، کمتر، بیشتر،
///     مهتر، کهتر (and their ترین forms) which stay attached.
///  4. Attached plural «ها» split with ZWNJ: کتابها → کتاب‌ها (تنها exempt).
///  5. Past-perfect endings after ه: رفتهام → رفته‌ام، خوابیدهاید → خوابیده‌اید.
///  6. Possessive clitics after ه/ی-final stems: خانهاش → خانه‌اش،
///     کشتیشان → کشتی‌شان.
///  7. «شده» compounds: گمشده → گم‌شده.
///  8. «بی» prefix before known stems: بینهایت → بی‌نهایت، بیابرو → بی‌آبرو.
///  9. Standalone «ها/های» merged to the previous word with ZWNJ.
/// 10. Ezafe after ه-final heads: همه افراد → همهٔ افراد (also همه‌ی → همهٔ).
/// 11. Optional Arabic→Persian replacement from the dictionary.
library;

const String zwnj = '\u200C';
const String hamzaAbove = '\u0654'; // ٔ

const Map<String, String> _letterFix = {
  'ي': 'ی', 'ى': 'ی', 'ك': 'ک', 'ة': 'ه', 'ۀ': 'هٔ',
  'أ': 'ا', 'إ': 'ا', 'ٱ': 'ا', 'ؤ': 'و',
  // Arabic-Indic digits typed through imported layouts become Persian digits.
  '٠': '۰', '١': '۱', '٢': '۲', '٣': '۳', '٤': '۴',
  '٥': '۵', '٦': '۶', '٧': '۷', '٨': '۸', '٩': '۹',
};

String normalizeLetters(String s) {
  var out = s;
  _letterFix.forEach((k, v) => out = out.replaceAll(k, v));
  return out;
}

const Map<String, String> _stemFix = {
  'خام': 'خوام', 'خاد': 'خواهد', 'خان': 'خوان',
};

/// Words that start with می/نمی but are NOT verbs.
const Set<String> miExceptions = {
  'میدان', 'میدون', 'میخک', 'میهن', 'میان', 'میوه', 'میراث',
};

/// Present-tense verb stem beginnings used to recognize می/نمی verbs.
const List<String> verbStemStarts = [
  'خواه', 'خوا', 'آی', 'آور', 'آفرین', 'افکن', 'فکن', 'انداز', 'انگیز',
  'دون', 'دان', 'تون', 'توان', 'بین', 'گیر', 'ذار', 'زار', 'گذار', 'گزار',
  'خور', 'خر', 'نویس', 'نوش', 'نشین', 'خند', 'گری', 'گریز', 'فهم', 'سوز',
  'سوزان', 'خون', 'ساز', 'پرس', 'پرست', 'گرد', 'گشا', 'زن', 'گو', 'گوی',
  'شو', 'کن', 'ده', 'نه', 'دو', 'رم', 'رو', 'روی', 'رس', 'ره', 'شه',
  'گه', 'پر', 'جه', 'بار', 'باف', 'بند', 'بر', 'بوس', 'پاش', 'پذیر',
  'پوش', 'پیچ', 'تاب', 'تراش', 'ترس', 'جوش', 'چرخ', 'چسب', 'چین',
  'دار', 'دم', 'دوش', 'ران', 'رقص', 'ریز', 'ستان', 'سرا', 'شتاب',
  'شکاف', 'شمار', 'شناس', 'طلب', 'غلت', 'فرست', 'فروش', 'فشار',
  'کار', 'کش', 'کوش', 'کوب', 'لرز', 'مان', 'مال', 'مک', 'نال',
];

/// Fused comparatives that must NOT be split (academy rule).
const Set<String> fusedComparatives = {
  'بهتر', 'کمتر', 'بیشتر', 'مهتر', 'کهتر',
  'بهترین', 'کمترین', 'بیشترین', 'مهترین', 'کهترین',
  'دختر', 'لیتر', 'باختر', 'کبوتر', 'انگشتر',
};

const Set<String> haExceptions = {'تنها', 'آنها', 'اینها'};

/// ه/ی-final stems whose possessive clitics split with ZWNJ.
const Set<String> cliticStems = {
  'خانه', 'سایه', 'صفحه', 'نامه', 'واژه', 'جمله', 'قصه', 'لحظه', 'هفته',
  'پنجره', 'خاطره', 'مسئله', 'بهانه', 'نشانه', 'کشتی', 'همه', 'مدرسه',
  'جعبه', 'سرمایه', 'پرده', 'زمینه', 'ستاره', 'شیشه', 'سکه', 'تکه',
  'حادثه', 'فاجعه', 'واقعه', 'صحنه', 'نغمه', 'شعله', 'قطره', 'نمره',
  'نقشه', 'چهره', 'جلوه', 'زاویه', 'قهوه', 'میوه', 'پایه', 'مایه',
  'رویه', 'لایه', 'کوچه', 'بوته', 'غنچه', 'جوانه', 'کرانه', 'ترانه',
  'افسانه', 'پیمانه', 'شکوفه', 'خاله', 'عمه', 'صندلی', 'بازی', 'ماهی',
  'گاری', 'دایی', 'نیمه', 'دهه', 'گونه',
};

const List<String> clitics = [
  'شان', 'تان', 'مان', 'شون', 'تون', 'مون', 'اش', 'ام', 'ات', 'م', 'ت', 'ش',
];

/// Stems after «بی» that take a ZWNJ.
const Set<String> biStems = {
  'آبرو', 'ابرو', 'نهایت', 'پایان', 'فرهنگ', 'ادب', 'انصاف', 'سواد',
  'شمار', 'اندازه', 'رحم', 'مزه', 'خبر', 'نام', 'نشان', 'رنگ', 'بو',
  'حیا', 'شرم', 'عقل', 'احتیاط', 'اختیار', 'اراده', 'اعتماد', 'امان',
  'باک', 'باور', 'بهره', 'پروا', 'پرده', 'پول', 'تاب', 'تجربه',
  'تردید', 'تکلف', 'توجه', 'ثبات', 'جا', 'چاره', 'حاصل', 'حال',
  'حساب', 'حس', 'خانمان', 'خواب', 'خود', 'درد', 'دریغ', 'دلیل',
  'دین', 'رقیب', 'روح', 'ریا', 'زبان', 'سابقه', 'سرپرست', 'سلیقه',
  'سود', 'شعور', 'شک', 'صاحب', 'صبر', 'صدا', 'ضرر', 'طرف', 'طاقت',
  'عاطفه', 'عرضه', 'علاقه', 'عیب', 'غرض', 'فایده', 'قاعده', 'قرار',
  'قید', 'کار', 'کس', 'گناه', 'لطف', 'محابا', 'مسئولیت', 'معرفت',
  'معنی', 'مغز', 'ملاحظه', 'منطق', 'موقع', 'نظم', 'نصیب', 'نقاب',
  'نظیر', 'نوا', 'نیاز', 'هدف', 'همتا', 'هنر', 'هوا', 'هوش',
  'واسطه', 'وفا', 'وقفه', 'سر',
};

/// Words ending in ه that take an ezafe (ٔ) before a following noun.
const Set<String> ezafeHeads = {
  'همه', 'خانه', 'صفحه', 'نامه', 'سایه', 'پنجره', 'هفته', 'لحظه',
  'نکته', 'واژه', 'جمله', 'قصه', 'خاطره', 'مسئله', 'بهانه', 'نشانه',
  'مدرسه', 'چهره', 'جلوه', 'زاویه', 'قهوه', 'میوه', 'پایه', 'مایه',
  'لایه', 'رویه', 'کوچه', 'بوته', 'غنچه', 'جوانه', 'کرانه', 'ترانه',
  'افسانه', 'پیمانه', 'شکوفه', 'حادثه', 'فاجعه', 'واقعه', 'صحنه',
  'نغمه', 'شعله', 'قطره', 'نمره', 'نقشه', 'سکه', 'تکه', 'شیشه',
  'ستاره', 'زمینه', 'پرده', 'سرمایه', 'جعبه', 'نیمه', 'کلیه', 'عده',
  'دهه', 'سده', 'گونه', 'رده', 'مرحله', 'ناحیه', 'قاره', 'جزیره',
};

class WordFix {
  final String fixed;
  final List<String> suggestions;
  const WordFix(this.fixed, [this.suggestions = const []]);
}

String _splitBefore(String w, String suffix) =>
    '${w.substring(0, w.length - suffix.length)}$zwnj$suffix';

String correctionLearningKey(
  String from,
  String left,
  String right,
  String candidate,
) => [from, left, right, candidate].map(normalizeLetters).join('\u001F');

WordFix correctWord(
  String word, {
  Map<String, List<String>> dictionary = const {},
  bool replaceArabic = true,
  Map<String, int> learnedPairs = const {},
  String leftContext = '',
  String rightContext = '',
}) {
  var w = normalizeLetters(word);
  final suggestions = <String>[];

  // ه‌ی → هٔ
  if (w.endsWith('ه‌ی')) {
    w = '${w.substring(0, w.length - 2)}ه$hamzaAbove';
  }
  // Attached ezafe ی after a known ه-final head: همهی → همهٔ
  if (w.length > 2 && w.endsWith('ی') && !w.contains(hamzaAbove)) {
    final stem = w.substring(0, w.length - 1);
    if (ezafeHeads.contains(stem)) w = '$stem$hamzaAbove';
  }

  // می/نمی + verb stem (guarded).
  if (!miExceptions.contains(w)) {
    for (final prefix in ['نمی', 'می']) {
      if (w.startsWith(prefix) &&
          w.length > prefix.length + 1 &&
          !w.contains(zwnj)) {
        final rest = w.substring(prefix.length);
        final stemmed = _stemFix.containsKey(rest)
            ? _stemFix[rest]
            : (verbStemStarts.any((s) => rest.startsWith(s)) ? rest : null);
        if (stemmed != null) w = '$prefix$zwnj$stemmed';
        break;
      }
    }
  }
  // Stem fix inside an existing ZWNJ form: می‌خام → می‌خوام
  final parts = w.split(zwnj);
  if (parts.length == 2 && (parts[0] == 'می' || parts[0] == 'نمی')) {
    final stem = _stemFix[parts[1]];
    if (stem != null) w = '${parts[0]}$zwnj$stem';
  }

  // ترین / تر suffixes.
  if (!fusedComparatives.contains(w) && !w.contains(zwnj)) {
    if (w.endsWith('ترین') && w.length > 5) {
      w = _splitBefore(w, 'ترین');
    } else if (w.endsWith('تر') && w.length > 4) {
      w = _splitBefore(w, 'تر');
    }
  }

  // Attached ها plural.
  if (!haExceptions.contains(w) &&
      w.endsWith('ها') &&
      w.length > 3 &&
      !w.contains(zwnj)) {
    w = _splitBefore(w, 'ها');
  }

  // Past-perfect endings after ه: رفته‌ام pattern.
  if (!w.contains(zwnj)) {
    for (final ending in ['است', 'ایم', 'اید', 'اند', 'ام', 'ای']) {
      if (w.endsWith(ending)) {
        final stem = w.substring(0, w.length - ending.length);
        if (stem.endsWith('ه') && stem.length >= 3) {
          w = '$stem$zwnj$ending';
        }
        break;
      }
    }
  }

  // Possessive clitics after known ه/ی stems.
  if (!w.contains(zwnj)) {
    for (final c in clitics) {
      if (w.endsWith(c) && w.length > c.length + 2) {
        final stem = w.substring(0, w.length - c.length);
        if (cliticStems.contains(stem)) {
          w = '$stem$zwnj$c';
          break;
        }
      }
    }
  }

  // شده compounds.
  if (w.endsWith('شده') && w.length - 3 >= 2 && !w.contains(zwnj)) {
    w = _splitBefore(w, 'شده');
  }

  // بی prefix before known stems.
  if (w.startsWith('بی') && w.length > 4 && !w.contains(zwnj)) {
    final rest = w.substring(2);
    if (biStems.contains(rest)) w = 'بی$zwnj$rest';
  }

  // Dictionary: Arabic word → Persian equivalents. Replacement used to
  // require exactly ONE equivalent, so any word with two or more
  // equivalents (اتفاق ← رویداد/پیشامد) never got replaced. Now the
  // first single-word equivalent wins; phrasal ones stay suggestions.
  final eq = dictionary[w] ?? dictionary[word] ?? dictionary[normalizeLetters(word)];
  if (eq != null && eq.isNotEmpty) {
    final ranked = eq.asMap().entries.toList()
      ..sort((a, b) {
        final scoreA = learnedPairs[correctionLearningKey(
              word, leftContext, rightContext, a.value)] ??
            0;
        final scoreB = learnedPairs[correctionLearningKey(
              word, leftContext, rightContext, b.value)] ??
            0;
        final byScore = scoreB.compareTo(scoreA);
        return byScore != 0 ? byScore : a.key.compareTo(b.key);
      });
    suggestions.addAll(ranked.map((entry) => entry.value));
    if (replaceArabic) {
      final candidates = ranked
          .where((entry) =>
              !entry.value.contains(' ') && !entry.value.contains('،'))
          .toList();
      final preferred = candidates.isEmpty ? '' : candidates.first.value;
      if (preferred.isNotEmpty && preferred != w) w = preferred;
    }
  }
  return WordFix(w, suggestions);
}

/// Leading/trailing marks around a word are preserved while the core is
/// sent through the spelling and dictionary rules.
const String _leadingMarks = '«"\'(‘“';
const String _trailingMarks = '»"\')’”،.؟!؛:…';

(String lead, String core, String trail) _splitMarks(String word) {
  var lead = '';
  var core = word;
  while (core.isNotEmpty && core.length > lead.length + 1) {
    final c = core[0];
    if (!_leadingMarks.contains(c)) break;
    lead += c;
    core = core.substring(1);
  }
  var trail = '';
  while (core.length > 1) {
    final c = core[core.length - 1];
    if (!_trailingMarks.contains(c)) break;
    trail = c + trail;
    core = core.substring(0, core.length - 1);
  }
  return (lead, core, trail);
}

/// Correct a full [text] without rewriting its separators. Spaces, repeated
/// spaces, tabs, newlines and whitespace before punctuation remain verbatim.
String correctText(
  String text, {
  Map<String, List<String>> dictionary = const {},
  bool replaceArabic = true,
  Map<String, int> learnedPairs = const {},
}) {
  var t = normalizeLetters(text);
  // This phrase rule is deliberately limited to one ordinary space.
  t = t.replaceAll('ساعت چند', 'چه زمانی');

  final wordRe = RegExp(r'\S+');
  final matches = wordRe.allMatches(t).toList();
  if (matches.isEmpty) return t;

  final words = matches.map((m) => m.group(0)!).toList();
  final out = <String>[];
  final separators = <String>[];

  for (var i = 0; i < words.length; i++) {
    final sepBefore = i == 0
        ? ''
        : t.substring(matches[i - 1].end, matches[i].start);
    var token = words[i];

    // Merge «ها/های/هایی» only across one ordinary space.
    if ((token == 'ها' || token == 'های' || token == 'هایی') &&
        out.isNotEmpty &&
        sepBefore == ' ') {
      out[out.length - 1] = out[out.length - 1] + zwnj + token;
      continue;
    }

    final (lead, core, trail) = _splitMarks(token);
    final leftContext = i > 0 ? _splitMarks(words[i - 1]).$2 : '';
    final rightContext =
        i + 1 < words.length ? _splitMarks(words[i + 1]).$2 : '';
    final fix = correctWord(
      core,
      dictionary: dictionary,
      replaceArabic: replaceArabic,
      learnedPairs: learnedPairs,
      leftContext: leftContext,
      rightContext: rightContext,
    );
    token = lead + fix.fixed + trail;

    if (out.isNotEmpty && sepBefore == ' ') {
      final previous = out.last;
      final previousBare = previous.replaceAll(hamzaAbove, '');
      if (previous.endsWith('ه') &&
          ezafeHeads.contains(previousBare) &&
          core.length >= 2) {
        out[out.length - 1] = previous + hamzaAbove;
      }
    }

    if (out.isNotEmpty) separators.add(sepBefore);
    out.add(token);
  }

  final result = StringBuffer(t.substring(0, matches.first.start));
  for (var i = 0; i < out.length; i++) {
    result.write(out[i]);
    if (i < separators.length) result.write(separators[i]);
  }
  result.write(t.substring(matches.last.end));
  return result.toString();
}
