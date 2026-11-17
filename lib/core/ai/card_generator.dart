import 'dart:convert';
import 'dart:typed_data';

import 'package:firebase_ai/firebase_ai.dart';

import '../models/card.dart';
import '../models/source.dart';

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
  const GenerationResult({
    required this.summary,
    required this.cards,
    this.transcript = const [],
  });

  final String summary;
  final List<GeneratedCard> cards;

  /// 녹음일 때 시간별 전사 (시간순). 다른 자료는 빈 목록.
  final List<TranscriptLine> transcript;
}

class CardGenerateOptions {
  const CardGenerateOptions({
    this.count = 10,
    this.types = const {CardType.mcq, CardType.ox, CardType.short},
  });

  final int count;
  final Set<CardType> types;

  static const counts = [5, 10, 15, 20, 30];
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
  CardGenerator({GenerativeModel? model, GenerativeModel? audioModel})
    : _model = model ?? defaultModel(),
      _audioModel = audioModel ?? defaultAudioModel();

  final GenerativeModel _model;

  /// 녹음 전용 (전사가 들어간 스키마)
  final GenerativeModel _audioModel;

  static const modelName = 'gemini-3.8-flash';

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

  static GenerativeModel defaultAudioModel() {
    return FirebaseAI.googleAI().generativeModel(
      model: modelName,
      generationConfig: GenerationConfig(
        responseMimeType: 'application/json',
        responseSchema: audioResponseSchema,
        temperature: 0.3,
      ),
    );
  }

  /// 녹음 응답 스키마: 요약 + 시간별 전사 + 카드(근거 시각 포함).
  static final Schema audioResponseSchema = Schema.object(
    properties: {
      'summary': Schema.string(description: '강의 핵심 요약 3~5문장 (한국어)'),
      'transcript': Schema.array(
        items: Schema.object(
          properties: {
            't': Schema.integer(description: '이 문단이 시작하는 시각 (녹음 시작부터 초)'),
            'text': Schema.string(description: '그 시각부터 말한 내용 (한국어 전사)'),
          },
        ),
      ),
      'cards': Schema.array(items: _cardSchema(audio: true)),
    },
  );

  /// 응답 JSON 스키마. 모델이 이 모양으로만 답하게 강제한다.
  static final Schema responseSchema = Schema.object(
    properties: {
      'summary': Schema.string(description: '자료의 핵심 요약 3~5문장 (한국어)'),
      'cards': Schema.array(items: _cardSchema(audio: false)),
    },
  );

  /// 카드 한 장 스키마. 녹음이면 근거 시각(sourceSec)을 받는다.
  static Schema _cardSchema({required bool audio}) => Schema.object(
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
      'sourceHint': Schema.string(description: '자료 안 위치. 예: "p.3", "둘째 장 공식"'),
      if (audio)
        'sourceSec': Schema.integer(description: '이 문제의 근거를 말한 시각 (녹음 시작부터 초)'),
    },
    optionalProperties: ['sourceHint', if (audio) 'sourceSec'],
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

  /// 녹음용 프롬프트: 시간별 전사 → 요약 → 카드(근거 시각).
  static String buildAudioPrompt({
    required String subjectName,
    required int week,
    required CardGenerateOptions options,
  }) {
    final types = options.types
        .map((t) => '${t.name}=${typeLabel(t)}')
        .join(', ');
    return '''
너는 대학 시험 출제 보조다. 첨부한 오디오는 "$subjectName" 과목 $week주차 강의 녹음이다.

할 일:
1. 강의를 한국어로 전사한다 (transcript). 말이 이어지는 문단 단위(대략 20~60초)로 나누고,
   각 문단이 시작하는 시각을 녹음 시작부터 초(t, 정수)로 적는다. 시간순으로 적는다.
   "음", "어" 같은 군말과 강의와 상관없는 잡담은 줄여도 된다. 들리지 않는 부분은 지어내지 말고 건너뛴다.
2. 강의의 핵심을 한국어 3~5문장으로 요약한다 (summary).
3. 시험에 나올 만한 문제를 정확히 ${options.count}개 만든다 (cards).

카드 규칙:
- 녹음에서 실제로 말한 내용만 쓴다. 말하지 않은 사실을 지어내지 않는다.
- 허용 유형: $types. 이 유형들을 고르게 섞는다.
- mcq: 보기(choices) 정확히 4개, 정답 1개. answer는 정답 보기의 텍스트를 그대로 적는다.
- ox: choices는 빈 배열, answer는 "O" 또는 "X". 틀린 문장은 핵심 단어 하나만 바꿔서 만든다.
- short: choices는 빈 배열, answer는 단어 또는 짧은 구(10자 이내 권장).
- explanation: 왜 그 답인지 강의 내용 근거로 1~2문장.
- concept: 이 문제의 개념 태그 (2~5단어). 비슷한 문제는 같은 태그를 쓴다.
- sourceSec: 이 문제의 근거를 말한 시각 (초, 정수). sourceHint는 빈 문자열.
- 모든 문장은 한국어. 문제에 "강의에 따르면" 같은 말은 넣지 않는다.
''';
  }

