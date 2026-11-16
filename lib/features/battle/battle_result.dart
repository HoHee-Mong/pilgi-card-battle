import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/card.dart';
import '../../core/models/room.dart';
import '../../core/theme/layout.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/chunky_button.dart';
import '../../core/widgets/chunky_card.dart';
import '../../core/widgets/outlined_text.dart';
import '../../core/widgets/stat_chip.dart';
import '../../core/widgets/vote_button.dart';
import '../../core/widgets/rank_stamp.dart';
import '../../fx/confetti.dart';
import '../../fx/sound.dart';
import '../room/progress_repository.dart';
import '../room/progress_rules.dart';
import 'battle_repository.dart';

final _myAnswersProvider = StreamProvider.autoDispose
    .family<List<BattleAnswer>, (String, String)>(
      (ref, args) =>
          ref.watch(battleRepositoryProvider).watchMyAnswers(args.$1, args.$2),
    );

/// 배틀 결과 요약 (테스트용으로 분리)
class BattleSummary {
  const BattleSummary({
    required this.correct,
    required this.total,
    required this.bestCombo,
  });

  final int correct;
  final int total;
  final int bestCombo;

  /// 정답률 0~100
  int get percent => total == 0 ? 0 : (correct * 100 / total).round();

  /// [answers]는 라운드 순. 안 낸 라운드는 틀린 것으로 센다.
  factory BattleSummary.of(List<BattleAnswer> answers, int total) {
    final byRound = {for (final a in answers) a.round: a};
    var correct = 0, combo = 0, best = 0;
    for (var r = 0; r < total; r++) {
      if (byRound[r]?.correct ?? false) {
        correct++;
        combo++;
        if (combo > best) best = combo;
      } else {
        combo = 0;
      }
    }
    return BattleSummary(correct: correct, total: total, bestCombo: best);
  }
}

/// 배틀 결과 (시안 game-result.png 톤: sun 배경).
///
/// 순위, 맞힌 문제·정답률·최고 콤보, 문제별 정답과 "나올 것 같아요" 투표,
/// 내 답은 한 번만 `attempts`(mode: battle)로 저장 → 오답 노트.
class BattleResult extends ConsumerStatefulWidget {
  const BattleResult({
    super.key,
    required this.room,
    required this.myUid,
    required this.cards,
    required this.onBackToWaiting,
  });

  final Room room;
  final String myUid;

  /// 출제된 카드 (cardIds 순서)
  final List<QuizCard> cards;
  final VoidCallback onBackToWaiting;

  @override
  ConsumerState<BattleResult> createState() => _BattleResultState();
}

class _BattleResultState extends ConsumerState<BattleResult> {
  bool _saved = false;

  /// 이번 판으로 받은 XP (저장되면 채워짐)
  int? _gainedXp;

  /// 이미 저장된 판을 다시 본 경우 (XP는 처음 볼 때 받음)
  bool _alreadySaved = false;

  @override
  void initState() {
    super.initState();
    final ranked = widget.room.players.entries.toList()
      ..sort((a, b) => b.value.score.compareTo(a.value.score));
    if (ranked.isNotEmpty && ranked.first.key == widget.myUid) {
      Sound.play(Sfx.bossDown);
    }
  }

  /// 내 답을 오답 노트에 저장하고, 새로 저장했을 때만 XP를 준다.
  /// 끝난 방에 다시 들어오면 이미 저장된 답이라 둘 다 건너뛴다.
  Future<void> _saveOnce(List<BattleAnswer> answers) async {
    if (_saved || answers.isEmpty || widget.cards.isEmpty) return;
    _saved = true;
    final bool savedNow;
    try {
      savedNow = await ref
          .read(battleRepositoryProvider)
          .saveAttempts(
            roomId: widget.room.id,
            uid: widget.myUid,
            cards: widget.cards,
            answers: answers,
            cardIds: widget.room.cardIds,
          );
    } catch (_) {
      _saved = false; // 다음 화면 갱신 때 다시 시도
      return;
    }
    if (!savedNow) {
      if (mounted) setState(() => _alreadySaved = true);
      return;
    }
    // XP: 한 판 기본 + 점수 100점당 1 (퀘스트 "배틀 1판" 포함)
    final myScore = widget.room.players[widget.myUid]?.score ?? 0;
    try {
      final xp = await ref
          .read(progressRepositoryProvider)
          .record(widget.myUid, XpEvent.battle, bonusXp: myScore ~/ 100);
      if (mounted) setState(() => _gainedXp = xp);
    } catch (_) {
      // XP 저장 실패는 결과 화면을 막지 않는다
    }
  }

