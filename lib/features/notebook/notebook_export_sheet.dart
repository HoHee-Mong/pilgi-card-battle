import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/subject.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/chunky_button.dart';
import '../../fx/haptics.dart';
import '../cards/card_providers.dart';
import 'notebook_export.dart';
import 'notebook_providers.dart';

/// 족보 내보내기: 범위·정답 포함을 골라 PDF(저장·공유) 또는 텍스트(복사)로.
Future<void> showNotebookExportSheet(BuildContext context, Subject subject) {
  return showModalBottomSheet<void>(
    context: context,
    useSafeArea: true,
    isScrollControlled: true,
    builder: (_) => Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.page,
        AppSpacing.section,
        AppSpacing.page,
        AppSpacing.section * 2,
      ),
      child: _ExportForm(subject: subject),
    ),
  );
}

class _ExportForm extends ConsumerStatefulWidget {
  const _ExportForm({required this.subject});
  final Subject subject;

  @override
  ConsumerState<_ExportForm> createState() => _ExportFormState();
}

class _ExportFormState extends ConsumerState<_ExportForm> {
  ExportScope _scope = ExportScope.myVerified;
  bool _withAnswers = true;
  bool _busy = false;
  String? _message;

  Future<NotebookExport> _build() async {
    final id = widget.subject.id;
    final sources = await ref.read(subjectSourcesProvider(id).future);
    final List<ExportCard> cards;
    if (_scope == ExportScope.room) {
      final items = await ref.read(roomCardsProvider(id).future);
      cards = [
        for (final it in items)
          (
            card: it.card,
            votes: it.entry.voteCount,
            author: it.card.ownerNickname,
          ),
      ];
    } else {
      final mine = await ref.read(
        myCardsProvider((subjectId: id, week: null)).future,
      );
      cards = [
        for (final c in mine)
          if (_scope == ExportScope.myAll || c.isVerified)
            (card: c, votes: null, author: null),
      ];
    }
    return NotebookExport.build(
      subjectName: widget.subject.name,
      scope: _scope,
      withAnswers: _withAnswers,
      cards: cards,
      sources: sources,
    );
  }

  Future<void> _run(Future<String> Function(NotebookExport) action) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      final export = await _build();
      final msg = export.isEmpty
          ? '내보낼 카드가 없어요. 범위를 바꿔 보세요.'
          : await action(export);
      if (mounted) setState(() => _message = msg);
    } catch (e) {
      if (mounted) setState(() => _message = '내보내지 못했어요. 인터넷 연결을 확인해 주세요.\n$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<String> _pdf(NotebookExport e) async {
    await e.sharePdf();
    Haptics.light();
    return 'PDF를 만들었어요 (문제 ${e.cardCount}개). 저장하거나 친구에게 보내세요.';
  }

  Future<String> _text(NotebookExport e) async {
    await Clipboard.setData(ClipboardData(text: e.toText()));
    Haptics.light();
    return '복사했어요 (문제 ${e.cardCount}개). 카톡 같은 데 붙여 넣으세요.';
  }

  @override
  Widget build(BuildContext context) {
    final hasRooms = ref
        .watch(subjectRoomsProvider(widget.subject.id))
        .isNotEmpty;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('족보 내보내기', style: AppTextStyles.titleM),
        const SizedBox(height: AppSpacing.xs),
        Text(
          '${widget.subject.name} 카드를 주차별 요약과 함께 정리해요. '
          '원본 파일(PDF·녹음·사진)은 들어가지 않아요.',
          style: AppTextStyles.bodyS,
        ),
        const SizedBox(height: AppSpacing.section),
        const Text('어떤 카드를 넣을까요?', style: AppTextStyles.heading),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            for (final (s, label) in [
              (ExportScope.myVerified, '내 카드 (검수 완료)'),
              (ExportScope.myAll, '내 카드 (초안 포함)'),
              if (hasRooms) (ExportScope.room, '방 카드 (친구 것 포함)'),
            ])
              ChoiceChip(
                label: Text(label),
                selected: _scope == s,
                onSelected: _busy ? null : (_) => setState(() => _scope = s),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        FilterChip(
          label: const Text('정답·해설 넣기'),
          selected: _withAnswers,
          onSelected: _busy ? null : (on) => setState(() => _withAnswers = on),
        ),
        const SizedBox(height: AppSpacing.section),
        ChunkyButton(
          label: 'PDF로 저장·공유',
          icon: Icons.picture_as_pdf_rounded,
          loading: _busy,
          onPressed: _busy ? null : () => _run(_pdf),
        ),
        const SizedBox(height: AppSpacing.sm),
        ChunkyButton(
          label: '텍스트로 복사',
          icon: Icons.copy_rounded,
          color: AppColors.paper,
          onPressed: _busy ? null : () => _run(_text),
        ),
        if (_message != null) ...[
          const SizedBox(height: AppSpacing.md),
          Text(_message!, style: AppTextStyles.bodyS),
        ],
      ],
    );
  }
}
