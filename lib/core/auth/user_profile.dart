import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'auth_providers.dart';

/// `users/{uid}` 프로필 중 닉네임 관련 값
class UserProfile {
  const UserProfile({
    this.nickname = '',
    this.nicknameChanges = 0,
    this.nicknameSet = false,
  });

  final String nickname;

  /// 지금까지 이름을 바꾼 횟수 (처음 정하기는 세지 않음)
  final int nicknameChanges;

  /// Google 로그인 뒤 "이름 정하기"를 끝냈는지
  final bool nicknameSet;

  int get changesLeft => nicknameChangesLeft(nicknameChanges);

  factory UserProfile.fromMap(Map<String, dynamic>? m) => UserProfile(
    nickname: m?['nickname'] as String? ?? '',
    nicknameChanges: (m?['nicknameChanges'] as num?)?.toInt() ?? 0,
    nicknameSet: m?['nicknameSet'] as bool? ?? false,
  );
}

/// 이름은 처음 정한 뒤 이만큼만 바꿀 수 있다
const kMaxNicknameChanges = 3;

/// 남은 변경 횟수 (0 아래로 안 내려감)
int nicknameChangesLeft(int used) =>
    used >= kMaxNicknameChanges ? 0 : kMaxNicknameChanges - used;

/// 이름 바꾸기 실패 (화면에 그대로 보여 줄 문구)
class NicknameException implements Exception {
  const NicknameException(this.message);
  final String message;
}

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

  Stream<UserProfile> watchProfile(String uid) =>
      _doc(uid).snapshots().map((d) => UserProfile.fromMap(d.data()));

  /// 처음 이름 정하기 (Google 로그인 뒤 한 번). 변경 횟수에 안 들어간다.
  Future<void> setInitialNickname(String uid, String nickname) {
    return _doc(uid).set({
      'nickname': nickname.trim(),
      'nicknameSet': true,
    }, SetOptions(merge: true));
  }

  /// 이름 바꾸기. [kMaxNicknameChanges]번까지만 (트랜잭션으로 횟수 확인).
  Future<void> changeNickname(String uid, String nickname) {
    final ref = _doc(uid);
    return _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      final profile = UserProfile.fromMap(snap.data());
      if (profile.changesLeft == 0) {
        throw const NicknameException('이름은 $kMaxNicknameChanges번까지만 바꿀 수 있어요');
      }
      tx.set(ref, {
        'nickname': nickname.trim(),
        'nicknameChanges': profile.nicknameChanges + 1,
      }, SetOptions(merge: true));
    });
  }

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

/// 내 프로필 (닉네임·변경 횟수). 로그인 전이면 기본값.
final userProfileProvider = StreamProvider<UserProfile>((ref) {
  final uid = ref.watch(uidProvider);
  if (uid == null) return Stream.value(const UserProfile());
  return ref.watch(userProfileRepositoryProvider).watchProfile(uid);
});