  @override
  Widget build(BuildContext context) {
    final room = widget.room;
    final answers =
        ref.watch(_myAnswersProvider((room.id, widget.myUid))).value ??
        const <BattleAnswer>[];
    _saveOnce(answers);

    final total = room.cardIds.length;
    final summary = BattleSummary.of(answers, total);
    final ranked = room.players.entries.toList()
      ..sort((a, b) => b.value.score.compareTo(a.value.score));
    final myRank = ranked.indexWhere((e) => e.key == widget.myUid) + 1;
    final cardsById = {for (final c in widget.cards) c.id: c};
    final answerByRound = {for (final a in answers) a.round: a};
    final wrongCount = total - summary.correct;

    // 결과: 랭크 도장 + 뒤 별 회전 + 색종이 낙하 (DESIGN.md)
    return Stack(
      children: [
        ListView(
          padding: AppLayout.pagePadding(
            context,
            top: AppSpacing.section,
            bottom: AppSpacing.section * 2,
          ),
          children: [
            Center(child: RankStamp(rank: resultRank(summary.percent))),
            Center(
              child:
                  OutlinedText(
                    myRank == 1 ? '우승!' : '$myRank위',
                    color: myRank == 1 ? AppColors.pink : AppColors.paper,
                  ).animate().scaleXY(
                    begin: 2,
                    end: 1,
                    duration: AppMotion.stamp,
                    curve: AppMotion.spring,
                  ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              '${room.name} 배틀 $total문제 · 정답률 ${summary.percent}%',
              textAlign: TextAlign.center,
              style: AppTextStyles.label.copyWith(color: AppColors.ink),
            ),
            const SizedBox(height: AppSpacing.section),
            Row(
              children: [
                Expanded(
                  child: _StatTile(
                    value: '${summary.correct}/$total',
                    label: '맞힌 문제',
                    color: AppColors.paper,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: _StatTile(
                    value: 'x${summary.bestCombo}',
                    label: '최고 콤보',
                    color: AppColors.lime,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: _StatTile(
                    value: _alreadySaved
                        ? '받음'
                        : _gainedXp == null
                        ? '…'
                        : '+$_gainedXp',
                    label: '획득 XP',
                    color: AppColors.cyan,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.section),
            ChunkyCard(
              title: '순위',
              child: Column(
                children: [
                  for (final (i, e) in ranked.indexed)
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                      child: Row(
                        children: [
                          SizedBox(
                            width: AppSpacing.minTouch,
                            child: Text('${i + 1}위', style: AppTextStyles.chip),
                          ),
                          Expanded(
                            child: Text(
                              e.key == widget.myUid
                                  ? '${e.value.nickname} (나)'
                                  : e.value.nickname,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTextStyles.body.copyWith(
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          Text('${e.value.score}점', style: AppTextStyles.chip),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.section),
            ChunkyCard(
              title: '문제별 결과',
              trailing: wrongCount == 0
                  ? null
                  : Text(
                      '오답 노트에 저장',
                      style: AppTextStyles.label.copyWith(
                        color: AppColors.grape,
                      ),
                    ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final (r, id) in room.cardIds.indexed)
                    _QuestionRow(
                      roomId: room.id,
                      cardId: id,
                      card: cardsById[id],
                      correct: answerByRound[r]?.correct ?? false,
                    ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    '시험에 나올 것 같은 문제엔 별을 눌러 주세요',
                    style: AppTextStyles.caption,
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.section),
            if (room.isHost(widget.myUid))
              ChunkyButton(
                label: '한 판 더',
                color: AppColors.pink,
                onPressed: widget.onBackToWaiting,
              )
            else
              Text(
                '방장이 한 판 더 하면 대기실로 돌아가요',
                textAlign: TextAlign.center,
                style: AppTextStyles.label.copyWith(color: AppColors.ink),
              ),
            const SizedBox(height: AppSpacing.sm),
            ChunkyButton(
              label: '나가기',
              color: AppColors.paper,
              onPressed: () => Navigator.of(context).maybePop(),
            ),
          ],
        ),
        const Positioned.fill(child: ConfettiRain()),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.value,
    required this.label,
    required this.color,
  });

  final String value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return ChunkyCard(
      color: color,
      padding: const EdgeInsets.symmetric(
        vertical: AppSpacing.lg,
        horizontal: AppSpacing.sm,
      ),
      child: Column(
        children: [
          FittedBox(child: Text(value, style: AppTextStyles.titleM)),
          const SizedBox(height: AppSpacing.xs),
          Text(
            label,
            style: AppTextStyles.label.copyWith(color: AppColors.ink),
          ),
        ],
      ),
    );
  }
}

class _QuestionRow extends StatelessWidget {
  const _QuestionRow({
    required this.roomId,
    required this.cardId,
    required this.card,
    required this.correct,
  });

  final String roomId;
  final String cardId;
  final QuizCard? card;
  final bool correct;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Row(
        children: [
          StatChip(
            label: correct ? '적중' : '빗나감',
            color: correct ? AppColors.lime : AppColors.wrong,
            border: false,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  card?.question ?? '문제',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.bodyS.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                if (card != null)
                  Text('정답: ${card!.answer}', style: AppTextStyles.caption),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          VoteButton(roomId: roomId, cardId: cardId, compact: true),
        ],
      ),
    );
  }
}
