import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';
import 'data/ario_curriculum.dart';

class ArioWritingLessonResult {
  final Set<String> reviewedExerciseIds, missedExerciseIds;
  final int correctAnswers, totalQuestions;
  const ArioWritingLessonResult({required this.reviewedExerciseIds, required this.missedExerciseIds, required this.correctAnswers, required this.totalQuestions});
}
class ArioWritingReviewResult {
  final Set<String> reviewedExerciseIds, missedExerciseIds;
  const ArioWritingReviewResult({required this.reviewedExerciseIds, required this.missedExerciseIds});
}

class ArioWritingPage extends StatefulWidget {
  final List<ArioWritingCoursePlan> courses;
  final Set<String> completedLessonIds;
  final Map<String, int> reviewDue;
  final Future<void> Function(String, Set<String>, Set<String>) onLessonCompleted;
  final Future<void> Function(Set<String>, Set<String>) onReviewCompleted;
  final Color backgroundColor, cardColor, pillColor, textColor, mutedColor, selectedColor, accentColor, dividerColor;
  const ArioWritingPage({super.key, required this.courses, required this.completedLessonIds, required this.reviewDue, required this.onLessonCompleted, required this.onReviewCompleted, required this.backgroundColor, required this.cardColor, required this.pillColor, required this.textColor, required this.mutedColor, required this.selectedColor, required this.accentColor, required this.dividerColor});
  @override
  State<ArioWritingPage> createState() => _ArioWritingPageState();
}

class _ArioWritingPageState extends State<ArioWritingPage> {
  late final Set<String> _completed = {...widget.completedLessonIds};
  late final Map<String, int> _reviewDue = {...widget.reviewDue};
  List<ArioWritingExercisePlan> get _catalog => [
    for (final c in widget.courses) for (final u in c.units) for (final l in u.lessons) for (final s in l.sections) ...s.exercises,
  ];
  List<ArioWritingExercisePlan> get _queued {
    final now = DateTime.now().millisecondsSinceEpoch;
    final byId = {for (final e in _catalog) e.id: e};
    return [
      for (final entry in _reviewDue.entries)
        if (entry.value <= now && byId[entry.key] != null) byId[entry.key]!,
    ];
  }

  Future<void> _openLesson(ArioWritingCoursePlan course, ArioWritingUnitPlan unit, ArioWritingLessonPlan lesson) async {
    final result = await Navigator.of(context).push<ArioWritingLessonResult>(MaterialPageRoute(
      builder: (_) => ArioWritingLessonPage(courseTitle: course.title, unitTitle: unit.title, lesson: lesson,
        backgroundColor: widget.backgroundColor, cardColor: widget.cardColor, pillColor: widget.pillColor,
        textColor: widget.textColor, mutedColor: widget.mutedColor, selectedColor: widget.selectedColor,
        accentColor: widget.accentColor, dividerColor: widget.dividerColor),
    ));
    if (result == null || !mounted) return;
    await widget.onLessonCompleted(lesson.id, result.reviewedExerciseIds, result.missedExerciseIds);
    if (!mounted) return;
    setState(() {
      _completed.add(lesson.id);
      final due = DateTime.now().millisecondsSinceEpoch;
      for (final id in result.reviewedExerciseIds) {
        if (result.missedExerciseIds.contains(id)) {
          _reviewDue[id] = due;
        } else {
          _reviewDue.remove(id);
        }
      }
    });
  }

