import 'package:flutter_test/flutter_test.dart';
import 'package:pilgi_card_battle/core/models/room.dart';
import 'package:pilgi_card_battle/features/bank/bank_repository.dart';

void main() {
  final room = Room(
    id: 'r',
    code: 'ABC234',
    hostId: 'host',
    subjectId: 's',
    name: '방',
    createdAt: DateTime(2026),
  );
  final entry = BankEntry(
    cardId: 'c',
    addedBy: 'author',
    addedByNickname: '민지',
    week: 3,
    addedAt: DateTime(2026),
  );

  test('올린 사람은 뺄 수 있다', () {
    expect(BankRepository.canRemove(entry, room, 'author'), isTrue);
  });

  test('방장은 남의 카드도 뺄 수 있다', () {
    expect(BankRepository.canRemove(entry, room, 'host'), isTrue);
  });

  test('다른 사람은 뺄 수 없다', () {
    expect(BankRepository.canRemove(entry, room, 'friend'), isFalse);
  });
}
