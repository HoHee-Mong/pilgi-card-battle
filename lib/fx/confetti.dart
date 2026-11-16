import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../core/theme/tokens.dart';
import 'motion.dart';

/// 결과 화면 색종이 낙하 (DESIGN.md 결과 모션). 한 번 떨어지고 끝난다.
/// 누르기를 막지 않도록 위에 겹쳐 둔다.
class ConfettiRain extends StatefulWidget {
  const ConfettiRain({super.key, this.count = 40});

  final int count;

  @override
  State<ConfettiRain> createState() => _ConfettiRainState();
}

class _ConfettiRainState extends State<ConfettiRain>
    with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: AppMotion.confetti)
    ..forward();

  // 매번 같은 모양이 나오도록 고정 시드
  late final _pieces = _makePieces(widget.count, math.Random(7));

  static const _colors = [
    AppColors.pink,
    AppColors.grape,
    AppColors.lime,
    AppColors.cyan,
    AppColors.paper,
  ];

  static List<_Piece> _makePieces(int n, math.Random r) => [
    for (var i = 0; i < n; i++)
      _Piece(
        x: r.nextDouble(),
        delay: r.nextDouble() * 0.35,
        speed: 0.8 + r.nextDouble() * 0.6,
        sway: (r.nextDouble() - 0.5) * 0.12,
        spin: (r.nextDouble() - 0.5) * 8,
        color: _colors[i % _colors.length],
        round: i % 3 == 0,
      ),
  ];

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (motionReduced(context)) return const SizedBox.shrink();
    return IgnorePointer(
      child: RepaintBoundary(
        child: AnimatedBuilder(
          animation: _c,
          builder: (context, _) => CustomPaint(
            size: Size.infinite,
            painter: _ConfettiPainter(_pieces, _c.value),
          ),
        ),
      ),
    );
  }
}

class _Piece {
  const _Piece({
    required this.x,
    required this.delay,
    required this.speed,
    required this.sway,
    required this.spin,
    required this.color,
    required this.round,
  });

  final double x, delay, speed, sway, spin;
  final Color color;
  final bool round;
}

class _ConfettiPainter extends CustomPainter {
  const _ConfettiPainter(this.pieces, this.t);

  final List<_Piece> pieces;
  final double t;

  static const _w = 10.0, _h = 16.0;

  @override
  void paint(Canvas canvas, Size size) {
    if (t >= 1) return;
    final border = Paint()
      ..color = AppColors.ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    for (final p in pieces) {
      final local = ((t - p.delay) / (1 - p.delay)).clamp(0.0, 1.0);
      if (local <= 0) continue;
      final y = -_h + local * p.speed * (size.height + _h * 2);
      if (y > size.height + _h) continue;
      final x =
          p.x * size.width +
          math.sin(local * math.pi * 3) * p.sway * size.width;
      final fill = Paint()..color = p.color.withValues(alpha: 1 - local * 0.4);
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(local * p.spin);
      if (p.round) {
        canvas.drawCircle(Offset.zero, _w / 2, fill);
        canvas.drawCircle(Offset.zero, _w / 2, border);
      } else {
        final r = RRect.fromRectAndRadius(
          const Rect.fromLTWH(-_w / 2, -_h / 2, _w, _h),
          const Radius.circular(3),
        );
        canvas.drawRRect(r, fill);
        canvas.drawRRect(r, border);
      }
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter old) => old.t != t;
}
