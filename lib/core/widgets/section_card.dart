import 'package:flutter/material.dart';

import '../theme/tokens.dart';
import 'pressable_scale.dart';

/// 흰 면 + 라운드 24의 기본 카드. 그림자·왼쪽 컬러 테두리 없음.
///
/// [title]을 주면 위에 제목 줄(오른쪽 [trailing] 포함)을 붙인다.
/// [onTap]을 주면 눌림 모션이 생긴다.
class SectionCard extends StatelessWidget {
  const SectionCard({
    super.key,
    required this.child,
    this.title,
    this.trailing,
    this.onTap,
    this.padding = const EdgeInsets.all(AppSpacing.page),
    this.color = AppColors.surface,
  });

  final Widget child;
  final String? title;
  final Widget? trailing;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;

  /// 기본은 surface. 몰입 화면에서는 [AppColors.dark] 등 토큰 값만 넘긴다.
  final Color color;

  @override
  Widget build(BuildContext context) {
    final body = Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      child: title == null && trailing == null
          ? child
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    if (title != null)
                      Expanded(
                        child: Text(title!, style: AppTextStyles.heading),
                      )
                    else
                      const Spacer(),
                    ?trailing,
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                child,
              ],
            ),
    );

    if (onTap == null) return body;
    return PressableScale(onTap: onTap, child: body);
  }
}
