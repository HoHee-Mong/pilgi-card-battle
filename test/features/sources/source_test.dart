import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:pilgi_card_battle/core/models/source.dart';
import 'package:pilgi_card_battle/features/sources/data/source_repository.dart';

void main() {
  test('StudySource toMap → fromMap 왕복 (storagePath 없음)', () {
    final s = StudySource(
      id: 'src',
      ownerId: 'u',
      subjectId: 'sub',
      week: 3,
      kind: SourceKind.pdf,
      fileName: '3주차 강의자료.pdf',
      status: SourceStatus.done,
      summary: '요약',
      createdAt: DateTime(2026, 11, 15, 10),
    );
    final map = s.toMap();
    expect(map.containsKey('storagePath'), isFalse);
    expect(StudySource.fromMap(s.id, map).toMap(), map);
    expect(s.label, '3주차 3주차 강의자료.pdf');
  });

  test('StudySource 빈 문서 기본값은 image·processing', () {
    final s = StudySource.fromMap('x', {});
    expect(s.kind, SourceKind.image);
    expect(s.status, SourceStatus.processing);
    expect(s.summary, isNull);
  });

  SourceFile file(String name, int size) => SourceFile(
    fileName: name,
    bytes: Uint8List(size),
    kind: SourceKind.image,
    contentType: 'image/jpeg',
  );

  test('checkSizes: 빈 파일·15MB 초과·합계 18MB 초과는 거절', () {
    expect(
      () => SourceRepository.checkSizes([]),
      throwsA(isA<SourceException>()),
    );
    expect(
      () => SourceRepository.checkSizes([file('a', 0)]),
      throwsA(isA<SourceException>()),
    );
    expect(
      () =>
          SourceRepository.checkSizes([file('a', SourceFile.maxSizeBytes + 1)]),
      throwsA(isA<SourceException>()),
    );
    expect(
      () => SourceRepository.checkSizes([
        file('a', 10 * 1024 * 1024),
        file('b', 10 * 1024 * 1024),
      ]),
      throwsA(isA<SourceException>()),
    );
    expect(
      () => SourceRepository.checkSizes([file('a', 1024), file('b', 1024)]),
      returnsNormally,
    );
  });
}
