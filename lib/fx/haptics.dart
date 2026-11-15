import 'package:flutter/services.dart';

/// 진동 모음. 규칙은 `docs/DESIGN.md` 모션 항목.
abstract final class Haptics {
  /// 가벼운 반응: 투표, 정답
  static Future<void> light() => HapticFeedback.lightImpact();

  /// 묵직한 반응: 오답
  static Future<void> medium() => HapticFeedback.mediumImpact();

  /// 선택 바뀜: 정렬 탭 등
  static Future<void> selection() => HapticFeedback.selectionClick();
}
