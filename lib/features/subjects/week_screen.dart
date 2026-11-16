import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/subject.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/chunky_button.dart';
import '../../core/widgets/stat_chip.dart';
import '../cards/card_edit_screen.dart';
import '../cards/card_list_tile.dart';
import '../cards/card_providers.dart';
import '../sources/add_source_sheet.dart';
import '../sources/source_detail_screen.dart';
import '../sources/source_providers.dart';
import '../sources/source_tile.dart';
import 'arcade_app_bar.dart';

/// 과목의 한 주차. 자료 목록·업로드, 직접 문제 쓰기, 이 주차 카드.
class WeekScreen extends ConsumerWidget {
  const WeekScreen({super.key, required this.subject, required this.week});

  final Subject subject;
  final int week;

  Future<void> _upload(BuildContext context) async {
    final uploaded = await showAddSourceSheet(
      context,
      subjectId: subject.id,
      subjectName: subject.name,
      week: week,
    );
    if (uploaded.isEmpty || !context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('자료 ${uploaded.length}개로 카드를 만들었어요. 검수해 주세요.')),
    );
    if (uploaded.length == 1) {
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => SourceDetailScreen(sourceId: uploaded.single.id),
        ),
      );
    }
  }

  void _write(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            CardEditScreen.create(subjectId: subject.id, week: week),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sources = ref.watch(
      weekSourcesProvider((subjectId: subject.id, week: week)),
    );
    final cards = ref.watch(
      myCardsProvider((subjectId: subject.id, week: week)),
    );
    final cardList = cards.value ?? const [];
    final draftCount = cardList.where((c) => !c.isVerified).length;

    return Scaffold(
      appBar: ArcadeAppBar(
        trailing: [StatChip(label: subject.name, color: AppColors.paper)],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.page,
          0,
          AppSpacing.page,
          AppSpacing.section * 2,
        ),
        children: [
          ArcadeTitle(
            title: '$week주차',
            subtitle: cardList.isEmpty
                ? '필기를 찍으면 AI가 카드를 만들어요'
                : '카드 ${cardList.length}장'
                      '${draftCount > 0 ? ' · 검수 기다리는 초안 $draftCount' : ''}',
          ),
          const SizedBox(height: AppSpacing.section),
          ChunkyButton(
            label: '필기 찍고 카드 뽑기',
            icon: Icons.photo_camera_outlined,
            large: true,
            onPressed: () => _upload(context),
          ),
          const SizedBox(height: AppSpacing.sm),
          ChunkyButton(
            label: '직접 문제 쓰기',
            icon: Icons.edit_outlined,
            color: AppColors.paper,
            onPressed: () => _write(context),
          ),
          const SizedBox(height: AppSpacing.section),
          const ArcadeSectionHeader(title: '자료'),
          const SizedBox(height: AppSpacing.md),
          sources.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(AppSpacing.section),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, _) => ArcadeEmpty(message: '자료를 불러오지 못했어요\n$e'),
            data: (list) {
              if (list.isEmpty) {
                return const ArcadeEmpty(
                  message: '아직 자료가 없어요.\n필기 사진이나 PDF를 올리면 AI가 요약하고 카드를 만들어요.',
                );
              }
              return Column(
                children: [
                  for (final s in list) ...[
                    SourceTile(
                      source: s,
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => SourceDetailScreen(sourceId: s.id),
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                  ],
                ],
              );
            },
          ),
          const SizedBox(height: AppSpacing.section),
          const ArcadeSectionHeader(title: '카드'),
          const SizedBox(height: AppSpacing.md),
          cards.when(
            loading: () => const SizedBox.shrink(),
            error: (e, _) => ArcadeEmpty(message: '카드를 불러오지 못했어요\n$e'),
            data: (list) => list.isEmpty
                ? const ArcadeEmpty(
                    message: '아직 카드가 없어요.\n자료를 올려 뽑거나 직접 써 보세요.',
                  )
                : Column(
                    children: [
                      for (final c in list) ...[
                        CardListTile(
                          card: c,
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => CardEditScreen.edit(card: c),
                            ),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                      ],
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}
