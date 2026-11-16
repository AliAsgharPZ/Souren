import 'dart:math' as math;
import 'package:material_ui/material_ui.dart';
import 'data/ario_lab.dart';
import 'data/store.dart';

typedef ArioLabRatedCallback = Future<void> Function(String wordId, ArioReviewRating rating);

class ArioLabQuizPage extends StatefulWidget {
  final List<Entry> entries;
  final String title;
  final bool mixedChallenge;
  final void Function(Entry entry, bool correct) onAnswered;
  final Future<void> Function(int answers, int correct, bool mixed) onFinished;
  final Color backgroundColor, cardColor, pillColor, textColor, mutedColor, selectedColor, accentColor, dividerColor;
  const ArioLabQuizPage({super.key, required this.entries, required this.title, this.mixedChallenge = false, required this.onAnswered, required this.onFinished, required this.backgroundColor, required this.cardColor, required this.pillColor, required this.textColor, required this.mutedColor, required this.selectedColor, required this.accentColor, required this.dividerColor});
  @override
  State<ArioLabQuizPage> createState() => _ArioLabQuizPageState();
}

class _ArioLabQuestion {
  final Entry entry;
  final String instruction, prompt, answer;
  final List<String> options;
  const _ArioLabQuestion(this.entry, this.instruction, this.prompt, this.answer, this.options);
}

class _ArioLabQuizPageState extends State<ArioLabQuizPage> {
  int _mode = 0, _index = 0, _correct = 0;
  bool _started = false, _finished = false, _reported = false;
  String? _selected;
  List<_ArioLabQuestion> _questions = [];

  void _start() {
    final pool = widget.entries.where((e) => e.hasFa).toList()..shuffle(math.Random());
    if (pool.length < 2) return;
    final random = math.Random();
    final count = math.min(widget.mixedChallenge ? 12 : 10, pool.length);
    final questions = <_ArioLabQuestion>[];
    for (var i = 0; i < count; i++) {
      var kind = widget.mixedChallenge ? i % 3 : (_mode == 2 ? i % 2 : _mode);
      final entry = pool[i];
      if (kind == 2 && entry.concept.trim().isEmpty) kind = 1;
      final arabicAnswers = kind != 0;
      final instruction = kind == 0
          ? 'برابر فارسی این واژه را انتخاب کن'
          : kind == 1
              ? 'این معنی به کدام واژهٔ عربی مربوط است؟'
              : 'این تعریف به کدام واژه مربوط است؟';
      final prompt = kind == 0 ? entry.ar : kind == 1 ? entry.fa.first : entry.concept.trim();
      final answer = arabicAnswers ? entry.ar : entry.fa.first;
      final choices = <String>{answer};
      final distractors = pool.where((e) => e.ar != entry.ar).toList()..shuffle(random);
      for (final other in distractors) {
        choices.add(arabicAnswers ? other.ar : other.fa.first);
        if (choices.length == 4) break;
      }
      final options = choices.toList()..shuffle(random);
      questions.add(_ArioLabQuestion(entry, instruction, prompt, answer, options));
    }
    setState(() {
      _questions = questions;
      _started = true;
      _finished = false;
      _reported = false;
      _index = 0;
      _correct = 0;
      _selected = null;
    });
  }

  void _answer(String choice) {
    if (_selected != null || _finished) return;
    final question = _questions[_index];
    final correct = choice == question.answer;
    setState(() {
      _selected = choice;
      if (correct) _correct++;
    });
    widget.onAnswered(question.entry, correct);
  }

  Future<void> _next() async {
    if (_selected == null) return;
    if (_index + 1 < _questions.length) {
      setState(() { _index++; _selected = null; });
      return;
    }
    setState(() => _finished = true);
    if (!_reported) {
      _reported = true;
      await widget.onFinished(_questions.length, _correct, widget.mixedChallenge);
    }
  }