  Future<void> _openReview() async {
    final items = _queued;
    if (items.isEmpty) return;
    final result = await Navigator.of(context).push<ArioWritingReviewResult>(MaterialPageRoute(
      builder: (_) => ArioWritingReviewPage(exercises: items, backgroundColor: widget.backgroundColor,
        cardColor: widget.cardColor, pillColor: widget.pillColor, textColor: widget.textColor,
        mutedColor: widget.mutedColor, selectedColor: widget.selectedColor, accentColor: widget.accentColor,
        dividerColor: widget.dividerColor),
    ));
    if (result == null || !mounted) return;
    await widget.onReviewCompleted(result.reviewedExerciseIds, result.missedExerciseIds);
    if (!mounted) return;
    setState(() {
      for (final id in result.reviewedExerciseIds) {
        if (result.missedExerciseIds.contains(id)) {
          _reviewDue[id] = DateTime.now().add(const Duration(days: 1)).millisecondsSinceEpoch;
        } else {
          _reviewDue.remove(id);
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final total = widget.courses.fold<int>(0, (sum, c) => sum + c.units.fold<int>(0, (s, u) => s + u.lessons.length));
    final progress = total == 0 ? 0.0 : (_completed.length / total).clamp(0.0, 1.0).toDouble();
    final queued = _queued.length;
    return Directionality(textDirection: TextDirection.rtl, child: Scaffold(
      backgroundColor: widget.backgroundColor,
      appBar: AppBar(backgroundColor: widget.backgroundColor, foregroundColor: widget.textColor, elevation: 0, title: const Text('فارسی‌نویسی و ادبیات')),
      body: ListView(padding: const EdgeInsets.fromLTRB(18, 10, 18, 28), children: [
        Text('مهارت‌های نوشتن و شناخت آرایه‌ها', style: TextStyle(color: widget.textColor, fontSize: 20, fontWeight: FontWeight.w800)),
        const SizedBox(height: 6),
        Text('هر درس با آموزش آغاز می‌شود، با یادآوری ادامه پیدا می‌کند و با تمرین به پایان می‌رسد.', style: TextStyle(color: widget.mutedColor, height: 1.8)),
        const SizedBox(height: 14),
        Container(padding: const EdgeInsets.all(17), decoration: BoxDecoration(color: widget.cardColor, borderRadius: BorderRadius.circular(22)), child: Column(children: [
          Row(children: [Expanded(child: Text('پیشرفت این مسیر', style: TextStyle(color: widget.textColor, fontWeight: FontWeight.w700))), Text('${_completed.length} از $total درس', style: TextStyle(color: widget.mutedColor, fontSize: 12))]),
          const SizedBox(height: 10),
          ClipRRect(borderRadius: BorderRadius.circular(20), child: LinearProgressIndicator(value: progress, minHeight: 8, backgroundColor: widget.dividerColor, color: widget.selectedColor)),
        ])),
        const SizedBox(height: 12),
        Card(color: widget.cardColor, elevation: 0, child: ListTile(
          leading: Icon(Icons.history_rounded, color: widget.selectedColor),
          title: Text('مرور پاسخ‌های دشوار', style: TextStyle(color: widget.textColor, fontWeight: FontWeight.w700)),
          subtitle: Text(queued == 0 ? 'پاسخ نادرستی در صف مرور نیست.' : '$queued تمرین برای مرور ذخیره شده است.', style: TextStyle(color: widget.mutedColor)),
          trailing: Icon(Icons.chevron_left, color: widget.mutedColor), onTap: queued == 0 ? null : _openReview,
        )),
        const SizedBox(height: 14),
        for (final course in widget.courses)
          Card(color: widget.cardColor, elevation: 0, margin: const EdgeInsets.only(bottom: 10), child: ExpansionTile(
            iconColor: widget.selectedColor, collapsedIconColor: widget.mutedColor,
            title: Text(course.title, style: TextStyle(color: widget.textColor, fontWeight: FontWeight.w800)),
            subtitle: Text(course.description, style: TextStyle(color: widget.mutedColor, height: 1.6)),
            childrenPadding: const EdgeInsets.fromLTRB(8, 0, 8, 10),
            children: [for (final unit in course.units) ExpansionTile(
              iconColor: widget.selectedColor, collapsedIconColor: widget.mutedColor,
              title: Text(unit.title, style: TextStyle(color: widget.textColor, fontWeight: FontWeight.w700)),
              children: [for (final lesson in unit.lessons) ListTile(
                title: Text(lesson.title, style: TextStyle(color: widget.textColor)),
                subtitle: Text(lesson.summary, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: widget.mutedColor)),
                leading: Icon(_completed.contains(lesson.id) ? Icons.check_circle_rounded : Icons.menu_book_rounded, color: _completed.contains(lesson.id) ? widget.selectedColor : widget.mutedColor),
                trailing: Icon(Icons.chevron_left, color: widget.mutedColor),
                onTap: () => _openLesson(course, unit, lesson),
              )],
            )],
          )),
      ]),
    ));
  }
}

class ArioWritingLessonPage extends StatefulWidget {
  final String courseTitle, unitTitle;
  final ArioWritingLessonPlan lesson;
  final Color backgroundColor, cardColor, pillColor, textColor, mutedColor, selectedColor, accentColor, dividerColor;
  const ArioWritingLessonPage({super.key, required this.courseTitle, required this.unitTitle, required this.lesson, required this.backgroundColor, required this.cardColor, required this.pillColor, required this.textColor, required this.mutedColor, required this.selectedColor, required this.accentColor, required this.dividerColor});
  @override
  State<ArioWritingLessonPage> createState() => _ArioWritingLessonPageState();
}

class _ArioWritingLessonPageState extends State<ArioWritingLessonPage> {
  int _sectionIndex = 0, _questionIndex = 0, _correctAnswers = 0, _totalQuestions = 0;
  String? _selected;
  bool? _correct;
  final Set<String> _reviewed = {};
  final Set<String> _missed = {};
  ArioWritingSectionPlan get _section => widget.lesson.sections[_sectionIndex];
  bool get _learning => _section.type == 'learn';

  void _answer(ArioWritingExercisePlan exercise, String choice) {
    if (_selected != null) return;
    final correct = choice == exercise.answer;
    setState(() {
      _selected = choice; _correct = correct; _totalQuestions++;
      _reviewed.add(exercise.id);
      if (correct) { _correctAnswers++; } else { _missed.add(exercise.id); }
    });
  }

  void _advance() {
    if (_learning) {
      setState(() { _sectionIndex = 1; _questionIndex = 0; _selected = null; _correct = null; });
      return;
    }
    final questions = _section.exercises;
    if (_questionIndex + 1 < questions.length) {
      setState(() { _questionIndex++; _selected = null; _correct = null; });
      return;
    }
    if (_sectionIndex + 1 < widget.lesson.sections.length) {
      setState(() { _sectionIndex++; _questionIndex = 0; _selected = null; _correct = null; });
      return;
    }
    Navigator.of(context).pop(ArioWritingLessonResult(reviewedExerciseIds: {..._reviewed}, missedExerciseIds: {..._missed}, correctAnswers: _correctAnswers, totalQuestions: _totalQuestions));
  }

  @override
  Widget build(BuildContext context) {
    final questions = _section.exercises;
    final exercise = _learning || questions.isEmpty ? null : questions[_questionIndex];
    final partProgress = _learning ? 1.0 : (_questionIndex + (_selected == null ? 0 : 1)) / questions.length;
    final progress = ((_sectionIndex + partProgress) / widget.lesson.sections.length).clamp(0.0, 1.0).toDouble();
    return Directionality(textDirection: TextDirection.rtl, child: Scaffold(
      backgroundColor: widget.backgroundColor,
      appBar: AppBar(backgroundColor: widget.backgroundColor, foregroundColor: widget.textColor, elevation: 0, title: Text(widget.lesson.title)),
      body: SafeArea(child: Column(children: [
        Padding(padding: const EdgeInsets.fromLTRB(18, 0, 18, 14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('${widget.courseTitle} · ${widget.unitTitle}', style: TextStyle(color: widget.mutedColor, fontSize: 12)),
          const SizedBox(height: 7),
          Row(children: [Expanded(child: Text(_section.title, style: TextStyle(color: widget.textColor, fontWeight: FontWeight.w800))), Text('${_sectionIndex + 1} از ${widget.lesson.sections.length}', style: TextStyle(color: widget.mutedColor))]),
          const SizedBox(height: 8),
          ClipRRect(borderRadius: BorderRadius.circular(20), child: LinearProgressIndicator(value: progress, minHeight: 7, backgroundColor: widget.dividerColor, color: widget.selectedColor)),
        ])),
        Expanded(child: SingleChildScrollView(padding: const EdgeInsets.fromLTRB(18, 4, 18, 16), child: _learning ? _learningContent() : _questionContent(exercise!))),
        Padding(padding: const EdgeInsets.fromLTRB(18, 10, 18, 18), child: SizedBox(width: double.infinity, child: FilledButton(
          onPressed: _learning || _selected != null ? _advance : null,
          child: Text(_learning ? 'رفتن به یادآوری' : _questionIndex + 1 < questions.length ? 'سؤال بعدی' : _sectionIndex + 1 < widget.lesson.sections.length ? 'رفتن به تمرین' : 'پایان درس'),
        ))),
      ])),
    ));
  }

  Widget _learningContent() => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
    Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: widget.cardColor, borderRadius: BorderRadius.circular(22)),
      child: Text(_section.content, style: TextStyle(color: widget.textColor, fontSize: 15, height: 2))),
    const SizedBox(height: 14),
    Text('نمونه‌ها', style: TextStyle(color: widget.textColor, fontWeight: FontWeight.w800, fontSize: 16)),
    const SizedBox(height: 8),
    for (final example in _section.examples) Container(margin: const EdgeInsets.only(bottom: 8), padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      decoration: BoxDecoration(color: widget.cardColor, borderRadius: BorderRadius.circular(16), border: Border.all(color: widget.dividerColor)),
      child: Text(example, style: TextStyle(color: widget.selectedColor, fontWeight: FontWeight.w700, height: 1.6))),
  ]);

  Widget _questionContent(ArioWritingExercisePlan exercise) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
    Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: widget.cardColor, borderRadius: BorderRadius.circular(22)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(_section.type == 'recall' ? 'یادآوری از حافظه' : 'به‌کارگیری آموخته', style: TextStyle(color: widget.mutedColor, fontSize: 12)),
      const SizedBox(height: 12),
      Text(exercise.prompt, style: TextStyle(color: widget.textColor, fontSize: 17, fontWeight: FontWeight.w800, height: 1.8)),
    ])),
    const SizedBox(height: 14),
    for (final option in (List<String>.from(exercise.options)..shuffle(math.Random(exercise.id.hashCode)))) Padding(padding: const EdgeInsets.only(bottom: 9), child: Material(color: Colors.transparent, child: InkWell(
      borderRadius: BorderRadius.circular(16), onTap: _selected == null ? () => _answer(exercise, option) : null,
      child: Container(width: double.infinity, padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        decoration: BoxDecoration(color: _selected != option ? widget.pillColor : (_correct == true ? widget.selectedColor : widget.accentColor),
          borderRadius: BorderRadius.circular(16), border: Border.all(color: _selected == option ? (_correct == true ? widget.selectedColor : widget.accentColor) : widget.dividerColor)),
        child: Text(option, style: TextStyle(color: _selected == option ? widget.backgroundColor : widget.textColor, fontWeight: FontWeight.w600, height: 1.5))),
    ))),
    if (_selected != null) Container(margin: const EdgeInsets.only(top: 8), padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: widget.cardColor, borderRadius: BorderRadius.circular(16)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(_correct == true ? 'پاسخ درست است.' : 'پاسخ درست: ${exercise.answer}', style: TextStyle(color: _correct == true ? widget.selectedColor : widget.accentColor, fontWeight: FontWeight.w800)),
        const SizedBox(height: 6), Text(exercise.explanation, style: TextStyle(color: widget.mutedColor, height: 1.7)),
      ])),
  ]);
}

