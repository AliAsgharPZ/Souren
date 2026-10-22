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
  'ي': 'ی', 'ك': 'ک', 'ة': 'ه', 'ۀ': 'هٔ',
  'أ': 'ا', 'إ': 'ا', 'ٱ': 'ا', 'ؤ': 'و',
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
const Set<String> miExceptions = {'میدان', 'میدون'};

/// Present-tense verb stem beginnings used to recognize می/نمی verbs.
const List<String> verbStemStarts = [
  'خواه', 'خوا', 'دون', 'دان', 'تون', 'توان', 'بین', 'گیر', 'ذار', 'زار',
  'خور', 'نویس', 'خند', 'گری', 'فهم', 'سوز', 'خون', 'ساز', 'پرس', 'گرد',
  'زن', 'گو', 'شو', 'کن', 'ده', 'دو', 'رم', 'رو', 'رس', 'ره', 'شه',
  'گه', 'پر',
];

/// Fused comparatives that must NOT be split (academy rule).
const Set<String> fusedComparatives = {
  'بهتر', 'کمتر', 'بیشتر', 'مهتر', 'کهتر',
  'بهترین', 'کمترین', 'بیشترین', 'مهترین', 'کهترین',
  'دختر', 'لیتر', 'باختر',
};

const Set<String> haExceptions = {'تنها'};

/// ه/ی-final stems whose possessive clitics split with ZWNJ.
const Set<String> cliticStems = {
  'خانه', 'سایه', 'صفحه', 'نامه', 'واژه', 'جمله', 'قصه', 'لحظه', 'هفته',
  'پنجره', 'خاطره', 'مسئله', 'بهانه', 'نشانه', 'کشتی', 'همه', 'مدرسه',
  'جعبه', 'سرمایه', 'پرده', 'زمینه', 'ستاره', 'شیشه', 'سکه', 'تکه',
};

const List<String> clitics = ['شان', 'تان', 'مان', 'اش', 'ام', 'ات'];

/// Stems after «بی» that take a ZWNJ.
const Set<String> biStems = {
  'آبرو', 'ابرو', 'نهایت', 'پایان', 'فرهنگ', 'ادب', 'انصاف', 'سواد',
  'شمار', 'اندازه', 'رحم', 'مزه', 'خبر', 'نام', 'نشان', 'رنگ', 'بو',
  'حیا', 'شرم', 'عقلی',
};

/// Words ending in ه that take an ezafe (ٔ) before a following noun.
const Set<String> ezafeHeads = {
  'همه', 'خانه', 'صفحه', 'نامه', 'سایه', 'پنجره', 'هفته', 'لحظه',
  'نکته', 'واژه', 'جمله', 'قصه', 'خاطره', 'مسئله', 'بهانه', 'نشانه',
};

class WordFix {
  final String fixed;
  final List<String> suggestions;
  const WordFix(this.fixed, [this.suggestions = const []]);
}

String _splitBefore(String w, String suffix) =>
    '${w.substring(0, w.length - suffix.length)}$zwnj$suffix';

WordFix correctWord(String word,
    {Map<String, List<String>> dictionary = const {}, bool replaceArabic = true}) {
  var w = normalizeLetters(word);
  final suggestions = <String>[];

  // ه‌ی → هٔ
  if (w.endsWith('ه‌ی')) {
    w = '${w.substring(0, w.length - 2)}ه$hamzaAbove';
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
    for (final ending in ['ایم', 'اید', 'اند', 'ام', 'ای']) {
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

  // Dictionary: Arabic word → Persian equivalents.
  final eq = dictionary[w] ?? dictionary[word] ?? dictionary[normalizeLetters(word)];
  if (eq != null && eq.isNotEmpty) {
    suggestions.addAll(eq);
    if (replaceArabic && eq.length == 1 && !eq.first.contains(' ') && !eq.first.contains('،')) {
      w = eq.first;
    }
  }
  return WordFix(w, suggestions);
}

/// Correct a full [text]: word fixes + ها-merge + ezafe + spacing.
String correctText(String text,
    {Map<String, List<String>> dictionary = const {}, bool replaceArabic = true}) {
  var t = normalizeLetters(text);
  t = t.replaceAllMapped(
      RegExp(r'\s+([،.؟!؛:])'), (m) => m.group(1)!);
  final tokens = t.split(' ');
  final out = <String>[];
  for (var i = 0; i < tokens.length; i++) {
    var tok = tokens[i];
    if (tok.isEmpty) continue;
    if ((tok == 'ها' || tok == 'های' || tok == 'هایی') && out.isNotEmpty) {
      out[out.length - 1] = '${out.last}$zwnj$tok';
      continue;
    }
    final fix = correctWord(tok, dictionary: dictionary, replaceArabic: replaceArabic);
    tok = fix.fixed;
    if (out.isNotEmpty) {
      final prev = out.last;
      final prevBare = prev.replaceAll(hamzaAbove, '');
      if (prev.endsWith('ه') &&
          ezafeHeads.contains(prevBare) &&
          tok.length >= 2) {
        out[out.length - 1] = '$prev$hamzaAbove';
      }
    }
    out.add(tok);
  }
  return out.join(' ');
}
