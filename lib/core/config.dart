/// AI 비용·시간 제한값. 한곳에서 바꾼다 (docs/SPEC.md "기획상 원칙").
class AppLimits {
  AppLimits._();

  /// 한 사람이 하루에 AI로 자료를 분석할 수 있는 횟수 (사진 묶음·PDF·녹음 한 개 = 1회).
  static const dailyGenerations = 20;

  /// 녹음 파일 길이 안내값(분). 웹에서는 길이를 미리 재기 어려워서 용량(15MB)으로 막고,
  /// 프롬프트·안내 문구에 이 값을 쓴다.
  static const maxAudioMinutes = 30;

  /// 녹음 전사본 최대 줄 수 (Firestore 문서 1MB·응답 시간 때문에 핵심 구간만 남긴다).
  static const maxTranscriptLines = 120;
}
