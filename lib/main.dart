import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/router.dart';
import 'fx/sound.dart';
import 'core/theme/app_theme.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  // 지난번 로그인을 먼저 불러온다 (안 그러면 잠깐 로그인 화면이 깜빡임)
  await FirebaseAuth.instance.authStateChanges().first;
  await Sound.init();
  // 로그인은 앱 안 로그인 화면에서 한다 (core/auth/auth_service.dart)
  runApp(const ProviderScope(child: PilgiApp()));
}

/// 앱 루트. 화면 경로와 하단 탭은 `core/router.dart`.
class PilgiApp extends StatelessWidget {
  const PilgiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: '필기 카드 배틀',
      theme: AppTheme.light(),
      routerConfig: appRouter,
    );
  }
}
