import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/tokens.dart';
import '../core/widgets/chunky_button.dart';
import 'game_settings.dart';
import 'sound.dart';

/// 게임 설정: 효과음, 진동, 애니메이션 줄이기 (로비 톱니 버튼)
Future<void> showGameSettingsSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (ctx) => SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.page,
        AppSpacing.section,
        AppSpacing.page,
        AppSpacing.section * 2,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('게임 설정', style: AppTextStyles.titleM),
          const SizedBox(height: AppSpacing.sm),
          const _Settings(),
          const SizedBox(height: AppSpacing.section),
          ChunkyButton(
            label: '닫기',
            color: AppColors.paper,
            onPressed: () => Navigator.of(ctx).pop(),
          ),
        ],
      ),
    ),
  );
}

class _Settings extends ConsumerWidget {
  const _Settings();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sound = ref.watch(soundOnProvider);
    final haptics = ref.watch(hapticsOnProvider);
    final reduce = ref.watch(reduceMotionProvider);
    return Column(
      children: [
        _Row(
          icon: Icons.volume_up_rounded,
          title: '효과음',
          subtitle: '정답·오답·카운트다운 소리',
          value: sound,
          onChanged: (_) async {
            await ref.read(soundOnProvider.notifier).toggle();
            if (!sound) Sound.play(Sfx.vote); // 켰을 때 들려주기
          },
        ),
        _Row(
          icon: Icons.vibration_rounded,
          title: '진동',
          subtitle: '투표·정답·오답 때 짧은 진동',
          value: haptics,
          onChanged: (v) => ref.read(hapticsOnProvider.notifier).set(v),
        ),
        _Row(
          icon: Icons.motion_photos_off_rounded,
          title: '애니메이션 줄이기',
          subtitle: '보스 둥둥, 카드 뒤집기, 색종이 같은 움직임을 멈춰요',
          value: reduce,
          onChanged: (v) => ref.read(reduceMotionProvider.notifier).set(v),
        ),
      ],
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      secondary: Icon(icon, color: AppColors.ink),
      title: Text(title, style: AppTextStyles.heading),
      subtitle: Text(subtitle, style: AppTextStyles.caption),
      value: value,
      activeThumbColor: AppColors.grape,
      onChanged: onChanged,
    );
  }
}
