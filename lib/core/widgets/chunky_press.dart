import 'package:flutter/widgets.dart';

import '../theme/tokens.dart';

/// 블록(Chunky) 상자: 굵은 ink 테두리 + 아래로 딱딱한 그림자(blur 0).
///
/// [onTap]이 있으면 누를 때 [AppBlock.pressDepth]만큼 내려가고 그림자가 줄어든다.
/// 그림자 높이만큼 아래 여백을 차지하므로, 눌려도 주변 레이아웃이 움직이지 않는다.
/// [ChunkyButton]·[ChunkyCard]가 공통으로 쓴다.
class ChunkyPress extends StatefulWidget {
  const ChunkyPress({
    super.key,
    required this.child,
    required this.color,
    required this.radius,
    this.onTap,
    this.onLongPress,
    this.shadowColor = AppColors.ink,
    this.padding = EdgeInsets.zero,
    this.width,
    this.height,
    this.alignment,
    this.minWidth,
  });

  final Widget child;
  final Color color;
  final double radius;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  /// 그림자 색. 기본 ink, 어두운 버튼은 grape 등
  final Color shadowColor;
  final EdgeInsetsGeometry padding;
  final double? width;
  final double? height;
  final AlignmentGeometry? alignment;

  /// 내용이 짧아도 이 너비보다 좁아지지 않는다 (아이콘 버튼이 정사각형이 되게)
  final double? minWidth;

  @override
  State<ChunkyPress> createState() => _ChunkyPressState();
}

class _ChunkyPressState extends State<ChunkyPress> {
  bool _pressed = false;

  bool get _enabled => widget.onTap != null || widget.onLongPress != null;

  void _set(bool v) {
    if (_enabled && _pressed != v) setState(() => _pressed = v);
  }

  @override
  Widget build(BuildContext context) {
    final depth = _pressed ? AppBlock.pressDepth : 0.0;
    final shadow = _pressed ? AppBlock.shadowPressed : AppBlock.shadow;

    final box = AnimatedContainer(
      duration: AppMotion.press,
      curve: Curves.easeOut,
      width: widget.width,
      height: widget.height,
      alignment: widget.alignment,
      constraints: widget.minWidth == null
          ? null
          : BoxConstraints(minWidth: widget.minWidth!),
      padding: widget.padding,
      transform: Matrix4.translationValues(0, depth, 0),
      decoration: BoxDecoration(
        color: widget.color,
        borderRadius: BorderRadius.circular(widget.radius),
        border: Border.all(color: AppColors.ink, width: AppBlock.border),
        boxShadow: [
          BoxShadow(
            color: widget.shadowColor,
            offset: Offset(0, shadow),
            blurRadius: 0,
          ),
        ],
      ),
      child: widget.child,
    );

    final spaced = Padding(
      padding: const EdgeInsets.only(bottom: AppBlock.shadow),
      child: box,
    );

    if (!_enabled) return spaced;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _set(true),
      onTapUp: (_) => _set(false),
      onTapCancel: () => _set(false),
      onTap: widget.onTap,
      onLongPress: widget.onLongPress,
      child: spaced,
    );
  }
}

/// 배경색 위에 올릴 글자색. 밝은 색(pink·lime·sun·cyan·paper 등) 위는 항상 ink.
Color onChunkyColor(Color bg) {
  if (bg == AppColors.grape) return AppColors.paper;
  if (bg == AppColors.ink) return AppColors.lime;
  return AppColors.ink;
}
