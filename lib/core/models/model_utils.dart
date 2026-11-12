import 'package:cloud_firestore/cloud_firestore.dart';

/// Firestore 값 ↔ Dart 값 변환 헬퍼 (A 소유 모델 공용).

DateTime readDate(Object? value) => readDateOrNull(value) ?? DateTime.now();

DateTime? readDateOrNull(Object? value) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
  return null;
}

Timestamp writeDate(DateTime value) => Timestamp.fromDate(value);

List<String> readStringList(Object? value) =>
    value is List ? value.map((e) => e.toString()).toList() : <String>[];

List<int> readIntList(Object? value) => value is List
    ? value.whereType<num>().map((e) => e.toInt()).toList()
    : <int>[];

int readInt(Object? value, [int fallback = 0]) =>
    value is num ? value.toInt() : fallback;

/// enum을 `name` 문자열로 읽는다. 모르는 값이면 [fallback].
T readEnum<T extends Enum>(List<T> values, Object? value, T fallback) {
  for (final v in values) {
    if (v.name == value) return v;
  }
  return fallback;
}
