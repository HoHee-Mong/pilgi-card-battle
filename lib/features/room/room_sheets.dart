import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/auth/auth_providers.dart';
import '../../core/auth/user_profile.dart';
import '../../core/models/room.dart';
import '../../core/models/subject.dart';
import '../../core/router.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/chunky_button.dart';
import '../../core/widgets/chunky_card.dart';
import '../../core/widgets/chunky_press.dart';
import '../../fx/haptics.dart';
import '../subjects/subject_providers.dart';
import 'room_providers.dart';
import 'room_repository.dart';

// 방 만들기 → 초대 코드 → 코드로 입장, 방 고르기. 모두 아래에서 올라오는 시트.

Future<T?> _sheet<T>(BuildContext context, Widget child) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (ctx) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.page,
          0,
          AppSpacing.page,
          AppSpacing.section * 2,
        ),
        child: child,
      ),
    ),
  );
}

/// 방 만들기. 만들면 그 방을 고르고 초대 코드 시트를 띄운다.
Future<void> showCreateRoomSheet(BuildContext context) async {
  final room = await _sheet<Room>(context, const _CreateRoomForm());
  if (room == null || !context.mounted) return;
  await showInviteCodeSheet(context, room);
}

/// 초대 코드로 입장. 들어가면 그 방을 고른다.
Future<void> showJoinRoomSheet(BuildContext context) async {
  final room = await _sheet<Room>(context, const _JoinRoomForm());
  if (room == null || !context.mounted) return;
  ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text('"${room.name}" 방에 들어왔어요')));
}

/// 방의 초대 코드 크게 보여 주기 + 복사
Future<void> showInviteCodeSheet(BuildContext context, Room room) {
  return _sheet<void>(context, _InviteCode(room: room));
}

/// 내 방 목록에서 고르기 + 방 만들기·코드 입장·초대 코드
Future<void> showRoomPickerSheet(BuildContext context) {
  return _sheet<void>(context, const _RoomPicker());
}

Future<String> _myNickname(WidgetRef ref, String uid) {
  return ref.read(userProfileRepositoryProvider).ensureNickname(uid);
}

String _errorText(Object e) =>
    e is RoomException ? e.message : '문제가 생겼어요. 잠시 후 다시 해 주세요.';

// ── 방 만들기 ─────────────────────────────────────────────

class _CreateRoomForm extends ConsumerStatefulWidget {
  const _CreateRoomForm();

  @override
  ConsumerState<_CreateRoomForm> createState() => _CreateRoomFormState();
}

class _CreateRoomFormState extends ConsumerState<_CreateRoomForm> {
  final _name = TextEditingController();
  String? _subjectId;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _pickSubject(Subject s) {
    Haptics.selection();
    setState(() {
      // 이름을 안 바꿨으면 과목 이름으로 채워 준다.
      final prev = ref
          .read(mySubjectsProvider)
          .value
          ?.where((x) => x.id == _subjectId)
          .firstOrNull;
      if (_name.text.isEmpty || _name.text == prev?.name) _name.text = s.name;
      _subjectId = s.id;
    });
  }

