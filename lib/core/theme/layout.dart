import 'package:flutter/widgets.dart';

import 'tokens.dart';

/// 화면 폭 대응. 폰은 좌우 여백 18, 태블릿·넓은 창은 가운데 [maxContent] 폭으로 모은다.
abstract final class AppLayout {
  /// 내용이 가장 넓어지는 폭 (폰 시안 기준 + 여유)
  static const maxContent = 600.0;

  /// 기기 글자 크기 설정을 따르되 이 배수까지만 (버튼·카드가 깨지지 않게)
  static const maxTextScale = 1.6;

  /// 화면 폭에 맞는 좌우 여백
  static double sideFor(double screenWidth) {
    final extra = (screenWidth - maxContent) / 2;
    return extra > AppSpacing.page ? extra : AppSpacing.page;
  }

  /// 화면 단위 목록의 padding. 넓은 화면에서는 좌우를 늘려 가운데로 모은다.
  static EdgeInsets pagePadding(
    BuildContext context, {
    double top = 0,
    double bottom = 0,
  }) {
    final side = sideFor(MediaQuery.sizeOf(context).width);
    return EdgeInsets.fromLTRB(side, top, side, bottom);
  }
}
