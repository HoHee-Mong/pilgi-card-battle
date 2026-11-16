import 'dart:math' as math;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/card.dart';
import '../../core/models/room.dart';
import '../../core/theme/layout.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/chunky_button.dart';
import '../../core/widgets/chunky_card.dart';
import '../../core/widgets/chunky_press.dart';
import '../../core/widgets/stat_chip.dart';
import '../../core/widgets/vote_button.dart';
import '../../fx/haptics.dart';
import '../battle/waiting_room_screen.dart';
import '../room/room_repository.dart';
import '../room/room_sheets.dart';
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

/// 공동 문제은행 = "예상 문제 랭킹" (시안 `docs/design/game-bank.png`).
///
/// 방에 공유된 카드 목록 + 정렬 + "나올 것 같아요" 투표.
/// 투표순일 때 1위는 분홍 큰 카드 + 왕관, 나머지는 순위 배지가 붙은 한 줄 카드.
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
    final canPop = Navigator.of(context).canPop();

    return Scaffold(
      backgroundColor: AppColors.cream,
      // 시안 맨 아래 어두운 버튼 자리. 모의고사(A)가 생기면 옆에 같이 둔다.
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: AppLayout.pagePadding(
            context,
            top: AppSpacing.sm,
            bottom: AppSpacing.sm,
          ),
          child: ChunkyButton(
            label: '친구랑 배틀하기',
            icon: Icons.bolt_rounded,
            color: AppColors.ink,
            shadowColor: AppColors.grape,
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => WaitingRoomScreen(roomId: widget.roomId),
              ),
            ),
          ),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: AppLayout.pagePadding(
            context,
            top: AppSpacing.lg,
            bottom: AppSpacing.section * 3,
          ),
          children: [
            _Header(room: room, canPop: canPop),
            const SizedBox(height: AppSpacing.section),
            const Text('예상 문제 랭킹', style: AppTextStyles.titleL),
            const SizedBox(height: AppSpacing.xs),
            const Text('우리가 ‘나올 것 같다’고 고른 문제들', style: AppTextStyles.label),
            const SizedBox(height: AppSpacing.section),
            _SortTabs(
              value: _sort,
              onChanged: (s) {
                Haptics.selection();
                setState(() => _sort = s);
              },
            ),
            const SizedBox(height: AppSpacing.section + AppSpacing.md),
            ...bank.when(
              loading: () => const [_Message('불러오는 중이에요')],
              error: (e, _) => const [_Message('문제은행을 불러오지 못했어요.')],
              data: (entries) => entries.isEmpty
                  ? const [
                      _Message('아직 공유된 문제가 없어요.\n카드 화면에서 "방에 공유"를 눌러 보세요.'),
                    ]
                  : _entryList(entries, room),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _entryList(List<BankEntry> entries, Room? room) {
    final ids = entries.map((e) => e.cardId).toList()..sort();
    final cards = ref.watch(_cardsProvider(ids.join(','))).value ?? const {};
    final myUid = FirebaseAuth.instance.currentUser?.uid;
    final ranked = _sort == BankSort.votes;

    Widget tile(int i, BankEntry entry) {
      final card = cards[entry.cardId];
      final voterText = room == null
          ? ''
          : voterSummaryFor(entry, room, myUid: myUid);
      // 올린 사람·방장은 길게 눌러 문제은행에서 뺄 수 있다.
      final onLongPress =
          room != null &&
              myUid != null &&
              BankRepository.canRemove(entry, room, myUid)
          ? () => _confirmRemove(room, entry, card, myUid)
          : null;
      // 투표순 1위는 표가 하나 이상 있을 때만 크게 보여 준다.
      if (ranked && i == 0 && entry.voteCount > 0) {
        return _TopTile(
          roomId: widget.roomId,
          entry: entry,
          card: card,
          voterText: voterText,
          onLongPress: onLongPress,
        );
      }
      return _RowTile(
        onLongPress: onLongPress,
        roomId: widget.roomId,
        entry: entry,
        card: card,
        badge: ranked ? '${i + 1}' : '${entry.week}주',
        badgeColor: ranked ? _rankColor(i) : AppColors.cream,
      );
    }

    return [
      for (final (i, entry) in entries.indexed)
        Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
          child: tile(i, entry)
              .animate(key: ValueKey('${_sort.name}-${entry.cardId}'))
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

  Future<void> _confirmRemove(
    Room room,
    BankEntry entry,
    QuizCard? card,
    String uid,
  ) async {
    Haptics.medium();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.paper,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.card),
          side: const BorderSide(color: AppColors.ink, width: AppBlock.border),
        ),
        title: const Text('문제은행에서 뺄까요?', style: AppTextStyles.heading),
        content: Text(
          '${card?.question ?? '이 문제'}\n\n받은 표 ${entry.voteCount}개도 같이 사라져요. '
          '내 카드 자체는 지워지지 않아요.',
          style: AppTextStyles.bodyS,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('그대로 두기'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('빼기'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await ref
          .read(bankRepositoryProvider)
          .removeCard(room: room, cardId: entry.cardId, uid: uid);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('문제은행에서 뺐어요')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              e is BankException ? e.message : '빼지 못했어요. 잠시 후 다시 해 주세요.',
            ),
          ),
        );
      }
    }
  }

  /// 순위 배지 색: 1위 pink, 2위 sun, 3위 cyan, 4위 lime, 그 뒤는 cream
  static Color _rankColor(int i) => switch (i) {
    0 => AppColors.pink,
    1 => AppColors.sun,
    2 => AppColors.cyan,
    3 => AppColors.lime,
    _ => AppColors.cream,
  };
}

