import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../features/bank/bank_tab.dart';
import '../features/room/lobby_screen.dart';
import '../features/subjects/subject_list_screen.dart';
import 'theme/tokens.dart';
import 'widgets/app_shell.dart';

/// 앱 경로. 새 화면 경로 추가는 각자 한 줄씩 가능 (`docs/ROLES.md`).
///
/// 하단 탭 4개는 각자 자기 Navigator를 가진다. 탭 안에서 `Navigator.of(context).push`로
/// 연 화면은 하단 탭이 보이는 채로 쌓이고, 탭을 바꿔도 쌓인 화면이 유지된다.
abstract final class AppRoutes {
  static const lobby = '/lobby';
  static const bank = '/bank';
  static const mock = '/mock';
  static const cards = '/cards';
}

final appRouter = GoRouter(
  initialLocation: AppRoutes.lobby,
  routes: [
    StatefulShellRoute.indexedStack(
      builder: (context, state, shell) => AppShell(shell: shell),
      branches: [
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: AppRoutes.lobby,
              builder: (_, _) => const LobbyScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(path: AppRoutes.bank, builder: (_, _) => const BankTab()),
          ],
        ),
        StatefulShellBranch(
          routes: [
            // A의 모의고사 화면이 생기면 이 줄만 바꾼다.
            GoRoute(
              path: AppRoutes.mock,
              builder: (_, _) => const _ComingSoon('모의고사는 곧 열려요'),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: AppRoutes.cards,
              builder: (_, _) => const SubjectListScreen(),
            ),
          ],
        ),
      ],
    ),
  ],
);

/// 아직 없는 탭 자리 표시
class _ComingSoon extends StatelessWidget {
  const _ComingSoon(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.ink,
      body: Center(
        child: Text(
          text,
          style: AppTextStyles.heading.copyWith(color: AppColors.paper),
        ),
      ),
    );
  }
}
