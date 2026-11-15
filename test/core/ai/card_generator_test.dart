import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:pilgi_card_battle/core/ai/card_generator.dart';
import 'package:pilgi_card_battle/core/models/card.dart';

void main() {
  Map<String, dynamic> mcq({String answer = 'SYN+ACK'}) => {
    'type': 'mcq',
    'question': '두 번째 패킷은?',
    'choices': ['SYN', 'SYN+ACK', 'ACK', 'FIN'],
    'answer': answer,
    'explanation': '순서가 그렇다.',
    'concept': 'TCP 연결',
    'sourceHint': 'p.3',
  };

  test('정상 응답을 요약 + 카드로 읽는다', () {
    final json = jsonEncode({
      'summary': '요약이다.',
      'cards': [
        mcq(),
        {
          'type': 'ox',
          'question': 'UDP는 순서를 보장한다.',
          'choices': [],
          'answer': 'X',
          'explanation': '아니다.',
          'concept': 'UDP',
        },
        {
          'type': 'short',
          'question': 'IP→MAC 프로토콜은?',
          'answer': 'ARP',
          'explanation': '',
          'concept': 'ARP',
        },
      ],
    });
    final r = CardGenerator.parse(json);
    expect(r.summary, '요약이다.');
    expect(r.cards.length, 3);
    expect(r.cards[0].type, CardType.mcq);
    expect(r.cards[0].sourceHint, 'p.3');
    expect(r.cards[1].answer, 'X');
    expect(r.cards[2].choices, isEmpty);
  });

  test('규칙에 어긋나는 카드는 버린다', () {
    final json = jsonEncode({
      'summary': '',
      'cards': [
        mcq(answer: '없는 보기'), // 정답이 보기에 없음
        {
          ...mcq(),
          'choices': ['A', 'B', 'C'], // 보기 3개
        },
        {...mcq(), 'question': ''}, // 질문 없음
        {'type': 'ox', 'question': 'q', 'answer': '모름'}, // O/X 아님
        {'type': 'essay', 'question': 'q', 'answer': 'a'}, // 모르는 유형
        mcq(answer: ' syn+ack. '), // 공백·마침표 차이는 보기 쪽으로 맞춤
      ],
    });
    final r = CardGenerator.parse(json);
    expect(r.cards.length, 1);
    expect(r.cards.single.answer, 'SYN+ACK');
  });

  test('허용 유형만 남긴다', () {
    final json = jsonEncode({
      'summary': '',
      'cards': [
        mcq(),
        {'type': 'ox', 'question': 'q', 'answer': 'O'},
      ],
    });
    final r = CardGenerator.parse(json, allowedTypes: {CardType.ox});
    expect(r.cards.single.type, CardType.ox);
  });

  test('OX 답은 O/X로 정규화한다', () {
    final json = jsonEncode({
      'cards': [
        {'type': 'ox', 'question': 'q', 'answer': '참'},
        {'type': 'ox', 'question': 'q', 'answer': 'false'},
      ],
    });
    final r = CardGenerator.parse(json);
    expect(r.cards.map((c) => c.answer), ['O', 'X']);
  });

  test('코드 펜스로 감싼 JSON도 읽는다', () {
    final r = CardGenerator.parse('```json\n{"summary":"s","cards":[]}\n```');
    expect(r.summary, 's');
  });

  test('JSON이 아니면 예외', () {
    expect(
      () => CardGenerator.parse('not json'),
      throwsA(isA<CardGenerationException>()),
    );
  });

  test('프롬프트에 개수·과목·유형이 들어간다', () {
    final p = CardGenerator.buildPrompt(
      subjectName: '영상처리',
      week: 3,
      options: const CardGenerateOptions(count: 5, types: {CardType.ox}),
    );
    expect(p, contains('영상처리'));
    expect(p, contains('3주차'));
    expect(p, contains('5개'));
    expect(p, contains('ox=OX'));
    expect(p, isNot(contains('mcq=')));
  });
}
