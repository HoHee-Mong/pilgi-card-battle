/// 주차 범위. SPEC: 1~16주차.
const int kMaxWeek = 16;

/// 시험일까지 남은 날짜 문구. 시험일이 없으면 null.
String? examDDayLabel(DateTime? examDate, {DateTime? now}) {
  if (examDate == null) return null;
  final today = _dateOnly(now ?? DateTime.now());
  final diff = _dateOnly(examDate).difference(today).inDays;
  if (diff == 0) return '오늘 시험';
  if (diff > 0) return 'D-$diff';
  return '시험 끝 (D+${-diff})';
}

DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);
