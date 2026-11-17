import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:pilgi_card_battle/core/models/attempt.dart';
import 'package:pilgi_card_battle/core/models/card.dart';
import 'package:pilgi_card_battle/features/solo/solo_model.dart';

void main() {
  final pool = [
    QuizCard.sample(0).copyWith(id: 'a', week: 3), // mcq
    QuizCard.sample(1).copyWith(id: 'b', week: 4), // ox
    QuizCard.sample(2).copyWith(id: 'c', week: 4), // short
    QuizCard.sample(0).copyWith(id: 'd', week: 5),
  ];

  group('buildQuizSet', () {
    test('주차·유형으로 거르고 count만큼 뽑는다', () {
      final set = buildQuizSet(
        pool,
        weeks: {4},
        types: {CardType.ox, CardType.short},
        count: 10,
        random: Random(1),
      );
      expect(set.map((c) => c.id), unorderedEquals(['b', 'c']));
    });

    test('weeks가 비면 전체, count 0이면 전부', () {
      final set = buildQuizSet(
        pool,
        weeks: {},
        types: CardType.values.toSet(),
        count: 0,
        random: Random(1),
      );
      expect(set, hasLength(4));
    });

    test('count가 작으면 그만큼만', () {
      final set = buildQuizSet(
        pool,
        weeks: {},
        types: CardType.values.toSet(),
        count: 2,
        random: Random(1),
      );
      expect(set, hasLength(2));
    });

    test('안 푼 카드 먼저, 그다음 오래전에 푼 카드', () {
      final now = DateTime(2026, 11, 17);
      final set = buildQuizSet(
        pool,
        weeks: {},
        types: CardType.values.toSet(),
        count: 2,
        lastSolved: {
          'a': now,
          'b': now.subtract(const Duration(days: 3)),
          'c': now.subtract(const Duration(days: 1)),
        },
        random: Random(2),
      );
      // d는 안 풂, b는 가장 오래전에 풂
      expect(set.map((c) => c.id), unorderedEquals(['d', 'b']));
    });

    test('객관식 보기 순서를 섞어도 보기·정답은 그대로', () {
      final card = pool[0];
      final seen = <String>{};
      for (var i = 0; i < 20; i++) {
        final s = shuffleChoices(card, Random(i));
        expect(s.choices, unorderedEquals(card.choices));
        expect(isCorrectAnswer(s, card.answer), isTrue);
        seen.add(s.choices.join('|'));
      }
      expect(seen.length, greaterThan(1));
    });

    test('lastSolvedAt은 카드마다 가장 최근 기록', () {
      final t1 = DateTime(2026, 11, 1);
      final t2 = DateTime(2026, 11, 5);
      Attempt at(String id, DateTime t) => Attempt(
        id: '$id$t',
        cardId: id,
        subjectId: 's',
        concept: '',
        correct: true,
        mode: AttemptMode.solo,
        at: t,
      );
      expect(lastSolvedAt([at('a', t1), at('a', t2), at('b', t1)]), {
        'a': t2,
        'b': t1,
      });
    });
  });

  group('isCorrectAnswer', () {
    test('객관식·OX는 정확히 같아야', () {
      expect(isCorrectAnswer(pool[0], 'SYN+ACK'), isTrue);
      expect(isCorrectAnswer(pool[0], 'SYN'), isFalse);
      expect(isCorrectAnswer(pool[1], 'X'), isTrue);
    });

    test('단답형은 공백·대소문자 무시', () {
      expect(isCorrectAnswer(pool[2], 'arp'), isTrue);
      expect(isCorrectAnswer(pool[2], ' A R P '), isTrue);
      expect(isCorrectAnswer(pool[2], 'RARP'), isFalse);
    });
  });
}
