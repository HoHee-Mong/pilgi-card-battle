import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/ai/card_generator.dart';
import '../../core/models/card.dart';
import '../../core/models/subject.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/chunky_button.dart';
import '../../core/widgets/stat_chip.dart';
import '../cards/card_providers.dart';
import '../subjects/arcade_app_bar.dart';
import 'favorite_button.dart';
import 'solo_model.dart';
import 'solo_play_screen.dart';
import 'solo_providers.dart';

/// 혼자 풀기 설정: 범위(주차)·유형·문항 수 → 시작.
class SoloSetupScreen extends ConsumerStatefulWidget {
  const SoloSetupScreen({super.key, required this.subject});

  final Subject subject;

  @override
  ConsumerState<SoloSetupScreen> createState() => _SoloSetupScreenState();
}

class _SoloSetupScreenState extends ConsumerState<SoloSetupScreen> {
  /// 비어 있으면 전체 주차
  final Set<int> _weeks = {};
  final Set<CardType> _types = {...CardType.values};
  int _count = 10;
  bool _includeDrafts = false;
  bool _favoritesOnly = false;

  /// 풀이·결과는 하단 탭 없이 전체 화면으로 띄운다. 결과에서 "끝내기"면 과목 화면으로 돌아간다.
  Future<void> _start(List<QuizCard> cards) async {
    final outcome = await Navigator.of(context, rootNavigator: true)
        .push<String>(
          MaterialPageRoute<String>(
            builder: (_) =>
                SoloPlayScreen(subject: widget.subject, cards: cards),
          ),
        );
    if (outcome == 'done' && mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final subject = widget.subject;
    final all =
        ref.watch(myCardsProvider((subjectId: subject.id, week: null))).value ??
        const <QuizCard>[];
    final favorites = ref.watch(favoriteIdsProvider);
    final pool = all
        .where((c) => _includeDrafts || c.isVerified)
        .where((c) => !_favoritesOnly || favorites.contains(c.id))
        .toList();
    final lastSolved = lastSolvedAt(
      ref.watch(subjectAttemptsProvider(subject.id)).value ?? const [],
    );
    final weeksAvailable = {for (final c in pool) c.week}.toList()..sort();
    final ready = buildQuizSet(
      pool,
      weeks: _weeks,
      types: _types,
      count: 0,
    ).length;
    final unsolved = countUnsolved(
      pool,
      weeks: _weeks,
      types: _types,
      lastSolved: lastSolved,
    );
    final willAsk = _count <= 0 ? ready : (ready < _count ? ready : _count);

    return Scaffold(
      appBar: ArcadeAppBar(
        trailing: [StatChip(label: subject.name, color: AppColors.paper)],
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(
          AppSpacing.page,
          AppSpacing.sm,
          AppSpacing.page,
          AppSpacing.page,
        ),
        child: ChunkyButton(
          label: willAsk == 0 ? '풀 카드가 없어요' : '$willAsk문제 풀기 시작',
          icon: Icons.play_arrow_rounded,
          large: true,
          onPressed: willAsk == 0
              ? null
              : () => _start(
                  buildQuizSet(
                    pool,
                    weeks: _weeks,
                    types: _types,
                    count: _count,
                    lastSolved: lastSolved,
                  ),
                ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.page,
          0,
          AppSpacing.page,
          AppSpacing.section,
        ),
        children: [
          const ArcadeTitle(title: '혼자 풀기', subtitle: '범위와 유형을 골라 문제집을 만들어요'),
          const SizedBox(height: AppSpacing.section),
          const ArcadeSectionHeader(title: '주차'),
          const SizedBox(height: AppSpacing.sm),
          if (weeksAvailable.isEmpty)
            const ArcadeEmpty(
              message: '검수 완료한 카드가 없어요.\n카드를 검수하거나 아래 "초안도 포함"을 켜 보세요.',
            )
          else
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                ChoiceChip(
                  label: const Text('전체'),
                  selected: _weeks.isEmpty,
                  onSelected: (_) => setState(_weeks.clear),
                ),
                for (final w in weeksAvailable)
                  FilterChip(
                    label: Text('$w주차'),
                    selected: _weeks.contains(w),
                    onSelected: (on) => setState(() {
                      on ? _weeks.add(w) : _weeks.remove(w);
                    }),
                  ),
              ],
            ),
          const SizedBox(height: AppSpacing.section),
          const ArcadeSectionHeader(title: '유형'),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            children: [
              for (final t in CardType.values)
                FilterChip(
                  label: Text(CardGenerator.typeLabel(t)),
                  selected: _types.contains(t),
                  onSelected: (on) => setState(() {
                    if (on) {
                      _types.add(t);
                    } else if (_types.length > 1) {
                      _types.remove(t);
                    }
                  }),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.section),
          const ArcadeSectionHeader(title: '문항 수'),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            children: [
              for (final n in soloCounts)
                ChoiceChip(
                  label: Text(n == 0 ? '전부' : '$n문제'),
                  selected: _count == n,
                  onSelected: (_) => setState(() => _count = n),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.section),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              FilterChip(
                label: const Text('초안도 포함 (검수 전 카드)'),
                selected: _includeDrafts,
                onSelected: (on) => setState(() => _includeDrafts = on),
              ),
              FilterChip(
                label: Text('★ 즐겨찾기만 (${favorites.length})'),
                selected: _favoritesOnly,
                onSelected: (on) => setState(() => _favoritesOnly = on),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.section),
          Text(
            '조건에 맞는 카드 $ready장 · 안 푼 문제 $unsolved장',
            style: AppTextStyles.label,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            unsolved >= willAsk
                ? '안 푼 문제부터 냅니다. 보기 순서도 매번 섞어요.'
                : '안 푼 문제를 먼저 내고, 모자라면 오래전에 푼 문제로 채워요. '
                      '새 문제를 원하면 카드를 더 만들어 보세요.',
            style: AppTextStyles.label,
          ),
        ],
      ),
    );
  }
}
