import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/auth_providers.dart';
import '../../core/models/source.dart';
import 'data/source_repository.dart';

final sourceRepositoryProvider = Provider<SourceRepository>(
  (ref) => SourceRepository(FirebaseFirestore.instance),
);

/// 과목·주차 하나의 자료 목록. 로그인 전이면 빈 목록.
final weekSourcesProvider =
    StreamProvider.family<List<StudySource>, ({String subjectId, int week})>((
      ref,
      key,
    ) {
      final uid = ref.watch(uidProvider);
      if (uid == null) return Stream.value(const []);
      return ref
          .watch(sourceRepositoryProvider)
          .watchWeek(uid: uid, subjectId: key.subjectId, week: key.week);
    });

final sourceProvider = StreamProvider.family<StudySource?, String>(
  (ref, id) => ref.watch(sourceRepositoryProvider).watch(id),
);