  static bool _isAudio(InlineFile f) => f.mimeType.startsWith('audio/');

  /// [files]는 이미지(jpeg/png)·PDF 여러 개, 또는 녹음 하나. 사진 여러 장은 한 요청에 같이 보낸다.
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
    // 녹음은 한 요청에 하나만 보내고, 전사가 들어간 스키마로 받는다.
    final audio = files.any(_isAudio);
    if (audio && files.length > 1) {
      throw const CardGenerationException('녹음은 한 번에 하나만 보낼 수 있어요.');
    }
    final prompt = audio
        ? buildAudioPrompt(
            subjectName: subjectName,
            week: week,
            options: options,
          )
        : buildPrompt(subjectName: subjectName, week: week, options: options);
    GenerateContentResponse response;
    try {
      response = await (audio ? _audioModel : _model).generateContent([
        Content.multi([
          TextPart(prompt),
          for (final f in files) InlineDataPart(f.mimeType, f.bytes),
        ]),
      ]);
    } on FirebaseAIException catch (e) {
      throw CardGenerationException(friendlyError(e.message));
    }
    final text = response.text;
    if (text == null || text.trim().isEmpty) {
      throw const CardGenerationException('AI가 빈 응답을 보냈어요. 다시 시도해 주세요.');
    }
    final result = parse(text, allowedTypes: options.types);
    if (result.cards.isEmpty) {
      throw CardGenerationException(
        audio
            ? '녹음에서 문제를 만들지 못했어요. 강의 소리가 잘 들리는지 확인해 주세요.'
            : '자료에서 문제를 만들지 못했어요. 글씨가 잘 보이는 사진인지 확인해 주세요.',
      );
    }
    return result;
  }

  /// AI 오류 메시지를 사용자용 문장으로. (붐빔·시간 초과는 다시 시도하면 되는 경우가 많다)
  static String friendlyError(String message) {
    final m = message.toLowerCase();
    if (m.contains('high demand') ||
        m.contains('overloaded') ||
        m.contains('unavailable') ||
        m.contains('try again later')) {
      return 'AI가 지금 너무 붐벼요. 잠시 후 다시 시도해 주세요.';
    }
    if (m.contains('deadline') ||
        m.contains('timeout') ||
        m.contains('timed out')) {
      return 'AI 응답이 너무 오래 걸렸어요. 잠시 후 다시 시도하거나 더 짧은 자료로 올려 주세요.';
    }
    if (m.contains('quota') ||
        m.contains('resource_exhausted') ||
        m.contains('rate')) {
      return '오늘 AI 사용량이 많아요. 잠시 후 다시 시도해 주세요.';
    }
    return 'AI 호출에 실패했어요: $message';
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
    final transcript = <TranscriptLine>[];
    final rawLines = decoded['transcript'];
    if (rawLines is List) {
      for (final raw in rawLines) {
        if (raw is! Map) continue;
        final text = (raw['text'] as String? ?? '').trim();
        if (text.isEmpty) continue;
        transcript.add(TranscriptLine(t: _toSeconds(raw['t']), text: text));
      }
      transcript.sort((a, b) => a.t.compareTo(b.t));
    }
    return GenerationResult(
      summary: summary,
      cards: cards,
      transcript: transcript,
    );
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
      sourceHint: _hint(m),
    );
  }

  /// 근거 위치. 녹음이면 근거 시각을 "23:41"로.
  static String _hint(Map<String, dynamic> m) {
    final hint = (m['sourceHint'] as String? ?? '').trim();
    if (hint.isNotEmpty || m['sourceSec'] == null) return hint;
    return formatSeconds(_toSeconds(m['sourceSec']));
  }

  /// 초 값 (정수·실수·"83" 모두). 음수나 이상한 값은 0.
  static int _toSeconds(Object? v) {
    final n = switch (v) {
      final num x => x.round(),
      final String x => num.tryParse(x.trim())?.round() ?? 0,
      _ => 0,
    };
    return n < 0 ? 0 : n;
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
