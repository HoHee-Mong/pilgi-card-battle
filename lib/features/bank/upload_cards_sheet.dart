import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/auth/auth_providers.dart';
import '../../core/auth/user_profile.dart';
import '../../core/models/card.dart';
import '../../core/models/room.dart';
import '../../core/router.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/chunky_button.dart';
import '../../fx/haptics.dart';
import '../cards/card_providers.dart';
import 'bank_repository.dart';

/// 문제은행에 아직 안 올린 내 검수 완료 카드 (만든 순서 그대로)
List<QuizCard> cardsToUpload(List<QuizCard> mine, Set<String> inBank) => [
  for (final c in mine)
    if (c.isVerified && !inBank.contains(c.id)) c,
];

final _bankIdsProvider = StreamProvider.autoDispose.family<Set<String>, String>(
  (ref, roomId) => ref
      .watch(bankRepositoryProvider)
      .watchBank(roomId)
      .map((list) => {for (final e in list) e.cardId}),
);

/// 내 카드 한꺼번에 올리기: 이 방 과목의 검수 완료 카드 중 아직 안 올린 것 전부.
/// (카드 화면에서 하나씩 "방에 공유"를 누르지 않아도 된다)
Future<void> showUploadMyCardsSheet(BuildContext context, Room room) {
  return showModalBottomSheet<void>(
    context: context,
    useSafeArea: true,
    builder: (_) => Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.page,
        AppSpacing.section,
        AppSpacing.page,
        AppSpacing.section * 2,
      ),
      child: _UploadForm(room: room),
    ),
  );
}

class _UploadForm extends ConsumerStatefulWidget {
  const _UploadForm({required this.room});
  final Room room;

  @override
  ConsumerState<_UploadForm> createState() => _UploadFormState();
}

class _UploadFormState extends ConsumerState<_UploadForm> {
  int? _done;
  String? _error;

  Future<void> _upload(List<QuizCard> cards) async {
    final uid = ref.read(uidProvider);
    if (uid == null || _done != null) return;
    setState(() {
      _done = 0;
      _error = null;
    });
    try {
      final nickname = await ref
          .read(userProfileRepositoryProvider)
          .ensureNickname(uid);
      final bank = ref.read(bankRepositoryProvider);
      for (final c in cards) {
        await bank.addCard(
          roomId: widget.room.id,
          card: c,
          uid: uid,
          nickname: nickname,
        );
        if (mounted) setState(() => _done = _done! + 1);
      }
      Haptics.light();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('문제 ${cards.length}개를 문제은행에 올렸어요')),
      );
      Navigator.of(context).pop();
    } catch (_) {
      if (mounted) {
        setState(() {
          _done = null;
          _error = '올리다가 멈췄어요. 다시 눌러 주세요.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final room = widget.room;
    final mine =
        ref
            .watch(myCardsProvider((subjectId: room.subjectId, week: null)))
            .value ??
        const <QuizCard>[];
    final inBank = ref.watch(_bankIdsProvider(room.id)).value ?? const {};
    final ready = cardsToUpload(mine, inBank);
    final drafts = mine.where((c) => !c.isVerified).length;
    final busy = _done != null;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('내 카드 올리기', style: AppTextStyles.titleM),
        const SizedBox(height: AppSpacing.sm),
        Text(
          ready.isEmpty
              ? '올릴 카드가 없어요.'
              : '"${room.name}" 과목 카드 중 아직 안 올린 ${ready.length}개를 '
                    '한 번에 문제은행에 올려요.',
          style: AppTextStyles.bodyS,
        ),
        if (drafts > 0) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(
            '검수 전 카드 $drafts개는 카드 화면에서 확인(검수)하면 올릴 수 있어요.',
            style: AppTextStyles.caption,
          ),
        ],
        const SizedBox(height: AppSpacing.section),
        if (ready.isNotEmpty)
          ChunkyButton(
            label: busy
                ? '올리는 중 $_done/${ready.length}'
                : '${ready.length}개 전부 올리기',
            icon: Icons.upload_rounded,
            color: AppColors.lime,
            loading: busy,
            onPressed: busy ? null : () => _upload(ready),
          )
        else
          ChunkyButton(
            label: '필기 찍고 카드 만들기',
            icon: Icons.photo_camera_outlined,
            onPressed: () {
              Navigator.of(context).pop();
              context.go(AppRoutes.cards);
            },
          ),
        if (_error != null) ...[
          const SizedBox(height: AppSpacing.sm),
          Text(
            _error!,
            textAlign: TextAlign.center,
            style: AppTextStyles.label.copyWith(color: AppColors.pink),
          ),
        ],
      ],
    );
  }
}
