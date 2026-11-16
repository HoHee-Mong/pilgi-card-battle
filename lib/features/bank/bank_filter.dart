import '../../core/models/card.dart';
import '../../core/models/room.dart';

/// 문제은행 검색·필터 조건. 비어 있으면 전체.
///
/// 방 하나 = 과목 하나라서 과목 필터는 따로 두지 않는다 (방을 바꾸면 과목이 바뀐다).
class BankFilter {
  const BankFilter({
    this.query = '',
    this.weeks = const {},
    this.types = const {},
  });

  /// 문제·보기·정답·개념에서 찾을 말
  final String query;

  /// 고른 주차 (비면 전체)
  final Set<int> weeks;

  /// 고른 유형 (비면 전체)
  final Set<CardType> types;

  static const none = BankFilter();

  bool get isActive =>
      query.trim().isNotEmpty || weeks.isNotEmpty || types.isNotEmpty;

  BankFilter copyWith({String? query, Set<int>? weeks, Set<CardType>? types}) {
    return BankFilter(
      query: query ?? this.query,
      weeks: weeks ?? this.weeks,
      types: types ?? this.types,
    );
  }

  BankFilter toggleWeek(int w) => copyWith(weeks: {...weeks}..toggle(w));

  BankFilter toggleType(CardType t) => copyWith(types: {...types}..toggle(t));
}

extension<T> on Set<T> {
  void toggle(T v) {
    if (!remove(v)) add(v);
  }
}

/// 유형 이름 (필터 칩)
const cardTypeLabels = {
  CardType.mcq: '객관식',
  CardType.ox: 'OX',
  CardType.short: '단답형',
};

/// 검색 비교용: 공백 없애고 소문자
String _norm(String s) => s.replaceAll(RegExp(r'\s+'), '').toLowerCase();

/// [entries](정렬된 순서 유지)에서 [filter]에 맞는 것만.
///
/// 카드 본문이 아직 안 불러와졌으면([cards]에 없음) 검색어·유형은 판단할 수 없어서 뺀다.
List<BankEntry> filterBank(
  List<BankEntry> entries,
  Map<String, QuizCard> cards,
  BankFilter filter,
) {
  if (!filter.isActive) return entries;
  final q = _norm(filter.query);
  return [
    for (final e in entries)
      if (_matches(e, cards[e.cardId], filter, q)) e,
  ];
}

bool _matches(BankEntry e, QuizCard? card, BankFilter f, String q) {
  if (f.weeks.isNotEmpty && !f.weeks.contains(e.week)) return false;
  if (f.types.isEmpty && q.isEmpty) return true;
  if (card == null) return false;
  if (f.types.isNotEmpty && !f.types.contains(card.type)) return false;
  if (q.isEmpty) return true;
  final text = _norm(
    [card.question, ...card.choices, card.answer, card.concept].join(' '),
  );
  return text.contains(q);
}
