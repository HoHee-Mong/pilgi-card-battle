import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/ai/card_generator.dart';
import '../../core/auth/auth_providers.dart';
import '../../core/auth/user_profile.dart';
import '../../core/models/card.dart';
import '../../core/models/source.dart';
import '../../core/theme/tokens.dart';
import '../sources/data/source_repository.dart';
import '../sources/source_providers.dart';
import 'card_providers.dart';

/// 생성 옵션(카드 수·유형) 고르고 AI로 카드를 만든다.
/// 만든 카드 수를 돌려준다. 취소·실패면 null.
Future<int?> showGenerateSheet(
  BuildContext context, {
  required StudySource source,
  required String subjectName,
}) {
  return showModalBottomSheet<int>(
    context: context,
    isScrollControlled: true,
    isDismissible: false,
    enableDrag: false,
    backgroundColor: Theme.of(context).colorScheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.card)),
    ),
    builder: (_) => _GenerateSheet(source: source, subjectName: subjectName),
  );
}

class _GenerateSheet extends ConsumerStatefulWidget {
  const _GenerateSheet({required this.source, required this.subjectName});

  final StudySource source;
  final String subjectName;

  @override
  ConsumerState<_GenerateSheet> createState() => _GenerateSheetState();
}

class _GenerateSheetState extends ConsumerState<_GenerateSheet> {
  int _count = 10;
  final Set<CardType> _types = {CardType.mcq, CardType.ox, CardType.short};
  String? _stage;

  bool get _busy => _stage != null;

  Future<void> _run() async {
    if (_busy || _types.isEmpty) return;
    final uid = ref.read(uidProvider);
    if (uid == null) {
      _toast('로그인 정보를 불러오지 못했어요');
      return;
    }
    final sources = ref.read(sourceRepositoryProvider);
    final cards = ref.read(cardRepositoryProvider);
    final generator = ref.read(cardGeneratorProvider);
    final source = widget.source;

    try {
      setState(() => _stage = '자료 읽는 중');
      await sources.updateStatus(source.id, SourceStatus.processing);
      final bytes = await sources.download(source);
      final nickname = await ref
          .read(userProfileRepositoryProvider)
          .ensureNickname(uid);

      setState(() => _stage = 'AI가 문제 만드는 중');
      final result = await generator.generate(
        bytes: bytes,
        mimeType: _mimeType(source),
        subjectName: widget.subjectName,
        week: source.week,
        options: CardGenerateOptions(count: _count, types: _types),
      );

      setState(() => _stage = '저장하는 중');
      final now = DateTime.now();
      final drafts = [
        for (final g in result.cards)
          QuizCard(
            id: cards.newId(),
            ownerId: uid,
            ownerNickname: nickname,
            subjectId: source.subjectId,
            week: source.week,
            sourceId: source.id,
            sourceLabel: g.sourceHint.isEmpty
                ? source.label
                : '${source.label} ${g.sourceHint}',
            type: g.type,
            question: g.question,
            choices: g.choices,
            answer: g.answer,
            explanation: g.explanation,
            concept: g.concept,
            // AI가 만든 카드는 항상 draft. 검수해야 verified가 된다.
            status: CardStatus.draft,
            createdAt: now,
            updatedAt: now,
          ),
      ];
      await cards.createAll(drafts);
      await sources.updateStatus(
        source.id,
        SourceStatus.done,
        summary: result.summary.isEmpty ? null : result.summary,
      );
      if (mounted) Navigator.of(context).pop(drafts.length);
    } on CardGenerationException catch (e) {
      await sources.updateStatus(source.id, SourceStatus.failed);
      _fail(e.message);
    } on SourceException catch (e) {
      await sources.updateStatus(source.id, SourceStatus.failed);
      _fail(e.message);
    } catch (e) {
      await sources.updateStatus(source.id, SourceStatus.failed);
      _fail('카드를 만들지 못했어요: $e');
    }
  }

  String _mimeType(StudySource s) => switch (s.kind) {
    SourceKind.pdf => 'application/pdf',
    SourceKind.audio => 'audio/mp4',
    SourceKind.image =>
      s.fileName.toLowerCase().endsWith('.png') ? 'image/png' : 'image/jpeg',
  };

  void _fail(String msg) {
    if (!mounted) return;
    setState(() => _stage = null);
    _toast(msg);
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.page,
        AppSpacing.section,
        AppSpacing.page,
        AppSpacing.page + MediaQuery.paddingOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(child: Text('카드 뽑기', style: AppTextStyles.titleM)),
              if (!_busy)
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                  tooltip: '닫기',
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            '${widget.source.fileName} · ${widget.source.week}주차',
            style: AppTextStyles.caption,
          ),
          const SizedBox(height: AppSpacing.sectionTight),
          if (_busy) ...[
            Text(_stage!, style: AppTextStyles.heading),
            const SizedBox(height: AppSpacing.md),
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.chip),
              child: const LinearProgressIndicator(
                minHeight: 10,
                color: AppColors.ink,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text('보통 10~30초 걸려요.', style: AppTextStyles.caption),
          ] else ...[
            const Text('몇 장 만들까요?', style: AppTextStyles.heading),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              children: [
                for (final n in CardGenerateOptions.counts)
                  ChoiceChip(
                    label: Text('$n장'),
                    selected: _count == n,
                    onSelected: (_) => setState(() => _count = n),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            const Text('문제 유형', style: AppTextStyles.heading),
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
            SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton.icon(
                onPressed: _run,
                icon: const Icon(Icons.auto_awesome_outlined),
                label: Text('$_count장 만들기'),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'AI가 만든 카드는 초안이에요. 검수를 끝내야 풀기와 공유에 쓸 수 있어요.',
              style: AppTextStyles.caption,
            ),
          ],
        ],
      ),
    );
  }
}
