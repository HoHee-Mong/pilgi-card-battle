import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../theme/tokens.dart';
import '../widgets/chunky_button.dart';
import 'account_sheet.dart';
import 'auth_providers.dart';
import 'user_profile.dart';

/// Google 로그인 뒤 한 번: 친구들에게 보일 이름 정하기 (변경 횟수에 안 들어감).
/// 닫을 수 없고, 정해야 넘어간다.
Future<void> showNicknameSetupSheet(
  BuildContext context, {
  required String suggested,
  Future<void> Function(String uid, String nickname)? onSaved,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    isDismissible: false,
    enableDrag: false,
    useSafeArea: true,
    builder: (ctx) => PopScope(
      canPop: false,
      child: Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.page,
            AppSpacing.section,
            AppSpacing.page,
            AppSpacing.section * 2,
          ),
          child: _SetupForm(suggested: suggested, onSaved: onSaved),
        ),
      ),
    ),
  );
}

class _SetupForm extends ConsumerStatefulWidget {
  const _SetupForm({required this.suggested, this.onSaved});

  final String suggested;
  final Future<void> Function(String uid, String nickname)? onSaved;

  @override
  ConsumerState<_SetupForm> createState() => _SetupFormState();
}

class _SetupFormState extends ConsumerState<_SetupForm> {
  late final _name = TextEditingController(
    text: widget.suggested.characters
        .take(UserProfileRepository.maxNicknameLength)
        .toString(),
  );
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
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
    });
    try {
      await ref
          .read(userProfileRepositoryProvider)
          .setInitialNickname(uid, name);
      await widget.onSaved?.call(uid, name);
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      if (mounted) setState(() => _error = '저장하지 못했어요. 다시 눌러 주세요.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('이름 정하기', style: AppTextStyles.titleM),
        const SizedBox(height: AppSpacing.sm),
        const Text(
          '배틀·투표에서 친구들에게 보일 이름이에요. '
          '나중에 $kMaxNicknameChanges번까지 바꿀 수 있어요.',
          style: AppTextStyles.bodyS,
        ),
        const SizedBox(height: AppSpacing.section),
        TextField(
          controller: _name,
          autofocus: true,
          maxLength: UserProfileRepository.maxNicknameLength,
          textInputAction: TextInputAction.done,
          decoration: const InputDecoration(hintText: '예) 선우'),
          onSubmitted: (_) => _save(),
        ),
        if (_error != null) ...[
          Text(
            _error!,
            style: AppTextStyles.label.copyWith(color: AppColors.pink),
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
        ChunkyButton(
          label: '이 이름으로 시작',
          color: AppColors.lime,
          loading: _busy,
          onPressed: _busy ? null : _save,
        ),
      ],
    );
  }
}
