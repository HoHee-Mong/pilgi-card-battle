import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 게임 설정: 진동, 애니메이션 줄이기. 기기에 저장돼 앱을 다시 켜도 유지된다.
/// (효과음 켜기·끄기는 `Sound`가 따로 저장한다)
///
/// [load]는 `Sound.init`에서 함께 부른다. 부르기 전(테스트 등)에는 기본값.
abstract final class GameSettings {
  static const _hapticsKey = 'haptics_on';
  static const _reduceMotionKey = 'reduce_motion';
  static SharedPreferences? _prefs;

  /// 진동 (처음엔 켜짐)
  static bool haptics = true;

  /// 애니메이션 줄이기 (처음엔 꺼짐). 기기 접근성 설정의 "동작 줄이기"와 별개로 앱에서 켤 수 있다.
  static bool reduceMotion = false;

  static void load(SharedPreferences prefs) {
    _prefs = prefs;
    try {
      haptics = prefs.getBool(_hapticsKey) ?? true;
      reduceMotion = prefs.getBool(_reduceMotionKey) ?? false;
    } catch (e) {
      debugPrint('게임 설정 읽기 실패: $e');
    }
  }

  static Future<void> setHaptics(bool on) async {
    haptics = on;
    await _prefs?.setBool(_hapticsKey, on);
  }

  static Future<void> setReduceMotion(bool on) async {
    reduceMotion = on;
    await _prefs?.setBool(_reduceMotionKey, on);
  }
}

class HapticsOn extends Notifier<bool> {
  @override
  bool build() => GameSettings.haptics;

  Future<void> set(bool on) async {
    await GameSettings.setHaptics(on);
    state = on;
  }
}

class ReduceMotion extends Notifier<bool> {
  @override
  bool build() => GameSettings.reduceMotion;

  Future<void> set(bool on) async {
    await GameSettings.setReduceMotion(on);
    state = on;
  }
}

final hapticsOnProvider = NotifierProvider<HapticsOn, bool>(HapticsOn.new);
final reduceMotionProvider = NotifierProvider<ReduceMotion, bool>(
  ReduceMotion.new,
);
