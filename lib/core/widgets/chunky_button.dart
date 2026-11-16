import 'package:flutter/material.dart';

import '../theme/tokens.dart';
import 'chunky_press.dart';

/// 앱 공용 블록 버튼. 3px 테두리 + 아래 6px 딱딱한 그림자, 누르면 4px 내려간다.
///
/// - [label] 또는 [child] 중 하나를 준다. 아이콘만 있는 네모 버튼은 `child: Icon(...)`, `expand: false`.
/// - [color] 기본 pink. 글자색은 배경에 맞춰 자동(밝은 색 위 ink, grape 위 paper, ink 위 lime).
/// - [onPressed]가 null이면 비활성(흐리게), [loading]이면 스피너를 보이고 누를 수 없다.
///
/// ```dart
/// ChunkyButton(label: '필기 찍고 카드 뽑기', icon: Icons.photo_camera_outlined, large: true, onPressed: ...)
/// ChunkyButton(label: '이 순서로 모의고사', color: AppColors.ink, shadowColor: AppColors.grape, onPressed: ...)
/// ```
class ChunkyButton extends StatelessWidget {
  const ChunkyButton({
    super.key,
    this.label,
    this.child,
    required this.onPressed,
    this.icon,
    this.color = AppColors.pink,
    this.textColor,
    this.shadowColor = AppColors.ink,
    this.expand = true,
    this.large = false,
    this.loading = false,
    this.semanticLabel,
  }) : assert(label != null || child != null, 'label 또는 child가 필요하다');

  final String? label;
  final Widget? child;
  final VoidCallback? onPressed;
  final IconData? icon;
  final Color color;

  /// 비우면 [color]에 맞춰 자동
  final Color? textColor;
  final Color shadowColor;

  /// true면 가로를 꽉 채운다
  final bool expand;

  /// 화면의 대표 버튼 (높이 72, 큰 글자)
  final bool large;
  final bool loading;

  /// 아이콘만 있는 버튼의 읽기 이름
  final String? semanticLabel;

  bool get _enabled => onPressed != null && !loading;

  @override
  Widget build(BuildContext context) {
    final fg = textColor ?? onChunkyColor(color);
    final textStyle = (large ? AppTextStyles.buttonL : AppTextStyles.button)
        .copyWith(color: fg);
    final iconSize = large ? 28.0 : 22.0;
    // 글자를 크게 해 둔 기기에서는 버튼도 그만큼 높게 (글자가 잘리지 않게)
    final base = textStyle.fontSize ?? 16;
    final grow = MediaQuery.textScalerOf(context).scale(base) / base;
    final height =
        (large ? AppSpacing.buttonLarge : AppSpacing.button) *
        (grow < 1 ? 1 : grow);

    final Widget content;
    if (loading) {
      content = SizedBox.square(
        dimension: 22,
        child: CircularProgressIndicator(strokeWidth: 3, color: fg),
      );
    } else if (child != null) {
      content = IconTheme.merge(
        data: IconThemeData(color: fg, size: iconSize),
        child: DefaultTextStyle.merge(style: textStyle, child: child!),
      );
    } else {
      content = Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (icon != null) ...[
            Icon(icon, size: iconSize, color: fg),
            const SizedBox(width: AppSpacing.sm),
          ],
          Flexible(
            child: Text(
              label!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: textStyle,
            ),
          ),
        ],
      );
    }

    return Semantics(
      button: true,
      enabled: _enabled,
      label: label ?? semanticLabel,
      excludeSemantics: label != null || semanticLabel != null,
      child: AnimatedOpacity(
        duration: AppMotion.press,
        opacity: _enabled || loading ? 1 : 0.45,
        child: ChunkyPress(
          onTap: _enabled ? onPressed : null,
          color: color,
          shadowColor: shadowColor,
          radius: AppRadius.button,
          height: height,
          width: expand ? double.infinity : null,
          minWidth: height,
          padding: EdgeInsets.symmetric(
            horizontal: child != null && label == null
                ? AppSpacing.sm
                : AppSpacing.page,
          ),
          // expand가 아닐 때 alignment를 주면 부모 너비만큼 늘어나므로 비운다
          alignment: expand ? Alignment.center : null,
          child: content,
        ),
      ),
    );
  }
}
