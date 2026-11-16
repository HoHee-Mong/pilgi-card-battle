import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../fx/haptics.dart';
import '../../fx/motion.dart';
import '../../fx/sound.dart';
import '../theme/tokens.dart';
import 'outlined_text.dart';

/// [BossSprite]를 움직이는 리모컨. 화면에서 하나 만들어 넘기고, 정답·오답 때 부른다.
///
/// ```dart
/// final boss = BossController();          // State 필드로 두고 dispose()에서 정리
/// BossSprite(hp: left, maxHp: total, controller: boss)
/// boss.hit();   // 정답: 보스 흔들림·축소 + "적중!" + 가벼운 진동
/// boss.miss();  // 오답: 보스 깡충 + "빗나감" + 묵직한 진동
/// ```
class BossController extends ChangeNotifier {
  BossReaction? _last;

  /// 마지막 반응 (테스트용)
  BossReaction? get last => _last;

  void hit() => _fire(BossReaction.hit);
  void miss() => _fire(BossReaction.miss);

  void _fire(BossReaction r) {
    _last = r;
    notifyListeners();
  }
}

enum BossReaction { hit, miss }

/// 시험지 보스 (시안 game-lobby / game-exam).
///
/// - 평소: 위아래로 둥둥 + 살짝 기울어짐 (2.4s 반복)
/// - 체력 비율에 따라 표정이 바뀐다: 절반 넘게 남음 = 이빨 드러낸 화남, 그 아래 = 찡그림, 0 = 격파(× 눈)
/// - [BossController.hit]: 흔들리며 작아졌다 돌아옴(600ms) + "적중!" 도장 쾅(500ms 스프링)
/// - [BossController.miss]: 깡충 뛰며 "빗나감"
/// - [onTap]을 주면 눌렀을 때 부른다 (로비에서 장난으로 때리기 등)
class BossSprite extends StatefulWidget {
  const BossSprite({
    super.key,
    required this.hp,
    required this.maxHp,
    this.controller,
    this.size = 180,
    this.onTap,
  });

  final int hp;
  final int maxHp;
  final BossController? controller;

  /// 보스 몸통 너비. 높이는 너비의 1.15배.
  final double size;
  final VoidCallback? onTap;

  @override
  State<BossSprite> createState() => _BossSpriteState();
}

class _BossSpriteState extends State<BossSprite> with TickerProviderStateMixin {
  late final _float = AnimationController(
    vsync: this,
    duration: AppMotion.bossFloat,
  )..repeat();

  late final _react = AnimationController(
    vsync: this,
    duration: AppMotion.bossHit,
  );

  late final _stamp = AnimationController(
    vsync: this,
    duration: AppMotion.stampShow,
  );

  BossReaction? _reaction;

  @override
  void initState() {
    super.initState();
    widget.controller?.addListener(_onReact);
  }

  @override
  void didUpdateWidget(BossSprite old) {
    super.didUpdateWidget(old);
    // 체력이 0이 되는 순간 격파음
    if (old.hp > 0 && widget.hp <= 0) Sound.play(Sfx.bossDown);
    if (old.controller != widget.controller) {
      old.controller?.removeListener(_onReact);
      widget.controller?.addListener(_onReact);
    }
  }

  void _onReact() {
    final r = widget.controller?.last;
    if (r == null) return;
    setState(() => _reaction = r);
    _react.forward(from: 0);
    _stamp.forward(from: 0);
    if (r == BossReaction.hit) {
      Haptics.light();
      Sound.play(Sfx.correct);
    } else {
      Haptics.medium();
      Sound.play(Sfx.wrong);
    }
  }

  @override
  void dispose() {
    widget.controller?.removeListener(_onReact);
    _float.dispose();
    _react.dispose();
    _stamp.dispose();
    super.dispose();
  }

  BossMood get _mood {
    if (widget.hp <= 0) return BossMood.defeated;
    final mostlyLeft = widget.maxHp <= 0 || widget.hp * 2 > widget.maxHp;
    return mostlyLeft ? BossMood.angry : BossMood.frown;
  }

