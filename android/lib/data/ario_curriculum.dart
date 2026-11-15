import 'dart:convert';

import 'package:flutter/services.dart';

class ArioExercisePlan {
  final String id;
  final String type;
  final String entryId;
  const ArioExercisePlan({required this.id, required this.type, required this.entryId});
  factory ArioExercisePlan.fromJson(Map<String, dynamic> json) => ArioExercisePlan(
    id: json['id'] as String, type: json['type'] as String, entryId: json['entryId'] as String,
  );
}

class ArioSectionPlan {
  final String id;
  final String title;
  final String type;
  final List<String> entryIds;
  final List<ArioExercisePlan> exercises;
  const ArioSectionPlan({required this.id, required this.title, required this.type, required this.entryIds, required this.exercises});
  factory ArioSectionPlan.fromJson(Map<String, dynamic> json) => ArioSectionPlan(
    id: json['id'] as String, title: json['title'] as String, type: json['type'] as String,
    entryIds: (json['entryIds'] as List? ?? const []).map((e) => e.toString()).toList(growable: false),
    exercises: (json['exercises'] as List? ?? const []).whereType<Map>().map((e) => ArioExercisePlan.fromJson(Map<String, dynamic>.from(e))).toList(growable: false),
  );
}

class ArioLessonPlan {
  final String id;
  final String title;
  final List<ArioSectionPlan> sections;
  const ArioLessonPlan({required this.id, required this.title, required this.sections});
  factory ArioLessonPlan.fromJson(Map<String, dynamic> json) => ArioLessonPlan(
    id: json['id'] as String, title: json['title'] as String,
    sections: (json['sections'] as List).whereType<Map>().map((e) => ArioSectionPlan.fromJson(Map<String, dynamic>.from(e))).toList(growable: false),
  );
  List<String> get entryIds => sections.where((s) => s.type == 'learn').expand((s) => s.entryIds).toList(growable: false);
}

class ArioUnitPlan {
  final String id;
  final String title;
  final List<ArioLessonPlan> lessons;
  const ArioUnitPlan({required this.id, required this.title, required this.lessons});
  factory ArioUnitPlan.fromJson(Map<String, dynamic> json) => ArioUnitPlan(
    id: json['id'] as String, title: json['title'] as String,
    lessons: (json['lessons'] as List).whereType<Map>().map((e) => ArioLessonPlan.fromJson(Map<String, dynamic>.from(e))).toList(growable: false),
  );
}

class ArioStagePlan {
  final String id;
  final int level;
  final int difficultyMin;
  final int difficultyMax;
  final String title;
  final int phase;
  final String phaseTitle;
  final List<ArioUnitPlan> units;
  const ArioStagePlan({required this.id, required this.level, required this.difficultyMin, required this.difficultyMax, required this.title, required this.phase, required this.phaseTitle, required this.units});
  factory ArioStagePlan.fromJson(Map<String, dynamic> json) => ArioStagePlan(
    id: json['id'] as String, level: (json['level'] as num).toInt(),
    difficultyMin: (json['difficultyMin'] as num?)?.toInt() ?? (json['level'] as num).toInt(),
    difficultyMax: (json['difficultyMax'] as num?)?.toInt() ?? (json['level'] as num).toInt(),
    title: json['title'] as String,
    phase: (json['phase'] as num).toInt(), phaseTitle: json['phaseTitle'] as String,
    units: (json['units'] as List).whereType<Map>().map((e) => ArioUnitPlan.fromJson(Map<String, dynamic>.from(e))).toList(growable: false),
  );
  List<String> get entryIds => units.expand((u) => u.lessons).expand((l) => l.entryIds).toList(growable: false);
}

class ArioWritingExercisePlan {
  final String id;
  final String prompt;
  final List<String> options;
  final String answer;
  final String explanation;
  const ArioWritingExercisePlan({required this.id, required this.prompt, required this.options, required this.answer, required this.explanation});
  factory ArioWritingExercisePlan.fromJson(Map<String, dynamic> json) => ArioWritingExercisePlan(
    id: json['id'] as String,
    prompt: json['prompt'] as String,
    options: (json['options'] as List).map((item) => item.toString()).toList(growable: false),
    answer: json['answer'] as String,
    explanation: json['explanation'] as String,
  );
}

