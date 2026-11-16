import 'package:flutter/material.dart';

import '../../core/theme/tokens.dart';
import '../../core/widgets/chunky_button.dart';

/// A 화면 공용 상단바 — 시안(game-bank.png)처럼 네모 블록 뒤로가기 + 오른쪽 상태 알약.
///
/// 제목은 상단바에 넣지 않고 본문 첫 줄에 `AppTextStyles.titleL`로 크게 쓴다.
/// [trailing]에는 보통 `StatChip`이나 아이콘 블록 버튼이 온다.
class ArcadeAppBar extends StatelessWidget implements PreferredSizeWidget {
  const ArcadeAppBar({
    super.key,
    this.trailing = const [],
    this.showBack = true,
    this.backgroundColor,
  });

  final List<Widget> trailing;
  final bool showBack;

  /// 비우면 테마의 scaffold 배경(cream)
  final Color? backgroundColor;

  /// 버튼 56 + 그림자 6 + 위아래 여백. Scaffold는 여기에 상태바 높이를 더해 준다.
  static const _height = 84.0;

  @override
  Size get preferredSize => const Size.fromHeight(_height);

  @override
  Widget build(BuildContext context) {
    final canPop = showBack && Navigator.of(context).canPop();
    final top = MediaQuery.paddingOf(context).top;
    // 내용이 비어도 같은 높이를 차지하게 높이를 못 박는다 (제목 위치가 화면마다 흔들리지 않게).
    return Container(
      height: top + _height,
      color: backgroundColor ?? Theme.of(context).scaffoldBackgroundColor,
      padding: EdgeInsets.fromLTRB(
        AppSpacing.page,
        top + AppSpacing.sm,
        AppSpacing.page,
        AppSpacing.section,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (canPop)
            ArcadeIconButton(
              icon: Icons.chevron_left,
              onPressed: () => Navigator.of(context).maybePop(),
              semanticLabel: '뒤로',
            ),
          const Spacer(),
          for (final w in trailing) ...[
            w,
            const SizedBox(width: AppSpacing.sm),
          ],
        ],
      ),
    );
  }
}

/// 네모 블록 아이콘 버튼 (뒤로, 닫기, 더보기 등). 56×56, paper 면.
class ArcadeIconButton extends StatelessWidget {
  const ArcadeIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    required this.semanticLabel,
    this.color = AppColors.paper,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final String semanticLabel;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return ChunkyButton(
      expand: false,
      color: color,
      semanticLabel: semanticLabel,
      onPressed: onPressed,
      child: Icon(icon, size: 26),
    );
  }
}

/// 화면 맨 위 큰 제목 + 한 줄 설명 (시안 "예상 문제 랭킹 / 우리가 '나올 것 같다'고 고른 문제들").
class ArcadeTitle extends StatelessWidget {
  const ArcadeTitle({
    super.key,
    required this.title,
    this.subtitle,
    this.color = AppColors.ink,
  });

  final String title;
  final String? subtitle;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: AppTextStyles.titleL.copyWith(color: color)),
        if (subtitle != null) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(
            subtitle!,
            style: AppTextStyles.body.copyWith(
              color: color == AppColors.ink ? AppColors.inkSub : color,
            ),
          ),
        ],
      ],
    );
  }
}

/// 섹션 소제목 (카드 목록 위 "자료", "카드" 등). 오른쪽에 작은 동작을 붙일 수 있다.
class ArcadeSectionHeader extends StatelessWidget {
  const ArcadeSectionHeader({super.key, required this.title, this.trailing});

  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Text(title, style: AppTextStyles.heading)),
        ?trailing,
      ],
    );
  }
}

/// 비어 있을 때 안내 상자. 본문 + (선택) 버튼.
class ArcadeEmpty extends StatelessWidget {
  const ArcadeEmpty({
    super.key,
    required this.message,
    this.actionLabel,
    this.actionIcon,
    this.onAction,
  });

  final String message;
  final String? actionLabel;
  final IconData? actionIcon;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.page),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppColors.line, width: AppBlock.border),
      ),
      child: Column(
        children: [
          Text(
            message,
            textAlign: TextAlign.center,
            style: AppTextStyles.body.copyWith(color: AppColors.inkSub),
          ),
          if (actionLabel != null) ...[
            const SizedBox(height: AppSpacing.lg),
            ChunkyButton(
              label: actionLabel,
              icon: actionIcon,
              expand: false,
              onPressed: onAction,
            ),
          ],
        ],
      ),
    );
  }
}
