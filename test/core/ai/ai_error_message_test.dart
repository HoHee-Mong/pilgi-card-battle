import 'package:flutter_test/flutter_test.dart';
import 'package:pilgi_card_battle/core/ai/card_generator.dart';

void main() {
  test('붐빔은 다시 시도 안내', () {
    expect(
      CardGenerator.friendlyError(
        'This model is currently experiencing high demand. '
        'Spikes in demand are usually temporary. Please try again later.',
      ),
      'AI가 지금 너무 붐벼요. 잠시 후 다시 시도해 주세요.',
    );
  });

  test('시간 초과', () {
    expect(
      CardGenerator.friendlyError(
        'Deadline expired before operation could complete.',
      ),
      contains('오래 걸렸어요'),
    );
  });

  test('사용량 초과', () {
    expect(
      CardGenerator.friendlyError('RESOURCE_EXHAUSTED: quota exceeded'),
      contains('사용량'),
    );
  });

  test('그 밖의 오류는 원문을 붙인다', () {
    expect(CardGenerator.friendlyError('bad'), 'AI 호출에 실패했어요: bad');
  });
}
