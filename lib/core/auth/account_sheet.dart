import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../theme/tokens.dart';
import '../widgets/chunky_button.dart';
import 'auth_providers.dart';
import 'auth_service.dart';
import 'user_profile.dart';

/// 내 계정: 이름 바꾸기, 지금 로그인 방식, Google 로그인(게스트일 때), 로그아웃.
///
/// [onNicknameChanged]: 이름을 바꾼 뒤 할 일 (예: 내 방들의 이름표도 바꾸기).
Future<void> showAccountSheet(
  BuildContext context, {
  Future<void> Function(String uid, String nickname)? onNicknameChanged,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (ctx) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.page,
          AppSpacing.section,
          AppSpacing.page,
          AppSpacing.section * 2,
        ),
        child: _AccountForm(onNicknameChanged: onNicknameChanged),
      ),
    ),
  );
}

/// 이름으로 쓸 수 있는지. 쓸 수 있으면 null, 아니면 이유.
String? nicknameProblem(String input) {
  final name = input.trim();
  if (name.isEmpty) return '이름을 써 주세요';
  if (name.characters.length > UserProfileRepository.maxNicknameLength) {
    return '${UserProfileRepository.maxNicknameLength}글자까지 쓸 수 있어요';
  }
  return null;
}

class _AccountForm extends ConsumerStatefulWidget {
  const _AccountForm({this.onNicknameChanged});

  final Future<void> Function(String uid, String nickname)? onNicknameChanged;

  @override
  ConsumerState<_AccountForm> createState() => _AccountFormState();
}

class _AccountFormState extends ConsumerState<_AccountForm> {
  final _name = TextEditingController();
  bool _busy = false;
  bool _nameLoaded = false;
  String? _error;
  String? _saved;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) setState(() => _error = AuthService.messageOf(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _saveName() async {
    final uid = ref.read(uidProvider);
    final problem = nicknameProblem(_name.text);
    if (uid == null || problem != null) {
      setState(() => _error = problem);
      return;
    }
    final name = _name.text.trim();
    setState(() {
      _busy = true;
      _error = null;
      _saved = null;
    });
    try {
      await ref.read(userProfileRepositoryProvider).setNickname(uid, name);
      await widget.onNicknameChanged?.call(uid, name);
      if (mounted) setState(() => _saved = '이름을 "$name"(으)로 바꿨어요');
    } catch (_) {
      if (mounted) setState(() => _error = '이름을 바꾸지 못했어요. 잠시 후 다시 해 주세요.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = authService;
    final google = auth.isGoogle;
    final email = auth.user?.email;
    final current = ref.watch(nicknameProvider).value;
    if (!_nameLoaded && current != null) {
      _nameLoaded = true;
      _name.text = current;
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('내 계정', style: AppTextStyles.titleM),
        const SizedBox(height: AppSpacing.section),
        const Text('친구들에게 보이는 이름', style: AppTextStyles.label),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _name,
                maxLength: UserProfileRepository.maxNicknameLength,
                textInputAction: TextInputAction.done,
                decoration: const InputDecoration(
                  hintText: '예) 선우',
                  counterText: '',
                ),
                onSubmitted: (_) => _saveName(),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            ChunkyButton(
              label: '바꾸기',
              expand: false,
              color: AppColors.sun,
              onPressed: _busy ? null : _saveName,
            ),
          ],
        ),
        if (_saved != null) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(
            _saved!,
            style: AppTextStyles.label.copyWith(color: AppColors.grape),
          ),
        ],
        const SizedBox(height: AppSpacing.section),
        Text(
          google
              ? 'Google 계정으로 로그인했어요${email == null ? '' : '\n$email'}'
              : '게스트로 쓰는 중이에요. Google로 로그인하면 지금 기록이 그대로 이어지고, '
                    '다른 기기에서도 볼 수 있어요.',
          style: AppTextStyles.bodyS,
        ),
        const SizedBox(height: AppSpacing.section),
        if (!google) ...[
          ChunkyButton(
            label: 'Google로 로그인',
            icon: Icons.login_rounded,
            color: AppColors.lime,
            loading: _busy,
            onPressed: _busy ? null : () => _run(auth.signInWithGoogle),
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
        ChunkyButton(
          label: '로그아웃',
          color: AppColors.paper,
          onPressed: _busy ? null : () => _run(auth.signOut),
        ),
        if (!google) ...[
          const SizedBox(height: AppSpacing.xs),
          const Text(
            '게스트로 로그아웃하면 지금 기록은 다시 볼 수 없어요',
            textAlign: TextAlign.center,
            style: AppTextStyles.caption,
          ),
        ],
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
