import 'dart:math' as math;

/// Review outcomes are stored only in the local Ario learning file.
enum ArioReviewRating { again, hard, good, easy }

class ArioReviewCard {
  final String wordId;
  final int dueAt;
  final int intervalMinutes;
  final int repetitions;
  final double easeFactor;
  final int lapses;
  final int reviews;
  final int lastReviewedAt;

  const ArioReviewCard({
    required this.wordId,
    required this.dueAt,
    this.intervalMinutes = 0,
    this.repetitions = 0,
    this.easeFactor = 2.5,
    this.lapses = 0,
    this.reviews = 0,
    this.lastReviewedAt = 0,
  });

  factory ArioReviewCard.initial(String wordId, DateTime now) =>
      ArioReviewCard(wordId: wordId, dueAt: now.millisecondsSinceEpoch);

  factory ArioReviewCard.fromJson(String wordId, Object? raw) {
    final json = raw is Map ? raw : const <Object?, Object?>{};
    int readInt(Object? value, [int fallback = 0]) =>
        value is num ? value.toInt() : fallback;
    final ease = json['easeFactor'];
    return ArioReviewCard(
      wordId: wordId,
      dueAt: readInt(json['dueAt']),
      intervalMinutes: readInt(json['intervalMinutes']),
      repetitions: readInt(json['repetitions']),
      easeFactor: (ease is num ? ease.toDouble() : 2.5).clamp(1.3, 3.0).toDouble(),
      lapses: readInt(json['lapses']),
      reviews: readInt(json['reviews']),
      lastReviewedAt: readInt(json['lastReviewedAt']),
    );
  }

  bool isDue(DateTime now) => dueAt <= now.millisecondsSinceEpoch;

  ArioReviewCard rate(ArioReviewRating rating, DateTime now) {
    var nextEase = easeFactor;
    var nextInterval = intervalMinutes;
    var nextRepetitions = repetitions;
    var nextLapses = lapses;

    switch (rating) {
      case ArioReviewRating.again:
        nextInterval = 10;
        nextRepetitions = 0;
        nextEase = (easeFactor - .2).clamp(1.3, 3.0).toDouble();
        nextLapses++;
        break;
      case ArioReviewRating.hard:
        nextInterval = (repetitions == 0 ? 720 : math.max(60, (intervalMinutes * 1.2).round())).toInt();
        nextRepetitions++;
        nextEase = (easeFactor - .15).clamp(1.3, 3.0).toDouble();
        break;
      case ArioReviewRating.good:
        nextInterval = repetitions == 0
            ? 1440
            : repetitions == 1
                ? 4320
                : math.max(1440, (intervalMinutes * easeFactor).round()).toInt();
        nextRepetitions++;
        break;
      case ArioReviewRating.easy:
        nextInterval = repetitions == 0
            ? 5760
            : repetitions == 1
                ? 8640
                : math.max(2880, (intervalMinutes * easeFactor * 1.3).round()).toInt();
        nextRepetitions++;
        nextEase = (easeFactor + .15).clamp(1.3, 3.0).toDouble();
        break;
    }

    return ArioReviewCard(
      wordId: wordId,
      dueAt: now.add(Duration(minutes: nextInterval)).millisecondsSinceEpoch,
      intervalMinutes: nextInterval,
      repetitions: nextRepetitions,
      easeFactor: nextEase,
      lapses: nextLapses,
      reviews: reviews + 1,
      lastReviewedAt: now.millisecondsSinceEpoch,
    );
  }

  Map<String, dynamic> toJson() => {
        'dueAt': dueAt,
        'intervalMinutes': intervalMinutes,
        'repetitions': repetitions,
        'easeFactor': easeFactor,
        'lapses': lapses,
        'reviews': reviews,
        'lastReviewedAt': lastReviewedAt,
      };
}

class ArioLabState {
  final Map<String, ArioReviewCard> cards;
  int freePracticeSessions;
  int mixedChallengeAttempts;
  int bestMixedScore;
  int flashcardsReviewed;
  int explorerSearches;

