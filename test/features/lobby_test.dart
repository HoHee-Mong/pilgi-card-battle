import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pilgi_card_battle/core/models/subject.dart';
import 'package:pilgi_card_battle/core/widgets/app_shell.dart';
import 'package:pilgi_card_battle/features/room/lobby_screen.dart';

Subject _s(String name, DateTime? exam) => Subject(
  id: name,
  ownerId: 'u',
  name: name,
  examDate: exam,
  createdAt: DateTime(2026),
);

void main() {
  group('nextExam', () {
    final now = DateTime(2026, 11, 16, 15);

    test('지난 시험·시험일 없는 과목은 빼고 가장 가까운 시험', () {
      final subjects = [
        _s('지난', DateTime(2026, 11, 10)),
        _s('없음', null),
        _s('먼', DateTime(2026, 12, 20)),
        _s('가까운', DateTime(2026, 11, 28)),
      ];
      expect(nextExam(subjects, now: now)?.name, '가까운');
    });

    test('오늘 시험도 포함', () {
      expect(
        nextExam([_s('오늘', DateTime(2026, 11, 16))], now: now)?.name,
        '오늘',
      );
    });

    test('후보가 없으면 null', () {
      expect(nextExam([_s('없음', null)], now: now), isNull);
    });
  });

  testWidgets('AppTabBar: 탭 4개, 누르면 그 번호', (tester) async {
    int? tapped;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          bottomNavigationBar: AppTabBar(
            current: 0,
            labels: AppShell.tabs,
            onTap: (i) => tapped = i,
          ),
        ),
      ),
    );
    for (final label in ['로비', '문제은행', '모의고사', '내 카드']) {
      expect(find.text(label), findsOneWidget);
    }
    await tester.tap(find.text('내 카드'));
    expect(tapped, 3);
  });
}
