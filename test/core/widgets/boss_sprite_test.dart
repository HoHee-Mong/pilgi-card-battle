import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pilgi_card_battle/core/widgets/boss_sprite.dart';

Widget _wrap(Widget child) => MaterialApp(
  home: Scaffold(body: Center(child: child)),
);

BossMood _mood(WidgetTester tester) => tester
    .widget<CustomPaint>(
      find.byWidgetPredicate(
        (w) => w is CustomPaint && w.painter is BossPainter,
      ),
    )
    .painter
    .let((p) => (p! as BossPainter).mood);

extension<T> on T {
  R let<R>(R Function(T) f) => f(this);
}

void main() {
  testWidgets('체력 비율에 따라 표정이 바뀐다', (tester) async {
    await tester.pumpWidget(_wrap(const BossSprite(hp: 20, maxHp: 20)));
    expect(_mood(tester), BossMood.angry);
    await tester.pumpWidget(_wrap(const BossSprite(hp: 5, maxHp: 20)));
    expect(_mood(tester), BossMood.frown);
    await tester.pumpWidget(_wrap(const BossSprite(hp: 0, maxHp: 20)));
    expect(_mood(tester), BossMood.defeated);
  });

  testWidgets('hit()이면 "적중!", miss()면 "빗나감"이 떴다 사라진다', (tester) async {
    final boss = BossController();
    addTearDown(boss.dispose);
    await tester.pumpWidget(
      _wrap(BossSprite(hp: 10, maxHp: 20, controller: boss)),
    );
    expect(find.text('적중!'), findsNothing);

    boss.hit();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('적중!'), findsWidgets);
    await tester.pump(const Duration(seconds: 2));
    expect(find.text('적중!'), findsNothing);

    boss.miss();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('빗나감'), findsWidgets);
    await tester.pump(const Duration(seconds: 2));
    expect(find.text('빗나감'), findsNothing);
  });

  testWidgets('BossHpBar: 남은 체력 문구', (tester) async {
    await tester.pumpWidget(
      _wrap(const BossHpBar(hp: 17, maxHp: 20, name: '영상처리 기말 보스')),
    );
    expect(find.text('남은 체력 17 / 20'), findsOneWidget);
    expect(find.text('영상처리 기말 보스'), findsOneWidget);
  });
}
