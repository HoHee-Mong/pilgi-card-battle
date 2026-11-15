import 'dart:convert';
import 'dart:typed_data';

import 'package:firebase_ai/firebase_ai.dart';

import '../models/card.dart';

/// AI가 만든 카드 한 장 (저장 전). 저장할 때는 항상 `draft`.
class GeneratedCard {
  const GeneratedCard({
    required this.type,
    required this.question,
    this.choices = const [],
    required this.answer,
    required this.explanation,
    required this.concept,
    this.sourceHint = '',
  });

  final CardType type;
  final String question;
  final List<String> choices;
  final String answer;
  final String explanation;
  final String concept;

  /// 자료 안 위치. 예: "p.3", "둘째 장 공식"
  final String sourceHint;
}

/// Gemini로 바로 보내는 파일 하나.
class InlineFile {
  const InlineFile({required this.mimeType, required this.bytes});

  /// 예: "image/jpeg", "application/pdf", "audio/mp4"
  final String mimeType;
  final Uint8List bytes;
}

class GenerationResult {
  const GenerationResult({required this.summary, required this.cards});

  final String summary;
  final List<GeneratedCard> cards;
}

class CardGenerateOptions {
  const CardGenerateOptions({
    this.count = 10,
    this.types = const {CardType.mcq, CardType.ox, CardType.short},
  });

  final int count;
  final Set<CardType> types;

  static const counts = [5, 10, 15];
}

class CardGenerationException implements Exception {
  const CardGenerationException(this.message);
  final String message;

  @override
  String toString() => 'CardGenerationException: $message';
}

/// Gemini(Firebase AI Logic)로 자료 → 요약 + 카드 N개.
/// API 키는 코드에 없다. `firebase_ai`가 Firebase 프로젝트 설정으로 호출한다.
class CardGenerator {
  CardGenerator({GenerativeModel? model}) : _model = model ?? defaultModel();

  final GenerativeModel _model;

  static const modelName = 'gemini-2.5-flash';

  static GenerativeModel defaultModel() {
    return FirebaseAI.googleAI().generativeModel(
      model: modelName,
      generationConfig: GenerationConfig(
        responseMimeType: 'application/json',
        responseSchema: responseSchema,
        temperature: 0.4,
      ),
    );
  }

  /// 응답 JSON 스키마. 모델이 이 모양으로만 답하게 강제한다.
  static final Schema responseSchema = Schema.object(
    properties: {
      'summary': Schema.string(description: '자료의 핵심 요약 3~5문장 (한국어)'),
      'cards': Schema.array(
        items: Schema.object(
          properties: {
            'type': Schema.enumString(enumValues: ['mcq', 'ox', 'short']),
            'question': Schema.string(),
            'choices': Schema.array(
              items: Schema.string(),
              description: 'mcq만 4개. 다른 유형은 빈 배열',
            ),
            'answer': Schema.string(
              description: 'mcq는 정답 보기 텍스트 그대로, ox는 "O" 또는 "X", short는 짧은 정답',
            ),
            'explanation': Schema.string(description: '자료 근거가 드러나는 해설 1~2문장'),
            'concept': Schema.string(description: '개념 태그 2~5단어'),
            'sourceHint': Schema.string(
              description: '자료 안 위치. 예: "p.3", "둘째 장 공식"',
            ),
          },
          optionalProperties: ['sourceHint'],
        ),
      ),
    },
  );

  static String typeLabel(CardType t) => switch (t) {
    CardType.mcq => '객관식(4지선다)',
    CardType.ox => 'OX',
    CardType.short => '단답형',
  };

  static String buildPrompt({
    required String subjectName,
    required int week,
    required CardGenerateOptions options,
  }) {
    final types = options.types
        .map((t) => '${t.name}=${typeLabel(t)}')
        .join(', ');
    return '''
너는 대학 시험 출제 보조다. 첨부한 자료(여러 장일 수 있다)는 "$subjectName" 과목 $week주차의 필기 사진 또는 강의자료다.

할 일:
1. 자료의 핵심을 한국어 3~5문장으로 요약한다 (summary).
2. 시험에 나올 만한 문제를 정확히 ${options.count}개 만든다 (cards).

규칙:
- 자료에 실제로 있는 내용만 쓴다. 자료에 없는 사실을 지어내지 않는다. 글씨가 안 보이면 그 부분은 건너뛴다.
- 허용 유형: $types. 이 유형들을 고르게 섞는다.
- mcq: 보기(choices) 정확히 4개, 정답 1개. answer는 정답 보기의 텍스트를 그대로 적는다. 보기 길이와 형식을 비슷하게 맞춘다.
- ox: choices는 빈 배열, answer는 "O" 또는 "X". 틀린 문장은 핵심 단어 하나만 바꿔서 만든다.
- short: choices는 빈 배열, answer는 단어 또는 짧은 구(10자 이내 권장).
- explanation: 왜 그 답인지 자료 근거로 1~2문장.
- concept: 이 문제의 개념 태그 (2~5단어). 비슷한 문제는 같은 태그를 쓴다.
- sourceHint: 자료 안에서 근거 위치 (예: "p.3", "둘째 장 공식", "표 2"). 모르면 빈 문자열.
- 모든 문장은 한국어. 문제에 "자료에 따르면" 같은 말은 넣지 않는다.
''';
  }

