import 'package:flutter_test/flutter_test.dart';
import 'package:pilgi_card_battle/core/auth/account_sheet.dart';

void main() {
  test('이름: 빈칸·12글자 초과는 안 되고, 앞뒤 공백은 무시', () {
    expect(nicknameProblem('   '), isNotNull);
    expect(nicknameProblem('가나다라마바사아자차카타파'), isNotNull); // 13글자
    expect(nicknameProblem('  선우  '), isNull);
    expect(nicknameProblem('가나다라마바사아자차카타'), isNull); // 12글자
  });
}
