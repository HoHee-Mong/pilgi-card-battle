import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/auth_providers.dart';
import '../../core/models/subject.dart';
import 'data/subject_repository.dart';

final subjectRepositoryProvider = Provider<SubjectRepository>(
  (ref) => SubjectRepository(FirebaseFirestore.instance),
);

/// 내 과목 목록. 로그인 전이면 빈 목록.
final mySubjectsProvider = StreamProvider<List<Subject>>((ref) {
  final uid = ref.watch(uidProvider);
  if (uid == null) return Stream.value(const []);
  return ref.watch(subjectRepositoryProvider).watchMine(uid);
});

final subjectProvider = StreamProvider.family<Subject?, String>(
  (ref, id) => ref.watch(subjectRepositoryProvider).watch(id),
);
