import 'package:flutter/material.dart';

import '../theme/layout.dart';
import '../theme/tokens.dart';
import '../widgets/boss_sprite.dart';
import '../widgets/chunky_button.dart';
import '../widgets/outlined_text.dart';
import 'auth_service.dart';

/// 앱을 켜면 먼저 나오는 화면: Google로 시작하기 / 게스트로 둘러보기.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _busy = false;
  String? _error;

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
    } catch (e) {
      if (mounted) setState(() => _error = AuthService.messageOf(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.grape,
      body: SafeArea(
        child: ListView(
          padding: AppLayout.pagePadding(
            context,
            top: AppSpacing.section * 3,
            bottom: AppSpacing.section * 2,
          ),
          children: [
            const Center(child: BossSprite(hp: 3, maxHp: 3, size: 150)),
            const SizedBox(height: AppSpacing.section * 2),
            const Center(child: OutlinedText('필기 카드 배틀')),
            const SizedBox(height: AppSpacing.sm),
            Text(
              '우리가 만드는 시험문제\n친구들이 "나올 것 같아요" 한 문제로 모의고사를 풀어요',
              textAlign: TextAlign.center,
              style: AppTextStyles.label.copyWith(color: AppColors.cream),
            ),
            const SizedBox(height: AppSpacing.section * 3),
            ChunkyButton(
              label: 'Google로 시작하기',
              icon: Icons.login_rounded,
              large: true,
              color: AppColors.lime,
              loading: _busy,
              onPressed: _busy
                  ? null
                  : () => _run(authService.signInWithGoogle),
            ),
            const SizedBox(height: AppSpacing.md),
            ChunkyButton(
              label: '게스트로 둘러보기',
              color: AppColors.paper,
              onPressed: _busy ? null : () => _run(authService.continueAsGuest),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              _error ?? '게스트로 만든 기록은 나중에 Google로 로그인하면 그대로 이어져요',
              textAlign: TextAlign.center,
              style: AppTextStyles.label.copyWith(
                color: _error == null ? AppColors.cream : AppColors.sun,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
