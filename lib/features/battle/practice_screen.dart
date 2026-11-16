import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/layout.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/chunky_button.dart';
import '../../core/widgets/chunky_card.dart';
import '../../core/widgets/rank_stamp.dart';
import '../../core/widgets/stat_chip.dart';
import '../../fx/haptics.dart';
import '../../fx/motion.dart';
import '../../fx/sound.dart';
import '../bank/bank_repository.dart';
import '../room/progress_rules.dart';
import 'battle_rules.dart';
import 'battle_view.dart';
import 'practice_game.dart';

/// 연습 문항 수
const kPracticeQuestions = 10;

/// 혼자 하는 배틀 연습: 우리 방 문제은행 문제를 섞어서 15초·콤보·정답 공개로 풀어 본다.
/// 실시간 대전이 아니라 기록·승패·XP·오답 노트에 들어가지 않는다.
/// (A의 "혼자 풀기"는 오답 노트용 공부, 이건 배틀 연출 맛보기)
class PracticeScreen extends ConsumerStatefulWidget {
  const PracticeScreen({super.key, required this.roomId});

  final String roomId;

  @override
  ConsumerState<PracticeScreen> createState() => _PracticeScreenState();
}

class _PracticeScreenState extends ConsumerState<PracticeScreen> {
  PracticeGame? _game;
  String? _error;
  DateTime _roundStart = DateTime.now();
  Timer? _ticker;
  int? _lastBeep;
  int _wrongShakes = 0;
  final _shortAnswer = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
    _ticker = Timer.periodic(const Duration(milliseconds: 100), (_) => _tick());
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _shortAnswer.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _game = null;
      _error = null;
    });
    try {
      final bank = ref.read(bankRepositoryProvider);
      final entries = await bank.topVoted(widget.roomId, limit: 1000);
      final ids = [for (final e in entries) e.cardId]..shuffle();
      final cards = await bank.cardsByIds(
        ids.take(kPracticeQuestions).toList(),
      );
      if (!mounted) return;
      if (cards.isEmpty) {
        setState(() => _error = '문제은행에 문제가 없어요.\n먼저 내 카드를 올려 주세요.');
        return;
      }
      setState(() {
        _game = PracticeGame(cards);
        _startRound();
      });
    } catch (_) {
      if (mounted) setState(() => _error = '문제를 불러오지 못했어요.');
    }
  }

  void _startRound() {
    _roundStart = DateTime.now();
    _lastBeep = null;
    _shortAnswer.clear();
  }

  Duration get _elapsed => DateTime.now().difference(_roundStart);

  int get _answerElapsedMs => (_elapsed - BattleRules.countdown).inMilliseconds
      .clamp(0, BattleRules.answerTime.inMilliseconds);

  RoundPhase get _phase {
    final g = _game;
    if (g == null || g.finished) return RoundPhase.reveal;
    return phaseAt(_elapsed, everyoneAnswered: g.answered);
  }

  void _tick() {
    final g = _game;
    if (!mounted || g == null || g.finished) return;
    final phase = _phase;
    if (phase == RoundPhase.countdown) {
      final n = BattleRules.countdown.inSeconds - _elapsed.inSeconds;
      if (n > 0 && n != _lastBeep) {
        _lastBeep = n;
        Sound.play(Sfx.countdown);
      }
    }
    if (phase == RoundPhase.reveal && !g.answered) {
      g.timeout();
      _feedback(false);
    }
    setState(() {});
  }

  void _pick(String choice) {
    final g = _game;
    if (g == null || g.answered || _phase != RoundPhase.question) return;
    if (choice.trim().isEmpty) return;
    final correct = g.answer(choice, elapsedMs: _answerElapsedMs);
    _feedback(correct);
    setState(() {});
  }

  void _feedback(bool correct) {
    if (correct) {
      Haptics.light();
      Sound.play(Sfx.correct);
    } else {
      Haptics.medium();
      Sound.play(Sfx.wrong);
      _wrongShakes++;
    }
  }

  void _next() {
    final g = _game;
    if (g == null) return;
    setState(() {
      g.next();
      if (!g.finished) _startRound();
    });
  }

  @override
  Widget build(BuildContext context) {
    final g = _game;
    return Scaffold(
      backgroundColor: g != null && g.finished ? AppColors.sun : AppColors.ink,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: g != null && g.finished
            ? AppColors.ink
            : AppColors.paper,
        title: const Text('혼자 연습'),
      ),
      body: SafeArea(child: _body(g)),
    );
  }

  Widget _body(PracticeGame? g) {
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.page),
          child: Text(
            _error!,
            textAlign: TextAlign.center,
            style: AppTextStyles.body.copyWith(color: AppColors.paper),
          ),
        ),
      );
    }
    if (g == null) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.paper),
      );
    }
    if (g.finished) return _result(g);

    final phase = _phase;
    final left = Duration(
      milliseconds: BattleRules.answerTime.inMilliseconds - _answerElapsedMs,
    );
    final card = g.card;
    return ListView(
      padding: AppLayout.pagePadding(
        context,
        top: AppSpacing.sm,
        bottom: AppSpacing.section * 2,
      ),
      children: [
        Row(
          children: [
            Text(
              '${g.round + 1} / ${g.total}',
              style: AppTextStyles.titleM.copyWith(color: AppColors.paper),
            ),
            const Spacer(),
            StatChip(label: '${g.score}점', color: AppColors.lime),
            if (g.combo >= BattleRules.comboFrom) ...[
              const SizedBox(width: AppSpacing.xs),
              StatChip(label: 'x${g.combo}', color: AppColors.pink),
            ],
            const SizedBox(width: AppSpacing.xs),
            StatChip(
              label: phase == RoundPhase.question
                  ? '${(left.inMilliseconds / 1000).ceil()}초'
                  : phase == RoundPhase.countdown
                  ? '준비'
                  : '정답 공개',
              icon: Icons.timer_outlined,
              color: phase == RoundPhase.question && left.inSeconds < 5
                  ? AppColors.pink
                  : AppColors.sun,
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.section),
        if (phase == RoundPhase.countdown)
          BattleCountdown(
            left: BattleRules.countdown.inSeconds - _elapsed.inSeconds,
          )
        else ...[
          FlipIn(
            key: ValueKey('practice-flip-${g.round}'),
            child: Shake(
              trigger: _wrongShakes,
              child: ChunkyCard(
                shadowColor: AppColors.grape,
                child: Text(card.question, style: AppTextStyles.heading),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          BattleAnswerArea(
            card: card,
            phase: phase,
            myChoice: g.choice,
            shortAnswer: _shortAnswer,
            onPick: g.answered ? null : _pick,
          ),
          if (phase == RoundPhase.reveal) ...[
            const SizedBox(height: AppSpacing.section),
            Text(
              (g.results.lastOrNull ?? false)
                  ? '적중!'
                  : '빗나감 · 정답: ${card.answer}',
              textAlign: TextAlign.center,
              style: AppTextStyles.heading.copyWith(
                color: (g.results.lastOrNull ?? false)
                    ? AppColors.lime
                    : AppColors.wrong,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            ChunkyButton(
              label: g.round + 1 >= g.total ? '결과 보기' : '다음 문제',
              color: AppColors.lime,
              onPressed: _next,
            ),
          ],
        ],
      ],
    );
  }

  Widget _result(PracticeGame g) {
    return ListView(
      padding: AppLayout.pagePadding(
        context,
        top: AppSpacing.sm,
        bottom: AppSpacing.section * 2,
      ),
      children: [
        Center(child: RankStamp(rank: resultRank(g.percent))),
        const SizedBox(height: AppSpacing.section),
        ChunkyCard(
          title: '연습 결과',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${g.score}점', style: AppTextStyles.titleM),
              const SizedBox(height: AppSpacing.xs),
              Text(
                '${g.total}문제 중 ${g.correctCount}개 적중 · 정답률 ${g.percent}% · 최고 콤보 x${g.bestCombo}',
                style: AppTextStyles.bodyS,
              ),
              const SizedBox(height: AppSpacing.sm),
              const Text(
                '연습은 배틀 기록·승패·XP·오답 노트에 들어가지 않아요',
                style: AppTextStyles.caption,
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.section),
        ChunkyButton(
          label: '다시 연습하기',
          icon: Icons.replay_rounded,
          color: AppColors.pink,
          onPressed: _load,
        ),
        const SizedBox(height: AppSpacing.sm),
        ChunkyButton(
          label: '나가기',
          color: AppColors.paper,
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }
}

/// 연습 화면 열기
void openPractice(BuildContext context, String roomId) {
  Navigator.of(context).push(
    MaterialPageRoute<void>(builder: (_) => PracticeScreen(roomId: roomId)),
  );
}
