import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../core/theme/tokens.dart';

/// 애니메이션을 줄여야 하는지: 앱 설정 "애니메이션 줄이기" 또는 기기의 "동작 줄이기".
/// (앱 설정은 `AppShell`이 MediaQuery.disableAnimations로 내려 준다)
bool motionReduced(BuildContext context) =>
    MediaQuery.maybeDisableAnimationsOf(context) ?? false;

extension AnimateOrStill on Widget {
  /// `.animate()`와 같지만, 애니메이션 줄이기면 움직이지 않고 끝난 모습으로 바로 보여 준다.
  Animate animateOrStill(
    BuildContext context, {
    Key? key,
    AnimateCallback? onPlay,
  }) {
    final still = motionReduced(context);
    return animate(
      key: key,
      autoPlay: !still,
      value: still ? 1 : null,
      onPlay: still ? null : onPlay,
    );
  }
}

/// 카드 뒤집기 등장: Y축으로 90도 누운 상태에서 앞면으로 돌아온다 (원근감 0.001).
/// [key]가 바뀔 때마다 다시 뒤집힌다 (예: 문제가 바뀔 때).
class FlipIn extends StatefulWidget {
  const FlipIn({super.key, required this.child});
  final Widget child;

  @override
  State<FlipIn> createState() => _FlipInState();
}

class _FlipInState extends State<FlipIn> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: AppMotion.cardFlip)
    ..forward();

  late final _t = CurvedAnimation(parent: _c, curve: AppMotion.spring);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (motionReduced(context)) return widget.child;
    return AnimatedBuilder(
      animation: _t,
      builder: (context, child) => Transform(
        alignment: Alignment.center,
        transform: Matrix4.identity()
          ..setEntry(3, 2, AppMotion.perspective)
          ..rotateY((1 - _t.value) * math.pi / 2),
        child: child,
      ),
      child: widget.child,
    );
  }
}

/// [trigger]가 바뀔 때마다 좌우로 두 번 흔든다 (오답).
class Shake extends StatefulWidget {
  const Shake({super.key, required this.trigger, required this.child});

  /// 값이 바뀌면 흔든다 (0이면 처음엔 가만히)
  final int trigger;
  final Widget child;

  @override
  State<Shake> createState() => _ShakeState();
}

class _ShakeState extends State<Shake> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: AppMotion.shake);

  @override
  void didUpdateWidget(Shake old) {
    super.didUpdateWidget(old);
    if (old.trigger != widget.trigger) _c.forward(from: 0);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (motionReduced(context)) return widget.child;
    return AnimatedBuilder(
      animation: _c,
      builder: (context, child) {
        final t = _c.value;
        // 두 번 왕복, 갈수록 작아짐
        final dx =
            math.sin(t * math.pi * 4) * AppMotion.shakeDistance * (1 - t);
        return Transform.translate(offset: Offset(dx, 0), child: child);
      },
      child: widget.child,
    );
  }
}
