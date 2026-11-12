import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pilgi_card_battle/core/theme/app_theme.dart';
import 'package:pilgi_card_battle/core/widgets/pressable_scale.dart';
import 'package:pilgi_card_battle/core/widgets/primary_button.dart';
import 'package:pilgi_card_battle/core/widgets/section_card.dart';

Widget _wrap(Widget child) => MaterialApp(
  theme: AppTheme.light(),
  home: Scaffold(body: Center(child: child)),
);

double _currentScale(WidgetTester tester) {
  final transition = tester.widget<ScaleTransition>(
    find.descendant(
      of: find.byType(PressableScale),
      matching: find.byType(ScaleTransition),
    ),
  );
  return transition.scale.value;
}

void main() {
  testWidgets('PressableScale: 누르면 줄고 떼면 돌아오며 onTap 호출', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      _wrap(
        PressableScale(
          onTap: () => taps++,
          child: const SizedBox(width: 100, height: 100),
        ),
      ),
    );

    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(PressableScale)),
    );
    await tester.pumpAndSettle();
    expect(_currentScale(tester), closeTo(0.96, 0.001));

    await gesture.up();
    await tester.pumpAndSettle();
    expect(_currentScale(tester), closeTo(1.0, 0.001));
    expect(taps, 1);
  });

  testWidgets('PressableScale: onTap이 없으면 줄어들지 않음', (tester) async {
    await tester.pumpWidget(
      _wrap(const PressableScale(child: SizedBox(width: 100, height: 100))),
    );
    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(PressableScale)),
    );
    await tester.pumpAndSettle();
    expect(_currentScale(tester), 1.0);
    await gesture.up();
  });

  testWidgets('PrimaryButton: 누르면 onPressed 호출', (tester) async {
    var pressed = false;
    await tester.pumpWidget(
      _wrap(PrimaryButton(label: '방 만들기', onPressed: () => pressed = true)),
    );
    expect(find.text('방 만들기'), findsOneWidget);
    await tester.tap(find.text('방 만들기'));
    await tester.pumpAndSettle();
    expect(pressed, isTrue);
  });

  testWidgets('PrimaryButton: loading이면 스피너, 눌러도 호출 안 됨', (tester) async {
    var pressed = false;
    await tester.pumpWidget(
      _wrap(
        PrimaryButton(
          label: '저장',
          loading: true,
          onPressed: () => pressed = true,
        ),
      ),
    );
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await tester.tap(find.byType(PrimaryButton));
    await tester.pump(const Duration(milliseconds: 400));
    expect(pressed, isFalse);
  });

  testWidgets('PrimaryButton: 모든 tone 렌더링', (tester) async {
    for (final tone in ButtonTone.values) {
      await tester.pumpWidget(
        _wrap(PrimaryButton(label: tone.name, tone: tone, onPressed: () {})),
      );
      expect(find.text(tone.name), findsOneWidget);
    }
  });

  testWidgets('SectionCard: 제목·trailing·본문 표시, onTap 호출', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      _wrap(
        SectionCard(
          title: '우리가 뽑은 예상 문제',
          trailing: const Text('전체'),
          onTap: () => taps++,
          child: const Text('본문'),
        ),
      ),
    );
    expect(find.text('우리가 뽑은 예상 문제'), findsOneWidget);
    expect(find.text('전체'), findsOneWidget);
    expect(find.text('본문'), findsOneWidget);
    await tester.tap(find.text('본문'));
    await tester.pumpAndSettle();
    expect(taps, 1);
  });
}
