import 'package:flutter/material.dart';

import '../../core/theme/tokens.dart';
import '../../core/widgets/chunky_button.dart';

/// 배틀 하는 법 (대기실 "?" 버튼)
const battleHelpSteps = [
  ('친구 부르기', '위의 초대 코드를 눌러 복사하고 친구에게 보내요. 친구는 로비 → 코드로 입장.'),
  ('대기실에 모이기', '친구가 이 화면에 들어오면 방장이 "배틀 시작"을 눌러요. 따로 준비 버튼은 없어요.'),
  ('문제', '우리 방 문제은행에서 "나올 것 같아요" 표를 많이 받은 문제부터 나와요.'),
  ('점수', '15초 안에 맞히면 500점 + 빨리 맞힐수록 최대 500점. 연속으로 맞히면 콤보 +100.'),
  ('끝나면', '틀린 문제는 오답 노트로 가요. 결과 화면에서 문제마다 투표도 할 수 있어요.'),
];

Future<void> showBattleHelpSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (ctx) => SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.page,
        AppSpacing.section,
        AppSpacing.page,
        AppSpacing.section * 2,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('배틀 하는 법', style: AppTextStyles.titleM),
          const SizedBox(height: AppSpacing.section),
          for (final (i, (title, body)) in battleHelpSteps.indexed)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: AppSpacing.minTouch * 0.7,
                    height: AppSpacing.minTouch * 0.7,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppColors.sun,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppColors.ink,
                        width: AppBlock.border,
                      ),
                    ),
                    child: Text('${i + 1}', style: AppTextStyles.chip),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title, style: AppTextStyles.heading),
                        Text(body, style: AppTextStyles.bodyS),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: AppSpacing.sm),
          ChunkyButton(
            label: '알겠어요',
            color: AppColors.lime,
            onPressed: () => Navigator.of(ctx).pop(),
          ),
        ],
      ),
    ),
  );
}
