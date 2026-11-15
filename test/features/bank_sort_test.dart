import 'package:flutter_test/flutter_test.dart';
import 'package:pilgi_card_battle/core/models/room.dart';
import 'package:pilgi_card_battle/features/bank/bank_repository.dart';
import 'package:pilgi_card_battle/features/room/room_repository.dart';

BankEntry _e(String id, {int votes = 0, int week = 1, int hour = 0}) =>
    BankEntry(
      cardId: id,
      addedBy: 'u',
      addedByNickname: 'n',
      week: week,
      voteCount: votes,
      addedAt: DateTime(2026, 11, 12, hour),
    );

void main() {
  final entries = [
    _e('a', votes: 1, week: 4, hour: 1),
    _e('b', votes: 3, week: 3, hour: 2),
    _e('c', votes: 3, week: 4, hour: 5),
    _e('d', votes: 0, week: 3, hour: 9),
  ];

  List<String> ids(List<BankEntry> l) => l.map((e) => e.cardId).toList();

  test('투표순: 표 많은 순, 같으면 최신 먼저', () {
    expect(ids(BankRepository.sortEntries(entries, BankSort.votes)), [
      'c',
      'b',
      'a',
      'd',
    ]);
  });

  test('최신순', () {
    expect(ids(BankRepository.sortEntries(entries, BankSort.latest)), [
      'd',
      'c',
      'b',
      'a',
    ]);
  });

  test('주차순: 주차 오름차순, 안에서는 투표순', () {
    expect(ids(BankRepository.sortEntries(entries, BankSort.week)), [
      'b',
      'd',
      'c',
      'a',
    ]);
  });

  test('topVoted: 주차 범위와 개수 제한', () {
    expect(ids(BankRepository.pickTopVoted(entries, limit: 2)), ['c', 'b']);
    expect(ids(BankRepository.pickTopVoted(entries, weeks: [4], limit: 10)), [
      'c',
      'a',
    ]);
  });

  test('초대 코드 정리', () {
    expect(RoomRepository.normalizeCode(' k7q 2mx '), 'K7Q2MX');
  });
}
