import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/ai/card_generator.dart';
import '../../core/auth/auth_providers.dart';
import '../../core/models/attempt.dart';
import '../../core/models/card.dart';
import '../../core/models/mock_exam.dart';
import '../../core/models/room.dart';
import '../../core/theme/layout.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/boss_sprite.dart';
import '../../core/widgets/chunky_button.dart';
import '../../core/widgets/chunky_card.dart';
import '../../core/widgets/stat_chip.dart';
import '../../fx/motion.dart';
import '../room/progress_repository.dart';
import '../room/progress_rules.dart';
import '../solo/quiz_question_view.dart';
import '../solo/solo_providers.dart';
import '../subjects/arcade_app_bar.dart';
import '../subjects/arcade_dialog.dart';
import 'mock_exam_model.dart';
import 'mock_exam_repository.dart';
import 'mock_exam_result_screen.dart';

/// 모의고사 보스전 (시안 game-exam, ink 배경).
///
/// - 전체 제한 시간, 문제 앞뒤 이동·번호로 이동, 답은 언제든 바꿀 수 있다.
/// - 보스 체력 = 아직 안 푼 문제 수. 답할수록 체력바가 줄어든다.
/// - 제출(또는 시간 끝) → 한 문제씩 채점 연출: 맞히면 `hit()` "적중!", 틀리면 `miss()`.
/// - 제출할 때 `rooms/{roomId}/mockExams`, `attempts`(mode: mock), XP를 저장한다.
class MockExamPlayScreen extends ConsumerStatefulWidget {
  const MockExamPlayScreen({
    super.key,
    required this.room,
    required this.cards,
    required this.votes,
    required this.weeks,
  });

  final Room room;

  /// 투표 많은 순
  final List<QuizCard> cards;

  /// cardId → 시작할 때 투표 수
  final Map<String, int> votes;
  final List<int> weeks;

  @override
  ConsumerState<MockExamPlayScreen> createState() => _MockExamPlayScreenState();
}

enum _Phase { exam, grading }

class _MockExamPlayScreenState extends ConsumerState<MockExamPlayScreen> {
  late final DateTime _startedAt = DateTime.now();
  late final int _limitSec = mockTimeLimitSec(widget.cards.length);
  late final DateTime _deadline = _startedAt.add(Duration(seconds: _limitSec));
  Timer? _clock;
  int _left = 0;

  int _index = 0;

  /// cardId → 내 답
  final Map<String, String> _answers = {};
  final Map<String, TextEditingController> _shortInputs = {};

  _Phase _phase = _Phase.exam;
  final _boss = BossController();
  List<MockMark> _marks = const [];
  int _graded = 0;
  int _gradeHp = 0;
  Timer? _gradeTimer;
  Future<int?>? _saving;
  DateTime? _submittedAt;
  bool _skipGrading = false;

  List<QuizCard> get _cards => widget.cards;
  QuizCard get _card => _cards[_index];
  int get _total => _cards.length;

