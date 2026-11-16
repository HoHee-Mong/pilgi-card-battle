import 'package:flutter/material.dart';

import '../../core/theme/tokens.dart';
import '../../core/widgets/boss_sprite.dart';
import '../../core/widgets/chunky_button.dart';

/// 개발용: 보스 연출 미리보기 (로비 보스를 길게 누르면 열림, 디버그 빌드에서만).
/// 정답 = 체력 -1 + hit(), 오답 = miss(). 실제 모의고사 화면은 A가 만든다.
class BossPreviewScreen extends StatefulWidget {
  const BossPreviewScreen({super.key});

  @override
  State<BossPreviewScreen> createState() => _BossPreviewScreenState();
}

class _BossPreviewScreenState extends State<BossPreviewScreen> {
  static const _maxHp = 10;
  final _boss = BossController();
  int _hp = _maxHp;

  @override
  void dispose() {
    _boss.dispose();
    super.dispose();
  }

  void _correct() {
    if (_hp == 0) return;
    setState(() => _hp--);
    _boss.hit();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.ink,
      appBar: AppBar(
        backgroundColor: AppColors.ink,
        foregroundColor: AppColors.paper,
        title: Text(
          '보스 미리보기 (개발용)',
          style: AppTextStyles.heading.copyWith(color: AppColors.paper),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(AppSpacing.page),
        child: Column(
          children: [
            BossHpBar(hp: _hp, maxHp: _maxHp, name: '미리보기 보스'),
            const Spacer(),
            BossSprite(hp: _hp, maxHp: _maxHp, controller: _boss),
            const Spacer(),
            Row(
              children: [
                Expanded(
                  child: ChunkyButton(
                    label: '정답',
                    color: AppColors.lime,
                    shadowColor: AppColors.grape,
                    onPressed: _hp == 0 ? null : _correct,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: ChunkyButton(
                    label: '오답',
                    color: AppColors.wrong,
                    shadowColor: AppColors.grape,
                    onPressed: _boss.miss,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            ChunkyButton(
              label: '체력 다시 채우기',
              color: AppColors.paper,
              shadowColor: AppColors.grape,
              onPressed: () => setState(() => _hp = _maxHp),
            ),
          ],
        ),
      ),
    );
  }
}
