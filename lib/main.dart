import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/theme/app_theme.dart';
import 'features/subjects/subject_list_screen.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await _ensureSignedIn();
  runApp(const ProviderScope(child: PilgiApp()));
}

/// 익명 로그인. 이미 로그인돼 있으면 그대로 쓴다.
Future<void> _ensureSignedIn() async {
  final auth = FirebaseAuth.instance;
  if (auth.currentUser != null) return;
  try {
    await auth.signInAnonymously();
  } on FirebaseAuthException catch (e) {
    debugPrint('익명 로그인 실패: ${e.code} ${e.message}');
  }
}

/// 임시 루트. B가 router.dart를 만들면 MaterialApp.router로 교체한다.
/// 그 전까지는 A의 과목 목록을 홈으로 띄운다.
class PilgiApp extends StatelessWidget {
  const PilgiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '필기 카드 배틀',
      theme: AppTheme.light(),
      home: const SubjectListScreen(),
    );
  }
}
