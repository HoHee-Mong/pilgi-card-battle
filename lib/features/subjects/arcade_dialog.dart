import 'package:flutter/material.dart';

import '../../core/theme/tokens.dart';
import '../../core/widgets/chunky_button.dart';
import '../../core/widgets/chunky_card.dart';

/// 블록 스타일 확인 다이얼로그. 확인하면 true, 아니면 false.
///
/// [message] 대신 [body]를 주면 본문 위젯을 그대로 넣는다.
/// [confirmColor] 기본 pink. 지우기처럼 되돌릴 수 없는 동작은 [AppColors.wrong].
Future<bool> showArcadeConfirm(
  BuildContext context, {
  required String title,
  String? message,
  Widget? body,
  String confirmLabel = '확인',
  String cancelLabel = '취소',
  Color confirmColor = AppColors.pink,
}) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.all(AppSpacing.page),
      child: ChunkyCard(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: AppTextStyles.titleM),
            if (message != null) ...[
              const SizedBox(height: AppSpacing.md),
              Text(message, style: AppTextStyles.body),
            ],
            if (body != null) ...[const SizedBox(height: AppSpacing.md), body],
            const SizedBox(height: AppSpacing.section),
            Row(
              children: [
                Expanded(
                  child: ChunkyButton(
                    label: cancelLabel,
                    color: AppColors.paper,
                    onPressed: () => Navigator.pop(ctx, false),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: ChunkyButton(
                    label: confirmLabel,
                    color: confirmColor,
                    onPressed: () => Navigator.pop(ctx, true),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
  return ok == true;
}