  @override
  void initState() {
    super.initState();
    _left = _limitSec;
    _clock = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  @override
  void dispose() {
    _clock?.cancel();
    _gradeTimer?.cancel();
    _boss.dispose();
    for (final c in _shortInputs.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _tick() {
    final left = _deadline.difference(DateTime.now()).inSeconds;
    if (left <= 0) {
      setState(() => _left = 0);
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('시간 끝! 자동으로 제출했어요.')));
      _submit();
      return;
    }
    if (left != _left) setState(() => _left = left);
  }

  void _setAnswer(String answer) {
    setState(() {
      if (answer.trim().isEmpty) {
        _answers.remove(_card.id);
      } else {
        _answers[_card.id] = answer;
      }
    });
  }

  void _go(int i) {
    if (i < 0 || i >= _total) return;
    FocusScope.of(context).unfocus();
    setState(() => _index = i);
  }

  Future<void> _confirmSubmit() async {
    final left = unansweredCount(_cards, _answers);
    final ok = await showArcadeConfirm(
      context,
      title: '제출할까요?',
      message: left == 0
          ? '제출하면 답을 바꿀 수 없어요.'
          : '아직 안 푼 문제가 $left개 있어요. 안 푼 문제는 틀린 것으로 채점돼요.',
      confirmLabel: '제출하기',
      cancelLabel: '더 풀기',
      confirmColor: AppColors.lime,
    );
    if (ok && mounted) _submit();
  }

  /// 채점하고 저장을 시작한 뒤 채점 연출로 넘어간다.
  void _submit() {
    if (_phase != _Phase.exam) return;
    _clock?.cancel();
    FocusScope.of(context).unfocus();
    final marks = gradeMock(_cards, _answers);
    _submittedAt = DateTime.now();
    setState(() {
      _phase = _Phase.grading;
      _marks = marks;
      _graded = 0;
      _gradeHp = _total;
    });
    _saving = _save(marks);
    if (motionReduced(context)) {
      _finishGrading();
    } else {
      // 보스가 다시 나타난 걸 보고 나서 채점 시작
      _gradeTimer = Timer(AppMotion.pageTransition, _gradeNext);
    }
  }

  void _gradeNext() {
    if (!mounted || _skipGrading) return;
    if (_graded >= _marks.length) {
      _gradeTimer = Timer(AppMotion.stampShow, _openResult);
      return;
    }
    final mark = _marks[_graded];
    setState(() {
      _graded++;
      if (mark.correct) _gradeHp--;
    });
    mark.correct ? _boss.hit() : _boss.miss();
    _gradeTimer = Timer(gradingStep(_total), _gradeNext);
  }

  void _finishGrading() {
    _gradeTimer?.cancel();
    setState(() {
      _skipGrading = true;
      _graded = _marks.length;
      _gradeHp = _total - _marks.where((m) => m.correct).length;
    });
    _openResult();
  }

  /// 모의고사 기록 + 풀이 기록 + XP. 실패해도 결과는 보여 준다. 반환값은 얻은 XP.
  Future<int?> _save(List<MockMark> marks) async {
    final uid = ref.read(uidProvider);
    if (uid == null) return null;
    final score = marks.where((m) => m.correct).length;
    final now = _submittedAt ?? DateTime.now();
    final exam = MockExam(
      id: '',
      uid: uid,
      nickname: widget.room.nicknameOf(uid),
      cardIds: [for (final c in _cards) c.id],
      weeks: widget.weeks,
      timeLimitSec: _limitSec,
      score: score,
      total: _total,
      wrongCardIds: [
        for (final m in marks)
          if (!m.correct) m.card.id,
      ],
      startedAt: _startedAt,
      submittedAt: now,
    );
    try {
      await ref.read(mockExamRepositoryProvider).save(widget.room.id, exam);
      final attempts = ref.read(attemptRepositoryProvider);
      await attempts.saveAttempts(uid, [
        for (final m in marks)
          Attempt(
            id: attempts.newId(uid),
            cardId: m.card.id,
            subjectId: m.card.subjectId,
            concept: m.card.concept,
            correct: m.correct,
            mode: AttemptMode.mock,
            at: now,
          ),
      ]);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('기록을 저장하지 못했어요: $e')));
      }
      return null;
    }
    try {
      return await ref
          .read(progressRepositoryProvider)
          .record(uid, XpEvent.mock, bonusXp: score);
    } catch (_) {
      return null; // XP 실패는 결과를 막지 않는다
    }
  }

  bool _opening = false;

  Future<void> _openResult() async {
    if (_opening || !mounted) return;
    _opening = true;
    final xp = await (_saving ?? Future.value(null));
    if (!mounted) return;
    // push → pop으로 결과 화면의 선택("again"/"done")을 설정 화면까지 넘긴다.
    final outcome = await Navigator.of(context).push<String>(
      MaterialPageRoute<String>(
        builder: (_) => MockExamResultScreen(
          room: widget.room,
          marks: _marks,
          elapsed: (_submittedAt ?? DateTime.now()).difference(_startedAt),
          xp: xp,
        ),
      ),
    );
    if (!mounted) return;
    Navigator.of(context).pop(outcome);
  }

  Future<void> _quit() async {
    if (_phase != _Phase.exam) return;
    final ok = await showArcadeConfirm(
      context,
      title: '모의고사를 그만둘까요?',
      message: '제출하지 않으면 이번 모의고사는 기록되지 않아요.',
      confirmLabel: '그만두기',
      cancelLabel: '계속 풀기',
      confirmColor: AppColors.wrong,
    );
    if (ok && mounted) Navigator.of(context).pop();
  }

  Future<void> _openSheet() async {
    final picked = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: AppColors.cream,
      isScrollControlled: true,
      builder: (_) => _QuestionGrid(
        total: _total,
        current: _index,
        answered: {
          for (final (i, c) in _cards.indexed)
            if (_answers.containsKey(c.id)) i,
        },
      ),
    );
    if (!mounted || picked == null) return;
    if (picked < 0) {
      _confirmSubmit();
    } else {
      _go(picked);
    }
  }

  TextEditingController _shortFor(QuizCard c) => _shortInputs.putIfAbsent(
    c.id,
    () => TextEditingController(text: _answers[c.id] ?? ''),
  );

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _quit();
      },
      child: Scaffold(
        backgroundColor: AppColors.ink,
        appBar: ArcadeAppBar(
          backgroundColor: AppColors.ink,
          showBack: false,
          leading: _phase == _Phase.exam
              ? ArcadeIconButton(
                  icon: Icons.close,
                  semanticLabel: '그만두기',
                  onPressed: _quit,
                )
              : null,
          trailing: [
            _ClockChip(
              left: _left,
              urgent: _left <= 60 && _phase == _Phase.exam,
            ),
          ],
        ),
        bottomNavigationBar: _phase == _Phase.exam ? _examBar() : null,
        body: _phase == _Phase.exam ? _examBody() : _gradingBody(),
      ),
    );
  }

  Widget _examBody() {
    final card = _card;
    final left = unansweredCount(_cards, _answers);
    final votes = widget.votes[card.id] ?? 0;
    return ListView(
      padding: AppLayout.pagePadding(
        context,
        top: 0,
        bottom: AppSpacing.section * 2,
      ),
      children: [
        Center(
          child: Text(
            '${_index + 1} / $_total',
            style: AppTextStyles.titleM.copyWith(color: AppColors.paper),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        BossHpBar(name: '${widget.room.name} 보스', hp: left, maxHp: _total),
        const SizedBox(height: AppSpacing.sm),
        Center(
          child: BossSprite(
            hp: left,
            maxHp: _total,
            controller: _boss,
            size: 96,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        ChunkyCard(
          shadowColor: AppColors.grape,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.xs,
                children: [
                  StatChip(
                    label: CardGenerator.typeLabel(card.type),
                    color: AppColors.paper,
                  ),
                  if (votes > 0)
                    StatChip(
                      label: '$votes명이 나올 것 같대요',
                      icon: Icons.star_rounded,
                      color: AppColors.sun,
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              Text(card.question, style: AppTextStyles.titleM),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.section),
        ..._answerArea(card),
      ],
    );
  }

  List<Widget> _answerArea(QuizCard card) {
    final mine = _answers[card.id];
    QuizChoiceState stateOf(String v) =>
        mine == v ? QuizChoiceState.picked : QuizChoiceState.idle;
    return switch (card.type) {
      CardType.mcq => [
        for (final (i, choice) in card.choices.indexed) ...[
          QuizChoiceBlock(
            key: ValueKey('${card.id}-$i'),
            letter: String.fromCharCode(65 + i),
            text: choice,
            state: stateOf(choice),
            onTap: () => _setAnswer(choice),
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
      ],
      CardType.ox => [
        Row(
          children: [
            for (final v in const ['O', 'X']) ...[
              Expanded(
                child: QuizChoiceBlock(
                  letter: v,
                  text: v == 'O' ? '맞다' : '틀리다',
                  state: stateOf(v),
                  onTap: () => _setAnswer(v),
                ),
              ),
              if (v == 'O') const SizedBox(width: AppSpacing.sm),
            ],
          ],
        ),
      ],
      CardType.short => [
        TextField(
          key: ValueKey('short-${card.id}'),
          controller: _shortFor(card),
          textInputAction: TextInputAction.next,
          onChanged: _setAnswer,
          onSubmitted: (_) => _index + 1 < _total ? _go(_index + 1) : null,
          decoration: const InputDecoration(hintText: '정답을 적어 주세요'),
        ),
      ],
    };
  }

  Widget _examBar() {
    final last = _index + 1 >= _total;
    return SafeArea(
      minimum: const EdgeInsets.fromLTRB(
        AppSpacing.page,
        AppSpacing.sm,
        AppSpacing.page,
        AppSpacing.page,
      ),
      child: Center(
        heightFactor: 1,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: AppLayout.maxContent),
          child: Row(
            children: [
              ChunkyButton(
                expand: false,
                color: AppColors.paper,
                shadowColor: AppColors.grape,
                semanticLabel: '이전 문제',
                onPressed: _index == 0 ? null : () => _go(_index - 1),
                child: const Icon(Icons.chevron_left_rounded),
              ),
              const SizedBox(width: AppSpacing.sm),
              ChunkyButton(
                expand: false,
                color: AppColors.cyan,
                shadowColor: AppColors.grape,
                semanticLabel: '문제 목록',
                onPressed: _openSheet,
                child: const Icon(Icons.grid_view_rounded),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: ChunkyButton(
                  label: last ? '제출하기' : '다음 문제',
                  color: AppColors.lime,
                  shadowColor: AppColors.grape,
                  onPressed: last ? _confirmSubmit : () => _go(_index + 1),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _gradingBody() {
    final done = _graded >= _marks.length;
    final correct = _marks.take(_graded).where((m) => m.correct).length;
    return ListView(
      padding: AppLayout.pagePadding(
        context,
        top: 0,
        bottom: AppSpacing.section * 2,
      ),
      children: [
        Center(
          child: Text(
            done ? '채점 끝!' : '채점 중… $_graded / $_total',
            style: AppTextStyles.titleM.copyWith(color: AppColors.paper),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        BossHpBar(name: '${widget.room.name} 보스', hp: _gradeHp, maxHp: _total),
        const SizedBox(height: AppSpacing.section * 2),
        Center(
          child: BossSprite(
            hp: _gradeHp,
            maxHp: _total,
            controller: _boss,
            size: 180,
          ),
        ),
        const SizedBox(height: AppSpacing.section * 2),
        Text(
          '맞힌 문제마다 보스에게 데미지! 적중 $correct',
          textAlign: TextAlign.center,
          style: AppTextStyles.heading.copyWith(color: AppColors.lime),
        ),
        const SizedBox(height: AppSpacing.section),
        if (!done)
          Center(
            child: ChunkyButton(
              expand: false,
              label: '결과 바로 보기',
              color: AppColors.paper,
              shadowColor: AppColors.grape,
              onPressed: _finishGrading,
            ),
          ),
      ],
    );
  }
}

/// 남은 시간 알약 (1분 이하면 pink)
class _ClockChip extends StatelessWidget {
  const _ClockChip({required this.left, required this.urgent});

  final int left;
  final bool urgent;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '남은 시간 ${left ~/ 60}분 ${left % 60}초',
      excludeSemantics: true,
      child: StatChip(
        label: formatClock(left),
        icon: Icons.timer_outlined,
        color: urgent ? AppColors.pink : AppColors.sun,
      ),
    );
  }
}

/// 문제 번호판: 푼 문제 lime, 지금 문제 cyan. 고르면 그 번호, "제출하기"면 -1.
class _QuestionGrid extends StatelessWidget {
  const _QuestionGrid({
    required this.total,
    required this.current,
    required this.answered,
  });

  final int total;
  final int current;
  final Set<int> answered;

  @override
  Widget build(BuildContext context) {
    final left = total - answered.length;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.page),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('문제 목록', style: AppTextStyles.titleM),
            const SizedBox(height: AppSpacing.xs),
            Text(
              left == 0 ? '모두 풀었어요!' : '안 푼 문제 $left개',
              style: AppTextStyles.label,
            ),
            const SizedBox(height: AppSpacing.section),
            Flexible(
              child: SingleChildScrollView(
                child: Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: [
                    for (var i = 0; i < total; i++)
                      SizedBox(
                        width: AppSpacing.button,
                        child: ChunkyButton(
                          label: '${i + 1}',
                          color: i == current
                              ? AppColors.cyan
                              : answered.contains(i)
                              ? AppColors.lime
                              : AppColors.paper,
                          semanticLabel:
                              '${i + 1}번 ${answered.contains(i) ? '푼 문제' : '안 푼 문제'}',
                          onPressed: () => Navigator.of(context).pop(i),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.section),
            ChunkyButton(
              label: '제출하기',
              color: AppColors.lime,
              onPressed: () => Navigator.of(context).pop(-1),
            ),
          ],
        ),
      ),
    );
  }
}