  Future<void> _create() async {
    final uid = ref.read(uidProvider);
    final subjectId = _subjectId;
    final name = _name.text.trim();
    if (uid == null || subjectId == null || name.isEmpty || _busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final nickname = await _myNickname(ref, uid);
      final room = await ref
          .read(roomRepositoryProvider)
          .createRoom(
            uid: uid,
            nickname: nickname,
            subjectId: subjectId,
            name: name,
          );
      ref.read(selectedRoomIdProvider.notifier).select(room.id);
      if (mounted) Navigator.of(context).pop(room);
    } catch (e) {
      if (mounted) setState(() => _error = _errorText(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final subjects = ref.watch(mySubjectsProvider);
    final list = subjects.value ?? const <Subject>[];
    final ready = _subjectId != null && _name.text.trim().isNotEmpty && !_busy;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('스터디 방 만들기', style: AppTextStyles.titleM),
        const SizedBox(height: AppSpacing.xs),
        const Text('같이 시험 볼 친구들과 예상 문제를 모아요', style: AppTextStyles.label),
        const SizedBox(height: AppSpacing.section),
        const Text('과목', style: AppTextStyles.heading),
        const SizedBox(height: AppSpacing.sm),
        if (subjects.isLoading)
          const Text('과목을 불러오는 중이에요', style: AppTextStyles.caption)
        else if (list.isEmpty)
          _NoSubject(
            onGo: () {
              Navigator.of(context).pop();
              context.go(AppRoutes.cards);
            },
          )
        else
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              for (final s in list)
                _Choice(
                  label: s.name,
                  selected: s.id == _subjectId,
                  onTap: () => _pickSubject(s),
                ),
            ],
          ),
        const SizedBox(height: AppSpacing.section),
        const Text('방 이름', style: AppTextStyles.heading),
        const SizedBox(height: AppSpacing.sm),
        TextField(
          controller: _name,
          maxLength: 20,
          textInputAction: TextInputAction.done,
          decoration: const InputDecoration(hintText: '예) 영상처리 벼락치기방'),
          onChanged: (_) => setState(() {}),
          onSubmitted: (_) => _create(),
        ),
        if (_error != null) ...[
          const SizedBox(height: AppSpacing.sm),
          Text(
            _error!,
            style: AppTextStyles.label.copyWith(color: AppColors.ink),
          ),
        ],
        const SizedBox(height: AppSpacing.lg),
        ChunkyButton(
          label: '방 만들고 초대 코드 받기',
          loading: _busy,
          onPressed: ready ? _create : null,
        ),
      ],
    );
  }
}

class _NoSubject extends StatelessWidget {
  const _NoSubject({required this.onGo});
  final VoidCallback onGo;

  @override
  Widget build(BuildContext context) {
    return ChunkyCard(
      color: AppColors.sun,
      onTap: onGo,
      child: const Text(
        '아직 과목이 없어요.\n내 카드에서 과목을 먼저 만들어 주세요 →',
        style: AppTextStyles.bodyS,
      ),
    );
  }
}

/// 고르기 알약 (고르면 lime)
class _Choice extends StatelessWidget {
  const _Choice({
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
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        child: Text(
          label,
          style: AppTextStyles.chip.copyWith(color: onChunkyColor(color)),
        ),
      ),
    );
  }
}

// ── 코드로 입장 ───────────────────────────────────────────

class _JoinRoomForm extends ConsumerStatefulWidget {
  const _JoinRoomForm();

  @override
  ConsumerState<_JoinRoomForm> createState() => _JoinRoomFormState();
}

class _JoinRoomFormState extends ConsumerState<_JoinRoomForm> {
  final _code = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  String get _normalized => RoomRepository.normalizeCode(_code.text);

  Future<void> _join() async {
    final uid = ref.read(uidProvider);
    if (uid == null ||
        _normalized.length != RoomRepository.codeLength ||
        _busy) {
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final nickname = await _myNickname(ref, uid);
      final room = await ref
          .read(roomRepositoryProvider)
          .joinByCode(code: _normalized, uid: uid, nickname: nickname);
      ref.read(selectedRoomIdProvider.notifier).select(room.id);
      Haptics.light();
      if (mounted) Navigator.of(context).pop(room);
    } catch (e) {
      Haptics.medium();
      if (mounted) setState(() => _error = _errorText(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ready = _normalized.length == RoomRepository.codeLength && !_busy;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('코드로 입장', style: AppTextStyles.titleM),
        const SizedBox(height: AppSpacing.xs),
        const Text('친구에게 받은 6자리 초대 코드를 넣어 주세요', style: AppTextStyles.label),
        const SizedBox(height: AppSpacing.section),
        TextField(
          controller: _code,
          autofocus: true,
          maxLength: RoomRepository.codeLength,
          textAlign: TextAlign.center,
          textCapitalization: TextCapitalization.characters,
          textInputAction: TextInputAction.go,
          style: AppTextStyles.titleM.copyWith(letterSpacing: AppSpacing.sm),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp('[A-Za-z0-9]')),
            TextInputFormatter.withFunction(
              (_, v) => v.copyWith(text: v.text.toUpperCase()),
            ),
          ],
          decoration: const InputDecoration(
            hintText: 'ABC234',
            counterText: '',
          ),
          onChanged: (_) => setState(() => _error = null),
          onSubmitted: (_) => _join(),
        ),
        if (_error != null) ...[
          const SizedBox(height: AppSpacing.sm),
          Text(
            _error!,
            style: AppTextStyles.label.copyWith(color: AppColors.ink),
          ),
        ],
        const SizedBox(height: AppSpacing.lg),
        ChunkyButton(
          label: '입장하기',
          color: AppColors.lime,
          loading: _busy,
          onPressed: ready ? _join : null,
        ),
      ],
    );
  }
}

