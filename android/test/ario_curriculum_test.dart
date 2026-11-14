import 'package:flutter_test/flutter_test.dart';
import 'package:souren/data/ario_curriculum.dart';
import 'package:souren/data/store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
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
