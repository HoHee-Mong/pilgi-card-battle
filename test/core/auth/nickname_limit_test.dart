import 'package:flutter_test/flutter_test.dart';
import 'package:pilgi_card_battle/core/auth/user_profile.dart';

void main() {
  test('남은 변경 횟수: 3번까지, 0 아래로 안 내려감', () {
    expect(nicknameChangesLeft(0), kMaxNicknameChanges);
    expect(nicknameChangesLeft(2), 1);
    expect(nicknameChangesLeft(3), 0);
    expect(nicknameChangesLeft(9), 0);
  });

  test('프로필: 필드 없는 예전 문서는 0회·이름 미설정으로 읽힘', () {
    final old = UserProfile.fromMap(const {'nickname': '학생1234'});
    expect(old.nicknameChanges, 0);
    expect(old.nicknameSet, isFalse);
    expect(old.changesLeft, kMaxNicknameChanges);
    final p = UserProfile.fromMap(const {
      'nickname': '선우',
      'nicknameChanges': 3,
      'nicknameSet': true,
    });
    expect(p.changesLeft, 0);
    expect(p.nicknameSet, isTrue);
    expect(UserProfile.fromMap(null).nickname, '');
  });
}
