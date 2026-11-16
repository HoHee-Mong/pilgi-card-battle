import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../theme/tokens.dart';
import 'outlined_text.dart';

/// 결과 랭크 도장 (시안 game-result.png): grape 블록 + 큰 글자, 뒤에 pink 별이 천천히 돈다.
/// 처음 나타날 때 크게 → 작게 "쾅".
///
/// 랭크 글자는 `resultRank(percent)`(S/A/B/C)로 정한다. A의 모의고사 결과에서도 그대로 쓰면 된다.
class RankStamp extends StatelessWidget {
  const RankStamp({super.key, required this.rank, this.size = 160});

  final String rank;

  /// 블록 한 변 길이 (별은 이보다 크게 뒤에 깔림)
  final double size;

  @override
  Widget build(BuildContext context) {
    final starSize = size * 1.5;
    return Semantics(
      label: '랭크 $rank',
      excludeSemantics: true,
      child: SizedBox(
        width: starSize,
        height: starSize,
        child: Stack(
          alignment: Alignment.center,
          children: [
            CustomPaint(
                  size: Size.square(starSize),
                  painter: const _StarPainter(),
                )
                .animate(onPlay: (c) => c.repeat())
                .rotate(duration: AppMotion.starSpin),
            Container(
                  width: size,
                  height: size,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.grape,
                    borderRadius: BorderRadius.circular(AppRadius.card * 1.4),
                    border: Border.all(
                      color: AppColors.ink,
                      width: AppBlock.border * 1.5,
                    ),
                    boxShadow: const [
                      BoxShadow(
                        color: AppColors.ink,
                        offset: Offset(0, AppBlock.shadow * 1.5),
                      ),
                    ],
                  ),
                  child: OutlinedText(
                    rank,
                    style: AppTextStyles.titleL.copyWith(fontSize: size * 0.6),
                    color: AppColors.paper,
                    strokeWidth: AppBlock.border * 3,
                  ),
                )
                .animate()
                .scaleXY(
                  begin: 2.2,
                  end: 1,
                  duration: AppMotion.stamp,
                  curve: AppMotion.spring,
                )
                .fadeIn(duration: AppMotion.press),
          ],
        ),
      ),
    );
  }
}

/// 뾰족한 별 (pink 면 + ink 테두리)
class _StarPainter extends CustomPainter {
  const _StarPainter();

  static const _points = 8;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final outer = size.width / 2;
    final inner = outer * 0.62;
    final path = Path();
    for (var i = 0; i < _points * 2; i++) {
      final r = i.isEven ? outer : inner;
      final a = -math.pi / 2 + i * math.pi / _points;
      final p = c + Offset(math.cos(a) * r, math.sin(a) * r);
      i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
    }
    path.close();
    canvas.drawPath(path, Paint()..color = AppColors.pink);
    canvas.drawPath(
      path,
      Paint()
        ..color = AppColors.ink
        ..style = PaintingStyle.stroke
        ..strokeWidth = AppBlock.border
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(_StarPainter oldDelegate) => false;
}
