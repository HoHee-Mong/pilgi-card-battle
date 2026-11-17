import 'package:go_router/go_router.dart';

import '../features/bank/bank_tab.dart';
import '../features/mock_exam/mock_exam_tab.dart';
import '../features/notebook/notebook_share_screen.dart';
import '../features/room/lobby_screen.dart';
import '../features/subjects/subject_list_screen.dart';
import 'auth/auth_service.dart';
import 'auth/login_screen.dart';
import 'widgets/app_shell.dart';

/// 앱 경로. 새 화면 경로 추가는 각자 한 줄씩 가능 (`docs/ROLES.md`).
///
/// 하단 탭 4개는 각자 자기 Navigator를 가진다. 탭 안에서 `Navigator.of(context).push`로
/// 연 화면은 하단 탭이 보이는 채로 쌓이고, 탭을 바꿔도 쌓인 화면이 유지된다.
abstract final class AppRoutes {
  static const login = '/login';
  static const lobby = '/lobby';
  static const bank = '/bank';
  static const mock = '/mock';
  static const cards = '/cards';

  /// 공유 족보 링크: `/share/ABC123`
  static const sharePrefix = '/share/';
}

final appRouter = GoRouter(
  initialLocation: AppRoutes.lobby,
  // 로그인 전이면 로그인 화면으로, 로그인하면 로비로
  refreshListenable: authService,
  redirect: (context, state) => loginRedirect(
    canEnter: authService.canEnter,
    at: state.matchedLocation,
    next: state.uri.queryParameters['next'],
  ),
  routes: [
    GoRoute(
      path: '${AppRoutes.sharePrefix}:code',
      builder: (_, state) => NotebookShareScreen(
        code: state.pathParameters['code']!.toUpperCase(),
      ),
    ),
    GoRoute(path: AppRoutes.login, builder: (_, _) => const LoginScreen()),
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
            GoRoute(
              path: AppRoutes.mock,
              builder: (_, _) => const MockExamTab(),
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

/// 로그인 여부에 따른 화면 이동. null이면 그대로.
/// 공유 족보 링크로 들어왔는데 로그인 전이면, 로그인한 뒤 그 링크로 돌아간다 ([next]).
String? loginRedirect({
  required bool canEnter,
  required String at,
  String? next,
}) {
  final atLogin = at == AppRoutes.login;
  if (!canEnter) {
    if (atLogin) return null;
    if (at.startsWith(AppRoutes.sharePrefix)) {
      return '${AppRoutes.login}?next=${Uri.encodeComponent(at)}';
    }
    return AppRoutes.login;
  }
  if (!atLogin) return null;
  return next != null && next.startsWith(AppRoutes.sharePrefix)
      ? next
      : AppRoutes.lobby;
}