  @override
  Widget build(BuildContext context) {
    final w = widget.size;
    final h = w * 1.15;
    final mood = _mood;

    final body = AnimatedBuilder(
      animation: Listenable.merge([_float, _react]),
      builder: (context, child) {
        // 둥둥: 한 바퀴(2.4s)에 위아래 한 번, 기울기는 반 박자 늦게 (격파되면 멈춤)
        final still = mood == BossMood.defeated || motionReduced(context);
        final phase = _float.value * math.pi * 2;
        var dy = still ? 0.0 : math.sin(phase) * AppMotion.bossFloatY;
        var angle = still
            ? 0.0
            : math.cos(phase) * AppMotion.bossFloatDeg * math.pi / 180;
        var scale = 1.0;
        var dx = 0.0;

        final t = _react.value;
        if (_react.isAnimating || (t > 0 && t < 1)) {
          final fade = 1 - t; // 갈수록 잦아든다
          if (_reaction == BossReaction.hit) {
            dx = math.sin(t * math.pi * 8) * w * 0.06 * fade;
            scale = 1 - 0.14 * math.sin(t * math.pi);
          } else {
            dy -= math.sin(t * math.pi) * h * 0.12;
            angle += math.sin(t * math.pi * 4) * 0.08 * fade;
          }
        }

        return Transform.translate(
          offset: Offset(dx, dy),
          child: Transform.rotate(
            angle: angle,
            child: Transform.scale(scale: scale, child: child),
          ),
        );
      },
      child: CustomPaint(
        size: Size(w, h),
        painter: BossPainter(mood: mood),
      ),
    );

    final stampText = _reaction == BossReaction.miss ? '빗나감' : '적중!';
    final stampColor = _reaction == BossReaction.miss
        ? AppColors.wrong
        : AppColors.lime;

    return Semantics(
      label: '시험지 보스, 남은 체력 ${widget.hp} / ${widget.maxHp}',
      button: widget.onTap != null,
      child: GestureDetector(
        onTap: widget.onTap,
        behavior: HitTestBehavior.opaque,
        child: SizedBox(
          // 위아래로 떠다니는 폭만큼 여유를 둔다
          width: w,
          height: h + AppMotion.bossFloatY * 2,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              body,
              if (_reaction != null)
                Positioned(
                  left: w * 0.62,
                  top: 0,
                  child: AnimatedBuilder(
                    animation: _stamp,
                    builder: (context, child) {
                      final v = _stamp.value;
                      if (v == 0 || v == 1) return const SizedBox.shrink();
                      // 앞 40%: 크게 → 작게 도장 쾅, 끝 25%: 사라짐
                      final pop = (v / 0.4).clamp(0.0, 1.0);
                      final s = 2.2 - 1.2 * AppMotion.spring.transform(pop);
                      final o = v > 0.75 ? (1 - v) / 0.25 : 1.0;
                      return Opacity(
                        opacity: o.clamp(0.0, 1.0),
                        child: Transform.rotate(
                          angle: -0.12,
                          child: Transform.scale(scale: s, child: child),
                        ),
                      );
                    },
                    child: OutlinedText(
                      stampText,
                      style: AppTextStyles.titleL.copyWith(fontSize: w * 0.3),
                      color: stampColor,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 보스 표정
enum BossMood { angry, frown, defeated }

/// 시험지 보스 그림: 귀퉁이 접힌 종이 + 화난 눈썹 + 표정 + 볼 홍조.
class BossPainter extends CustomPainter {
  const BossPainter({required this.mood});

  final BossMood mood;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final stroke = w * 0.04;
    final fold = w * 0.2;
    final r = w * 0.06;

    final ink = Paint()
      ..color = AppColors.ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final inkFill = Paint()..color = AppColors.ink;

    // 몸통 (오른쪽 위 귀퉁이가 접힌 종이)
    final s = stroke / 2;
    final paper = Path()
      ..moveTo(s + r, s)
      ..lineTo(w - fold - s, s)
      ..lineTo(w - s, fold + s)
      ..lineTo(w - s, h - s - r)
      ..quadraticBezierTo(w - s, h - s, w - s - r, h - s)
      ..lineTo(s + r, h - s)
      ..quadraticBezierTo(s, h - s, s, h - s - r)
      ..lineTo(s, s + r)
      ..quadraticBezierTo(s, s, s + r, s)
      ..close();
    canvas.drawPath(paper, Paint()..color = AppColors.paper);
    canvas.drawPath(paper, ink);

    // 접힌 귀퉁이
    final ear = Path()
      ..moveTo(w - fold - s, s)
      ..lineTo(w - fold - s, fold + s)
      ..lineTo(w - s, fold + s)
      ..close();
    canvas.drawPath(ear, Paint()..color = AppColors.cream);
    canvas.drawPath(ear, ink);

    final eyeY = h * 0.42;
    final eyeL = Offset(w * 0.3, eyeY);
    final eyeR = Offset(w * 0.66, eyeY);
    final eyeR0 = w * 0.07;

    if (mood == BossMood.defeated) {
      // × 눈
      for (final c in [eyeL, eyeR]) {
        canvas.drawLine(
          c + Offset(-eyeR0, -eyeR0),
          c + Offset(eyeR0, eyeR0),
          ink,
        );
        canvas.drawLine(
          c + Offset(eyeR0, -eyeR0),
          c + Offset(-eyeR0, eyeR0),
          ink,
        );
      }
    } else {
      // 화난 눈썹 (가운데로 내려옴)
      canvas.drawLine(
        Offset(w * 0.18, h * 0.28),
        Offset(w * 0.38, h * 0.33),
        ink,
      );
      canvas.drawLine(
        Offset(w * 0.78, h * 0.28),
        Offset(w * 0.58, h * 0.33),
        ink,
      );
      // 눈 + 하이라이트
      for (final c in [eyeL, eyeR]) {
        canvas.drawCircle(c, eyeR0, inkFill);
        canvas.drawCircle(
          c + Offset(eyeR0 * 0.35, -eyeR0 * 0.35),
          eyeR0 * 0.32,
          Paint()..color = AppColors.paper,
        );
      }
    }

    // 입
    final mouthY = h * 0.62;
    switch (mood) {
      case BossMood.angry:
        // 이빨 드러낸 지그재그
        final teeth = Path()..moveTo(w * 0.28, mouthY);
        const n = 4;
        for (var i = 1; i <= n * 2; i++) {
          final x = w * 0.28 + (w * 0.4) * i / (n * 2);
          teeth.lineTo(x, mouthY + (i.isOdd ? h * 0.05 : 0));
        }
        canvas.drawPath(teeth, ink);
        canvas.drawLine(
          Offset(w * 0.24, mouthY + h * 0.02),
          Offset(w * 0.28, mouthY),
          ink,
        );
        canvas.drawLine(
          Offset(w * 0.68, mouthY),
          Offset(w * 0.72, mouthY + h * 0.02),
          ink,
        );
      case BossMood.frown:
        final frown = Path()
          ..moveTo(w * 0.3, mouthY + h * 0.04)
          ..quadraticBezierTo(
            w * 0.5,
            mouthY - h * 0.05,
            w * 0.7,
            mouthY + h * 0.04,
          );
        canvas.drawPath(frown, ink);
      case BossMood.defeated:
        final wave = Path()..moveTo(w * 0.3, mouthY);
        for (var i = 0; i < 4; i++) {
          final x0 = w * 0.3 + w * 0.1 * i;
          wave.quadraticBezierTo(
            x0 + w * 0.05,
            mouthY + (i.isEven ? -1 : 1) * h * 0.035,
            x0 + w * 0.1,
            mouthY,
          );
        }
        canvas.drawPath(wave, ink);
    }

    // 볼 홍조 (pink 줄 두 개)
    final blush = Paint()
      ..color = AppColors.pink
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke * 0.9
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(w * 0.14, h * 0.74),
      Offset(w * 0.3, h * 0.74),
      blush,
    );
    canvas.drawLine(Offset(w * 0.14, h * 0.8), Offset(w * 0.4, h * 0.8), blush);
  }

  @override
  bool shouldRepaint(BossPainter oldDelegate) => oldDelegate.mood != mood;
}

/// 보스 체력 막대 (시안 game-exam 위쪽). 체력이 줄면 700ms 동안 줄어든다.
class BossHpBar extends StatelessWidget {
  const BossHpBar({
    super.key,
    required this.hp,
    required this.maxHp,
    this.name,
  });

  final int hp;
  final int maxHp;

  /// 예: "영상처리 기말 보스"
  final String? name;

  static const _barHeight = AppSpacing.minTouch * 0.6;

  @override
  Widget build(BuildContext context) {
    final ratio = maxHp <= 0 ? 0.0 : (hp / maxHp).clamp(0.0, 1.0);
    return Semantics(
      label: '${name ?? '보스'} 남은 체력 $hp / $maxHp',
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              if (name != null)
                Expanded(
                  child: Text(
                    name!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.chip.copyWith(color: AppColors.pink),
                  ),
                )
              else
                const Spacer(),
              Text(
                '남은 체력 $hp / $maxHp',
                style: AppTextStyles.chip.copyWith(color: AppColors.paper),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Container(
            height: _barHeight,
            padding: const EdgeInsets.all(AppSpacing.xs / 2),
            decoration: BoxDecoration(
              color: AppColors.ink,
              borderRadius: BorderRadius.circular(AppRadius.pill),
              border: Border.all(
                color: AppColors.paper,
                width: AppBlock.border,
              ),
            ),
            child: LayoutBuilder(
              builder: (context, c) => Align(
                alignment: Alignment.centerLeft,
                child: AnimatedContainer(
                  duration: AppMotion.hpBar,
                  curve: Curves.easeOutCubic,
                  width: c.maxWidth * ratio,
                  decoration: BoxDecoration(
                    color: AppColors.pink,
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
