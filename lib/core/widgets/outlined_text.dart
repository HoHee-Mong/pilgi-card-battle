import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// ink 외곽선을 두른 큰 효과 글자. 예: "적중!", "D-12", 랭크 "S".
///
/// DESIGN.md: 큰 숫자·효과 글자는 Black Han Sans + ink 외곽선.
class OutlinedText extends StatelessWidget {
  const OutlinedText(
    this.text, {
    super.key,
    this.style = AppTextStyles.titleL,
    this.color = AppColors.lime,
    this.strokeColor = AppColors.ink,
    this.strokeWidth = AppBlock.border * 2,
  });

  final String text;
  final TextStyle style;
  final Color color;
  final Color strokeColor;

  /// 외곽선 두께 (글자 안쪽 절반은 채움 글자에 덮이므로 보이는 두께는 절반)
  final double strokeWidth;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Text(
          text,
          style: style.copyWith(
            foreground: Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = strokeWidth
              ..strokeJoin = StrokeJoin.round
              ..color = strokeColor,
          ),
        ),
        Text(text, style: style.copyWith(color: color)),
      ],
    );
  }
}
