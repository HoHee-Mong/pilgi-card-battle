import 'dart:math' as math;

import 'package:firebase_auth/firebase_auth.dart';

import 'dart:async';

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
import '../room/room_stats_screen.dart';
import 'bank_filter.dart';
import 'bank_repository.dart';
import 'upload_cards_sheet.dart';

final _roomProvider = StreamProvider.autoDispose.family<Room?, String>(
  (ref, roomId) => ref.watch(roomRepositoryProvider).watchRoom(roomId),
);

final _bankProvider = StreamProvider.autoDispose
    .family<List<BankEntry>, String>(
      (ref, roomId) => ref.watch(bankRepositoryProvider).watchBank(roomId),
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
  BankFilter _filter = BankFilter.none;
  final _search = TextEditingController();
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  /// 글자 칠 때마다 다시 그리지 않고 잠깐 멈추면 적용
  void _onQuery(String text) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 200), () {
      if (mounted) setState(() => _filter = _filter.copyWith(query: text));
    });
  }

  void _resetFilter() {
    _debounce?.cancel();
    _search.clear();
    setState(() => _filter = BankFilter.none);
  }

  @override
  Widget build(BuildContext context) {
    final room = ref.watch(_roomProvider(widget.roomId)).value;
    final bank = ref.watch(_bankProvider(widget.roomId));
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
            if (room != null) ...[
              const SizedBox(height: AppSpacing.md),
              ChunkyButton(
                label: '내 카드 한꺼번에 올리기',
                icon: Icons.upload_rounded,
                color: AppColors.sun,
                onPressed: () => showUploadMyCardsSheet(context, room),
              ),
            ],
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
                      _Message('아직 올라온 문제가 없어요.\n위의 "내 카드 한꺼번에 올리기"를 눌러 보세요.'),
                    ]
                  : _entryList(
                      BankRepository.sortEntries(entries, _sort),
                      room,
                    ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _entryList(List<BankEntry> all, Room? room) {
    // 카드 본문은 전체 목록 기준으로 한 번만 읽는다 (검색·필터를 바꿔도 다시 안 읽음)
    final ids = all.map((e) => e.cardId).toList()..sort();
    final cards = ref.watch(_cardsProvider(ids.join(','))).value ?? const {};
    final myUid = FirebaseAuth.instance.currentUser?.uid;
    final ranked = _sort == BankSort.votes;
    final filtering = _filter.isActive;
    final entries = filterBank(all, cards, _filter);
    // 필터를 걸어도 순위 숫자는 전체 순위 그대로
    final rankOf = {for (final (i, e) in all.indexed) e.cardId: i};
    final weeks = {for (final e in all) e.week}.toList()..sort();

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
      final rank = rankOf[entry.cardId] ?? i;
      // 투표순 1위는 표가 하나 이상 있을 때만 크게 보여 준다.
      if (ranked && rank == 0 && entry.voteCount > 0) {
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
        badge: ranked ? '${rank + 1}' : '${entry.week}주',
        badgeColor: ranked ? _rankColor(rank) : AppColors.cream,
      );
    }

    return [
      _SearchBar(
        controller: _search,
        filter: _filter,
        weeks: weeks,
        onQuery: _onQuery,
        onFilter: (f) {
          Haptics.selection();
          setState(() => _filter = f);
        },
      ),
      const SizedBox(height: AppSpacing.md),
      if (filtering)
        Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.md),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  '찾은 문제 ${entries.length}개 / 전체 ${all.length}개',
                  style: AppTextStyles.label,
                ),
              ),
              TextButton.icon(
                onPressed: _resetFilter,
                icon: const Icon(Icons.restart_alt_rounded),
                label: const Text('필터 초기화'),
              ),
            ],
          ),
        ),
      if (entries.isEmpty) const _Message('조건에 맞는 문제가 없어요.\n검색어나 필터를 바꿔 보세요.'),
      for (final (i, entry) in entries.indexed)
        Padding(
          // 목록이 바뀌어도 같은 카드는 같은 자리로 (등장 모션이 다시 안 돌게)
          key: ValueKey('row-${entry.cardId}'),
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
        if (room != null) ...[
          if (canPop) const SizedBox(width: AppSpacing.sm),
          // 우리 방 기록: 예상 적중왕·모의고사 점수 비교
          ChunkyButton(
            expand: false,
            color: AppColors.sun,
            semanticLabel: '우리 방 기록',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) =>
                    RoomStatsScreen(roomId: room.id, roomName: room.name),
              ),
            ),
            child: const Icon(Icons.emoji_events_rounded),
          ),
        ],
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

/// 검색창 + 주차·유형 필터 칩
class _SearchBar extends StatelessWidget {
  const _SearchBar({
    required this.controller,
    required this.filter,
    required this.weeks,
    required this.onQuery,
    required this.onFilter,
  });

  final TextEditingController controller;
  final BankFilter filter;

  /// 문제은행에 있는 주차들
  final List<int> weeks;
  final ValueChanged<String> onQuery;
  final ValueChanged<BankFilter> onFilter;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: controller,
          onChanged: onQuery,
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            hintText: '문제·보기·정답으로 찾기',
            prefixIcon: const Icon(Icons.search_rounded),
            suffixIcon: ListenableBuilder(
              listenable: controller,
              builder: (_, _) => controller.text.isEmpty
                  ? const SizedBox.shrink()
                  : IconButton(
                      tooltip: '검색어 지우기',
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () {
                        controller.clear();
                        onQuery('');
                      },
                    ),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.xs,
          runSpacing: AppSpacing.xs,
          children: [
            for (final t in CardType.values)
              _FilterChip(
                label: cardTypeLabels[t]!,
                selected: filter.types.contains(t),
                onTap: () => onFilter(filter.toggleType(t)),
              ),
            if (weeks.length > 1)
              for (final w in weeks)
                _FilterChip(
                  label: '$w주',
                  selected: filter.weeks.contains(w),
                  onTap: () => onFilter(filter.toggleWeek(w)),
                ),
          ],
        ),
      ],
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.lime : AppColors.paper;
    return Semantics(
      button: true,
      selected: selected,
      child: ChunkyPress(
        onTap: onTap,
        color: color,
        radius: AppRadius.chip,
        height: AppSpacing.minTouch,
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        child: Text(
          label,
          style: AppTextStyles.chip.copyWith(color: onChunkyColor(color)),
        ),
      ),
    );
  }
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
