import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/card.dart';
import '../../core/models/mock_exam.dart';
import '../../core/models/room.dart';
import '../../core/theme/layout.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/boss_sprite.dart';
import '../../core/widgets/chunky_button.dart';
import '../../core/widgets/chunky_card.dart';
import '../../core/widgets/stat_chip.dart';
import '../bank/bank_repository.dart';
import '../room/room_sheets.dart';
import '../solo/solo_model.dart';
import 'mock_exam_model.dart';
import 'mock_exam_play_screen.dart';
import 'mock_exam_repository.dart';

/// 모의고사 시작 (ink 배경, 보스전 대기 화면).
/// 문항 수(10/20/30)·범위(주차)를 고르면 투표 많은 순으로 문항을 뽑는다.
class MockExamSetupScreen extends ConsumerStatefulWidget {
  const MockExamSetupScreen({super.key, required this.room});

  final Room room;

  @override
  ConsumerState<MockExamSetupScreen> createState() =>
      _MockExamSetupScreenState();
}

class _MockExamSetupScreenState extends ConsumerState<MockExamSetupScreen> {
  int _count = mockCounts.first;

  /// 비어 있으면 전체 주차
  final Set<int> _weeks = {};
  bool _loading = false;

  Future<void> _start(int willAsk) async {
    setState(() => _loading = true);
    final bank = ref.read(bankRepositoryProvider);
    final List<QuizCard> cards;
    final Map<String, int> votes;
    try {
      final entries = await bank.topVoted(
        widget.room.id,
        weeks: _weeks.toList()..sort(),
        limit: willAsk,
      );
      votes = {for (final e in entries) e.cardId: e.voteCount};
      final loaded = await bank.cardsByIds([for (final e in entries) e.cardId]);
      // 객관식 보기 순서는 섞는다 (문항 순서는 투표 많은 순 그대로)
      cards = [for (final c in loaded) shuffleChoices(c, _rng)];
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('문제를 불러오지 못했어요: $e')));
      }
      return;
    }
    if (!mounted) return;
    setState(() => _loading = false);
    if (cards.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('문제를 불러오지 못했어요. 카드가 지워졌을 수 있어요.')),
      );
      return;
    }
    // 풀이·결과는 하단 탭 없이 전체 화면
    final outcome = await Navigator.of(context, rootNavigator: true)
        .push<String>(
          MaterialPageRoute<String>(
            builder: (_) => MockExamPlayScreen(
              room: widget.room,
              cards: cards,
              votes: votes,
              weeks: _weeks.toList()..sort(),
            ),
          ),
        );
    // "한 판 더": 같은 조건으로 바로 다시 (투표가 바뀌었으면 문항도 바뀐다)
    if (outcome == 'again' && mounted) await _start(willAsk);
  }

  @override
  Widget build(BuildContext context) {
    final room = widget.room;
    final entries = ref.watch(mockBankProvider(room.id));
    final list = entries.value ?? const <BankEntry>[];
    final weeks = bankWeeks(list);
    final inRange = countInWeeks(list, _weeks);
    final willAsk = inRange < _count ? inRange : _count;
    final history = ref.watch(myMockExamsProvider(room.id)).value ?? const [];

    return Scaffold(
      backgroundColor: AppColors.ink,
      body: SafeArea(
        child: ListView(
          padding: AppLayout.pagePadding(
            context,
            top: AppSpacing.section,
            bottom: AppSpacing.section * 2,
          ),
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '모의고사',
                    style: AppTextStyles.titleL.copyWith(
                      color: AppColors.paper,
                    ),
                  ),
                ),
                Flexible(
                  child: Semantics(
                    button: true,
                    hint: '방 바꾸기',
                    child: GestureDetector(
                      onTap: () => showRoomPickerSheet(context),
                      child: StatChip(
                        label: shortLabel(room.name, 10),
                        icon: Icons.expand_more_rounded,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.section),
            const Center(child: BossSprite(hp: 1, maxHp: 1, size: 130)),
            const SizedBox(height: AppSpacing.sm),
            Text(
              '이번 보스: ${room.name} 모의고사',
              textAlign: TextAlign.center,
              style: AppTextStyles.heading.copyWith(color: AppColors.pink),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              '친구들이 "나올 것 같아요"를 많이 누른 문제로 만들어요',
              textAlign: TextAlign.center,
              style: AppTextStyles.label.copyWith(color: AppColors.paper),
            ),
            const SizedBox(height: AppSpacing.section),
            if (entries.isLoading && list.isEmpty)
              const Center(
                child: CircularProgressIndicator(color: AppColors.lime),
              )
            else if (list.isEmpty)
              ChunkyCard(
                shadowColor: AppColors.grape,
                child: Text(
                  '아직 문제은행이 비어 있어요.\n'
                  '"문제은행" 탭에서 내 카드를 올리고 친구들과 투표해 보세요.',
                  style: AppTextStyles.body,
                ),
              )
            else
              _Options(
                count: _count,
                weeks: weeks,
                selected: _weeks,
                onCount: (n) => setState(() => _count = n),
                onAllWeeks: () => setState(_weeks.clear),
                onWeek: (w, on) =>
                    setState(() => on ? _weeks.add(w) : _weeks.remove(w)),
                summary: willAsk == 0
                    ? '이 범위에는 문제가 없어요'
                    : '범위 안 $inRange문제 중 표 많은 순 $willAsk문제'
                          ' · 제한 시간 ${mockTimeLimitSec(willAsk) ~/ 60}분',
              ),
            const SizedBox(height: AppSpacing.section),
            ChunkyButton(
              label: willAsk == 0 ? '풀 문제가 없어요' : '모의고사 시작',
              icon: Icons.play_arrow_rounded,
              large: true,
              shadowColor: AppColors.grape,
              loading: _loading,
              onPressed: willAsk == 0 || _loading
                  ? null
                  : () => _start(willAsk),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              '실제 시험처럼 끝까지 풀고 한 번에 제출해요. 문제는 앞뒤로 옮겨 다닐 수 있어요.',
              textAlign: TextAlign.center,
              style: AppTextStyles.caption.copyWith(color: AppColors.paper),
            ),
            if (history.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.section),
              _History(exams: history),
            ],
          ],
        ),
      ),
    );
  }
}

