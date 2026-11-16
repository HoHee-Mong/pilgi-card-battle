import 'package:flutter_test/flutter_test.dart';
import 'package:pilgi_card_battle/core/theme/layout.dart';
import 'package:pilgi_card_battle/core/theme/tokens.dart';

void main() {
  test('폰 폭이면 기본 여백 18', () {
    expect(AppLayout.sideFor(390), AppSpacing.page);
  });

  test('태블릿 폭이면 내용이 600이 되도록 좌우를 늘린다', () {
    expect(AppLayout.sideFor(1000), 200);
  });
}
