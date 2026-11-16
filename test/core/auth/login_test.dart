import 'package:flutter_test/flutter_test.dart';
import 'package:pilgi_card_battle/core/auth/user_profile.dart';
import 'package:pilgi_card_battle/core/router.dart';

void main() {
  group('로그인 화면 이동', () {
    test('로그인 전에는 어디로 가든 로그인 화면', () {
      expect(
        loginRedirect(canEnter: false, at: AppRoutes.lobby),
        AppRoutes.login,
      );
      expect(
        loginRedirect(canEnter: false, at: AppRoutes.bank),
        AppRoutes.login,
      );
      expect(loginRedirect(canEnter: false, at: AppRoutes.login), isNull);
    });

    test('로그인하면 로그인 화면에서 로비로, 다른 화면은 그대로', () {
      expect(
        loginRedirect(canEnter: true, at: AppRoutes.login),
        AppRoutes.lobby,
      );
      expect(loginRedirect(canEnter: true, at: AppRoutes.bank), isNull);
    });
  });

  test('자동 닉네임(학생1234)만 Google 이름으로 바꾼다', () {
    expect(UserProfileRepository.isAutoNickname('학생1234'), isTrue);
    expect(UserProfileRepository.isAutoNickname('선우'), isFalse);
    expect(UserProfileRepository.isAutoNickname('학생12345'), isFalse);
  });
}
