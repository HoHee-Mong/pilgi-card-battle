import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pilgi_card_battle/core/theme/app_theme.dart';
import 'package:pilgi_card_battle/core/theme/tokens.dart';
import 'package:pilgi_card_battle/core/widgets/chunky_button.dart';
import 'package:pilgi_card_battle/core/widgets/chunky_card.dart';
import 'package:pilgi_card_battle/core/widgets/stat_chip.dart';

Widget _wrap(Widget child) => MaterialApp(
  theme: AppTheme.light(),
  home: Scaffold(body: Center(child: child)),
);

void main() {
  testWidgets('ChunkyButton: 누르면 onPressed가 불린다', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      _wrap(ChunkyButton(label: '시작', onPressed: () => taps++)),
    );
    await tester.tap(find.text('시작'));
    await tester.pumpAndSettle();
    expect(taps, 1);
  });

  testWidgets('ChunkyButton: 누르는 동안 4px 내려간다', (tester) async {
    await tester.pumpWidget(_wrap(ChunkyButton(label: '시작', onPressed: () {})));
    double top() => tester.getTopLeft(find.text('시작')).dy;
    final before = top();
    final gesture = await tester.startGesture(
      tester.getCenter(find.text('시작')),
    );
    await tester.pumpAndSettle();
    expect(top() - before, closeTo(AppBlock.pressDepth, 0.01));
    await gesture.up();
    await tester.pumpAndSettle();
    expect(top(), closeTo(before, 0.01));
  });

  testWidgets('ChunkyButton: onPressed가 null이면 비활성', (tester) async {
    await tester.pumpWidget(
      _wrap(const ChunkyButton(label: '시작', onPressed: null)),
    );
    await tester.tap(find.text('시작'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('ChunkyButton: expand=false인 아이콘 버튼은 정사각형', (tester) async {
    await tester.pumpWidget(
      _wrap(
        ChunkyButton(
          expand: false,
          semanticLabel: '뒤로',
          onPressed: () {},
          child: const Icon(Icons.chevron_left),
        ),
      ),
    );
    final size = tester.getSize(find.byType(AnimatedContainer));
    expect(size.width, size.height);
  });

  testWidgets('ChunkyCard와 StatChip이 그려진다', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      _wrap(
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ChunkyCard(
              title: '오늘의 퀘스트',
              trailing: const StatChip(label: '5일 연속', color: AppColors.sun),
              onTap: () => taps++,
              child: const Text('카드 3장 만들기'),
            ),
          ],
        ),
      ),
    );
    expect(find.text('오늘의 퀘스트'), findsOneWidget);
    expect(find.text('5일 연속'), findsOneWidget);
    await tester.tap(find.text('카드 3장 만들기'));
    await tester.pumpAndSettle();
    expect(taps, 1);
  });
}
