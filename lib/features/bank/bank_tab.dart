import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/tokens.dart';
import '../room/room_providers.dart';
import '../room/room_sheets.dart';
import 'bank_screen.dart';

/// 하단 "문제은행" 탭: 지금 방의 문제은행. 방이 없으면 안내.
class BankTab extends ConsumerWidget {
  const BankTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final room = ref.watch(currentRoomProvider);
    return room.when(
      loading: () => const _Empty('불러오는 중이에요'),
      error: (e, _) => const _Empty('방 정보를 불러오지 못했어요.'),
      data: (room) => room == null
          ? const _Empty(
              '아직 들어간 스터디 방이 없어요.\n방을 만들거나 초대 코드로 들어오면\n여기에 우리가 뽑은 예상 문제가 모여요.',
              showActions: true,
            )
          : BankScreen(key: ValueKey(room.id), roomId: room.id),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty(this.text, {this.showActions = false});
  final String text;

  /// 방 만들기·코드로 입장 버튼
  final bool showActions;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.cream,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.page),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: AppSpacing.section),
              const Text('예상 문제 랭킹', style: AppTextStyles.titleL),
              const Spacer(),
              Center(
                child: Text(
                  text,
                  textAlign: TextAlign.center,
                  style: AppTextStyles.body.copyWith(color: AppColors.inkSub),
                ),
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
