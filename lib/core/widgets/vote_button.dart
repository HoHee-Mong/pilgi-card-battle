import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/bank/bank_repository.dart';
import '../../fx/haptics.dart';
import '../models/room.dart';
import '../theme/tokens.dart';
import 'pressable_scale.dart';

/// "나올 것 같아요" 투표 버튼 (공용, `docs/DATA.md` 계약).
///
/// A 화면(혼자 풀기·모의고사 결과)에서도 `VoteButton(roomId: ..., cardId: ...)`만
/// 넣으면 된다. 누르면 투표/취소, 숫자가 올라가는 모션 + 진동.
/// 문제은행에 없는 카드면 아무것도 그리지 않는다.
class VoteButton extends ConsumerStatefulWidget {
  const VoteButton({
    super.key,
    required this.roomId,
    required this.cardId,
    this.uid,
  });

  final String roomId;
  final String cardId;

  /// 테스트용. 보통은 비워 두면 현재 로그인 사용자.
  final String? uid;

  @override
  ConsumerState<VoteButton> createState() => _VoteButtonState();
}

class _VoteButtonState extends ConsumerState<VoteButton> {
  late Stream<BankEntry?> _stream;

  /// 서버 응답 전에 먼저 보여 줄 값 (누르자마자 반응하도록)
  bool? _pendingVoted;
  int? _pendingCount;
  bool _busy = false;

  String? get _uid => widget.uid ?? FirebaseAuth.instance.currentUser?.uid;

  @override
  void initState() {
    super.initState();
    _subscribe();
  }

  @override
  void didUpdateWidget(VoteButton old) {
    super.didUpdateWidget(old);
    if (old.roomId != widget.roomId || old.cardId != widget.cardId) {
      _subscribe();
    }
  }

  void _subscribe() {
    _stream = ref
        .read(bankRepositoryProvider)
        .watchEntry(widget.roomId, widget.cardId);
  }

  Future<void> _toggle(BankEntry entry) async {
    final uid = _uid;
    if (uid == null || _busy) return;
    final votedNow = !entry.votedBy(uid);
    setState(() {
      _busy = true;
      _pendingVoted = votedNow;
      _pendingCount = entry.voteCount + (votedNow ? 1 : -1);
    });
    Haptics.light();
    try {
      await ref
          .read(bankRepositoryProvider)
          .toggleVote(roomId: widget.roomId, cardId: widget.cardId, uid: uid);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          const SnackBar(content: Text('투표하지 못했어요. 잠시 후 다시 눌러 주세요.')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _pendingVoted = null;
          _pendingCount = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<BankEntry?>(
      stream: _stream,
      builder: (context, snap) {
        final entry = snap.data;
        if (entry == null) return const SizedBox.shrink();
        final uid = _uid;
        return VoteChip(
          count: _pendingCount ?? entry.voteCount,
          voted: _pendingVoted ?? (uid != null && entry.votedBy(uid)),
          onTap: uid == null ? null : () => _toggle(entry),
        );
      },
    );
  }
}

/// 투표 버튼의 겉모양만 (데이터 없이 쓰거나 테스트할 때).
class VoteChip extends StatelessWidget {
  const VoteChip({
    super.key,
    required this.count,
    required this.voted,
    required this.onTap,
  });

  final int count;
  final bool voted;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      toggled: voted,
      label: '나올 것 같아요 $count표',
      excludeSemantics: true,
      child: PressableScale(
        onTap: onTap,
        child: AnimatedContainer(
          duration: AppMotion.press,
          curve: AppMotion.spring,
          constraints: const BoxConstraints(minHeight: AppSpacing.minTouch),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          decoration: BoxDecoration(
            color: voted ? AppColors.lime : AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.chip),
            border: Border.all(color: voted ? AppColors.lime : AppColors.line),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '나올 것 같아요',
                style: AppTextStyles.label.copyWith(
                  color: AppColors.ink,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              _RollingCount(count: count),
            ],
          ),
        ),
      ),
    );
  }
}

/// 숫자가 바뀌면 위(증가) 또는 아래(감소)로 굴러가며 바뀐다.
class _RollingCount extends StatefulWidget {
  const _RollingCount({required this.count});
  final int count;

  @override
  State<_RollingCount> createState() => _RollingCountState();
}

class _RollingCountState extends State<_RollingCount> {
  bool _up = true;

  @override
  void didUpdateWidget(_RollingCount old) {
    super.didUpdateWidget(old);
    if (old.count != widget.count) _up = widget.count > old.count;
  }

  @override
  Widget build(BuildContext context) {
    final style = AppTextStyles.label.copyWith(
      color: AppColors.ink,
      fontWeight: FontWeight.w800,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    return ClipRect(
      child: AnimatedSwitcher(
        duration: AppMotion.press,
        switchInCurve: AppMotion.spring,
        switchOutCurve: Curves.easeIn,
        transitionBuilder: (child, animation) {
          final incoming = child.key == ValueKey(widget.count);
          final dir = _up ? 1.0 : -1.0;
          final begin = Offset(0, incoming ? dir : -dir);
          return SlideTransition(
            position: Tween(begin: begin, end: Offset.zero).animate(animation),
            child: FadeTransition(opacity: animation, child: child),
          );
        },
        child: Text(
          '${widget.count}',
          key: ValueKey(widget.count),
          style: style,
        ),
      ),
    );
  }
}

/// "선우 외 2명이 나올 것 같대요" 문구. 투표가 없으면 빈 문자열.
///
/// [names]는 투표한 사람 닉네임(투표 순서). 내가 투표했으면 [me]를 먼저 쓴다.
String voterSummaryText(List<String> names, {String? me}) {
  if (names.isEmpty) return '';
  final iVoted = me != null && names.contains(me);
  final first = iVoted ? '나' : names.first;
  final others = names.length - 1;
  if (iVoted && others == 0) return '나만 나올 것 같다고 했어요';
  return others == 0
      ? '$first${_subjectParticle(first)} 나올 것 같대요'
      : '$first 외 $others명이 나올 것 같대요';
}

/// [entry] 투표자 uid를 [room] 참가자 닉네임으로 바꿔 [voterSummaryText]를 만든다.
String voterSummaryFor(BankEntry entry, Room room, {String? myUid}) {
  final names = <String>[];
  String? me;
  for (final uid in entry.voters) {
    final name = room.nicknameOf(uid);
    final shown = name.isEmpty ? '친구' : name;
    names.add(shown);
    if (uid == myUid) me = shown;
  }
  return voterSummaryText(names, me: me);
}

/// 받침 있으면 "이", 없으면 "가"
String _subjectParticle(String word) {
  if (word.isEmpty) return '가';
  final code = word.codeUnitAt(word.length - 1);
  const hangulStart = 0xAC00, hangulEnd = 0xD7A3;
  if (code < hangulStart || code > hangulEnd) return '가';
  return (code - hangulStart) % 28 == 0 ? '가' : '이';
}
