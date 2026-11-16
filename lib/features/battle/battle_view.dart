import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/card.dart';
import '../../core/models/room.dart';
import '../../core/theme/layout.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/chunky_button.dart';
import '../../core/widgets/chunky_card.dart';
import '../../core/widgets/chunky_press.dart';
import '../../core/widgets/outlined_text.dart';
import '../../core/widgets/stat_chip.dart';
import '../../fx/haptics.dart';
import '../../fx/motion.dart';
import '../../fx/sound.dart';
import '../bank/bank_repository.dart';
import 'battle_repository.dart';
import 'battle_result.dart';
import 'battle_rules.dart';

/// 출제된 카드들 (cardIds를 쉼표로 이은 문자열 → 카드, 순서 유지)
final _battleCardsProvider = FutureProvider.autoDispose
    .family<List<QuizCard>, String>((ref, joined) {
      final ids = joined.isEmpty ? <String>[] : joined.split(',');
      return ref.watch(bankRepositoryProvider).cardsByIds(ids);
    });

final _answersProvider = StreamProvider.autoDispose
    .family<List<BattleAnswer>, (String, int)>(
      (ref, args) =>
          ref.watch(battleRepositoryProvider).watchAnswers(args.$1, args.$2),
    );

/// 배틀 진행 화면 (대기실 화면 안에서 status가 playing/finished일 때 보인다).
///
/// 라운드: 3-2-1 → 문제(15초) → 정답 공개(2.5초) → 방장 화면이 다음 문제로 넘김.
/// 모두 답하면 15초를 다 기다리지 않고 바로 정답 공개.
/// 시간은 각자 기기에서 "새 라운드를 받은 순간"부터 잰다 (기기 시계 차이 영향 없음).
class BattleView extends ConsumerStatefulWidget {
  const BattleView({
    super.key,
    required this.room,
    required this.uid,
    required this.onBackToWaiting,
  });

  final Room room;
  final String uid;

  /// 방장: 끝난 뒤 대기실로
  final VoidCallback onBackToWaiting;

  @override
  ConsumerState<BattleView> createState() => _BattleViewState();
}

class _BattleViewState extends ConsumerState<BattleView> {
  late int _round = widget.room.round;

  /// 배틀 중에 (다시) 들어왔으면 서버 시각으로 다른 사람과 맞춘다.
  late DateTime _roundStart = roundStartFor(
    widget.room.roundStartedAt,
    DateTime.now(),
  );
  late final AppLifecycleListener _lifecycle;
  DateTime? _revealAt;
  String? _myChoice;
  bool _submitted = false;
  bool _advancing = false;

  /// 마지막으로 소리 낸 카운트다운 숫자 (같은 숫자에 두 번 안 울리게)
  int? _lastBeep;