class ArioWritingReviewPage extends StatefulWidget {
  final List<ArioWritingExercisePlan> exercises;
  final Color backgroundColor, cardColor, pillColor, textColor, mutedColor, selectedColor, accentColor, dividerColor;
  const ArioWritingReviewPage({super.key, required this.exercises, required this.backgroundColor, required this.cardColor, required this.pillColor, required this.textColor, required this.mutedColor, required this.selectedColor, required this.accentColor, required this.dividerColor});
  @override
  State<ArioWritingReviewPage> createState() => _ArioWritingReviewPageState();
}

class _ArioWritingReviewPageState extends State<ArioWritingReviewPage> {
  int _index = 0;
  String? _selected;
  bool? _correct;
  final Set<String> _missed = {}, _reviewed = {};
  void _choose(String option) {
    if (_selected != null) return;
    final exercise = widget.exercises[_index];
    final correct = option == exercise.answer;
    setState(() { _selected = option; _correct = correct; _reviewed.add(exercise.id); if (!correct) _missed.add(exercise.id); });
  }
  void _next() {
    if (_selected == null) return;
    if (_index + 1 == widget.exercises.length) {
      Navigator.of(context).pop(ArioWritingReviewResult(reviewedExerciseIds: {..._reviewed}, missedExerciseIds: {..._missed}));
    } else {
      setState(() { _index++; _selected = null; _correct = null; });
    }
  }
  @override
  Widget build(BuildContext context) {
    final exercise = widget.exercises[_index];
    return Directionality(textDirection: TextDirection.rtl, child: Scaffold(
      backgroundColor: widget.backgroundColor,
      appBar: AppBar(backgroundColor: widget.backgroundColor, foregroundColor: widget.textColor, elevation: 0, title: const Text('مرور پاسخ‌های دشوار')),
      body: SafeArea(child: Padding(padding: const EdgeInsets.all(18), child: Column(children: [
        Row(children: [Expanded(child: Text('تمرین ${_index + 1} از ${widget.exercises.length}', style: TextStyle(color: widget.mutedColor)))]),
        const SizedBox(height: 8),
        ClipRRect(borderRadius: BorderRadius.circular(20), child: LinearProgressIndicator(value: (_index + (_selected == null ? 0 : 1)) / widget.exercises.length, backgroundColor: widget.dividerColor, color: widget.selectedColor)),
        const SizedBox(height: 18),
        Expanded(child: SingleChildScrollView(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: widget.cardColor, borderRadius: BorderRadius.circular(22)),
            child: Text(exercise.prompt, style: TextStyle(color: widget.textColor, fontSize: 17, fontWeight: FontWeight.w800, height: 1.8))),
          const SizedBox(height: 14),
          for (final option in (List<String>.from(exercise.options)..shuffle(math.Random(exercise.id.hashCode)))) Padding(padding: const EdgeInsets.only(bottom: 9), child: InkWell(
            borderRadius: BorderRadius.circular(16), onTap: _selected == null ? () => _choose(option) : null,
            child: Container(padding: const EdgeInsets.all(15), decoration: BoxDecoration(
              color: _selected != option ? widget.pillColor : (_correct == true ? widget.selectedColor : widget.accentColor),
              borderRadius: BorderRadius.circular(16), border: Border.all(color: widget.dividerColor)),
              child: Text(option, style: TextStyle(color: _selected == option ? widget.backgroundColor : widget.textColor))),
          )),
          if (_selected != null) ...[
            const SizedBox(height: 8),
            Text(_correct == true ? 'پاسخ درست است.' : 'پاسخ درست: ${exercise.answer}', style: TextStyle(color: _correct == true ? widget.selectedColor : widget.accentColor, fontWeight: FontWeight.w800)),
            const SizedBox(height: 6), Text(exercise.explanation, style: TextStyle(color: widget.mutedColor, height: 1.7)),
          ],
        ]))),
        const SizedBox(height: 10),
        SizedBox(width: double.infinity, child: FilledButton(onPressed: _selected == null ? null : _next, child: Text(_index + 1 == widget.exercises.length ? 'پایان مرور' : 'تمرین بعدی'))),
      ]))),
    ));
  }
}
