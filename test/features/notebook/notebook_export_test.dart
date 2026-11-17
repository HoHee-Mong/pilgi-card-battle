import 'package:flutter_test/flutter_test.dart';
import 'package:pilgi_card_battle/core/models/card.dart';
import 'package:pilgi_card_battle/features/notebook/notebook_export.dart';

void main() {
  final mcq = QuizCard.sample(0).copyWith(id: 'a', week: 3);
  final ox = QuizCard.sample(1).copyWith(id: 'b', week: 2);

  NotebookExport build({bool withAnswers = true, int? votes}) =>
      NotebookExport.build(
        subjectName: '컴퓨터 네트워크',
        scope: ExportScope.myVerified,
        withAnswers: withAnswers,
        cards: [
          (card: mcq, votes: votes, author: votes == null ? null : '선우'),
          (card: ox, votes: null, author: null),
        ],
        sources: const [],
        now: DateTime(2026, 11, 17),
      );

  test('주차 오름차순, 번호는 이어서', () {
    final e = build();
    expect(e.weeks.map((w) => w.week), [2, 3]);
    expect(e.cardCount, 2);
    final text = e.toText();
    expect(text.indexOf('2주차'), lessThan(text.indexOf('3주차')));
    expect(text, contains('1. [OX]'));
    expect(text, contains('2. [객관식]'));
    expect(text, contains(NotebookExport.notice));
  });

  test('정답·해설 끄면 정답이 안 들어간다', () {
    expect(build().toText(), contains('정답:'));
    expect(build(withAnswers: false).toText(), isNot(contains('정답:')));
  });

  test('방 카드는 작성자·투표 수 표시', () {
    expect(build(votes: 3).toText(), contains('(선우 · 나올 것 같아요 3)'));
  });

  test('파일 이름에 과목·날짜, 공백은 밑줄', () {
    expect(build().fileName, '족보_컴퓨터_네트워크_20261117.pdf');
  });
}