  /// 오답이면 올려서 문제 카드를 흔든다
  int _wrongShakes = 0;
  Timer? _ticker;
  final _shortAnswer = TextEditingController();

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(milliseconds: 100), (_) => _tick());
    // 앱을 내렸다 돌아오면 그사이 흐른 시간을 서버 시각으로 다시 맞춘다.
    _lifecycle = AppLifecycleListener(
      onResume: () {
        if (!mounted) return;
        setState(() {
          _roundStart = roundStartFor(
            widget.room.roundStartedAt,
            DateTime.now(),
          );
        });
      },
    );
  }

  @override
  void didUpdateWidget(BattleView old) {
    super.didUpdateWidget(old);
    if (widget.room.round != _round) {
      _round = widget.room.round;
      _roundStart = DateTime.now();
      _revealAt = null;
      _myChoice = null;
      _submitted = false;
      _advancing = false;
      _lastBeep = null;
      _shortAnswer.clear();
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _lifecycle.dispose();
    _shortAnswer.dispose();
    super.dispose();
  }

  Duration get _elapsed => DateTime.now().difference(_roundStart);

  int get _answerElapsedMs => (_elapsed - BattleRules.countdown).inMilliseconds
      .clamp(0, BattleRules.answerTime.inMilliseconds);

  List<BattleAnswer> get _answers =>
      ref.read(_answersProvider((widget.room.id, _round))).value ?? const [];

  bool get _everyoneAnswered {
    final answered = {for (final a in _answers) a.uid};
    return widget.room.players.keys.every(answered.contains);
  }

  QuizCard? get _card {
    final cards = ref
        .read(_battleCardsProvider(widget.room.cardIds.join(',')))
        .value;
    if (cards == null || _round >= widget.room.cardIds.length) return null;
    final id = widget.room.cardIds[_round];
    return cards.where((c) => c.id == id).firstOrNull;
  }

  /// 100ms마다: 화면 갱신, 시간 초과 자동 제출, (방장) 다음 문제로
  void _tick() {
    if (!mounted || widget.room.status != RoomStatus.playing) return;
    final phase = phaseAt(_elapsed, everyoneAnswered: _everyoneAnswered);
    if (phase == RoundPhase.countdown) {
      final n = BattleRules.countdown.inSeconds - _elapsed.inSeconds;
      if (n > 0 && n != _lastBeep) {
        _lastBeep = n;
        Sound.play(Sfx.countdown);
      }
    }
    if (phase == RoundPhase.reveal) {
      _revealAt ??= DateTime.now();
      if (!_submitted) _submit(''); // 시간 초과 = 오답 (콤보 끊김)
      // 다음 문제로는 방장 기기가 넘긴다. 방장 기기가 멈췄으면(앱 꺼짐 등)
      // 조금 더 기다렸다가 아무나 넘긴다 (advance는 라운드 번호로 중복을 막음).
      final waited = DateTime.now().difference(_revealAt!);
      final isHost = widget.room.isHost(widget.uid);
      final due = isHost
          ? waited >= BattleRules.reveal
          : waited >= BattleRules.reveal + BattleRules.hostStallGrace;
      if (due && !_advancing) {
        _advancing = true;
        ref
            .read(battleRepositoryProvider)
            .advance(roomId: widget.room.id, fromRound: _round)
            .catchError((_) => _advancing = false);
      }
    }
    setState(() {});
  }

  Future<void> _submit(String choice) async {
    final card = _card;
    if (_submitted || card == null) return;
    setState(() {
      _submitted = true;
      _myChoice = choice;
    });
    try {
      final correct = await ref
          .read(battleRepositoryProvider)
          .submit(
            roomId: widget.room.id,
            uid: widget.uid,
            round: _round,
            card: card,
            choice: choice,
            elapsedMs: _answerElapsedMs,
          );
      // 정답: 가벼운 진동 + 정답음 / 오답·시간 초과: 묵직한 진동 + 오답음 + 카드 흔들림
      if (correct) {
        Haptics.light();
        Sound.play(Sfx.correct);
      } else {
        Haptics.medium();
        Sound.play(Sfx.wrong);
        if (mounted) setState(() => _wrongShakes++);
      }
    } catch (_) {
      // 네트워크 실패 등: 다시 낼 수 있게 풀어 준다 (시간 안이면)
      if (mounted) setState(() => _submitted = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final room = widget.room;
    // 구독 유지 (값은 getter에서 read)
    ref.watch(_answersProvider((room.id, _round)));
    final cardsAsync = ref.watch(_battleCardsProvider(room.cardIds.join(',')));

    if (room.status == RoomStatus.finished) {
      return BattleResult(
        room: room,
        myUid: widget.uid,
        cards: cardsAsync.value ?? const [],
        onBackToWaiting: widget.onBackToWaiting,
      );
    }
    if (cardsAsync.isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.paper),
      );
    }
    final card = _card;
    if (card == null) {
      return Center(
        child: Text(
          '문제를 불러오지 못했어요',
          style: AppTextStyles.body.copyWith(color: AppColors.paper),
        ),
      );
    }

    final phase = phaseAt(_elapsed, everyoneAnswered: _everyoneAnswered);
    final total = room.cardIds.length;
    final left = Duration(
      milliseconds: BattleRules.answerTime.inMilliseconds - _answerElapsedMs,
    );
    final myAnswer = _answers.where((a) => a.uid == widget.uid).firstOrNull;

    return ListView(
      padding: AppLayout.pagePadding(
        context,
        top: AppSpacing.lg,
        bottom: AppSpacing.section * 2,
      ),
      children: [
        Row(
          children: [
            Text(
              '${_round + 1} / $total',
              style: AppTextStyles.titleM.copyWith(color: AppColors.paper),
            ),
            const Spacer(),
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
        ScoreBars(room: room, myUid: widget.uid),
        if (room.players.length < kBattleMinPlayers) ...[
          const SizedBox(height: AppSpacing.sm),
          _AloneNotice(
            isHost: room.isHost(widget.uid),
            onStop: widget.onBackToWaiting,
          ),
        ],
        const SizedBox(height: AppSpacing.section),
        if (phase == RoundPhase.countdown)
          _Countdown(left: BattleRules.countdown.inSeconds - _elapsed.inSeconds)
        else ...[
          // 문제가 바뀔 때마다 카드가 뒤집히며 나타나고, 틀리면 흔들린다
          FlipIn(
            key: ValueKey('flip-$_round'),
            child: Shake(
              trigger: _wrongShakes,
              child: ChunkyCard(
                shadowColor: AppColors.grape,
                child: Text(card.question, style: AppTextStyles.heading),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          _AnswerArea(
            card: card,
            phase: phase,
            myChoice: _myChoice,
            shortAnswer: _shortAnswer,
            onPick: _submitted ? null : _submit,
          ),
          if (phase == RoundPhase.reveal) ...[
            const SizedBox(height: AppSpacing.section),
            _RevealBanner(
              card: card,
              mine: myAnswer,
              room: room,
              answers: _answers,
            ),
          ] else if (_submitted) ...[
            const SizedBox(height: AppSpacing.lg),
            Center(
              child: Text(
                '친구가 답하길 기다리는 중…',
                style: AppTextStyles.label.copyWith(color: AppColors.cream),
              ),
            ),
          ],
        ],
      ],
    );
  }
}

/// 실시간 점수 막대: 1등 점수를 꽉 찬 막대로 보고 나머지는 비율로
class ScoreBars extends StatelessWidget {
  const ScoreBars({super.key, required this.room, required this.myUid});

  final Room room;
  final String myUid;

  static const _barHeight = AppSpacing.minTouch * 0.5;

  @override
  Widget build(BuildContext context) {
    final entries = room.players.entries.toList()
      ..sort((a, b) => b.value.score.compareTo(a.value.score));
    final top = entries.isEmpty ? 0 : entries.first.value.score;

    return Column(
      children: [
        for (final e in entries)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: Row(
              children: [
                SizedBox(
                  width: AppSpacing.minTouch * 1.8,
                  child: Text(
                    e.key == myUid ? '나' : e.value.nickname,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.chip.copyWith(color: AppColors.paper),
                  ),
                ),
                Expanded(
                  child: Container(
                    height: _barHeight,
                    padding: const EdgeInsets.all(AppSpacing.xs / 2),
                    decoration: BoxDecoration(
                      color: AppColors.ink,
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                      border: Border.all(
                        color: AppColors.paper,
                        width: AppBlock.border * 0.7,
                      ),
                    ),
                    child: LayoutBuilder(
                      builder: (context, c) => Align(
                        alignment: Alignment.centerLeft,
                        child: AnimatedContainer(
                          duration: AppMotion.scoreBar,
                          curve: AppMotion.spring,
                          width: top == 0
                              ? 0
                              : c.maxWidth * (e.value.score / top),
                          decoration: BoxDecoration(
                            color: e.key == myUid
                                ? AppColors.lime
                                : AppColors.cyan,
                            borderRadius: BorderRadius.circular(AppRadius.pill),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                SizedBox(
                  width: AppSpacing.minTouch * 1.4,
                  child: Text(
                    '${e.value.score}',
                    textAlign: TextAlign.end,
                    style: AppTextStyles.chip.copyWith(color: AppColors.paper),
                  ),
                ),
                if (e.value.combo >= BattleRules.comboFrom) ...[
                  const SizedBox(width: AppSpacing.xs),
                  StatChip(
                    label: 'x${e.value.combo}',
                    color: AppColors.pink,
                    border: false,
                  ),
                ],
              ],
            ),
          ),
      ],
    );
  }
}

class _Countdown extends StatelessWidget {
  const _Countdown({required this.left});
  final int left;

  @override
  Widget build(BuildContext context) {
    final text = left <= 0 ? '시작!' : '$left';
    return SizedBox(
      height: AppSpacing.minTouch * 6,
      child: Center(
        child:
            OutlinedText(
              text,
              key: ValueKey(text),
              style: AppTextStyles.titleL.copyWith(
                fontSize: AppSpacing.minTouch * 2.4,
              ),
              color: AppColors.sun,
            ).animate().scaleXY(
              begin: 1.8,
              end: 1,
              duration: AppMotion.stamp,
              curve: AppMotion.spring,
            ),
      ),
    );
  }
}

/// 유형별 답 고르기. 정답 공개 때 정답은 lime, 내가 고른 오답은 wrong 색.
class _AnswerArea extends StatelessWidget {
  const _AnswerArea({
    required this.card,
    required this.phase,
    required this.myChoice,
    required this.shortAnswer,
    required this.onPick,
  });

  final QuizCard card;
  final RoundPhase phase;
  final String? myChoice;
  final TextEditingController shortAnswer;

  /// null이면 더 못 고름 (이미 냈음)
  final ValueChanged<String>? onPick;

  Color _colorFor(String option) {
    final revealed = phase == RoundPhase.reveal;
    final isAnswer = BattleRules.isCorrect(card, option);
    if (revealed && isAnswer) return AppColors.lime;
    if (option == myChoice) return revealed ? AppColors.wrong : AppColors.sun;
    return revealed ? AppColors.cream : AppColors.paper;
  }

  @override
  Widget build(BuildContext context) {
    final canPick = onPick != null && phase == RoundPhase.question;
    switch (card.type) {
      case CardType.mcq:
        const letters = ['A', 'B', 'C', 'D', 'E', 'F'];
        return Column(
          children: [
            for (final (i, option) in card.choices.indexed)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: _Option(
                  badge: i < letters.length ? letters[i] : '${i + 1}',
                  label: option,
                  color: _colorFor(option),
                  onTap: canPick ? () => onPick!(option) : null,
                ),
              ),
          ],
        );
      case CardType.ox:
        return Row(
          children: [
            for (final (i, option) in const ['O', 'X'].indexed) ...[
              if (i > 0) const SizedBox(width: AppSpacing.md),
              Expanded(
                child: ChunkyPress(
                  onTap: canPick ? () => onPick!(option) : null,
                  color: _colorFor(option),
                  radius: AppRadius.card,
                  height: AppSpacing.minTouch * 3,
                  alignment: Alignment.center,
                  child: Text(option, style: AppTextStyles.titleL),
                ),
              ),
            ],
          ],
        );
      case CardType.short:
        final revealed = phase == RoundPhase.reveal;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: shortAnswer,
              enabled: canPick,
              textInputAction: TextInputAction.done,
              decoration: const InputDecoration(hintText: '답을 써 주세요'),
              onSubmitted: canPick ? (v) => onPick!(v.trim()) : null,
            ),
            const SizedBox(height: AppSpacing.sm),
            if (!revealed)
              ChunkyButton(
                label: myChoice == null ? '제출' : '냈어요',
                color: AppColors.lime,
                shadowColor: AppColors.grape,
                onPressed: canPick
                    ? () => onPick!(shortAnswer.text.trim())
                    : null,
              ),
          ],
        );
    }
  }
}

class _Option extends StatelessWidget {
  const _Option({
    required this.badge,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final String badge;
  final String label;
  final Color color;
  final VoidCallback? onTap;

  static const _badge = AppSpacing.minTouch;

  @override
  Widget build(BuildContext context) {
    return ChunkyPress(
      onTap: onTap,
      color: color,
      radius: AppRadius.button,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      child: Row(
        children: [
          Container(
            width: _badge,
            height: _badge,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.paper,
              borderRadius: BorderRadius.circular(AppRadius.chip),
              border: Border.all(color: AppColors.ink, width: AppBlock.border),
            ),
            child: Text(badge, style: AppTextStyles.chip),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              label,
              style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w900),
            ),
          ),
        ],
      ),
    );
  }
}

/// 정답 공개: 적중!/빗나감 + 정답 + 맞힌 사람
class _RevealBanner extends StatelessWidget {
  const _RevealBanner({
    required this.card,
    required this.mine,
    required this.room,
    required this.answers,
  });

  final QuizCard card;
  final BattleAnswer? mine;
  final Room room;
  final List<BattleAnswer> answers;

  @override
  Widget build(BuildContext context) {
    final correct = mine?.correct ?? false;
    final winners = [
      for (final a in answers)
        if (a.correct) room.nicknameOf(a.uid),
    ];
    return Column(
      children: [
        OutlinedText(
          correct ? '적중!' : '빗나감',
          color: correct ? AppColors.lime : AppColors.wrong,
        ).animate().scaleXY(
          begin: 2,
          end: 1,
          duration: AppMotion.stamp,
          curve: AppMotion.spring,
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          '정답: ${card.answer}',
          textAlign: TextAlign.center,
          style: AppTextStyles.heading.copyWith(color: AppColors.paper),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          winners.isEmpty ? '아무도 못 맞혔어요' : '${winners.join(', ')} 적중',
          textAlign: TextAlign.center,
          style: AppTextStyles.label.copyWith(color: AppColors.cream),
        ),
      ],
    );
  }
}

/// 친구가 다 나가고 혼자 남았을 때
class _AloneNotice extends StatelessWidget {
  const _AloneNotice({required this.isHost, required this.onStop});

  final bool isHost;
  final VoidCallback onStop;

  @override
  Widget build(BuildContext context) {
    return ChunkyCard(
      color: AppColors.sun,
      shadowColor: AppColors.grape,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      child: Row(
        children: [
          const Expanded(
            child: Text('친구가 나갔어요. 혼자 계속 풀 수 있어요.', style: AppTextStyles.bodyS),
          ),
          if (isHost) ...[
            const SizedBox(width: AppSpacing.sm),
            ChunkyButton(
              label: '그만두기',
              expand: false,
              color: AppColors.paper,
              onPressed: onStop,
            ),
          ],
        ],
      ),
    );
  }
}
