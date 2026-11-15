class ArioDayRecord {
  int lessons;
  int answers;
  int correctAnswers;
  int topicAnswers;
  int bossAttempts;
  int dailyBossBest;
  int ghostAttempts;
  int ghostBest;

  ArioDayRecord({
    this.lessons = 0,
    this.answers = 0,
    this.correctAnswers = 0,
    this.topicAnswers = 0,
    this.bossAttempts = 0,
    this.dailyBossBest = 0,
    this.ghostAttempts = 0,
    this.ghostBest = 0,
  });

  factory ArioDayRecord.fromJson(Map<String, dynamic> json) => ArioDayRecord(
        lessons: _readInt(json['lessons']),
        answers: _readInt(json['answers']),
        correctAnswers: _readInt(json['correctAnswers']),
        topicAnswers: _readInt(json['topicAnswers']),
        bossAttempts: _readInt(json['bossAttempts']),
        dailyBossBest: _readInt(json['dailyBossBest']),
        ghostAttempts: _readInt(json['ghostAttempts']),
        ghostBest: _readInt(json['ghostBest']),
      );

  Map<String, dynamic> toJson() => {
        'lessons': lessons,
        'answers': answers,
        'correctAnswers': correctAnswers,
        'topicAnswers': topicAnswers,
        'bossAttempts': bossAttempts,
        'dailyBossBest': dailyBossBest,
        'ghostAttempts': ghostAttempts,
        'ghostBest': ghostBest,
      };
}

int _readInt(Object? value) => value is num ? value.toInt() : 0;

