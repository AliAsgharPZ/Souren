import 'package:flutter_test/flutter_test.dart';
import 'package:souren/data/ario_curriculum.dart';
import 'package:souren/data/store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('writing curriculum links four skills to complete lessons and exercises', () async {
    final curriculum = await ArioCurriculum.load();
    expect(curriculum.writingCourses, hasLength(4));
    final lessons = curriculum.writingCourses.expand((course) => course.units).expand((unit) => unit.lessons).toList();
    expect(lessons, hasLength(18));
    for (final lesson in lessons) {
      expect(lesson.sections.map((section) => section.type).toList(), ['learn', 'recall', 'practice']);
      expect(lesson.sections.first.content, isNotEmpty);
      expect(lesson.sections.first.examples, isNotEmpty);
      for (final section in lesson.sections.skip(1)) {
        expect(section.exercises.length, greaterThanOrEqualTo(2));
        for (final exercise in section.exercises) {
          expect(exercise.options, contains(exercise.answer));
          expect(exercise.explanation, isNotEmpty);
        }
      }
    }
  });

  test('Ario difficulty is 1-100 while stage count grows with dictionary content', () async {
    final dictionary = await Dictionary.load();
    final curriculum = await ArioCurriculum.load();
    expect(dictionary.entries, hasLength(552));
    expect(curriculum.stages.length, (dictionary.entries.length / 5).ceil());
    expect(curriculum.stages.length, greaterThan(100));
    final byWord = {for (final entry in dictionary.entries) entry.ar: entry};
    final learnedIds = <String>[];
    for (var index = 0; index < curriculum.stages.length; index++) {
      final stage = curriculum.stages[index];
      expect(stage.level, index + 1);
      expect(stage.difficultyMin, inInclusiveRange(1, 100));
      expect(stage.difficultyMax, inInclusiveRange(stage.difficultyMin, 100));
      expect(stage.units, hasLength(1));
      expect(stage.units.single.lessons, hasLength(1));
      final lesson = stage.units.single.lessons.single;
      expect(lesson.sections.map((section) => section.type).toList(), ['learn', 'recall', 'practice']);
      expect(lesson.entryIds, isNotEmpty);
      expect(lesson.entryIds.length, lessThanOrEqualTo(5));
      for (final word in lesson.entryIds) {
        expect(byWord.containsKey(word), isTrue, reason: 'Unknown dictionary entry');
        expect(byWord[word]!.level, inInclusiveRange(1, 100));
        learnedIds.add(word);
      }
      final exercises = lesson.sections.singleWhere((section) => section.type == 'practice').exercises;
      expect(exercises, isNotEmpty);
      expect(exercises.every((exercise) => lesson.entryIds.contains(exercise.entryId)), isTrue);
    }
    expect(learnedIds, hasLength(552));
    expect(learnedIds.toSet(), hasLength(552));
  });
}
