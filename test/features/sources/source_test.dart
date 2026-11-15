import 'package:flutter_test/flutter_test.dart';
import 'package:pilgi_card_battle/core/models/source.dart';
import 'package:pilgi_card_battle/features/sources/data/source_repository.dart';

void main() {
  test('StudySource toMap → fromMap 왕복', () {
    final s = StudySource(
      id: 'src',
      ownerId: 'u',
      subjectId: 'sub',
      week: 3,
      kind: SourceKind.pdf,
      fileName: '3주차 강의자료.pdf',
      storagePath: 'sources/u/src/3주차 강의자료.pdf',
      status: SourceStatus.done,
      summary: '요약',
      createdAt: DateTime(2026, 11, 15, 10),
    );
    expect(StudySource.fromMap(s.id, s.toMap()).toMap(), s.toMap());
    expect(s.label, '3주차 3주차 강의자료.pdf');
  });

  test('StudySource 빈 문서 기본값은 image·uploaded', () {
    final s = StudySource.fromMap('x', {});
    expect(s.kind, SourceKind.image);
    expect(s.status, SourceStatus.uploaded);
    expect(s.summary, isNull);
  });

  test('sanitizeFileName: 경로 문자 제거, 한글 유지, 길이 제한', () {
    expect(
      SourceRepository.sanitizeFileName('a/b\\c:d*e?f"g<h>i|j#k[l].pdf'),
      'a_b_c_d_e_f_g_h_i_j_k_l_.pdf',
    );
    expect(SourceRepository.sanitizeFileName('  3주차   필기.jpg '), '3주차 필기.jpg');
    expect(SourceRepository.sanitizeFileName(''), 'file');
    expect(SourceRepository.sanitizeFileName('x' * 100 + '.pdf').length, 80);
  });
}