String arioDateKey(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-'
    '${date.month.toString().padLeft(2, '0')}-'
    '${date.day.toString().padLeft(2, '0')}';

DateTime _dayAsUtc(String key) => DateTime.parse('${key}T00:00:00Z');

class ArioDailyMission {
  final String id;
  final String title;
  final String description;
  final int progress;
  final int target;

  const ArioDailyMission({
    required this.id,
    required this.title,
    required this.description,
    required this.progress,
    required this.target,
  });

  bool get complete => progress >= target;
  double get fraction => target <= 0 ? 1 : (progress / target).clamp(0.0, 1.0).toDouble();
}

class ArioPeriodSummary {
  final int activeDays;
  final int lessons;
  final int answers;
  final int correctAnswers;
  final int topicAnswers;
  final int bossAttempts;
  final int bestBossScore;
  final int ghostAttempts;
  final int bestGhostScore;

  const ArioPeriodSummary({
    required this.activeDays,
    required this.lessons,
    required this.answers,
    required this.correctAnswers,
    required this.topicAnswers,
    required this.bossAttempts,
    required this.bestBossScore,
    required this.ghostAttempts,
    required this.bestGhostScore,
  });

  double get accuracy => answers == 0 ? 0 : correctAnswers / answers;
}

class ArioOfflineEvent {
  final String id;
  final String title;
  final String description;
  final String metricLabel;
  final int target;
  final int progress;

  const ArioOfflineEvent({
    required this.id,
    required this.title,
    required this.description,
    required this.metricLabel,
    required this.target,
    required this.progress,
  });

  bool get complete => progress >= target;
  double get fraction => target <= 0 ? 1 : (progress / target).clamp(0.0, 1.0).toDouble();
}

class ArioAchievement {
  final String id;
  final String title;
  final String description;

  const ArioAchievement({
    required this.id,
    required this.title,
    required this.description,
  });
}

class ArioGamificationState {
  static const achievements = <ArioAchievement>[
    ArioAchievement(id: 'first-lesson', title: 'آغازگر', description: 'اولین درس را کامل کن.'),
    ArioAchievement(id: 'ten-lessons', title: 'پیگیر یادگیری', description: '۱۰ درس را به پایان برسان.'),
    ArioAchievement(id: 'fifty-words', title: 'واژه‌شناس', description: '۵۰ واژه را یاد بگیر.'),
    ArioAchievement(id: 'fifty-answers', title: 'دست‌گرم', description: 'به ۵۰ تمرین پاسخ بده.'),
    ArioAchievement(id: 'three-day-streak', title: 'سه روز پیوسته', description: 'سه روز پیاپی فعالیت آموزشی داشته باش.'),
    ArioAchievement(id: 'seven-day-streak', title: 'هفتهٔ منظم', description: 'هفت روز پیاپی فعالیت آموزشی داشته باش.'),
    ArioAchievement(id: 'daily-boss-ten', title: 'غول‌کش', description: 'در Daily Boss به امتیاز ۱۰ برس.'),
    ArioAchievement(id: 'ghost-ten', title: 'پیشی از خود', description: 'در چالش شبح به رکورد ۱۰ برس.'),
    ArioAchievement(id: 'topic-fifteen', title: 'کاوشگر موضوعی', description: '۱۵ تمرین از گروه‌های موضوعی انجام بده.'),
  ];

  static const avatarIds = <String>['reader', 'explorer', 'scholar', 'writer', 'thinker'];

  static const _eventDefinitions = <({
    String id,
    String title,
    String description,
    String metric,
    int target,
  })>[
    (id: 'precision', title: 'هفتهٔ دقت', description: 'در طول هفته ۱۵ پاسخ درست ثبت کن.', metric: 'correctAnswers', target: 15),
    (id: 'consistency', title: 'هفتهٔ پیوستگی', description: 'در چهار روز متفاوت فعالیت آموزشی داشته باش.', metric: 'activeDays', target: 4),
    (id: 'milestones', title: 'هفتهٔ مرحله‌ها', description: 'سه درس را در همین هفته کامل کن.', metric: 'lessons', target: 3),
    (id: 'exploration', title: 'هفتهٔ کاوش', description: '۱۵ تمرین از گروه‌های موضوعی انجام بده.', metric: 'topicAnswers', target: 15),
  ];

  String? lastActiveDay;
  int currentStreak;
  int bestStreak;
  int bestDailyBossScore;
  int bestGhostScore;
  List<int> ghostBestTrack;
  String avatarId;
  int avatarTone;
  final Map<String, ArioDayRecord> history;
  final Set<String> unlockedAchievements;

  ArioGamificationState({
    this.lastActiveDay,
    this.currentStreak = 0,
    this.bestStreak = 0,
    this.bestDailyBossScore = 0,
    this.bestGhostScore = 0,
    List<int>? ghostBestTrack,
    this.avatarId = 'reader',
    this.avatarTone = 0,
    Map<String, ArioDayRecord>? history,
    Set<String>? unlockedAchievements,
  })  : ghostBestTrack = ghostBestTrack ?? <int>[],
        history = history ?? <String, ArioDayRecord>{},
        unlockedAchievements = unlockedAchievements ?? <String>{};

  factory ArioGamificationState.fromJson(Object? value) {
    if (value is! Map) return ArioGamificationState();
    final json = Map<String, dynamic>.from(value);
    final rawHistory = json['history'];
    final history = <String, ArioDayRecord>{};
    if (rawHistory is Map) {
      for (final entry in rawHistory.entries) {
        if (entry.value is Map) {
          history[entry.key.toString()] = ArioDayRecord.fromJson(
            Map<String, dynamic>.from(entry.value as Map),
          );
        }
      }
    }
    final rawTrack = json['ghostBestTrack'];
    final track = rawTrack is List
        ? rawTrack.whereType<num>().map((item) => item.toInt()).toList()
        : <int>[];
    final rawUnlocked = json['unlockedAchievements'];
    final unlocked = rawUnlocked is List
        ? rawUnlocked.map((item) => item.toString()).toSet()
        : <String>{};
    final avatar = json['avatarId']?.toString() ?? 'reader';
    return ArioGamificationState(
      lastActiveDay: json['lastActiveDay']?.toString(),
      currentStreak: _readInt(json['currentStreak']),
      bestStreak: _readInt(json['bestStreak']),
      bestDailyBossScore: _readInt(json['bestDailyBossScore']),
      bestGhostScore: _readInt(json['bestGhostScore']),
      ghostBestTrack: track,
      avatarId: avatarIds.contains(avatar) ? avatar : 'reader',
      avatarTone: _readInt(json['avatarTone']).clamp(0, 3).toInt(),
      history: history,
      unlockedAchievements: unlocked,
    );
  }

  Map<String, dynamic> toJson() => {
        'lastActiveDay': lastActiveDay,
        'currentStreak': currentStreak,
        'bestStreak': bestStreak,
        'bestDailyBossScore': bestDailyBossScore,
        'bestGhostScore': bestGhostScore,
        'ghostBestTrack': ghostBestTrack,
        'avatarId': avatarId,
        'avatarTone': avatarTone,
        'history': {
          for (final key in (history.keys.toList()..sort()))
            key: history[key]!.toJson(),
        },
        'unlockedAchievements': unlockedAchievements.toList()..sort(),
      };

  ArioDayRecord recordFor(DateTime date) =>
      history[arioDateKey(date)] ?? ArioDayRecord();

  ArioDayRecord _mutableRecord(DateTime date) =>
      history.putIfAbsent(arioDateKey(date), ArioDayRecord.new);

  int streakOn(DateTime date) {
    final last = lastActiveDay;
    if (last == null) return 0;
    final gap = _dayAsUtc(arioDateKey(date)).difference(_dayAsUtc(last)).inDays;
    return gap >= 0 && gap <= 1 ? currentStreak : 0;
  }

  void _markActive(DateTime date) {
    final key = arioDateKey(date);
    if (lastActiveDay == key) return;
    final previous = lastActiveDay;
    if (previous == null) {
      currentStreak = 1;
    } else {
      final gap = _dayAsUtc(key).difference(_dayAsUtc(previous)).inDays;
      currentStreak = gap == 1 ? currentStreak + 1 : 1;
    }
    lastActiveDay = key;
    if (currentStreak > bestStreak) bestStreak = currentStreak;
  }

  void recordActivity(
    DateTime date, {
    int lessons = 0,
    int answers = 0,
    int correctAnswers = 0,
    int topicAnswers = 0,
  }) {
    if (lessons <= 0 && answers <= 0 && correctAnswers <= 0 && topicAnswers <= 0) return;
    _markActive(date);
    final day = _mutableRecord(date);
    day.lessons += lessons < 0 ? 0 : lessons;
    day.answers += answers < 0 ? 0 : answers;
    day.correctAnswers += correctAnswers < 0 ? 0 : correctAnswers;
    day.topicAnswers += topicAnswers < 0 ? 0 : topicAnswers;
    _trimHistory(date);
  }

  void recordDailyBoss(DateTime date, int score) {
    _markActive(date);
    final day = _mutableRecord(date);
    day.bossAttempts++;
    if (score > day.dailyBossBest) day.dailyBossBest = score;
    if (score > bestDailyBossScore) bestDailyBossScore = score;
    _trimHistory(date);
    refreshAchievements(knownWords: 0);
  }

  void recordGhostRun(DateTime date, List<int> scoreTrack) {
    _markActive(date);
    final day = _mutableRecord(date);
    day.ghostAttempts++;
    final score = scoreTrack.isEmpty ? 0 : scoreTrack.last;
    if (score > day.ghostBest) day.ghostBest = score;
    if (score > bestGhostScore) {
      bestGhostScore = score;
      ghostBestTrack = List<int>.unmodifiable(scoreTrack);
    }
    _trimHistory(date);
    refreshAchievements(knownWords: 0);
  }

  void _trimHistory(DateTime date) {
    if (history.length <= 420) return;
    final cutoff = DateTime.utc(date.year, date.month, date.day).subtract(const Duration(days: 420));
    history.removeWhere((key, _) {
      try {
        return _dayAsUtc(key).isBefore(cutoff);
      } catch (_) {
        return true;
      }
    });
  }

  ArioDayRecord dailyRecord([DateTime? date]) => recordFor(date ?? DateTime.now());

  List<ArioDailyMission> dailyMissions([DateTime? date]) {
    final day = dailyRecord(date);
    return [
      ArioDailyMission(
        id: 'lesson',
        title: 'یک درس کامل کن',
        description: 'یک مرحله از مسیر یادگیری را به پایان برسان.',
        progress: day.lessons.clamp(0, 1).toInt(),
        target: 1,
      ),
      ArioDailyMission(
        id: 'practice',
        title: 'پنج تمرین انجام بده',
        description: 'به پنج پرسش آموزشی پاسخ بده.',
        progress: day.answers.clamp(0, 5).toInt(),
        target: 5,
      ),
      ArioDailyMission(
        id: 'boss',
        title: 'با Daily Boss روبه‌رو شو',
        description: 'یک دور چالش روزانه را کامل کن.',
        progress: day.bossAttempts.clamp(0, 1).toInt(),
        target: 1,
      ),
    ];
  }

  int completedDailyMissionsFor([DateTime? date]) => dailyMissions(date).where((mission) => mission.complete).length;

  int get completedDailyMissions => completedDailyMissionsFor();

  ArioPeriodSummary summary(DateTime start, DateTime end) {
    var activeDays = 0;
    var lessons = 0;
    var answers = 0;
    var correct = 0;
    var topicAnswers = 0;
    var bossAttempts = 0;
    var bestBoss = 0;
    var ghostAttempts = 0;
    var bestGhost = 0;
    final first = DateTime.utc(start.year, start.month, start.day);
    final last = DateTime.utc(end.year, end.month, end.day);
    for (final entry in history.entries) {
      DateTime day;
      try {
        day = _dayAsUtc(entry.key);
      } catch (_) {
        continue;
      }
      if (day.isBefore(first) || day.isAfter(last)) continue;
      final value = entry.value;
      if (value.lessons + value.answers + value.bossAttempts + value.ghostAttempts > 0) activeDays++;
      lessons += value.lessons;
      answers += value.answers;
      correct += value.correctAnswers;
      topicAnswers += value.topicAnswers;
      bossAttempts += value.bossAttempts;
      if (value.dailyBossBest > bestBoss) bestBoss = value.dailyBossBest;
      ghostAttempts += value.ghostAttempts;
      if (value.ghostBest > bestGhost) bestGhost = value.ghostBest;
    }
    return ArioPeriodSummary(
      activeDays: activeDays,
      lessons: lessons,
      answers: answers,
      correctAnswers: correct,
      topicAnswers: topicAnswers,
      bossAttempts: bossAttempts,
      bestBossScore: bestBoss,
      ghostAttempts: ghostAttempts,
      bestGhostScore: bestGhost,
    );
  }

  ArioPeriodSummary weeklySummary([DateTime? date]) {
    final now = date ?? DateTime.now();
    final day = DateTime(now.year, now.month, now.day);
    final start = day.subtract(Duration(days: day.weekday - DateTime.monday));
    return summary(start, start.add(const Duration(days: 6)));
  }

  ArioPeriodSummary monthlySummary([DateTime? date]) {
    final now = date ?? DateTime.now();
    final start = DateTime(now.year, now.month, 1);
    final end = DateTime(now.year, now.month + 1, 0);
    return summary(start, end);
  }

  ArioOfflineEvent offlineEvent([DateTime? date]) {
    final now = date ?? DateTime.now();
    final day = DateTime(now.year, now.month, now.day);
    final weekStart = day.subtract(Duration(days: day.weekday - DateTime.monday));
    final week = weeklySummary(now);
    final weekIndex = weekStart.difference(DateTime(now.year, 1, 1)).inDays ~/ 7;
    final definition = _eventDefinitions[weekIndex.abs() % _eventDefinitions.length];
    final progress = switch (definition.metric) {
      'correctAnswers' => week.correctAnswers,
      'activeDays' => week.activeDays,
      'lessons' => week.lessons,
      'topicAnswers' => week.topicAnswers,
      _ => 0,
    };
    return ArioOfflineEvent(
      id: definition.id,
      title: definition.title,
      description: definition.description,
      metricLabel: definition.metric == 'activeDays'
          ? 'روز فعال'
          : definition.metric == 'lessons'
              ? 'درس'
              : definition.metric == 'topicAnswers'
                  ? 'تمرین موضوعی'
                  : 'پاسخ درست',
      target: definition.target,
      progress: progress,
    );
  }

  void refreshAchievements({
    required int knownWords,
    int? completedLessons,
  }) {
    final lessons = completedLessons ?? history.values.fold<int>(0, (sum, item) => sum + item.lessons);
    final answers = history.values.fold<int>(0, (sum, item) => sum + item.answers);
    final topicAnswers = history.values.fold<int>(0, (sum, item) => sum + item.topicAnswers);
    final unlocked = <String>{
      if (lessons >= 1) 'first-lesson',
      if (lessons >= 10) 'ten-lessons',
      if (knownWords >= 50) 'fifty-words',
      if (answers >= 50) 'fifty-answers',
      if (bestStreak >= 3) 'three-day-streak',
      if (bestStreak >= 7) 'seven-day-streak',
      if (bestDailyBossScore >= 10) 'daily-boss-ten',
      if (bestGhostScore >= 10) 'ghost-ten',
      if (topicAnswers >= 15) 'topic-fifteen',
    };
    unlockedAchievements.addAll(unlocked);
  }

  void setAvatar(String id, int tone) {
    avatarId = avatarIds.contains(id) ? id : 'reader';
    avatarTone = tone.clamp(0, 3).toInt();
  }
}
