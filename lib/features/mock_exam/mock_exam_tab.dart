import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/tokens.dart';
import '../../core/widgets/boss_sprite.dart';
import '../room/room_providers.dart';
import '../room/room_sheets.dart';
import 'mock_exam_setup_screen.dart';

/// 하단 "모의고사" 탭: 지금 방의 모의고사. 방이 없으면 안내.
class MockExamTab extends ConsumerWidget {
  const MockExamTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final room = ref.watch(currentRoomProvider);
    return room.when(
      loading: () => const _Empty('불러오는 중이에요'),
      error: (e, _) => const _Empty('방 정보를 불러오지 못했어요.'),
      data: (room) => room == null
          ? const _Empty(
              '모의고사는 스터디 방에서 열려요.\n방을 만들거나 초대 코드로 들어오면\n'
              '친구들이 "나올 것 같아요"를 누른 문제로\n우리가 만든 모의고사를 풀 수 있어요.',
              showActions: true,
            )
          : MockExamSetupScreen(key: ValueKey(room.id), room: room),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty(this.text, {this.showActions = false});
  final String text;
  final bool showActions;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.ink,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.page),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: AppSpacing.section),
              Text(
                '우리가 만든 모의고사',
                style: AppTextStyles.titleL.copyWith(color: AppColors.paper),
              ),
              const Spacer(),
              const Center(child: BossSprite(hp: 1, maxHp: 1, size: 120)),
              const SizedBox(height: AppSpacing.section),
              Text(
                text,
                textAlign: TextAlign.center,
                style: AppTextStyles.body.copyWith(color: AppColors.paper),
              ),
              const Spacer(),
              if (showActions) const RoomActions(),
              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }
}
