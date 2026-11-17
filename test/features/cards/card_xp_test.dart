import 'package:flutter_test/flutter_test.dart';
import 'package:pilgi_card_battle/core/models/card.dart';
import 'package:pilgi_card_battle/features/cards/card_xp.dart';

void main() {
  test('새 카드를 검수 완료로 저장하면 카드 만들기로 센다', () {
    expect(becameVerified(null, CardStatus.verified), isTrue);
  });

  test('초안을 검수 완료로 바꾸면 센다', () {
    expect(becameVerified(CardStatus.draft, CardStatus.verified), isTrue);
  });

  test('초안 저장이나 검수 완료 카드 수정은 세지 않는다', () {
    expect(becameVerified(null, CardStatus.draft), isFalse);
    expect(becameVerified(CardStatus.draft, CardStatus.draft), isFalse);
    expect(becameVerified(CardStatus.verified, CardStatus.verified), isFalse);
    expect(becameVerified(CardStatus.verified, CardStatus.draft), isFalse);
  });
}
