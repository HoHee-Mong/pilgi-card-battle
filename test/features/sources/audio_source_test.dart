import 'package:flutter_test/flutter_test.dart';
import 'package:pilgi_card_battle/core/ai/card_generator.dart';
import 'package:pilgi_card_battle/core/models/card.dart';
import 'package:pilgi_card_battle/core/models/source.dart';
import 'package:pilgi_card_battle/features/sources/add_source_sheet.dart';
import 'package:pilgi_card_battle/features/sources/concept_signals.dart';

void main() {
  group('시간 표시', () {
    test('초 ↔ "분:초"', () {
      expect(formatTimestamp(0), '0:00');
      expect(formatTimestamp(754), '12:34');
      expect(formatTimestamp(3723), '1:02:03');
      expect(parseTimestamp('12:34'), 754);
      expect(parseTimestamp('1:02:03'), 3723);
      expect(parseTimestamp('90'), 90);
      expect(parseTimestamp('ab'), isNull);
      expect(parseTimestamp(''), isNull);
    });
  });

  test('녹음 자료는 전사·강조 발언을 저장하고 다시 읽는다', () {
    final src = StudySource(
      id: 's1',
      ownerId: 'u',
      subjectId: 'sub',
      week: 3,
      kind: SourceKind.audio,
      fileName: '3주차 녹음.m4a',
      createdAt: DateTime(2026, 11, 17),
      transcript: const [TranscriptLine(t: 5, text: '오늘은 TCP를 봅니다.')],
      emphasis: const [
        EmphasisLine(t: 754, quote: '이거 시험에 나옵니다', concept: 'TCP 연결 수립'),
      ],
    );
    final back = StudySource.fromMap('s1', src.toMap());
    expect(back.transcript.single.text, '오늘은 TCP를 봅니다.');
    expect(back.emphasis.single.t, 754);
    expect(back.emphasis.single.concept, 'TCP 연결 수립');

    // 예전 문서(필드 없음)도 읽힌다
    final old = StudySource.fromMap('s2', {'kind': 'pdf'});
    expect(old.transcript, isEmpty);
    expect(old.emphasis, isEmpty);
  });

  test('녹음 응답에서 전사·강조 발언을 읽고 시간순으로 정렬한다', () {
    const json = '''
{
  "summary": "TCP 연결 과정",
  "transcript": [
    {"t": "1:10", "text": "SYN을 보냅니다"},
    {"t": "0:05", "text": "시작합니다"},
    {"t": "??", "text": "버림"},
    {"t": "2:00", "text": ""}
  ],
  "emphasis": [
    {"t": "12:34", "quote": "3-way handshake는 꼭 나와요", "concept": "TCP 연결 수립"}
  ],
  "cards": [
    {"type": "ox", "question": "UDP는 순서를 보장한다", "choices": [], "answer": "X",
     "explanation": "", "concept": "UDP", "sourceHint": "3:20"}
  ]
}''';
    final r = CardGenerator.parse(json);
    expect(r.transcript.map((l) => l.t), [5, 70]);
    expect(r.emphasis.single.t, 754);
    expect(r.cards.single.sourceHint, '3:20');
  });

  test('사진·PDF 응답에는 전사가 없다', () {
    final r = CardGenerator.parse('{"summary":"s","cards":[]}');
    expect(r.transcript, isEmpty);
    expect(r.emphasis, isEmpty);
  });

  test('녹음 확장자 → MIME', () {
    expect(audioMime('a.MP3'), 'audio/mp3');
    expect(audioMime('lecture.m4a'), 'audio/mp4');
    expect(audioMime('x.wav'), 'audio/wav');
  });

  group('개념별 근거', () {
    QuizCard card(String id, String concept) =>
        QuizCard.sample().copyWith(id: id, concept: concept);

    test('AI 카드·교수님 발언·친구 투표를 개념별로 묶고 교수님 발언 개념이 먼저', () {
      final signals = buildConceptSignals(
        cards: [card('a', 'UDP'), card('b', 'TCP 연결 수립'), card('c', 'udp')],
        emphasis: const [
          EmphasisLine(t: 10, quote: '시험에 나와요', concept: 'TCP연결수립'),
          EmphasisLine(t: 20, quote: '외워 두세요', concept: ''),
        ],
        votesByCardId: const {'a': 3, 'c': 1},
      );
      final tcp = signals.firstWhere((s) => s.concept == 'TCP 연결 수립');
      expect(tcp.cardCount, 1);
      expect(tcp.quotes.single.t, 10);
      final udp = signals.firstWhere((s) => s.concept == 'UDP');
      expect(udp.cardCount, 2);
      expect(udp.votes, 4);
      expect(udp.professorSaid, isFalse);
      final etc = signals.firstWhere((s) => s.concept == '기타');
      expect(etc.cardCount, 0);
      // 교수님 발언 있는 개념이 앞
      expect(signals.first.professorSaid, isTrue);
      expect(signals.last.concept, 'UDP');
    });
  });
}