  /// [files]는 이미지(jpeg/png)·PDF·(P2) 오디오. 사진 여러 장은 한 요청에 같이 보낸다.
  /// 원본은 어디에도 저장하지 않고 기기에서 바로 보낸다 (Storage 미사용).
  Future<GenerationResult> generate({
    required List<InlineFile> files,
    required String subjectName,
    required int week,
    CardGenerateOptions options = const CardGenerateOptions(),
  }) async {
    if (files.isEmpty) {
      throw const CardGenerationException('보낼 자료가 없어요.');
    }
    if (options.types.isEmpty) {
      throw const CardGenerationException('문제 유형을 하나 이상 골라 주세요.');
    }
    final prompt = buildPrompt(
      subjectName: subjectName,
      week: week,
      options: options,
    );
    GenerateContentResponse response;
    try {
      response = await _model.generateContent([
        Content.multi([
          TextPart(prompt),
          for (final f in files) InlineDataPart(f.mimeType, f.bytes),
        ]),
      ]);
    } on FirebaseAIException catch (e) {
      throw CardGenerationException('AI 호출에 실패했어요: ${e.message}');
    }
    final text = response.text;
    if (text == null || text.trim().isEmpty) {
      throw const CardGenerationException('AI가 빈 응답을 보냈어요. 다시 시도해 주세요.');
    }
    final result = parse(text, allowedTypes: options.types);
    if (result.cards.isEmpty) {
      throw const CardGenerationException(
        '자료에서 문제를 만들지 못했어요. 글씨가 잘 보이는 사진인지 확인해 주세요.',
      );
    }
    return result;
  }

  /// 응답 JSON → 결과. 규칙에 어긋나는 카드(보기 수, 정답 불일치 등)는 버린다.
  /// Firestore 없이 테스트할 수 있게 순수 함수로 둔다.
  static GenerationResult parse(
    String jsonText, {
    Set<CardType> allowedTypes = const {
      CardType.mcq,
      CardType.ox,
      CardType.short,
    },
  }) {
    Object? decoded;
    try {
      decoded = jsonDecode(_stripCodeFence(jsonText));
    } on FormatException {
      throw const CardGenerationException('AI 응답을 읽지 못했어요. 다시 시도해 주세요.');
    }
    if (decoded is! Map) {
      throw const CardGenerationException('AI 응답 형식이 달라요. 다시 시도해 주세요.');
    }
    final summary = (decoded['summary'] as String? ?? '').trim();
    final rawCards = decoded['cards'];
    final cards = <GeneratedCard>[];
    if (rawCards is List) {
      for (final raw in rawCards) {
        if (raw is! Map) continue;
        final card = _toCard(raw.cast<String, dynamic>());
        if (card != null && allowedTypes.contains(card.type)) cards.add(card);
      }
    }
    return GenerationResult(summary: summary, cards: cards);
  }

  static GeneratedCard? _toCard(Map<String, dynamic> m) {
    CardType? type;
    for (final t in CardType.values) {
      if (t.name == m['type']) type = t;
    }
    final question = (m['question'] as String? ?? '').trim();
    var answer = (m['answer'] as String? ?? '').trim();
    if (type == null || question.isEmpty || answer.isEmpty) return null;

    var choices = <String>[];
    switch (type) {
      case CardType.mcq:
        final raw = m['choices'];
        if (raw is! List) return null;
        choices = raw
            .map((e) => e.toString().trim())
            .where((e) => e.isNotEmpty)
            .toList();
        if (choices.length != 4) return null;
        // 정답이 보기 텍스트와 조금 다르면(공백·마침표) 보기 쪽으로 맞춘다.
        final match = choices.where((c) => _norm(c) == _norm(answer));
        if (match.isEmpty) return null;
        answer = match.first;
      case CardType.ox:
        final up = answer.toUpperCase();
        if (up.startsWith('O') || up == '참' || up == 'TRUE') {
          answer = 'O';
        } else if (up.startsWith('X') || up == '거짓' || up == 'FALSE') {
          answer = 'X';
        } else {
          return null;
        }
      case CardType.short:
        break;
    }
    return GeneratedCard(
      type: type,
      question: question,
      choices: choices,
      answer: answer,
      explanation: (m['explanation'] as String? ?? '').trim(),
      concept: (m['concept'] as String? ?? '').trim(),
      sourceHint: (m['sourceHint'] as String? ?? '').trim(),
    );
  }

  static String _norm(String s) =>
      s.replaceAll(RegExp(r'[\s.。]'), '').toLowerCase();

  static String _stripCodeFence(String s) {
    final t = s.trim();
    if (!t.startsWith('```')) return t;
    final firstNewline = t.indexOf('\n');
    final end = t.lastIndexOf('```');
    if (firstNewline < 0 || end <= firstNewline) return t;
    return t.substring(firstNewline + 1, end).trim();
  }
}
