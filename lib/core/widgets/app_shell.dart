import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../fx/haptics.dart';
import '../theme/layout.dart';
import '../theme/tokens.dart';

/// 하단 탭 4개(로비 / 문제은행 / 모의고사 / 내 카드)를 단 앱 뼈대.
///
/// 시안: paper 바탕 + 위 ink 3px 선, 고른 탭은 pink 블록 알약.
class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.shell});

  final StatefulNavigationShell shell;

  static const tabs = ['로비', '문제은행', '모의고사', '내 카드'];

  void _go(int index) {
    if (index != shell.currentIndex) Haptics.selection();
    // 이미 고른 탭을 다시 누르면 그 탭의 첫 화면으로 돌아간다.
    shell.goBranch(index, initialLocation: index == shell.currentIndex);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: shell,
      bottomNavigationBar: AppTabBar(
        current: shell.currentIndex,
        labels: tabs,
        onTap: _go,
      ),
    );
  }
}

/// 하단 탭 막대 (겉모양만, 테스트에서도 쓴다)
class AppTabBar extends StatelessWidget {
  const AppTabBar({
    super.key,
    required this.current,
    required this.labels,
    required this.onTap,
  });

  final int current;
  final List<String> labels;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: AppColors.paper,
        border: Border(
          top: BorderSide(color: AppColors.ink, width: AppBlock.border),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          // 태블릿에서는 탭이 너무 벌어지지 않게 가운데로 모은다
          child: Center(
            heightFactor: 1,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: AppLayout.maxContent),
              child: Row(
                children: [
                  for (final (i, label) in labels.indexed)
                    Expanded(
                      child: _Tab(
                        label: label,
                        selected: i == current,
                        onTap: () => onTap(i),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Tab extends StatelessWidget {
  const _Tab({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: AnimatedContainer(
          duration: AppMotion.press,
          curve: Curves.easeOut,
          height: AppSpacing.button,
          margin: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? AppColors.pink : AppColors.paper,
            borderRadius: BorderRadius.circular(AppRadius.button),
            border: Border.all(
              color: selected ? AppColors.ink : AppColors.paper,
              width: AppBlock.border,
            ),
          ),
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.chip.copyWith(
              color: selected ? AppColors.ink : AppColors.inkSub,
            ),
          ),
        ),
      ),
    );
  }
}
