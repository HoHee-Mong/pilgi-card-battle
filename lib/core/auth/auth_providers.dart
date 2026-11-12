import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 로그인 상태 스트림. main()에서 익명 로그인을 먼저 끝내므로 보통 null이 아니다.
final authStateProvider = StreamProvider<User?>(
  (ref) => FirebaseAuth.instance.authStateChanges(),
);

/// 현재 uid. 로그인 전이면 null.
final uidProvider = Provider<String?>((ref) {
  final fromStream = ref.watch(authStateProvider).value?.uid;
  return fromStream ?? FirebaseAuth.instance.currentUser?.uid;
});
