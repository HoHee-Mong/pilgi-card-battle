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
import '../../core/widgets/stat_chip.dart';
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
                  _RoomMenu(room: room),
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

/// 방 하나의 더보기: 방 나가기, (방장) 방 지우기
class _RoomMenu extends ConsumerWidget {
  const _RoomMenu({required this.room});
  final Room room;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uid = ref.watch(uidProvider);
    final isHost = uid != null && room.isHost(uid);
    return PopupMenuButton<_RoomAction>(
      tooltip: '방 설정',
      icon: const Icon(Icons.more_vert_rounded, color: AppColors.ink),
      color: AppColors.paper,
      onSelected: (a) => a == _RoomAction.settings
          ? showRoomSettingsSheet(context, room.id)
          : _leaveOrDelete(context, ref, room, leave: a == _RoomAction.leave),
      itemBuilder: (_) => [
        const PopupMenuItem(
          value: _RoomAction.settings,
          child: Text('방 설정·멤버'),
        ),
        const PopupMenuItem(value: _RoomAction.leave, child: Text('방 나가기')),
        if (isHost)
          const PopupMenuItem(value: _RoomAction.delete, child: Text('방 지우기')),
      ],
    );
  }
}

/// 방 나가기·지우기 (확인 창 → 실행 → 성공하면 열려 있는 시트 닫기)
Future<void> _leaveOrDelete(
  BuildContext context,
  WidgetRef ref,
  Room room, {
  required bool leave,
}) async {
  final uid = ref.read(uidProvider);
  if (uid == null) return;
  final alone = room.memberIds.length <= 1;
  final ok = await _confirm(
    context,
    title: leave ? '"${room.name}"에서 나갈까요?' : '"${room.name}"을 지울까요?',
    body: leave
        ? alone
              ? '마지막 멤버라 나가면 방이 지워져요. 문제은행·투표 기록도 같이 사라져요.'
              : '다시 들어오려면 초대 코드가 필요해요. 내가 올린 문제와 투표는 방에 남아요.'
        : '모든 친구에게서 방이 사라지고, 문제은행·투표·배틀·모의고사 기록도 지워져요. '
              '각자의 카드는 남아요.',
    action: leave ? '나가기' : '지우기',
  );
  if (ok != true) return;
  Haptics.medium();
  final repo = ref.read(roomRepositoryProvider);
  try {
    if (leave) {
      await repo.leaveRoom(roomId: room.id, uid: uid);
    } else {
      await repo.deleteRoom(roomId: room.id, uid: uid);
    }
    if (context.mounted) Navigator.of(context).pop();
  } catch (e) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(e is RoomException ? e.message : '잠시 후 다시 해 주세요.'),
      ),
    );
  }
}

/// 방 멤버 한 명 (설정 화면 목록용)
typedef RoomMember = ({String uid, String name, bool isHost, bool isMe});

/// 방장 먼저, 그다음 들어온 순서. 이름을 모르면 "친구".
List<RoomMember> roomMembers(Room room, String? myUid) {
  final ids = room.memberIds.isNotEmpty
      ? room.memberIds
      : room.players.keys.toList();
  final list = [
    for (final id in ids)
      (
        uid: id,
        name: room.nicknameOf(id).isEmpty ? '친구' : room.nicknameOf(id),
        isHost: room.isHost(id),
        isMe: id == myUid,
      ),
  ];
  list.sort((a, b) => (b.isHost ? 1 : 0) - (a.isHost ? 1 : 0));
  return list;
}

final _watchRoomProvider = StreamProvider.autoDispose.family<Room?, String>(
  (ref, roomId) => ref.watch(roomRepositoryProvider).watchRoom(roomId),
);

/// 방 설정: 이름(방장만 변경), 초대 코드 복사, 멤버 목록(방장 표시), 나가기·지우기
Future<void> showRoomSettingsSheet(BuildContext context, String roomId) {
  return _sheet<void>(context, _RoomSettings(roomId: roomId));
}

class _RoomSettings extends ConsumerStatefulWidget {
  const _RoomSettings({required this.roomId});
  final String roomId;

