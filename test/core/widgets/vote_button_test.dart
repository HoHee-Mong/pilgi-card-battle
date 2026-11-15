import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pilgi_card_battle/core/models/room.dart';
import 'package:pilgi_card_battle/core/theme/app_theme.dart';
import 'package:pilgi_card_battle/core/widgets/vote_button.dart';

void main() {
  group('투표 문구', () {
    test('아무도 없으면 빈 문자열', () {
      expect(voterSummaryText([]), '');
    });

    test('한 명: 받침에 따라 이/가', () {
      expect(voterSummaryText(['선우']), '선우가 나올 것 같대요');
      expect(voterSummaryText(['승호']), '승호가 나올 것 같대요');
      expect(voterSummaryText(['지민']), '지민이 나올 것 같대요');
    });

    test('여러 명: "외 N명"', () {
      expect(voterSummaryText(['선우', 'a', 'b']), '선우 외 2명이 나올 것 같대요');
    });

    test('내가 투표했으면 "나"로', () {
      expect(voterSummaryText(['선우', '승호'], me: '승호'), '나 외 1명이 나올 것 같대요');
      expect(voterSummaryText(['승호'], me: '승호'), '나만 나올 것 같다고 했어요');
    });

    test('uid → 닉네임 변환, 모르는 사람은 "친구"', () {
      final text = voterSummaryFor(BankEntry.sample(0), Room.sample());
      // sample(0) 투표자: sample-user-2(선우), u3, u4
      expect(text, '선우 외 2명이 나올 것 같대요');
      final unknown = BankEntry.sample(0).copyWith(voters: ['zz']);
      expect(voterSummaryFor(unknown, Room.sample()), '친구가 나올 것 같대요');
    });
  });

  testWidgets('VoteChip: 숫자 표시, 누르면 onTap, 숫자 바뀌면 새 숫자', (tester) async {
    var taps = 0;
    Widget chip(int count, bool voted) => MaterialApp(
      theme: AppTheme.light(),
      home: Scaffold(
        body: Center(
          child: VoteChip(count: count, voted: voted, onTap: () => taps++),
        ),
      ),
    );

    await tester.pumpWidget(chip(2, false));
    expect(find.text('나올 것 같아요'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);

    await tester.tap(find.byType(VoteChip));
    await tester.pumpAndSettle();
    expect(taps, 1);

    await tester.pumpWidget(chip(3, true));
    await tester.pumpAndSettle();
    expect(find.text('3'), findsOneWidget);
    expect(find.text('2'), findsNothing);
  });
}
