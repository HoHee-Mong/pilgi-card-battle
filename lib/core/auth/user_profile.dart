import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'auth_providers.dart';

/// `users/{uid}` — 닉네임. 없으면 "학생1234"처럼 만들어 둔다.
class UserProfileRepository {
  UserProfileRepository(this._db);

  final FirebaseFirestore _db;

  DocumentReference<Map<String, dynamic>> _doc(String uid) =>
      _db.collection('users').doc(uid);

  Stream<String?> watchNickname(String uid) =>
      _doc(uid).snapshots().map((d) => d.data()?['nickname'] as String?);

  /// 닉네임을 돌려준다. 문서가 없으면 임의 닉네임으로 만든다.
  Future<String> ensureNickname(String uid) async {
    final snap = await _doc(uid).get();
    final existing = snap.data()?['nickname'] as String?;
    if (existing != null && existing.isNotEmpty) return existing;
    final nickname = '학생${1000 + Random().nextInt(9000)}';
    await _doc(uid).set({
      'nickname': nickname,
      'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    return nickname;
  }

  /// Google 로그인 때: 닉네임이 없거나 자동으로 만든 "학생1234"면 Google 이름으로 바꾼다.
  /// 직접 정한 닉네임은 그대로 둔다.
  Future<void> adoptName(String uid, String? displayName) async {
    final name = (displayName ?? '').trim();
    if (name.isEmpty) return;
    final snap = await _doc(uid).get();
    final existing = snap.data()?['nickname'] as String? ?? '';
    if (existing.isNotEmpty && !isAutoNickname(existing)) return;
    await _doc(uid).set({
      'nickname': name.characters.take(maxNicknameLength).toString(),
      if (!snap.exists) 'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  static const maxNicknameLength = 12;

  /// [ensureNickname]이 자동으로 만든 닉네임인지
  static bool isAutoNickname(String nickname) =>
      RegExp(r'^학생\d{4}$').hasMatch(nickname);

  Future<void> setNickname(String uid, String nickname) {
    return _doc(uid)
        .set({'nickname': nickname.trim()}, SetOptions(merge: true));
  }
}

final userProfileRepositoryProvider = Provider<UserProfileRepository>(
  (ref) => UserProfileRepository(FirebaseFirestore.instance),
);

/// 내 닉네임. 로그인 전이면 null.
final nicknameProvider = StreamProvider<String?>((ref) {
  final uid = ref.watch(uidProvider);
  if (uid == null) return Stream.value(null);
  return ref.watch(userProfileRepositoryProvider).watchNickname(uid);
});