  @override
  ConsumerState<_RoomSettings> createState() => _RoomSettingsState();
}

class _RoomSettingsState extends ConsumerState<_RoomSettings> {
  final _name = TextEditingController();
  bool _loaded = false;
  bool _busy = false;
  String? _message;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _rename(Room room, String uid) async {
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      await ref
          .read(roomRepositoryProvider)
          .rename(roomId: room.id, uid: uid, name: _name.text);
      Haptics.light();
      if (mounted) setState(() => _message = '방 이름을 바꿨어요');
    } catch (e) {
      if (mounted) {
        setState(
          () => _message = e is RoomException ? e.message : '잠시 후 다시 해 주세요.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _copy(String code) async {
    await Clipboard.setData(ClipboardData(text: code));
    Haptics.light();
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('초대 코드 $code 복사했어요')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final room = ref.watch(_watchRoomProvider(widget.roomId)).value;
    final uid = ref.watch(uidProvider);
    if (room == null || uid == null) {
      return const Padding(
        padding: EdgeInsets.all(AppSpacing.section),
        child: Text('방 정보를 불러오는 중이에요', style: AppTextStyles.label),
      );
    }
    if (!_loaded) {
      _loaded = true;
      _name.text = room.name;
    }
    final isHost = room.isHost(uid);
    final members = roomMembers(room, uid);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('방 설정', style: AppTextStyles.titleM),
        const SizedBox(height: AppSpacing.section),
        const Text('방 이름', style: AppTextStyles.label),
        const SizedBox(height: AppSpacing.sm),
        if (isHost)
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _name,
                  maxLength: RoomRepository.maxNameLength,
                  decoration: const InputDecoration(counterText: ''),
                  onSubmitted: (_) => _rename(room, uid),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              ChunkyButton(
                label: '바꾸기',
                expand: false,
                color: AppColors.sun,
                loading: _busy,
                onPressed: _busy ? null : () => _rename(room, uid),
              ),
            ],
          )
        else
          Text(room.name, style: AppTextStyles.heading),
        if (_message != null) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(
            _message!,
            style: AppTextStyles.label.copyWith(color: AppColors.grape),
          ),
        ],
        const SizedBox(height: AppSpacing.section),
        ChunkyButton(
          label: '초대 코드 ${room.code} 복사',
          icon: Icons.copy_rounded,
          color: AppColors.paper,
          onPressed: () => _copy(room.code),
        ),
        const SizedBox(height: AppSpacing.section),
        Text('멤버 ${members.length}명', style: AppTextStyles.heading),
        const SizedBox(height: AppSpacing.sm),
        for (final m in members)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.xs),
            child: Row(
              children: [
                Icon(
                  m.isHost ? Icons.star_rounded : Icons.person_rounded,
                  color: m.isHost ? AppColors.grape : AppColors.inkSub,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    m.isMe ? '${m.name} (나)' : m.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.body,
                  ),
                ),
                if (m.isHost) const StatChip(label: '방장', color: AppColors.sun),
              ],
            ),
          ),
        const SizedBox(height: AppSpacing.section),
        ChunkyButton(
          label: '방 나가기',
          color: AppColors.paper,
          onPressed: () => _leaveOrDelete(context, ref, room, leave: true),
        ),
        if (isHost) ...[
          const SizedBox(height: AppSpacing.sm),
          ChunkyButton(
            label: '방 지우기',
            color: AppColors.pink,
            onPressed: () => _leaveOrDelete(context, ref, room, leave: false),
          ),
        ],
      ],
    );
  }
}

enum _RoomAction { settings, leave, delete }

Future<bool?> _confirm(
  BuildContext context, {
  required String title,
  required String body,
  required String action,
}) {
  return showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: AppColors.paper,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.card),
        side: const BorderSide(color: AppColors.ink, width: AppBlock.border),
      ),
      title: Text(title, style: AppTextStyles.heading),
      content: Text(body, style: AppTextStyles.bodyS),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('그대로 두기'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(action),
        ),
      ],
    ),
  );
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
