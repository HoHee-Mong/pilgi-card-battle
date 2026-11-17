import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/auth/auth_providers.dart';
import '../../core/auth/user_profile.dart';
import '../../core/models/subject.dart';
import '../../core/router.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/chunky_button.dart';
import '../../core/widgets/chunky_card.dart';
import '../../core/widgets/stat_chip.dart';
import '../../fx/haptics.dart';
import '../cards/card_providers.dart';
import '../sources/source_providers.dart';
import '../subjects/arcade_app_bar.dart';
import '../subjects/subject_providers.dart';
import 'notebook_export.dart';
import 'notebook_share.dart';

/// 공유 링크(`/share/:code`)나 코드로 연 친구 족보.
/// 내 카드로 가져가기 / PDF로 받기.
class NotebookShareScreen extends ConsumerStatefulWidget {
  const NotebookShareScreen({super.key, required this.code});

  final String code;

  @override
  ConsumerState<NotebookShareScreen> createState() =>
      _NotebookShareScreenState();
}

class _NotebookShareScreenState extends ConsumerState<NotebookShareScreen> {
  bool _busy = false;
  String? _message;
  int? _imported;

  Future<void> _pdf(NotebookShare share) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      await share.toExport().sharePdf();
      Haptics.light();
      _message = 'PDF를 만들었어요. 저장해 두고 보세요.';
    } catch (e) {
      _message = 'PDF를 만들지 못했어요. 인터넷 연결을 확인해 주세요.\n$e';
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _import(NotebookShare share) async {
    final target = await _pickSubject(share);
    if (target == null || !mounted) return;
    final uid = ref.read(uidProvider);
    if (uid == null) return;
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      final subjects = ref.read(subjectRepositoryProvider);
      final subject =
          target.subject ??
          await subjects.create(uid: uid, name: target.newName!);
      final nickname = await ref
          .read(userProfileRepositoryProvider)
          .ensureNickname(uid);
      final n = await ref
          .read(shareRepositoryProvider)
          .importInto(
            share: share,
            subject: subject,
            uid: uid,
            nickname: nickname,
            cards: ref.read(cardRepositoryProvider),
            sources: ref.read(sourceRepositoryProvider),
          );
      Haptics.light();
      _imported = n;
      _message = '"${subject.name}"에 카드 $n장을 넣었어요. 족보 노트에서 볼 수 있어요.';
    } catch (e) {
      _message = '가져오지 못했어요. 다시 해 주세요.\n$e';
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<({Subject? subject, String? newName})?> _pickSubject(
    NotebookShare share,
  ) {
    final mine = ref.read(mySubjectsProvider).value ?? const <Subject>[];
    return showModalBottomSheet<({Subject? subject, String? newName})>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.page,
          AppSpacing.section,
          AppSpacing.page,
          AppSpacing.section * 2,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('어느 과목에 넣을까요?', style: AppTextStyles.titleM),
              const SizedBox(height: AppSpacing.xs),
              const Text(
                '카드는 내 카드가 돼요. 친구가 검수한 카드는 검수 완료로, 초안은 초안으로 들어가요.',
                style: AppTextStyles.bodyS,
              ),
              const SizedBox(height: AppSpacing.section),
              ChunkyButton(
                label: '새 과목 "${share.subjectName}" 만들어 넣기',
                icon: Icons.add_rounded,
                color: AppColors.lime,
                onPressed: () =>
                    Navigator.of(ctx)
                        .pop((subject: null, newName: share.subjectName)),
              ),
              for (final s in mine) ...[
                const SizedBox(height: AppSpacing.sm),
                ChunkyButton(
                  label: s.name,
                  icon: Icons.folder_rounded,
                  color: s.name.trim() == share.subjectName.trim()
                      ? AppColors.sun
                      : AppColors.paper,
                  onPressed: () =>
                      Navigator.of(ctx).pop((subject: s, newName: null)),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(sharedNotebookProvider(widget.code));
    return Scaffold(
      appBar: ArcadeAppBar(
        leading: Navigator.of(context).canPop()
            ? null
            : IconButton(
                icon: const Icon(Icons.home_rounded),
                tooltip: '로비로',
                onPressed: () => context.go(AppRoutes.lobby),
              ),
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ArcadeEmpty(message: '족보를 불러오지 못했어요\n$e'),
        data: (share) => share == null
            ? ArcadeEmpty(
                message: '공유 코드 ${widget.code}에 맞는 족보가 없어요.\n코드를 다시 확인해 주세요.',
              )
            : _body(share),
      ),
    );
  }

  Widget _body(NotebookShare share) {
    final isMine = share.ownerId == ref.watch(uidProvider);
    final from = share.ownerNickname.isEmpty ? '친구' : share.ownerNickname;
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.page,
        0,
        AppSpacing.page,
        AppSpacing.section * 2,
      ),
      children: [
        ArcadeTitle(
          title: '${share.subjectName} 족보',
          subtitle: isMine ? '내가 공유한 족보예요' : '$from님이 공유한 족보',
        ),
        const SizedBox(height: AppSpacing.md),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            StatChip(label: '문제 ${share.cards.length}', color: AppColors.lime),
            StatChip(
              label: '${share.weeks.join('·')}주차',
              color: AppColors.paper,
            ),
            StatChip(label: '코드 ${share.code}', color: AppColors.sun),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        const Text(NotebookExport.notice, style: AppTextStyles.bodyS),
        const SizedBox(height: AppSpacing.section),
        ChunkyButton(
          label: _imported == null ? '내 카드로 가져가기' : '한 번 더 가져가기',
          icon: Icons.download_rounded,
          large: true,
          loading: _busy,
          onPressed: _busy ? null : () => _import(share),
        ),
        const SizedBox(height: AppSpacing.sm),
        ChunkyButton(
          label: 'PDF로 받기',
          icon: Icons.picture_as_pdf_rounded,
          color: AppColors.paper,
          onPressed: _busy ? null : () => _pdf(share),
        ),
        if (_message != null) ...[
          const SizedBox(height: AppSpacing.md),
          Text(_message!, style: AppTextStyles.body),
        ],
        if (_imported != null) ...[
          const SizedBox(height: AppSpacing.sm),
          ChunkyButton(
            label: '내 카드로 가기',
            icon: Icons.style_rounded,
            color: AppColors.cyan,
            onPressed: () => context.go(AppRoutes.cards),
          ),
        ],
        const SizedBox(height: AppSpacing.section),
        const ArcadeSectionHeader(title: '미리 보기'),
        const SizedBox(height: AppSpacing.sm),
        for (final w in share.weeks) ...[
          ChunkyCard(
            title: '$w주차',
            trailing: StatChip(
              label: '${share.cards.where((c) => c.week == w).length}문제',
              color: AppColors.paper,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final s in share.summaries.where((s) => s.week == w))
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: Text(s.summary, style: AppTextStyles.bodyS),
                  ),
                for (final c in share.cards.where((c) => c.week == w).take(3))
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                    child: Text(
                      '• ${c.question}',
                      style: AppTextStyles.body,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                if (share.cards.where((c) => c.week == w).length > 3)
                  Text(
                    '외 ${share.cards.where((c) => c.week == w).length - 3}문제',
                    style: AppTextStyles.label,
                  ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
      ],
    );
  }
}

/// 공유 코드나 링크를 붙여 넣어 친구 족보 열기.
Future<void> showOpenShareDialog(BuildContext context) async {
  final ctrl = TextEditingController();
  final code = await showDialog<String>(
    context: context,
    builder: (ctx) {
      String? error;
      return StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('친구 족보 받기'),
          content: TextField(
            controller: ctrl,
            autofocus: true,
            decoration: InputDecoration(
              hintText: '공유 코드 6자리 또는 링크',
              errorText: error,
            ),
            onSubmitted: (_) {},
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('취소'),
            ),
            TextButton(
              onPressed: () {
                final c = parseShareCode(ctrl.text);
                if (c == null) {
                  setState(() => error = '코드 6자리를 확인해 주세요');
                } else {
                  Navigator.of(ctx).pop(c);
                }
              },
              child: const Text('열기'),
            ),
          ],
        ),
      );
    },
  );

  if (code != null && context.mounted) {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => NotebookShareScreen(code: code)),
    );
  }
}
