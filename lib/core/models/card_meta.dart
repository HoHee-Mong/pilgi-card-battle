/// `users/{uid}/cardMeta/{cardId}` — 사용자별 카드 상태 (A). docs/DATA.md와 1:1.
///
/// 문서가 없으면 전부 false로 본다. 틀리면 [inWrongNote]가 true,
/// 오답 노트에서 다시 맞히면 [reviewedDone]이 true.
class CardMeta {
  const CardMeta({
    required this.cardId,
    this.favorite = false,
    this.inWrongNote = false,
    this.reviewedDone = false,
  });

  /// Firestore 문서 ID(= cardId). `toMap`에는 넣지 않는다.
  final String cardId;
  final bool favorite;
  final bool inWrongNote;
  final bool reviewedDone;

  /// 오답 노트에 남아 있고 아직 복습 전
  bool get needsReview => inWrongNote && !reviewedDone;

  factory CardMeta.fromMap(String cardId, Map<String, dynamic> map) {
    return CardMeta(
      cardId: cardId,
      favorite: map['favorite'] as bool? ?? false,
      inWrongNote: map['inWrongNote'] as bool? ?? false,
      reviewedDone: map['reviewedDone'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'favorite': favorite,
      'inWrongNote': inWrongNote,
      'reviewedDone': reviewedDone,
    };
  }

  CardMeta copyWith({bool? favorite, bool? inWrongNote, bool? reviewedDone}) {
    return CardMeta(
      cardId: cardId,
      favorite: favorite ?? this.favorite,
      inWrongNote: inWrongNote ?? this.inWrongNote,
      reviewedDone: reviewedDone ?? this.reviewedDone,
    );
  }
}
