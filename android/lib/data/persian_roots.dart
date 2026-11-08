import 'package:flutter/foundation.dart';

import 'store.dart';

/// A Persian lexical item linked back to every dictionary entry in which
/// the Persian equivalent occurs. No Arabic-root corpus is used here.
@immutable
class PersianLexeme {
  final String word;
  final String base;
  final Set<String> sourceEntries;

  const PersianLexeme({
    required this.word,
    required this.base,
    required this.sourceEntries,
  });

  int get sourceCount => sourceEntries.length;
}

/// A conservative Persian morphology index. It identifies inflectional
/// bases (plural/comparative forms), not historical etymologies. The UI
/// labels these as structural base forms so a guess is never presented
/// as a proven linguistic origin.
class PersianRoots {
  static const _suffixes = <String>[
    'هایشان', 'هایمان', 'هایتان', 'هایش', 'هایم', 'هایت',
    'ترین', 'های', 'گان', 'ها',
  ];

  static String normalize(String value) => value
      .trim()
      .replaceAll('ي', 'ی')
      .replaceAll('ك', 'ک')
      .replaceAll('\u200c', '')
      .replaceAll(RegExp(r'[\u064B-\u065F\u0670\u0640]'), '')
      .replaceAll(RegExp(r'\s+'), ' ');

  static String baseOf(String value) {
    final word = normalize(value);
    for (final suffix in _suffixes) {
      if (word.endsWith(suffix)) {
        final base = word.substring(0, word.length - suffix.length);
        if (base.runes.length >= 3) return base;
      }
    }
    return word;
  }

  static List<PersianLexeme> index(Dictionary dictionary) {
    final sources = <String, Set<String>>{};
    for (final entry in dictionary.entries) {
      for (final raw in entry.fa) {
        final word = normalize(raw);
        if (word.isEmpty) continue;
        sources.putIfAbsent(word, () => <String>{}).add(entry.ar);
      }
    }
    final rows = sources.entries
        .map((e) => PersianLexeme(
              word: e.key,
              base: baseOf(e.key),
              sourceEntries: Set.unmodifiable(e.value),
            ))
        .toList()
      ..sort((a, b) => a.word.compareTo(b.word));
    return rows;
  }

  static List<PersianLexeme> search(
    List<PersianLexeme> rows,
    String query,
  ) {
    final q = normalize(query);
    if (q.isEmpty) return rows;
    return rows
        .where((row) =>
            row.word.contains(q) ||
            row.base.contains(q))
        .toList(growable: false);
  }

  static List<PersianLexeme> sameBase(
    List<PersianLexeme> rows,
    String word,
  ) {
    final selected = rows.where((e) => normalize(e.word) == normalize(word));
    if (selected.isEmpty) return const [];
    final base = selected.first.base;
    return rows.where((e) => e.base == base).toList(growable: false);
  }
}
