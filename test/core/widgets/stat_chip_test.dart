import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pilgi_card_battle/core/widgets/stat_chip.dart';

void main() {
  testWidgets('좁은 자리에서 긴 글자는 넘치지 않고 말줄임된다', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 120,
              child: Row(
                children: [
                  Flexible(
                    child: StatChip(
                      label: '아주아주 긴 방 이름입니다 정말로 깁니다 · 12명',
                      icon: Icons.expand_more_rounded,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    // 넘침(RenderFlex overflowed)이 나면 여기서 예외가 잡힌다.
    expect(tester.takeException(), isNull);
    expect(tester.getSize(find.byType(StatChip)).width, lessThanOrEqualTo(120));
  });

  testWidgets('짧은 글자는 글자 폭만큼만 차지한다', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(child: StatChip(label: '방장')),
        ),
      ),
    );
    expect(tester.getSize(find.byType(StatChip)).width, lessThan(200));
  });
}
