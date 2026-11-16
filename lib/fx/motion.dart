import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../core/theme/tokens.dart';

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