class ArioWritingSectionPlan {
  final String id;
  final String title;
  final String type;
  final String content;
  final List<String> examples;
  final List<ArioWritingExercisePlan> exercises;
  const ArioWritingSectionPlan({required this.id, required this.title, required this.type, required this.content, required this.examples, required this.exercises});
  factory ArioWritingSectionPlan.fromJson(Map<String, dynamic> json) => ArioWritingSectionPlan(
    id: json['id'] as String,
    title: json['title'] as String,
    type: json['type'] as String,
    content: (json['content'] as String?) ?? '',
    examples: (json['examples'] as List? ?? const []).map((item) => item.toString()).toList(growable: false),
    exercises: (json['exercises'] as List? ?? const []).whereType<Map>().map((item) => ArioWritingExercisePlan.fromJson(Map<String, dynamic>.from(item))).toList(growable: false),
  );
}

class ArioWritingLessonPlan {
  final String id;
  final String title;
  final String summary;
  final List<ArioWritingSectionPlan> sections;
  const ArioWritingLessonPlan({required this.id, required this.title, required this.summary, required this.sections});
  factory ArioWritingLessonPlan.fromJson(Map<String, dynamic> json) => ArioWritingLessonPlan(
    id: json['id'] as String,
    title: json['title'] as String,
    summary: (json['summary'] as String?) ?? '',
    sections: (json['sections'] as List).whereType<Map>().map((item) => ArioWritingSectionPlan.fromJson(Map<String, dynamic>.from(item))).toList(growable: false),
  );
}

class ArioWritingUnitPlan {
  final String id;
  final String title;
  final List<ArioWritingLessonPlan> lessons;
  const ArioWritingUnitPlan({required this.id, required this.title, required this.lessons});
  factory ArioWritingUnitPlan.fromJson(Map<String, dynamic> json) => ArioWritingUnitPlan(
    id: json['id'] as String,
    title: json['title'] as String,
    lessons: (json['lessons'] as List).whereType<Map>().map((item) => ArioWritingLessonPlan.fromJson(Map<String, dynamic>.from(item))).toList(growable: false),
  );
}

class ArioWritingCoursePlan {
  final String id;
  final String title;
  final String description;
  final List<ArioWritingUnitPlan> units;
  const ArioWritingCoursePlan({required this.id, required this.title, required this.description, required this.units});
  factory ArioWritingCoursePlan.fromJson(Map<String, dynamic> json) => ArioWritingCoursePlan(
    id: json['id'] as String,
    title: json['title'] as String,
    description: (json['description'] as String?) ?? '',
    units: (json['units'] as List).whereType<Map>().map((item) => ArioWritingUnitPlan.fromJson(Map<String, dynamic>.from(item))).toList(growable: false),
  );
}

class ArioCurriculum {
  final int version;
  final List<ArioStagePlan> stages;
  final List<ArioWritingCoursePlan> writingCourses;
  const ArioCurriculum({required this.version, required this.stages, this.writingCourses = const []});
  static Future<ArioCurriculum> load() async {
    final raw = await rootBundle.loadString('assets/db/ario_curriculum.json');
    final writingRaw = await rootBundle.loadString('assets/db/ario_writing.json');
    final json = jsonDecode(raw) as Map<String, dynamic>;
    final writingJson = jsonDecode(writingRaw) as Map<String, dynamic>;
    return ArioCurriculum(
      version: (json['version'] as num).toInt(),
      stages: (json['stages'] as List).whereType<Map>().map((e) => ArioStagePlan.fromJson(Map<String, dynamic>.from(e))).toList(growable: false),
      writingCourses: (writingJson['courses'] as List? ?? const []).whereType<Map>().map((e) => ArioWritingCoursePlan.fromJson(Map<String, dynamic>.from(e))).toList(growable: false),
    );
  }
}
