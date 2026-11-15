import 'package:flutter/widgets.dart';

import '../theme/tokens.dart';

/// 누르면 살짝 줄어들고, 손을 떼면 스프링으로 돌아오는 공용 래퍼.
///
/// 버튼·카드 등 눌리는 모든 요소에 쓴다. [onTap]이 null이면 반응하지 않는다.
class PressableScale extends StatefulWidget {
  const PressableScale({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.scale = AppMotion.pressScale,
    this.behavior = HitTestBehavior.opaque,
  });

  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  /// 눌렸을 때 크기 (기본 0.96)
  final double scale;
  final HitTestBehavior behavior;

  @override
  State<PressableScale> createState() => _PressableScaleState();
}

class _PressableScaleState extends State<PressableScale>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: AppMotion.press,
    reverseDuration: AppMotion.press,
  );

  late final Animation<double> _scale =
      Tween<double>(begin: 1, end: widget.scale).animate(
        CurvedAnimation(
          parent: _controller,
          curve: Curves.easeOut,
          // 손을 뗄 때(역방향)는 스프링처럼 살짝 넘쳤다가 돌아온다.
          reverseCurve: AppMotion.spring.flipped,
        ),
      );

  bool get _enabled => widget.onTap != null || widget.onLongPress != null;

  void _down(TapDownDetails _) {
    if (_enabled) _controller.forward();
  }

  void _up([Object? _]) {
    if (_enabled) _controller.reverse();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: widget.behavior,
      onTapDown: _down,
      onTapUp: _up,
      onTapCancel: _up,
      onTap: widget.onTap,
      onLongPress: widget.onLongPress,
      child: ScaleTransition(scale: _scale, child: widget.child),
    );
  }
}