final _rng = Random();

class _Options extends StatelessWidget {
  const _Options({
    required this.count,
    required this.weeks,
    required this.selected,
    required this.onCount,
    required this.onAllWeeks,
    required this.onWeek,
    required this.summary,
  });

  final int count;
  final List<int> weeks;
  final Set<int> selected;
  final ValueChanged<int> onCount;
  final VoidCallback onAllWeeks;
  final void Function(int week, bool on) onWeek;
  final String summary;

  @override
  Widget build(BuildContext context) {
    return ChunkyCard(
      shadowColor: AppColors.grape,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('문항 수', style: AppTextStyles.heading),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            children: [
              for (final n in mockCounts)
                ChoiceChip(
                  label: Text('$n문항'),
                  selected: count == n,
                  onSelected: (_) => onCount(n),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.section),
          const Text('범위', style: AppTextStyles.heading),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              ChoiceChip(
                label: const Text('전체'),
                selected: selected.isEmpty,
                onSelected: (_) => onAllWeeks(),
              ),
              for (final w in weeks)
                FilterChip(
                  label: Text('$w주차'),
                  selected: selected.contains(w),
                  onSelected: (on) => onWeek(w, on),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.section),
          Text(summary, style: AppTextStyles.label),
        ],
      ),
    );
  }
}

/// 이 방에서 내가 본 모의고사 (최근 5개)
class _History extends StatelessWidget {
  const _History({required this.exams});

  final List<MockExam> exams;

  @override
  Widget build(BuildContext context) {
    return ChunkyCard(
      title: '내 모의고사 기록',
      shadowColor: AppColors.grape,
      child: Column(
        children: [
          for (final e in exams.take(5))
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.xs),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '${e.startedAt.month}/${e.startedAt.day} · ${e.total}문항'
                      '${e.weeks.isEmpty ? '' : ' · ${e.weeks.join(',')}주차'}',
                      style: AppTextStyles.bodyS,
                    ),
                  ),
                  Text(
                    '${e.score}/${e.total} · ${percentOf(e.score, e.total)}%',
                    style: AppTextStyles.chip,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
