import 'package:flutter_test/flutter_test.dart';
import 'package:pilgi_card_battle/features/subjects/subject_utils.dart';

void main() {
  final today = DateTime(2026, 11, 12, 15, 30);

  test('시험일 없음 → null', () {
    expect(examDDayLabel(null, now: today), isNull);
  });

  test('D-day 계산은 시간을 무시한다', () {
    expect(examDDayLabel(DateTime(2026, 11, 12, 9), now: today), '오늘 시험');
    expect(examDDayLabel(DateTime(2026, 11, 13, 1), now: today), 'D-1');
    expect(examDDayLabel(DateTime(2026, 12, 2), now: today), 'D-20');
    expect(examDDayLabel(DateTime(2026, 11, 10), now: today), '시험 끝 (D+2)');
  });
}
