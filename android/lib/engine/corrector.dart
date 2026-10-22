/// Souren correction engine (Dart mirror of the Android IME engine).
///
/// Rules, in order:
///  1. Arabic-script letters normalized to Persian (ي ك ة أ إ …).
///  2. «می/نمی» verb prefix joined with a ZWNJ: میرم → می‌رم.
///  3. Colloquial خواه-spelling fixed after the prefix: میخام/میخوام → می‌خوام.
///  4. Standalone «ها/های» merged to the previous word with a ZWNJ.
///  5. Ezafe after ه-final heads: همه افراد → همهٔ افراد (also همه‌ی → همهٔ).
///  6. Optional Arabic→Persian replacement from the dictionary:
///     only single-word equivalents auto-apply; longer ones are suggestions.
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

/// Verb stems whose colloquial spelling drops the و.
const Map<String, String> _stemFix = {
  'خام': 'خوام', 'خاد': 'خواهد', 'خان': 'خوان',
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

/// Correct one already-typed [word]; [prev] is the word before it
/// (used for the «ها» merge decision at text level, not here).
WordFix correctWord(String word,
    {Map<String, List<String>> dictionary = const {}, bool replaceArabic = true}) {
  var w = normalizeLetters(word);
  final suggestions = <String>[];

  // Rule: ه‌ی → هٔ (ezafe written with ی)
  if (w.endsWith('ه‌ی')) {
    w = '${w.substring(0, w.length - 2)}ه$hamzaAbove';
  } else if (w.endsWith('هی')) {
    w = '${w.substring(0, w.length - 1)}ٔ';
  }

  // Rule: می/نمی prefix + stem.
  for (final prefix in ['نمی', 'می']) {
    if (w.startsWith(prefix) && w.length > prefix.length + 1 && !w.contains(zwnj)) {
      var stem = w.substring(prefix.length);
      stem = _stemFix[stem] ?? stem;
      w = '$prefix$zwnj$stem';
      break;
    }
  }
  // Also fix the stem inside an already-ZWNJ form: می‌خام → می‌خوام
  final parts = w.split(zwnj);
  if (parts.length == 2 && (parts[0] == 'می' || parts[0] == 'نمی')) {
    final stem = _stemFix[parts[1]];
    if (stem != null) w = '${parts[0]}$zwnj$stem';
  }

  // Dictionary: Arabic word → Persian equivalents.
  final eq = dictionary[w] ?? dictionary[word];
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
  // Punctuation spacing: no space before ، . ؟ ! ؛ :
  t = t.replaceAllMapped(
      RegExp(r'\s+([،.؟!؛:])'), (m) => m.group(1)!);
  final tokens = t.split(' ');
  final out = <String>[];
  for (var i = 0; i < tokens.length; i++) {
    var tok = tokens[i];
    if (tok.isEmpty) continue;
    // Rule: standalone ها/های merges to previous word with ZWNJ.
    if ((tok == 'ها' || tok == 'های' || tok == 'هایی') && out.isNotEmpty) {
      out[out.length - 1] = '${out.last}$zwnj$tok';
      continue;
    }
    final fix = correctWord(tok, dictionary: dictionary, replaceArabic: replaceArabic);
    tok = fix.fixed;
    // Rule: ezafe — previous word is an ه-final head, current word is a
    // following noun (heuristic: alphabetic token, length ≥ 2).
    if (out.isNotEmpty) {
      final prev = out.last;
      final prevBare = prev.replaceAll(hamzaAbove, '');
      if (prev.endsWith('ه') &&
          ezafeHeads.contains(prevBare) &&
          tok.length >= 2 &&
          !tok.startsWith(zwnj)) {
        out[out.length - 1] = '$prev$hamzaAbove';
      }
    }
    out.add(tok);
  }
  return out.join(' ');
}
