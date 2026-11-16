import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import 'user_profile.dart';

/// 로그인: Google 계정 또는 게스트(익명).
///
/// - 앱을 켜면 로그인 화면이 먼저 나온다. Google로 로그인했으면 다음부터는 바로 들어간다.
/// - 게스트로 쓰던 사람이 Google로 로그인하면 같은 계정에 Google을 연결한다
///   → uid가 그대로라 만든 카드·방·기록이 이어진다.
/// - 그 Google 계정을 이미 다른 기기에서 썼다면 그 계정으로 바꿔 들어간다.
///
/// 라우터가 [refreshListenable]로 듣는다 ([canEnter]가 바뀌면 화면 이동).
class AuthService extends ChangeNotifier {
  AuthService(this._auth, this._profiles) {
    _auth.userChanges().listen((_) => notifyListeners());
  }

  final FirebaseAuth _auth;
  final UserProfileRepository _profiles;

  /// 이번 실행에서 "게스트로 둘러보기"를 눌렀는지
  bool _guest = false;

  User? get user => _auth.currentUser;

  bool get isGoogle =>
      user?.providerData.any((p) => p.providerId == 'google.com') ?? false;

  /// 앱 안으로 들어갈 수 있는지: Google 로그인, 또는 이번에 게스트를 고름
  bool get canEnter {
    final u = user;
    if (u == null) return false;
    return !u.isAnonymous || _guest;
  }

  Future<void> continueAsGuest() async {
    if (user == null) await _auth.signInAnonymously();
    _guest = true;
    notifyListeners();
  }

  Future<void> signInWithGoogle() async {
    final provider = GoogleAuthProvider()
      ..setCustomParameters({'prompt': 'select_account'});
    final current = user;
    UserCredential cred;
    if (current != null && current.isAnonymous) {
      try {
        cred = kIsWeb
            ? await current.linkWithPopup(provider)
            : await current.linkWithProvider(provider);
      } on FirebaseAuthException catch (e) {
        // 이미 다른 데서 쓰던 Google 계정 → 그 계정으로 바꿔 들어간다
        if (e.code != 'credential-already-in-use') rethrow;
        final existing = e.credential;
        if (existing == null) {
          await _auth.signOut();
          throw const AuthMessage('이미 쓰던 Google 계정이에요. 한 번 더 눌러 주세요.');
        }
        cred = await _auth.signInWithCredential(existing);
      }
    } else {
      cred = kIsWeb
          ? await _auth.signInWithPopup(provider)
          : await _auth.signInWithProvider(provider);
    }
    _guest = false;
    final signed = cred.user;
    if (signed != null) {
      await _profiles.adoptName(signed.uid, signed.displayName);
    }
    notifyListeners();
  }

  Future<void> signOut() async {
    _guest = false;
    await _auth.signOut();
  }

  /// 로그인 실패를 화면 문구로
  static String messageOf(Object e) => switch (e) {
    AuthMessage(:final message) => message,
    FirebaseAuthException(code: 'popup-closed-by-user') ||
    FirebaseAuthException(code: 'cancelled-popup-request') ||
    FirebaseAuthException(code: 'web-context-canceled') => '로그인을 취소했어요.',
    FirebaseAuthException(code: 'popup-blocked') =>
      '팝업이 막혔어요. 브라우저에서 팝업을 허용해 주세요.',
    FirebaseAuthException(code: 'operation-not-allowed') =>
      'Google 로그인이 아직 켜져 있지 않아요. (Firebase 콘솔 설정 필요)',
    FirebaseAuthException(code: 'network-request-failed') => '인터넷 연결을 확인해 주세요.',
    _ => '로그인하지 못했어요. 잠시 후 다시 해 주세요.',
  };
}

/// 화면에 그대로 보여 줄 로그인 안내
class AuthMessage implements Exception {
  const AuthMessage(this.message);
  final String message;
}

/// 앱 전체에서 하나. 라우터(전역)도 이걸 쓴다.
final authService = AuthService(
  FirebaseAuth.instance,
  UserProfileRepository(FirebaseFirestore.instance),
);
