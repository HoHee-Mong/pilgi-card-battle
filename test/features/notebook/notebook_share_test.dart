import 'package:flutter_test/flutter_test.dart';
import 'package:pilgi_card_battle/core/models/card.dart';
import 'package:pilgi_card_battle/core/router.dart';
import 'package:pilgi_card_battle/features/notebook/notebook_export.dart';
import 'package:pilgi_card_battle/features/notebook/notebook_share.dart';

void main() {
  group('parseShareCode', () {
    test('코드만, 소문자, 링크 모두', () {
      expect(parseShareCode('abc234'), 'ABC234');
      expect(parseShareCode(' ABC-234 '), 'ABC234');
      expect(parseShareCode('http://localhost:5051/#/share/XYZ789'), 'XYZ789');
      expect(parseShareCode('ABC'), isNull);
    });
  });

  test('공유 족보 저장·읽기 그대로, 받는 카드는 검수 상태 유지', () {
    final verified = QuizCard.sample(0)
        .copyWith(week: 3, status: CardStatus.verified);
    final draft = QuizCard.sample(1)
        .copyWith(week: 4, status: CardStatus.draft);
    final share = NotebookShare(
      code: 'ABC234',
      ownerId: 'u1',
      ownerNickname: '선우',
      subjectName: '네트워크',
      scope: ExportScope.room,
      summaries: const [(week: 3, label: '3주차.pdf', summary: '요약')],
      cards: [
        SharedCard.fromExport((card: verified, votes: 2, author: '승호')),
        SharedCard.fromExport((card: draft, votes: null, author: null)),
      ],
      createdAt: DateTime(2026, 11, 17),
    );
    final back = NotebookShare.fromMap('ABC234', share.toMap());
    expect(back.cards, hasLength(2));
    expect(back.weeks, [3, 4]);
    expect(back.summaries.single.summary, '요약');
    expect(back.cards.first.votes, 2);
    expect(back.cards.first.choices, verified.choices);

    final mine = back.cards.first.toQuizCard(
      id: 'n1',
      ownerId: 'me',
      ownerNickname: '나',
      subjectId: 's',
      sourceId: 'src',
      from: '선우',
      now: DateTime(2026, 11, 18),
    );
    expect(mine.ownerId, 'me');
    expect(mine.isVerified, isTrue);
    expect(mine.sourceLabel, startsWith('선우 족보'));
    expect(
      back.cards.last
          .toQuizCard(
            id: 'n2',
            ownerId: 'me',
            ownerNickname: '나',
            subjectId: 's',
            sourceId: 'src',
            from: '선우',
            now: DateTime(2026, 11, 18),
          )
          .isVerified,
      isFalse,
    );

    final export = back.toExport();
    expect(export.cardCount, 2);
    expect(export.toText(), contains('(승호 · 나올 것 같아요 2)'));
  });

  test('공유 링크로 왔는데 로그인 전이면 로그인 뒤 그 링크로', () {
    final r = loginRedirect(canEnter: false, at: '/share/ABC234');
    expect(r, '/login?next=%2Fshare%2FABC234');
    expect(
      loginRedirect(canEnter: true, at: AppRoutes.login, next: '/share/ABC234'),
      '/share/ABC234',
    );
    // 다른 곳으로는 보내지 않는다
    expect(
      loginRedirect(canEnter: true, at: AppRoutes.login, next: 'https://x.y'),
      AppRoutes.lobby,
    );
    expect(loginRedirect(canEnter: true, at: '/share/ABC234'), isNull);
  });
}
