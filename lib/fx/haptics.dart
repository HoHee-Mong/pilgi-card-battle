import 'package:flutter/services.dart';

import 'game_settings.dart';

/// 진동 모음. 규칙은 `docs/DESIGN.md` 모션 항목. 설정에서 끄면 울리지 않는다.
abstract final class Haptics {
  static Future<void> _ifOn(Future<void> Function() f) =>
      GameSettings.haptics ? f() : Future.value();

  /// 가벼운 반응: 투표, 정답
  static Future<void> light() => _ifOn(HapticFeedback.lightImpact);

  /// 묵직한 반응: 오답
  static Future<void> medium() => _ifOn(HapticFeedback.mediumImpact);

  /// 선택 바뀜: 정렬 탭 등
  static Future<void> selection() => _ifOn(HapticFeedback.selectionClick);
}
