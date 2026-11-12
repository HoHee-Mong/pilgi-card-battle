import 'model_utils.dart';

/// `subjects/{subjectId}`
class Subject {
  const Subject({
    required this.id,
    required this.ownerId,
    required this.name,
    this.examDate,
    required this.createdAt,
  });

  final String id;
  final String ownerId;
  final String name;
  final DateTime? examDate;
  final DateTime createdAt;

  factory Subject.fromMap(String id, Map<String, dynamic> map) {
    return Subject(
      id: id,
      ownerId: map['ownerId'] as String? ?? '',
      name: map['name'] as String? ?? '',
      examDate: readDateOrNull(map['examDate']),
      createdAt: readDate(map['createdAt']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'ownerId': ownerId,
      'name': name,
      'examDate': examDate == null ? null : writeDate(examDate!),
      'createdAt': writeDate(createdAt),
    };
  }

  Subject copyWith({String? name, DateTime? examDate}) {
    return Subject(
      id: id,
      ownerId: ownerId,
      name: name ?? this.name,
      examDate: examDate ?? this.examDate,
      createdAt: createdAt,
    );
  }
}
