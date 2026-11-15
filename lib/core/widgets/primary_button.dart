import 'package:flutter/material.dart';

import '../theme/tokens.dart';
import 'pressable_scale.dart';

/// 버튼 색 조합. 포인트 색은 blue·lime 두 개뿐이다 (`docs/DESIGN.md`).
enum ButtonTone {
  /// 기본 주요 버튼: ink 바탕 + 흰 글자
  ink,

  /// 볼펜 파랑: 주요 동작·내 정보
  blue,

  /// 형광펜: 강조·정답 (글자는 항상 ink)
  lime,

  /// 보조 버튼: 흰 바탕 + 회색 테두리
  plain,
}

/// 앱 공용 버튼. 누르면 [PressableScale]로 살짝 줄어든다.
///
/// [onPressed]가 null이면 비활성, [loading]이 true면 스피너를 보이고 누를 수 없다.
class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.tone = ButtonTone.ink,
    this.icon,
    this.expand = true,
    this.loading = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final ButtonTone tone;
  final IconData? icon;

  /// true면 가로를 꽉 채운다
  final bool expand;
  final bool loading;

  static const _height = 56.0;

  bool get _enabled => onPressed != null && !loading;

  (Color bg, Color fg, Color? border) _colors() {
    if (!_enabled && !loading) {
      return (AppColors.line, AppColors.inkSub, null);
    }
    return switch (tone) {
      ButtonTone.ink => (AppColors.ink, AppColors.surface, null),
      ButtonTone.blue => (AppColors.blue, AppColors.surface, null),
      ButtonTone.lime => (AppColors.lime, AppColors.ink, null),
      ButtonTone.plain => (AppColors.surface, AppColors.ink, AppColors.line),
    };
  }

  @override
  Widget build(BuildContext context) {
    final (bg, fg, border) = _colors();

    final content = loading
        ? SizedBox.square(
            dimension: 20,
            child: CircularProgressIndicator(strokeWidth: 2.2, color: fg),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 20, color: fg),
                const SizedBox(width: AppSpacing.sm),
              ],
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.button.copyWith(color: fg),
                ),
              ),
            ],
          );

    return Semantics(
      button: true,
      enabled: _enabled,
      label: label,
      excludeSemantics: true,
      child: PressableScale(
        onTap: _enabled ? onPressed : null,
        child: AnimatedContainer(
          duration: AppMotion.press,
          height: _height,
          width: expand ? double.infinity : null,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.page),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(AppRadius.button),
            border: border == null ? null : Border.all(color: border),
          ),
          child: content,
        ),
      ),
    );
  }
}
