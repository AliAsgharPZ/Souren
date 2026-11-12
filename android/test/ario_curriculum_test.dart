import 'package:flutter_test/flutter_test.dart';
import 'package:souren/data/ario_curriculum.dart';
import 'package:souren/data/store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('Ario stages mirror all 100 dictionary levels exactly once', () async {
    final dictionary = await Dictionary.load();
    final curriculum = await ArioCurriculum.load();
    expect(dictionary.entries, hasLength(552));
    expect(curriculum.stages, hasLength(100));
    expect(curriculum.stages.map((stage) => stage.level).toList(), List<int>.generate(100, (i) => i + 1));
    final byWord = {for (final entry in dictionary.entries) entry.ar: entry};
    final learnedIds = <String>[];
    for (final stage in curriculum.stages) {
      expect(stage.units, hasLength(1));
      expect(stage.units.single.lessons, hasLength(1));
      final lesson = stage.units.single.lessons.single;
      expect(lesson.sections.map((section) => section.type).toList(), ['learn', 'recall', 'practice']);
      expect(lesson.entryIds, isNotEmpty);
      for (final word in lesson.entryIds) {
        expect(byWord.containsKey(word), isTrue, reason: 'Unknown dictionary entry');
        expect(byWord[word]!.level, stage.level, reason: 'Word must belong to the matching stage level');
        learnedIds.add(word);
      }
      final exercises = lesson.sections.singleWhere((section) => section.type == 'practice').exercises;
      expect(exercises, isNotEmpty);
      expect(exercises.every((exercise) => lesson.entryIds.contains(exercise.entryId)), isTrue);
    }
    expect(learnedIds, hasLength(552));
    expect(learnedIds.toSet(), hasLength(552));
    expect(curriculum.stages.every((stage) => stage.entryIds.length >= 5 && stage.entryIds.length <= 6), isTrue);
  });
}
