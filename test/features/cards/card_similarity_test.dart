import 'package:flutter_test/flutter_test.dart';
import 'package:pilgi_card_battle/core/models/card.dart';
import 'package:pilgi_card_battle/features/cards/card_similarity.dart';

QuizCard _card(String id, String question) =>
    QuizCard.sample().copyWith(id: id, question: question);

void main() {
  group('normalize', () {
    test('공백·문장부호를 빼고 소문자로 만든다', () {
      expect(
        CardSimilarity.normalize(' TCP 3-way  handshake? '),
        'tcp3wayhandshake',
      );
      expect(CardSimilarity.normalize('UDP는 순서를 보장한다.'), 'udp는순서를보장한다');
    });
  });

  group('score', () {
    test('같은 문장은 1, 전혀 다른 문장은 0에 가깝다', () {
      expect(CardSimilarity.score('ARP란?', 'ARP란?'), 1);
      expect(
        CardSimilarity.score('TCP 3-way handshake 두 번째 패킷은?', '광합성의 명반응 장소는?'),
        lessThan(0.1),
      );
    });

    test('띄어쓰기·조사만 다른 문장은 임계값을 넘는다', () {
      final s = CardSimilarity.score(
        'TCP 3-way handshake에서 두 번째로 보내는 패킷은?',
        'TCP 3way handshake 에서 두번째로 보내는 패킷은 무엇인가?',
      );
      expect(s, greaterThanOrEqualTo(CardSimilarity.threshold));
    });

    test('빈 문자열이나 한 글자는 0', () {
      expect(CardSimilarity.score('', 'ARP'), 0);
      expect(CardSimilarity.score('A', 'B'), 0);
    });
  });

  group('find', () {
    final pool = [
      _card('a', 'TCP 3-way handshake에서 두 번째로 보내는 패킷은?'),
      _card('b', 'UDP는 전송 순서를 보장한다.'),
      _card('c', 'IP 주소를 MAC 주소로 바꿔 주는 프로토콜은?'),
      _card('d', 'TCP 3-way handshake 에서 두번째 패킷은?'),
    ];

    test('비슷한 카드만 점수 높은 순으로 돌려준다', () {
      final hits = CardSimilarity.find('TCP 3-way handshake에서 두 번째 패킷은?', pool);
      expect(hits.map((h) => h.card.id), containsAll(['a', 'd']));
      expect(hits.map((h) => h.card.id), isNot(contains('b')));
      expect(hits.map((h) => h.card.id), isNot(contains('c')));
      for (var i = 1; i < hits.length; i++) {
        expect(hits[i - 1].score, greaterThanOrEqualTo(hits[i].score));
      }
    });

    test('자기 자신은 뺀다', () {
      final hits = CardSimilarity.find(pool[0].question, pool, excludeId: 'a');
      expect(hits.map((h) => h.card.id), isNot(contains('a')));
    });

    test('짧은 입력은 아무것도 돌려주지 않는다', () {
      expect(CardSimilarity.find('T', pool), isEmpty);
      expect(CardSimilarity.find('  ', pool), isEmpty);
    });

    test('limit만큼만 돌려준다', () {
      final many = List.generate(
        6,
        (i) => _card('x$i', 'TCP 3-way handshake에서 두 번째 패킷은? $i'),
      );
      expect(
        CardSimilarity.find(many[0].question, many, limit: 2),
        hasLength(2),
      );
    });
  });

  group('countWithin', () {
    test('서로 비슷한 카드 ID만 장수와 함께 돌려준다', () {
      final pool = [
        _card('a', 'TCP 3-way handshake에서 두 번째로 보내는 패킷은?'),
        _card('b', 'UDP는 전송 순서를 보장한다.'),
        _card('c', 'TCP 3-way handshake 에서 두번째 패킷은?'),
      ];
      final counts = CardSimilarity.countWithin(pool, pool);
      expect(counts, {'a': 1, 'c': 1});
    });
  });
}