  ArioLabState({
    Map<String, ArioReviewCard>? cards,
    this.freePracticeSessions = 0,
    this.mixedChallengeAttempts = 0,
    this.bestMixedScore = 0,
    this.flashcardsReviewed = 0,
    this.explorerSearches = 0,
  }) : cards = cards ?? {};

  factory ArioLabState.fromJson(Object? raw) {
    if (raw is! Map) return ArioLabState();
    final rawCards = raw['cards'];
    final cards = <String, ArioReviewCard>{};
    if (rawCards is Map) {
      for (final entry in rawCards.entries) {
        final id = entry.key.toString();
        if (id.isNotEmpty) cards[id] = ArioReviewCard.fromJson(id, entry.value);
      }
    }
    int readInt(String key) {
      final value = raw[key];
      return value is num ? value.toInt().clamp(0, 1 << 30).toInt() : 0;
    }
    return ArioLabState(
      cards: cards,
      freePracticeSessions: readInt('freePracticeSessions'),
      mixedChallengeAttempts: readInt('mixedChallengeAttempts'),
      bestMixedScore: readInt('bestMixedScore').clamp(0, 100).toInt(),
      flashcardsReviewed: readInt('flashcardsReviewed'),
      explorerSearches: readInt('explorerSearches'),
    );
  }

  void ensureWords(Iterable<String> wordIds, {DateTime? now}) {
    final time = now ?? DateTime.now();
    for (final rawId in wordIds) {
      final id = rawId.trim();
      if (id.isEmpty) continue;
      cards.putIfAbsent(id, () => ArioReviewCard.initial(id, time));
    }
  }

  void rateWord(String wordId, ArioReviewRating rating, {DateTime? now}) {
    final id = wordId.trim();
    if (id.isEmpty) return;
    final time = now ?? DateTime.now();
    final card = cards[id] ?? ArioReviewCard.initial(id, time);
    cards[id] = card.rate(rating, time);
  }

  void recordQuiz({required int answers, required int correct, required bool mixed}) {
    final safeAnswers = answers.clamp(0, 10000).toInt();
    final safeCorrect = correct.clamp(0, safeAnswers).toInt();
    if (mixed) {
      mixedChallengeAttempts++;
      if (safeAnswers > 0) {
        bestMixedScore = math.max(
          bestMixedScore,
          (safeCorrect * 100 / safeAnswers).round(),
        ).toInt();
      }
    } else {
      freePracticeSessions++;
    }
  }

  void recordFlashcardReview() {
    flashcardsReviewed++;
  }

  void recordExplorerSearch() {
    explorerSearches++;
  }

  List<String> dueWordIds(Iterable<String> wordIds, {DateTime? now}) {
    final timestamp = (now ?? DateTime.now()).millisecondsSinceEpoch;
    final uniqueIds = wordIds.toSet();
    final due = cards.values
        .where((card) => uniqueIds.contains(card.wordId) && card.dueAt <= timestamp)
        .toList()
      ..sort((a, b) {
        final byDue = a.dueAt.compareTo(b.dueAt);
        return byDue != 0 ? byDue : a.wordId.compareTo(b.wordId);
      });
    return due.map((card) => card.wordId).toList(growable: false);
  }

  DateTime? nextDueAt(Iterable<String> wordIds) {
    final ids = wordIds.toSet();
    final timestamps = cards.values
        .where((card) => ids.contains(card.wordId))
        .map((card) => card.dueAt)
        .toList();
    if (timestamps.isEmpty) return null;
    timestamps.sort();
    return DateTime.fromMillisecondsSinceEpoch(timestamps.first);
  }

  Map<String, dynamic> toJson() => {
        'cards': {for (final entry in cards.entries) entry.key: entry.value.toJson()},
        'freePracticeSessions': freePracticeSessions,
        'mixedChallengeAttempts': mixedChallengeAttempts,
        'bestMixedScore': bestMixedScore,
        'flashcardsReviewed': flashcardsReviewed,
        'explorerSearches': explorerSearches,
      };
}