  Widget _panel(Widget child) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(19),
    decoration: BoxDecoration(color: widget.cardColor, borderRadius: BorderRadius.circular(24)),
    child: child,
  );

  @override
  Widget build(BuildContext context) {
    final poolCount = widget.entries.where((e) => e.hasFa).length;
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: widget.backgroundColor,
        appBar: AppBar(title: Text(widget.title), backgroundColor: widget.backgroundColor, foregroundColor: widget.textColor, elevation: 0),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
            children: [
              if (!_started)
                _panel(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(widget.mixedChallenge ? 'چالش چندمهارته' : 'تمرین مستقل واژگان', style: TextStyle(color: widget.textColor, fontSize: 19, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 8),
                  Text(
                    widget.mixedChallenge
                        ? '۱۲ پرسش با جابه‌جایی میان ترجمه، یادآوری معکوس و تشخیص واژه از روی تعریف. نتیجه فقط روی همین دستگاه ثبت می‌شود.'
                        : 'یک دور ۱۰ پرسشی از واژه‌های پایگاه آفلاین. جهت پرسش را خودت انتخاب کن.',
                    style: TextStyle(color: widget.mutedColor, height: 1.8, fontSize: 13),
                  ),
                  if (!widget.mixedChallenge) ...[
                    const SizedBox(height: 18),
                    Text('شیوهٔ تمرین', style: TextStyle(color: widget.textColor, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 9),
                    Wrap(spacing: 7, runSpacing: 7, children: [
                      _modeChip(0, 'عربی به فارسی'),
                      _modeChip(1, 'فارسی به عربی'),
                      _modeChip(2, 'دوطرفه'),
                    ]),
                  ],
                  const SizedBox(height: 16),
                  Text('${poolCount} واژهٔ دارای معنی در دسترس است.', style: TextStyle(color: widget.mutedColor, fontSize: 12)),
                ]))
              else if (_finished)
                _panel(Column(children: [
                  Icon(Icons.assessment_outlined, size: 38, color: widget.selectedColor),
                  const SizedBox(height: 12),
                  Text('نتیجهٔ دور', style: TextStyle(color: widget.textColor, fontSize: 20, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 8),
                  Text('${_correct} از ${_questions.length} پاسخ درست', style: TextStyle(color: widget.selectedColor, fontSize: 18, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 5),
                  Text('دقت ${(_correct * 100 / _questions.length).round()}٪', style: TextStyle(color: widget.mutedColor)),
                  const SizedBox(height: 12),
                  Text(widget.mixedChallenge ? 'بهترین درصد چالش ترکیبی در گزارش آزمایشگاه ذخیره می‌شود.' : 'واژه‌هایی که اشتباه پاسخ دادی به صف مرور هوشمند اضافه شدند.', textAlign: TextAlign.center, style: TextStyle(color: widget.mutedColor, height: 1.7)),
                ]))
              else ...[
                Row(children: [
                  Expanded(child: Text('پرسش ${_index + 1} از ${_questions.length}', style: TextStyle(color: widget.mutedColor, fontWeight: FontWeight.w700))),
                  Text('درست: $_correct', style: TextStyle(color: widget.selectedColor, fontWeight: FontWeight.w800)),
                ]),
                const SizedBox(height: 9),
                ClipRRect(borderRadius: BorderRadius.circular(20), child: LinearProgressIndicator(value: (_index + (_selected == null ? 0 : 1)) / _questions.length, minHeight: 7, backgroundColor: widget.dividerColor, color: widget.selectedColor)),
                const SizedBox(height: 16),
                _panel(Column(children: [
                  Text(_questions[_index].instruction, textAlign: TextAlign.center, style: TextStyle(color: widget.mutedColor, fontSize: 13)),
                  const SizedBox(height: 16),
                  Text(_questions[_index].prompt, textAlign: TextAlign.center, style: TextStyle(color: widget.textColor, fontSize: _questions[_index].prompt.length > 55 ? 20 : 28, fontWeight: FontWeight.w800, height: 1.8)),
                ])),
                const SizedBox(height: 13),
                for (final option in _questions[_index].options)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: OutlinedButton(
                      onPressed: _selected == null ? () => _answer(option) : null,
                      style: OutlinedButton.styleFrom(
                        alignment: Alignment.centerRight,
                        foregroundColor: widget.textColor,
                        disabledForegroundColor: widget.textColor,
                        side: BorderSide(color: _selected == option ? (_selected == _questions[_index].answer ? widget.selectedColor : widget.accentColor) : widget.dividerColor),
                        backgroundColor: _selected == option ? (_selected == _questions[_index].answer ? widget.selectedColor.withValues(alpha: .12) : widget.accentColor.withValues(alpha: .12)) : widget.cardColor,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      ),
                      child: Row(children: [
                        Expanded(child: Text(option, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600))),
                        if (_selected != null && option == _questions[_index].answer) Icon(Icons.check_circle_outline, color: widget.selectedColor, size: 19),
                        if (_selected == option && option != _questions[_index].answer) Icon(Icons.cancel_outlined, color: widget.accentColor, size: 19),
                      ]),
                    ),
                  ),
                if (_selected != null) ...[
                  const SizedBox(height: 4),
                  Text(_selected == _questions[_index].answer ? 'پاسخ درست است.' : 'پاسخ درست: ${_questions[_index].answer}', style: TextStyle(color: _selected == _questions[_index].answer ? widget.selectedColor : widget.accentColor, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 12),
                  SizedBox(width: double.infinity, child: FilledButton(onPressed: _next, style: FilledButton.styleFrom(backgroundColor: widget.selectedColor, foregroundColor: widget.backgroundColor, padding: const EdgeInsets.symmetric(vertical: 14)), child: Text(_index + 1 == _questions.length ? 'دیدن نتیجه' : 'پرسش بعدی'))),
                ],
              ],
              if (!_started || _finished) ...[
                const SizedBox(height: 14),
                SizedBox(width: double.infinity, child: FilledButton(onPressed: poolCount < 2 ? null : _start, style: FilledButton.styleFrom(backgroundColor: widget.selectedColor, foregroundColor: widget.backgroundColor, padding: const EdgeInsets.symmetric(vertical: 14)), child: Text(_finished ? 'یک دور دیگر' : (widget.mixedChallenge ? 'شروع چالش' : 'شروع تمرین')))),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _modeChip(int value, String label) => ChoiceChip(
    label: Text(label),
    selected: _mode == value,
    onSelected: (_) => setState(() => _mode = value),
    selectedColor: widget.selectedColor.withValues(alpha: .18),
    backgroundColor: widget.pillColor,
    labelStyle: TextStyle(color: _mode == value ? widget.selectedColor : widget.textColor, fontWeight: FontWeight.w700),
    side: BorderSide(color: _mode == value ? widget.selectedColor : widget.dividerColor),
  );
}

class ArioLabReviewPage extends StatefulWidget {
  final List<Entry> entries;
  final ArioLabState reviewState;
  final ArioLabRatedCallback onRated;
  final Color backgroundColor, cardColor, textColor, mutedColor, selectedColor, accentColor, dividerColor;
  const ArioLabReviewPage({super.key, required this.entries, required this.reviewState, required this.onRated, required this.backgroundColor, required this.cardColor, required this.textColor, required this.mutedColor, required this.selectedColor, required this.accentColor, required this.dividerColor});
  @override
  State<ArioLabReviewPage> createState() => _ArioLabReviewPageState();
}

class _ArioLabReviewPageState extends State<ArioLabReviewPage> {
  late final Map<String, Entry> _byId = {for (final e in widget.entries) e.ar: e};
  late final List<String> _queue = widget.reviewState.dueWordIds(_byId.keys);
  int _index = 0;
  bool _revealed = false, _busy = false;
  Entry? get _current => _index < _queue.length ? _byId[_queue[_index]] : null;

  @override
  Widget build(BuildContext context) {
    final entry = _current;
    final nextDue = widget.reviewState.nextDueAt(_byId.keys);
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: widget.backgroundColor,
        appBar: AppBar(title: const Text('مرور هوشمند'), backgroundColor: widget.backgroundColor, foregroundColor: widget.textColor, elevation: 0),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
            children: [
              if (entry == null) ...[
                Container(padding: const EdgeInsets.all(17), decoration: BoxDecoration(color: widget.cardColor, borderRadius: BorderRadius.circular(22)), child: Column(children: [
                  Icon(Icons.event_available_outlined, color: widget.selectedColor, size: 30),
                  const SizedBox(height: 9),
                  Text('برنامهٔ مرور', style: TextStyle(color: widget.textColor, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 5),
                  Text(nextDue == null ? 'با یادگیری واژه‌ها، کارت‌های مرور در این بخش ساخته می‌شوند.' : 'نوبت بعدی: ${_formatDue(nextDue)}', textAlign: TextAlign.center, style: TextStyle(color: widget.mutedColor, height: 1.7)),
                ])),
                const SizedBox(height: 12),
                Text(_queue.isEmpty ? 'فعلاً واژهٔ سررسیدشده‌ای نداری.' : 'مرور این نوبت تمام شد.', textAlign: TextAlign.center, style: TextStyle(color: widget.textColor, fontSize: 18, fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                Text('زمان‌بندی مرور به پاسخ‌های قبلی وابسته است و روی همین دستگاه نگهداری می‌شود.', textAlign: TextAlign.center, style: TextStyle(color: widget.mutedColor, height: 1.8)),
              ] else ...[
                Row(children: [
                  Expanded(child: Text('کارت ${_index + 1} از ${_queue.length}', style: TextStyle(color: widget.mutedColor, fontWeight: FontWeight.w700))),
                  Text('مرور فاصله‌دار', style: TextStyle(color: widget.selectedColor, fontSize: 12, fontWeight: FontWeight.w700)),
                ]),
                const SizedBox(height: 9),
                ClipRRect(borderRadius: BorderRadius.circular(20), child: LinearProgressIndicator(value: (_index + 1) / _queue.length, minHeight: 7, backgroundColor: widget.dividerColor, color: widget.selectedColor)),
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(color: widget.cardColor, borderRadius: BorderRadius.circular(25)),
                  child: Column(children: [
                    Text('معنی این واژه را به خاطر بیاور', style: TextStyle(color: widget.mutedColor, fontSize: 13)),
                    const SizedBox(height: 18),
                    Text(entry.ar, textAlign: TextAlign.center, style: TextStyle(color: widget.textColor, fontSize: 33, fontWeight: FontWeight.w800)),
                    if (_revealed) ...[
                      const SizedBox(height: 18),
                      Divider(color: widget.dividerColor),
                      Text(entry.fa.join('، '), textAlign: TextAlign.center, style: TextStyle(color: widget.selectedColor, fontSize: 18, fontWeight: FontWeight.w700, height: 1.8)),
                      if (entry.concept.trim().isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(entry.concept, textAlign: TextAlign.center, style: TextStyle(color: widget.mutedColor, height: 1.8)),
                      ],
                    ],
                  ]),
                ),
                const SizedBox(height: 14),
                if (!_revealed)
                  FilledButton(onPressed: () => setState(() => _revealed = true), style: FilledButton.styleFrom(backgroundColor: widget.selectedColor, foregroundColor: widget.backgroundColor, padding: const EdgeInsets.symmetric(vertical: 14)), child: const Text('نمایش پاسخ'))
                else ...[
                  Text('چقدر راحت پاسخ را به یاد آوردی؟', textAlign: TextAlign.center, style: TextStyle(color: widget.mutedColor, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 10),
                  Wrap(spacing: 7, runSpacing: 7, alignment: WrapAlignment.center, children: [
                    _ratingButton('دوباره', ArioReviewRating.again, widget.accentColor),
                    _ratingButton('سخت', ArioReviewRating.hard, widget.mutedColor),
                    _ratingButton('خوب', ArioReviewRating.good, widget.selectedColor),
                    _ratingButton('آسان', ArioReviewRating.easy, widget.selectedColor),
                  ]),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _formatDue(DateTime date) {
    final now = DateTime.now();
    if (date.isBefore(now.add(const Duration(days: 1)))) {
      return 'امروز، ساعت ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    }
    return '${date.year}/${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')}';
  }

  Widget _ratingButton(String label, ArioReviewRating rating, Color color) => OutlinedButton(
    onPressed: _busy ? null : () async {
      final entry = _current;
      if (entry == null) return;
      setState(() => _busy = true);
      await widget.onRated(entry.ar, rating);
      if (!mounted) return;
      setState(() { _index++; _revealed = false; _busy = false; });
    },
    style: OutlinedButton.styleFrom(foregroundColor: color, side: BorderSide(color: color.withValues(alpha: .65)), padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 11)),
    child: Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
  );
}

class ArioLabFlashcardsPage extends StatefulWidget {
  final List<Entry> entries;
  final ArioLabRatedCallback onRated;
  final Color backgroundColor, cardColor, textColor, mutedColor, selectedColor, accentColor, dividerColor;
  const ArioLabFlashcardsPage({super.key, required this.entries, required this.onRated, required this.backgroundColor, required this.cardColor, required this.textColor, required this.mutedColor, required this.selectedColor, required this.accentColor, required this.dividerColor});
  @override
  State<ArioLabFlashcardsPage> createState() => _ArioLabFlashcardsPageState();
}

class _ArioLabFlashcardsPageState extends State<ArioLabFlashcardsPage> {
  late final List<Entry> _order = [...widget.entries]..shuffle(math.Random());
  int _index = 0;
  bool _revealed = false;
  Entry? get _current => _order.isEmpty ? null : _order[_index % _order.length];

  @override
  Widget build(BuildContext context) {
    final entry = _current;
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: widget.backgroundColor,
        appBar: AppBar(title: const Text('فلش‌کارت واژگان'), backgroundColor: widget.backgroundColor, foregroundColor: widget.textColor, elevation: 0),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
            children: [
              if (entry == null)
                Text('واژه‌ای برای نمایش وجود ندارد.', style: TextStyle(color: widget.mutedColor))
              else ...[
                Row(children: [
                  Expanded(child: Text('کارت ${_index % _order.length + 1} از ${_order.length}', style: TextStyle(color: widget.mutedColor, fontWeight: FontWeight.w700))),
                  TextButton.icon(onPressed: () => setState(() { _order.shuffle(math.Random()); _index = 0; _revealed = false; }), icon: Icon(Icons.shuffle, color: widget.selectedColor, size: 18), label: Text('درهم‌ریزی', style: TextStyle(color: widget.selectedColor))),
                ]),
                const SizedBox(height: 10),
                InkWell(
                  onTap: () => setState(() => _revealed = !_revealed),
                  borderRadius: BorderRadius.circular(25),
                  child: Container(
                    constraints: const BoxConstraints(minHeight: 250),
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(color: widget.cardColor, borderRadius: BorderRadius.circular(25)),
                    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Text(_revealed ? 'معنی واژه' : 'واژه را به خاطر بیاور', style: TextStyle(color: widget.mutedColor, fontSize: 13)),
                      const SizedBox(height: 19),
                      Text(entry.ar, textAlign: TextAlign.center, style: TextStyle(color: widget.textColor, fontSize: 34, fontWeight: FontWeight.w800)),
                      if (_revealed) ...[
                        const SizedBox(height: 15),
                        Divider(color: widget.dividerColor),
                        Text(entry.fa.join('، '), textAlign: TextAlign.center, style: TextStyle(color: widget.selectedColor, fontSize: 18, fontWeight: FontWeight.w700, height: 1.8)),
                        if (entry.concept.trim().isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(entry.concept, textAlign: TextAlign.center, style: TextStyle(color: widget.mutedColor, height: 1.7)),
                        ],
                      ],
                      const SizedBox(height: 12),
                      Text(_revealed ? 'برای پنهان‌کردن پاسخ لمس کن' : 'برای دیدن پاسخ لمس کن', style: TextStyle(color: widget.mutedColor, fontSize: 11.5)),
                    ]),
                  ),
                ),
                const SizedBox(height: 14),
                if (_revealed)
                  Row(children: [
                    Expanded(child: OutlinedButton(onPressed: () async { await widget.onRated(entry.ar, ArioReviewRating.again); if (mounted) setState(() { _index++; _revealed = false; }); }, style: OutlinedButton.styleFrom(foregroundColor: widget.accentColor, side: BorderSide(color: widget.accentColor)), child: const Text('نیاز به تمرین'))),
                    const SizedBox(width: 9),
                    Expanded(child: FilledButton(onPressed: () async { await widget.onRated(entry.ar, ArioReviewRating.easy); if (mounted) setState(() { _index++; _revealed = false; }); }, style: FilledButton.styleFrom(backgroundColor: widget.selectedColor, foregroundColor: widget.backgroundColor), child: const Text('بلدم'))),
                  ])
                else
                  OutlinedButton(onPressed: () => setState(() => _revealed = true), style: OutlinedButton.styleFrom(foregroundColor: widget.textColor, side: BorderSide(color: widget.dividerColor), padding: const EdgeInsets.symmetric(vertical: 13)), child: const Text('نمایش پاسخ')),
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(child: OutlinedButton(onPressed: _index == 0 ? null : () => setState(() { _index--; _revealed = false; }), child: const Text('قبلی'))),
                  const SizedBox(width: 8),
                  Expanded(child: OutlinedButton(onPressed: () => setState(() { _index++; _revealed = false; }), child: const Text('بعدی'))),
                ]),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class ArioLabExplorerPage extends StatefulWidget {
  final List<Entry> entries;
  final VoidCallback onSearch;
  final Color backgroundColor, cardColor, textColor, mutedColor, selectedColor, dividerColor;
  const ArioLabExplorerPage({super.key, required this.entries, required this.onSearch, required this.backgroundColor, required this.cardColor, required this.textColor, required this.mutedColor, required this.selectedColor, required this.dividerColor});
  @override
  State<ArioLabExplorerPage> createState() => _ArioLabExplorerPageState();
}

class _ArioLabExplorerPageState extends State<ArioLabExplorerPage> {
  final TextEditingController _search = TextEditingController();
  @override
  void dispose() { _search.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final query = _search.text.trim().toLowerCase();
    final results = widget.entries.where((e) => query.isEmpty ||
      e.ar.toLowerCase().contains(query) ||
      e.fa.any((meaning) => meaning.toLowerCase().contains(query)) ||
      e.concept.toLowerCase().contains(query)
    ).take(80).toList(growable: false);
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: widget.backgroundColor,
        appBar: AppBar(title: const Text('کاوشگر واژگان'), backgroundColor: widget.backgroundColor, foregroundColor: widget.textColor, elevation: 0),
        body: SafeArea(
          child: Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 8, 18, 12),
              child: TextField(
                controller: _search,
                onChanged: (_) => setState(() {}),
                onSubmitted: (_) { if (_search.text.trim().isNotEmpty) widget.onSearch(); },
                textDirection: TextDirection.rtl,
                decoration: InputDecoration(
                  hintText: 'جست‌وجوی عربی، فارسی یا تعریف',
                  prefixIcon: const Icon(Icons.search),
                  filled: true,
                  fillColor: widget.cardColor,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide.none),
                ),
              ),
            ),
            Padding(padding: const EdgeInsets.symmetric(horizontal: 20), child: Align(alignment: Alignment.centerRight, child: Text(results.length.toString() + (query.isNotEmpty ? ' نتیجهٔ نخست' : ' واژهٔ نخست'), style: TextStyle(color: widget.mutedColor, fontSize: 12)))),
            const SizedBox(height: 8),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(18, 0, 18, 24),
                itemCount: results.length,
                separatorBuilder: (_, __) => Divider(height: 1, color: widget.dividerColor),
                itemBuilder: (context, index) {
                  final entry = results[index];
                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                    title: Text(entry.ar, style: TextStyle(color: widget.textColor, fontWeight: FontWeight.w800)),
                    subtitle: Text(entry.fa.join('، '), maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: widget.mutedColor)),
                    trailing: Icon(Icons.chevron_left, color: widget.mutedColor),
                    onTap: () => _showEntry(entry),
                  );
                },
              ),
            ),
          ]),
        ),
      ),
    );
  }

  void _showEntry(Entry entry) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: widget.backgroundColor,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(22, 18, 22, 28),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text(entry.ar, textAlign: TextAlign.center, style: TextStyle(color: widget.textColor, fontSize: 30, fontWeight: FontWeight.w800)),
            const SizedBox(height: 10),
            Text(entry.fa.join('، '), textAlign: TextAlign.center, style: TextStyle(color: widget.selectedColor, fontSize: 17, fontWeight: FontWeight.w700, height: 1.8)),
            if (entry.concept.trim().isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(entry.concept, textAlign: TextAlign.right, style: TextStyle(color: widget.mutedColor, height: 1.9)),
            ],
            const SizedBox(height: 14),
            Divider(color: widget.dividerColor),
            Text('سطح واژه: ${entry.level} از ۱۰۰', style: TextStyle(color: widget.mutedColor)),
            const SizedBox(height: 6),
            Text('شاخص دشواری: ${entry.difficultyScore}', style: TextStyle(color: widget.mutedColor)),
            const SizedBox(height: 6),
            Text('رتبهٔ بسامد تخمینی: ${entry.frequencyRankEstimate}', style: TextStyle(color: widget.mutedColor)),
          ]),
        ),
      ),
    );
  }
}
