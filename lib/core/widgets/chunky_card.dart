import 'package:flutter/material.dart';

import '../theme/tokens.dart';
import 'chunky_press.dart';

/// 앱 공용 블록 카드. 3px ink 테두리 + 아래 6px 딱딱한 그림자, 라운드 26.
///
/// - [color] 기본 paper. 로비의 방·모의고사 카드처럼 lime·cyan·pink 면도 토큰 값으로 준다.
/// - [title]을 주면 위에 제목 줄(오른쪽 [trailing] 포함)을 붙인다.
/// - [onTap]을 주면 누를 때 버튼처럼 4px 내려간다.
class ChunkyCard extends StatelessWidget {
  const ChunkyCard({
    super.key,
    required this.child,
    this.title,
    this.trailing,
    this.onTap,
    this.onLongPress,
    this.color = AppColors.paper,
    this.shadowColor = AppColors.ink,
    this.padding = const EdgeInsets.all(AppSpacing.page),
    this.radius = AppRadius.card,
  });

  final Widget child;
  final String? title;
  final Widget? trailing;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final Color color;
  final Color shadowColor;
  final EdgeInsetsGeometry padding;

  /// 기본 26. 목록 한 줄짜리 작은 카드는 [AppRadius.button] 등
  final double radius;

  @override
  Widget build(BuildContext context) {
    final fg = onChunkyColor(color);

    final body = title == null && trailing == null
        ? child
        : Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  if (title != null)
                    Expanded(
                      child: Text(
                        title!,
                        style: AppTextStyles.heading.copyWith(color: fg),
                      ),
                    )
                  else
                    const Spacer(),
                  ?trailing,
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              child,
            ],
          );

    return ChunkyPress(
      onTap: onTap,
      onLongPress: onLongPress,
      color: color,
      shadowColor: shadowColor,
      radius: radius,
      width: double.infinity,
      padding: padding,
      child: DefaultTextStyle.merge(
        style: TextStyle(color: fg),
        child: body,
      ),
    );
  }
}
