import 'package:flutter/material.dart';

import '../theme/tokens.dart';
import '../widgets/chunky_button.dart';
import 'auth_service.dart';

/// 내 계정: 지금 로그인 방식, Google 로그인(게스트일 때), 로그아웃.
Future<void> showAccountSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    useSafeArea: true,
    builder: (_) => const Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.page,
        AppSpacing.section,
        AppSpacing.page,
        AppSpacing.section * 2,
      ),
      child: _AccountForm(),
    ),
  );
}

class _AccountForm extends StatefulWidget {
  const _AccountForm();

  @override
  State<_AccountForm> createState() => _AccountFormState();
}

class _AccountFormState extends State<_AccountForm> {
  bool _busy = false;
  String? _error;

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

  @override
  Widget build(BuildContext context) {
    final auth = authService;
    final google = auth.isGoogle;
    final email = auth.user?.email;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('내 계정', style: AppTextStyles.titleM),
        const SizedBox(height: AppSpacing.sm),
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
