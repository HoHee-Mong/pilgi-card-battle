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
import 'solo_model.dart';
import 'solo_play_screen.dart';

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

  @override
  Widget build(BuildContext context) {
    final subject = widget.subject;
    final all =
        ref.watch(myCardsProvider((subjectId: subject.id, week: null))).value ??
        const <QuizCard>[];
    final pool = _includeDrafts ? all : all.where((c) => c.isVerified).toList();
    final weeksAvailable = {for (final c in pool) c.week}.toList()..sort();
    final ready = buildQuizSet(
      pool,
      weeks: _weeks,
      types: _types,
      count: 0,
    ).length;
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
              : () => Navigator.of(context).pushReplacement(
                  MaterialPageRoute<void>(
                    builder: (_) => SoloPlayScreen(
                      subject: subject,
                      cards: buildQuizSet(
                        pool,
                        weeks: _weeks,
                        types: _types,
                        count: _count,
                      ),
                    ),
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
          FilterChip(
            label: const Text('초안도 포함 (검수 전 카드)'),
            selected: _includeDrafts,
            onSelected: (on) => setState(() => _includeDrafts = on),
          ),
          const SizedBox(height: AppSpacing.section),
          Text('조건에 맞는 카드 $ready장 · 섞어서 냅니다', style: AppTextStyles.label),
        ],
      ),
    );
  }
}
