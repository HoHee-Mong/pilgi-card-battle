import 'package:flutter/material.dart';

import '../theme/tokens.dart';
import 'chunky_press.dart';

/// 작은 상태 알약. 예: "벼락치기방 · 4명"(lime), "5일 연속"(sun), "이번 보스"(pink).
///
/// 3px ink 테두리, 그림자 없음. 글자는 Black Han Sans.
class StatChip extends StatelessWidget {
  const StatChip({
    super.key,
    required this.label,
    this.icon,
    this.color = AppColors.lime,
    this.border = true,
  });

  final String label;
  final IconData? icon;
  final Color color;

  /// false면 테두리 없이 면만 (카드 안 작은 태그용)
  final bool border;

  @override
  Widget build(BuildContext context) {
    final fg = onChunkyColor(color);
    return Container(
      constraints: const BoxConstraints(minHeight: 32),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: border
            ? Border.all(color: AppColors.ink, width: AppBlock.border)
            : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 18, color: fg),
            const SizedBox(width: AppSpacing.xs),
          ],
          // Flexible: 부모 폭이 좁으면 글자가 넘치지 않고 "…"로 줄어든다.
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.chip.copyWith(color: fg),
            ),
          ),
        ],
      ),
    );
  }
}
