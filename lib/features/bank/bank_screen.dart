import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/card.dart';
import '../../core/models/room.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/pressable_scale.dart';
import '../../core/widgets/section_card.dart';
import '../../core/widgets/vote_button.dart';
import '../../fx/haptics.dart';
import '../room/room_repository.dart';
import 'bank_repository.dart';

final _roomProvider = StreamProvider.autoDispose.family<Room?, String>(
  (ref, roomId) => ref.watch(roomRepositoryProvider).watchRoom(roomId),
);

final _bankProvider = StreamProvider.autoDispose
    .family<List<BankEntry>, (String, BankSort)>(
      (ref, args) =>
          ref.watch(bankRepositoryProvider).watchBank(args.$1, sort: args.$2),
    );

/// cardId 목록(쉼표로 이은 문자열) → 카드 본문. 목록이 같으면 다시 읽지 않는다.
final _cardsProvider = FutureProvider.autoDispose
    .family<Map<String, QuizCard>, String>((ref, joinedIds) async {
      final ids = joinedIds.isEmpty ? <String>[] : joinedIds.split(',');
      final cards = await ref.watch(bankRepositoryProvider).cardsByIds(ids);
      return {for (final c in cards) c.id: c};
    });

/// 공동 문제은행: 방에 공유된 카드 목록 + 정렬 + "나올 것 같아요" 투표.
class BankScreen extends ConsumerStatefulWidget {
  const BankScreen({super.key, required this.roomId});

  final String roomId;

  @override
  ConsumerState<BankScreen> createState() => _BankScreenState();
}

class _BankScreenState extends ConsumerState<BankScreen> {
  BankSort _sort = BankSort.votes;

  @override
  Widget build(BuildContext context) {
    final room = ref.watch(_roomProvider(widget.roomId)).value;
    final bank = ref.watch(_bankProvider((widget.roomId, _sort)));

    return Scaffold(
      appBar: AppBar(title: Text(room?.name ?? '문제은행')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.page,
          AppSpacing.sm,
          AppSpacing.page,
          AppSpacing.section * 2,
        ),
        children: [
          const Text('우리가 뽑은 예상 문제', style: AppTextStyles.titleM),
          const SizedBox(height: AppSpacing.xs),
          const Text(
            '시험에 나올 것 같은 문제에 투표해 주세요. 투표는 친구들의 예상일 뿐이에요.',
            style: AppTextStyles.label,
          ),
          const SizedBox(height: AppSpacing.section),
          _SortTabs(
            value: _sort,
            onChanged: (s) {
              Haptics.selection();
              setState(() => _sort = s);
            },
          ),
          const SizedBox(height: AppSpacing.lg),
          ...bank.when(
            loading: () => const [_Message('불러오는 중이에요')],
            error: (e, _) => const [_Message('문제은행을 불러오지 못했어요.')],
            data: (entries) => entries.isEmpty
                ? const [_Message('아직 공유된 문제가 없어요.\n카드 화면에서 "방에 공유"를 눌러 보세요.')]
                : _entryList(entries, room),
          ),
        ],
      ),
    );
  }

  List<Widget> _entryList(List<BankEntry> entries, Room? room) {
    final ids = entries.map((e) => e.cardId).toList()..sort();
    final cards = ref.watch(_cardsProvider(ids.join(','))).value ?? const {};
    final myUid = FirebaseAuth.instance.currentUser?.uid;

    return [
      for (final (i, entry) in entries.indexed)
        Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.md),
          child:
              _BankTile(
                    roomId: widget.roomId,
                    entry: entry,
                    card: cards[entry.cardId],
                    voterText: room == null
                        ? ''
                        : voterSummaryFor(entry, room, myUid: myUid),
                  )
                  .animate(key: ValueKey(entry.cardId))
                  .fadeIn(
                    delay: AppMotion.listStagger * i,
                    duration: AppMotion.listItem,
                  )
                  .moveY(
                    begin: AppMotion.listOffsetY,
                    end: 0,
                    delay: AppMotion.listStagger * i,
                    duration: AppMotion.listItem,
                    curve: AppMotion.spring,
                  ),
        ),
    ];
  }
}

class _SortTabs extends StatelessWidget {
  const _SortTabs({required this.value, required this.onChanged});

  final BankSort value;
  final ValueChanged<BankSort> onChanged;

  static const _labels = {
    BankSort.votes: '투표 많은 순',
    BankSort.latest: '최신순',
    BankSort.week: '주차별',
  };

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: [
        for (final s in BankSort.values)
          PressableScale(
            onTap: s == value ? null : () => onChanged(s),
            child: AnimatedContainer(
              duration: AppMotion.press,
              constraints: const BoxConstraints(minHeight: AppSpacing.minTouch),
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: s == value ? AppColors.ink : AppColors.surface,
                borderRadius: BorderRadius.circular(AppRadius.chip),
                border: Border.all(
                  color: s == value ? AppColors.ink : AppColors.line,
                ),
              ),
              child: Text(
                _labels[s]!,
                style: AppTextStyles.label.copyWith(
                  color: s == value ? AppColors.surface : AppColors.ink,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _BankTile extends StatelessWidget {
  const _BankTile({
    required this.roomId,
    required this.entry,
    required this.card,
    required this.voterText,
  });

  final String roomId;
  final BankEntry entry;

  /// 아직 못 읽었거나 지워진 카드면 null
  final QuizCard? card;
  final String voterText;

  static const _typeLabels = {
    CardType.mcq: '객관식',
    CardType.ox: 'OX',
    CardType.short: '단답형',
  };

  @override
  Widget build(BuildContext context) {
    final card = this.card;
    final source = card == null || card.sourceLabel.isEmpty
        ? entry.addedByNickname
        : '${entry.addedByNickname} · ${card.sourceLabel}';

    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _Tag('${entry.week}주차'),
              if (card != null) ...[
                const SizedBox(width: AppSpacing.xs),
                _Tag(_typeLabels[card.type]!),
              ],
              if (card != null && card.concept.isNotEmpty) ...[
                const SizedBox(width: AppSpacing.xs),
                Flexible(child: _Tag(card.concept)),
              ],
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            card?.question ?? '문제를 불러오는 중이에요',
            style: AppTextStyles.heading.copyWith(
              color: card == null ? AppColors.inkSub : AppColors.ink,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(source, style: AppTextStyles.caption),
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              Expanded(
                child: Text(
                  voterText.isEmpty ? '첫 번째로 투표해 보세요' : voterText,
                  style: AppTextStyles.caption.copyWith(
                    color: voterText.isEmpty
                        ? AppColors.inkSub
                        : AppColors.blueText,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              VoteButton(roomId: roomId, cardId: entry.cardId),
            ],
          ),
        ],
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: AppColors.bg,
        borderRadius: BorderRadius.circular(AppRadius.chip),
      ),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: AppTextStyles.caption.copyWith(color: AppColors.ink),
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.section * 2),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: AppTextStyles.body.copyWith(color: AppColors.inkSub),
      ),
    );
  }
}
