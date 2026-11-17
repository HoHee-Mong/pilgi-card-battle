import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:pilgi_card_battle/core/ai/card_generator.dart';
import 'package:pilgi_card_battle/core/models/card.dart';
import 'package:pilgi_card_battle/core/models/source.dart';
import 'package:pilgi_card_battle/features/sources/data/source_repository.dart';

void main() {
  group('녹음 응답 읽기', () {
    final json = jsonEncode({
      'summary': '히스토그램 평활화를 다뤘다.',
      'transcript': [
        {'t': 95, 'text': '이건 시험에 나옵니다.'},
        {'t': 0, 'text': '오늘은 히스토그램입니다.'},
        {'t': 40.6, 'text': '  '},
        {'t': -3, 'text': '시작 전'},
      ],
      'cards': [
        {
          'type': 'ox',
          'question': '평활화는 대비를 높인다.',
          'choices': [],
          'answer': 'O',
          'explanation': '분포를 고르게 편다.',
          'concept': '히스토그램 평활화',
          'sourceHint': '',
          'sourceSec': 1421,
        },
        {
          'type': 'short',
          'question': '임계값 자동 선택 방법은?',
          'choices': [],
          'answer': '오츠',
          'explanation': '',
          'concept': '이진화',
          'sourceSec': '3725',
        },
      ],
    });

    test('전사는 시간순, 빈 문단은 빼고 음수 시각은 0', () {
      final r = CardGenerator.parse(json);
      expect([for (final l in r.transcript) l.t], [0, 0, 95]);
      expect(r.transcript.last.text, '이건 시험에 나옵니다.');
    });

    test('카드 근거 시각을 "23:41"·"1:02:05"로 바꾼다', () {
      final r = CardGenerator.parse(json);
      expect(r.cards.map((c) => c.sourceHint), ['23:41', '1:02:05']);
    });

    test('사진·PDF 응답은 전사가 비어 있다', () {
      final r = CardGenerator.parse(
        jsonEncode({'summary': 's', 'cards': const []}),
      );
      expect(r.transcript, isEmpty);
    });
  });

  test('녹음 프롬프트에 과목·주차·개수가 들어간다', () {
    final p = CardGenerator.buildAudioPrompt(
      subjectName: '영상처리',
      week: 3,
      options: const CardGenerateOptions(count: 5, types: {CardType.ox}),
    );
    expect(p, contains('"영상처리" 과목 3주차 강의 녹음'));
    expect(p, contains('정확히 5개'));
    expect(p, contains('sourceSec'));
  });

  test('녹음 확장자 → MIME', () {
    expect(SourceRepository.audioMime('lec.MP3'), 'audio/mp3');
    expect(SourceRepository.audioMime('lec.m4a'), 'audio/mp4');
    expect(SourceRepository.audioMime('lec.wav'), 'audio/wav');
    expect(SourceRepository.audioMime('lec.txt'), isNull);
    expect(SourceRepository.audioMime('noext'), isNull);
  });

  test('StudySource 전사 저장·읽기', () {
    final s = StudySource(
      id: 'x',
      ownerId: 'u',
      subjectId: 's',
      week: 2,
      kind: SourceKind.audio,
      fileName: 'lec.m4a',
      transcript: const [TranscriptLine(t: 61, text: '안녕하세요')],
      createdAt: DateTime(2026, 11, 17),
    );
    final back = StudySource.fromMap('x', s.toMap());
    expect(back.transcript.single.t, 61);
    expect(back.transcript.single.clock, '1:01');
    // 녹음이 아니면 transcript 필드를 쓰지 않는다
    final plain = StudySource.fromMap('y', {'kind': 'pdf'});
    expect(plain.transcript, isEmpty);
    expect(formatSeconds(3600), '1:00:00');
  });

  test('AI 오류를 사용자용 문장으로', () {
    expect(
      CardGenerator.friendlyError(
        'This model is currently experiencing high demand. Please try again later.',
      ),
      contains('붐벼요'),
    );
    expect(
      CardGenerator.friendlyError(
        'Deadline expired before operation could complete.',
      ),
      contains('오래 걸렸어요'),
    );
    expect(CardGenerator.friendlyError('bad'), 'AI 호출에 실패했어요: bad');
  });
}
