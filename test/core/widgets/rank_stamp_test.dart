import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pilgi_card_battle/core/widgets/rank_stamp.dart';

void main() {
  testWidgets('RankStamp: 랭크 글자를 보여 준다', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(child: RankStamp(rank: 'S')),
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('S'), findsWidgets);
    expect(find.bySemanticsLabel('랭크 S'), findsOneWidget);
  });
}
