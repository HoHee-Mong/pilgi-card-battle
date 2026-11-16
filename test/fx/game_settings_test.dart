import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pilgi_card_battle/core/widgets/chunky_button.dart';
import 'package:pilgi_card_battle/fx/confetti.dart';
import 'package:pilgi_card_battle/fx/game_settings.dart';
import 'package:pilgi_card_battle/fx/motion.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('설정은 저장되고 다시 켜면 그대로 읽힌다', () async {
    SharedPreferences.setMockInitialValues({});
    GameSettings.load(await SharedPreferences.getInstance());
    expect(GameSettings.haptics, isTrue);
    expect(GameSettings.reduceMotion, isFalse);

    await GameSettings.setHaptics(false);
    await GameSettings.setReduceMotion(true);

    // 앱 재시작 흉내: 기본값으로 돌려놓고 다시 읽기
    GameSettings.haptics = true;
    GameSettings.reduceMotion = false;
    GameSettings.load(await SharedPreferences.getInstance());
    expect(GameSettings.haptics, isFalse);
    expect(GameSettings.reduceMotion, isTrue);
  });

  Widget wrap(Widget child, {bool reduce = false, double scale = 1}) =>
      MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(
            disableAnimations: reduce,
            textScaler: TextScaler.linear(scale),
          ),
          child: Scaffold(body: Center(child: child)),
        ),
      );

  testWidgets('애니메이션 줄이기면 색종이를 그리지 않는다', (tester) async {
    await tester.pumpWidget(wrap(const ConfettiRain(), reduce: true));
    expect(
      find.descendant(
        of: find.byType(ConfettiRain),
        matching: find.byType(CustomPaint),
      ),
      findsNothing,
    );
  });

  testWidgets('애니메이션 줄이기면 motionReduced가 true', (tester) async {
    late bool reduced;
    await tester.pumpWidget(
      wrap(
        Builder(
          builder: (c) {
            reduced = motionReduced(c);
            return const SizedBox();
          },
        ),
        reduce: true,
      ),
    );
    expect(reduced, isTrue);
  });

  testWidgets('글자를 크게 하면 버튼도 높아진다', (tester) async {
    await tester.pumpWidget(wrap(ChunkyButton(label: '시작', onPressed: () {})));
    final normal = tester.getSize(find.byType(ChunkyButton)).height;
    await tester.pumpWidget(
      wrap(ChunkyButton(label: '시작', onPressed: () {}), scale: 1.5),
    );
    await tester.pumpAndSettle(); // 높이는 부드럽게 바뀐다
    final big = tester.getSize(find.byType(ChunkyButton)).height;
    expect(big, greaterThan(normal));
  });
}
