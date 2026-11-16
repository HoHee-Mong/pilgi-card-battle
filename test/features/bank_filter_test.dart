import 'package:flutter_test/flutter_test.dart';
import 'package:pilgi_card_battle/core/models/card.dart';
import 'package:pilgi_card_battle/core/models/room.dart';
import 'package:pilgi_card_battle/features/bank/bank_filter.dart';

BankEntry _entry(String id, int week) => BankEntry(
  cardId: id,
  addedBy: 'u',
  addedByNickname: '선우',
  week: week,
  addedAt: DateTime(2026),
);

QuizCard _card(String id, CardType type, String q, {String answer = ''}) =>
    QuizCard.sample().copyWith(
      id: id,
      type: type,
      question: q,
      answer: answer,
      choices: const [],
      concept: '',
    );

void main() {
  final entries = [_entry('a', 3), _entry('b', 4), _entry('c', 4)];
  final cards = {
    'a': _card('a', CardType.mcq, 'TCP 3-way handshake 순서는?'),
    'b': _card('b', CardType.ox, 'UDP는 연결 지향이다', answer: 'X'),
    'c': _card('c', CardType.short, '라우팅 테이블 이름', answer: 'RIB'),
  };
  List<String> ids(BankFilter f) => [
    for (final e in filterBank(entries, cards, f)) e.cardId,
  ];

  test('조건이 없으면 전체, 순서 그대로', () {
    expect(ids(BankFilter.none), ['a', 'b', 'c']);
  });

  test('검색: 대소문자·띄어쓰기 무시, 정답에서도 찾음', () {
    expect(ids(const BankFilter(query: 'tcp 3-WAY')), ['a']);
    expect(ids(const BankFilter(query: 'rib')), ['c']);
  });

  test('주차 + 유형 같이 걸기', () {
    expect(ids(const BankFilter(weeks: {4})), ['b', 'c']);
    expect(ids(const BankFilter(weeks: {4}, types: {CardType.ox})), ['b']);
  });

  test('검색 + 필터 같이 걸고 결과가 없으면 빈 목록', () {
    expect(ids(const BankFilter(query: 'TCP', weeks: {4})), isEmpty);
  });

  test('카드 본문을 아직 못 불러왔으면 검색·유형에서는 빠지고 주차는 됨', () {
    final partial = {'a': cards['a']!};
    expect(
      [
        for (final e in filterBank(
          entries,
          partial,
          const BankFilter(weeks: {4}),
        ))
          e.cardId,
      ],
      ['b', 'c'],
    );
    expect([
      for (final e in filterBank(
        entries,
        partial,
        const BankFilter(types: {CardType.ox}),
      ))
        e.cardId,
    ], isEmpty);
  });

  test('칩 토글과 초기화 여부', () {
    final f = BankFilter.none.toggleWeek(3).toggleType(CardType.ox);
    expect(f.isActive, isTrue);
    expect(f.toggleWeek(3).toggleType(CardType.ox).isActive, isFalse);
    expect(const BankFilter(query: '   ').isActive, isFalse);
  });
}