// ── 초대 코드 ─────────────────────────────────────────────

class _InviteCode extends StatelessWidget {
  const _InviteCode({required this.room});
  final Room room;

  Future<void> _copy(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: room.code));
    Haptics.light();
    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('초대 코드를 복사했어요')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(room.name, style: AppTextStyles.titleM),
        const SizedBox(height: AppSpacing.xs),
        const Text('친구에게 이 코드를 알려 주면 같은 방에 들어와요', style: AppTextStyles.label),
        const SizedBox(height: AppSpacing.section),
        Semantics(
          label: '초대 코드 ${room.code.split('').join(' ')}',
          excludeSemantics: true,
          child: Row(
            children: [
              for (final (i, ch) in room.code.split('').indexed) ...[
                if (i > 0) const SizedBox(width: AppSpacing.xs),
                Expanded(child: _CodeTile(ch)),
              ],
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.section),
        ChunkyButton(
          label: '코드 복사하기',
          icon: Icons.copy_rounded,
          color: AppColors.sun,
          onPressed: () => _copy(context),
        ),
        const SizedBox(height: AppSpacing.sm),
        ChunkyButton(
          label: '다 했어요',
          color: AppColors.paper,
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }
}

class _CodeTile extends StatelessWidget {
  const _CodeTile(this.ch);
  final String ch;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 0.8,
      child: ChunkyCard(
        color: AppColors.paper,
        radius: AppRadius.chip,
        padding: EdgeInsets.zero,
        child: Center(child: Text(ch, style: AppTextStyles.titleM)),
      ),
    );
  }
}

// ── 방 고르기 ─────────────────────────────────────────────

class _RoomPicker extends ConsumerWidget {
  const _RoomPicker();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rooms = ref.watch(myRoomsProvider).value ?? const <Room>[];
    final current = ref.watch(currentRoomProvider).value;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('내 스터디 방', style: AppTextStyles.titleM),
        const SizedBox(height: AppSpacing.section),
        for (final room in rooms)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: ChunkyCard(
              radius: AppRadius.button,
              color: room.id == current?.id ? AppColors.lime : AppColors.paper,
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.md,
                AppSpacing.sm,
                AppSpacing.md,
              ),
              onTap: () {
                Haptics.selection();
                ref.read(selectedRoomIdProvider.notifier).select(room.id);
                Navigator.of(context).pop();
              },
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          room.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.heading,
                        ),
                        Text(
                          '${room.memberIds.length}명 · 코드 ${room.code}',
                          style: AppTextStyles.caption,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: '초대 코드 보기',
                    icon: const Icon(Icons.person_add_alt_1_rounded),
                    color: AppColors.ink,
                    onPressed: () => showInviteCodeSheet(context, room),
                  ),
                ],
              ),
            ),
          ),
        const SizedBox(height: AppSpacing.sm),
        RoomActions(onDone: () => Navigator.of(context).pop()),
      ],
    );
  }
}

/// "방 만들기" + "코드로 입장" 두 버튼. 문제은행 빈 화면·방 고르기에서 같이 쓴다.
class RoomActions extends StatelessWidget {
  const RoomActions({super.key, this.onDone});

  /// 버튼을 누르기 전에 닫을 것이 있으면 (예: 방 고르기 시트)
  final VoidCallback? onDone;

  @override
  Widget build(BuildContext context) {
    // 시트를 닫은 뒤에도 쓸 수 있도록 바깥 context를 미리 잡아 둔다.
    final outer = Navigator.of(context, rootNavigator: false).context;
    return Row(
      children: [
        Expanded(
          child: ChunkyButton(
            label: '방 만들기',
            onPressed: () {
              onDone?.call();
              showCreateRoomSheet(outer);
            },
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: ChunkyButton(
            label: '코드로 입장',
            color: AppColors.lime,
            onPressed: () {
              onDone?.call();
              showJoinRoomSheet(outer);
            },
          ),
        ),
      ],
    );
  }
}