/// 뒤로 가기 + 방 이름·인원 알약
class _Header extends StatelessWidget {
  const _Header({required this.room, required this.canPop});

  final Room? room;
  final bool canPop;

  @override
  Widget build(BuildContext context) {
    final room = this.room;
    return Row(
      children: [
        if (canPop)
          ChunkyButton(
            expand: false,
            color: AppColors.paper,
            semanticLabel: '뒤로',
            onPressed: () => Navigator.of(context).maybePop(),
            child: const Icon(Icons.chevron_left_rounded),
          ),
        const Spacer(),
        if (room != null)
          Flexible(
            child: Semantics(
              button: true,
              hint: '방 바꾸기·초대 코드',
              child: GestureDetector(
                onTap: () => showRoomPickerSheet(context),
                child: StatChip(
                  label: '${room.name} · ${room.memberIds.length}명',
                  icon: Icons.expand_more_rounded,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _SortTabs extends StatelessWidget {
  const _SortTabs({required this.value, required this.onChanged});

  final BankSort value;
  final ValueChanged<BankSort> onChanged;

  static const _labels = {
    BankSort.votes: '나올 것 같은 순',
    BankSort.latest: '최신순',
    BankSort.week: '주차별',
  };

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (final (i, s) in BankSort.values.indexed) ...[
          if (i > 0) const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Semantics(
              button: true,
              selected: s == value,
              child: ChunkyPress(
                onTap: s == value ? null : () => onChanged(s),
                color: s == value ? AppColors.grape : AppColors.paper,
                radius: AppRadius.chip,
                height: AppSpacing.minTouch + AppSpacing.xs,
                alignment: Alignment.center,
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
                child: Text(
                  _labels[s]!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.chip.copyWith(
                    color: onChunkyColor(
                      s == value ? AppColors.grape : AppColors.paper,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

String _sourceText(BankEntry entry, QuizCard? card) {
  final who = entry.addedByNickname.isEmpty ? '친구' : entry.addedByNickname;
  final base = '${entry.week}주차 · $who 카드';
  if (card == null || card.sourceLabel.isEmpty) return base;
  return '$base · ${card.sourceLabel}';
}

/// 투표순 1위: 분홍 큰 카드 + 위에 살랑이는 왕관
class _TopTile extends StatelessWidget {
  const _TopTile({
    required this.roomId,
    required this.entry,
    required this.card,
    required this.voterText,
    this.onLongPress,
  });

  final VoidCallback? onLongPress;

  final String roomId;
  final BankEntry entry;
  final QuizCard? card;
  final String voterText;

  static const _crownSize = Size(64, 44);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(top: _crownSize.height * 0.6),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          ChunkyCard(
            onLongPress: onLongPress,
            color: AppColors.pink,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text('1위', style: AppTextStyles.titleM),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Text(
                        _sourceText(entry, card),
                        textAlign: TextAlign.end,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.label.copyWith(
                          color: AppColors.ink,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  card?.question ?? '문제를 불러오는 중이에요',
                  style: AppTextStyles.titleM,
                ),
                const SizedBox(height: AppSpacing.lg),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Text(
                        voterText,
                        style: AppTextStyles.label.copyWith(
                          color: AppColors.ink,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    VoteButton(roomId: roomId, cardId: entry.cardId),
                  ],
                ),
              ],
            ),
          ),
          Positioned(
            left: AppSpacing.page,
            top: -_crownSize.height * 0.6,
            child: CustomPaint(size: _crownSize, painter: const _CrownPainter())
                .animate(onPlay: (c) => c.repeat(reverse: true))
                .rotate(
                  begin: -0.012,
                  end: 0.012,
                  duration: AppMotion.crownSway,
                  curve: Curves.easeInOut,
                  alignment: Alignment.bottomCenter,
                ),
          ),
        ],
      ),
    );
  }
}

/// 2위 이하(또는 투표순이 아닐 때 전부): 배지 + 문제 + 작은 투표 버튼
class _RowTile extends StatelessWidget {
  const _RowTile({
    required this.roomId,
    required this.entry,
    required this.card,
    required this.badge,
    required this.badgeColor,
    this.onLongPress,
  });

  final VoidCallback? onLongPress;

  final String roomId;
  final BankEntry entry;
  final QuizCard? card;
  final String badge;
  final Color badgeColor;

  static const _badgeSize = AppSpacing.minTouch + AppSpacing.xs;

  @override
  Widget build(BuildContext context) {
    return ChunkyCard(
      onLongPress: onLongPress,
      radius: AppRadius.button,
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.md,
      ),
      child: Row(
        children: [
          Container(
            width: _badgeSize,
            height: _badgeSize,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: badgeColor,
              borderRadius: BorderRadius.circular(AppRadius.chip),
              border: Border.all(color: AppColors.ink, width: AppBlock.border),
            ),
            child: Text(
              badge,
              style: AppTextStyles.heading.copyWith(
                color: onChunkyColor(badgeColor),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  card?.question ?? '문제를 불러오는 중이에요',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.body.copyWith(
                    fontWeight: FontWeight.w900,
                    color: card == null ? AppColors.inkSub : AppColors.ink,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  _sourceText(entry, card),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.caption,
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          VoteButton(roomId: roomId, cardId: entry.cardId, compact: true),
        ],
      ),
    );
  }
}

/// 1위 왕관: sun 면 + ink 굵은 테두리 + 가운데 pink 보석
class _CrownPainter extends CustomPainter {
  const _CrownPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final path = Path()
      ..moveTo(w * 0.08, h * 0.95)
      ..lineTo(w * 0.02, h * 0.18)
      ..lineTo(w * 0.30, h * 0.50)
      ..lineTo(w * 0.50, h * 0.04)
      ..lineTo(w * 0.70, h * 0.50)
      ..lineTo(w * 0.98, h * 0.18)
      ..lineTo(w * 0.92, h * 0.95)
      ..close();
    canvas.drawPath(path, Paint()..color = AppColors.sun);
    canvas.drawPath(
      path,
      Paint()
        ..color = AppColors.ink
        ..style = PaintingStyle.stroke
        ..strokeWidth = AppBlock.border
        ..strokeJoin = StrokeJoin.round,
    );
    final gem = Offset(w * 0.5, h * 0.66);
    final r = math.min(w, h) * 0.11;
    canvas.drawCircle(gem, r, Paint()..color = AppColors.pink);
    canvas.drawCircle(
      gem,
      r,
      Paint()
        ..color = AppColors.ink
        ..style = PaintingStyle.stroke
        ..strokeWidth = AppBlock.border * 0.8,
    );
  }

  @override
  bool shouldRepaint(_CrownPainter oldDelegate) => false;
}

class _Message extends StatelessWidget {
  const _Message(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.section * 3),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: AppTextStyles.body.copyWith(color: AppColors.inkSub),
      ),
    );
  }
}
