import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/theme/tokens.dart';
import 'game_settings.dart';

/// 효과음 5종 (`assets/sounds`, 직접 합성한 짧은 소리). DESIGN.md 사운드 항목.
enum Sfx {
  correct('correct.wav'),
  wrong('wrong.wav'),
  vote('vote.wav'),
  countdown('countdown.wav'),
  bossDown('boss_down.wav');

  const Sfx(this.file);
  final String file;
}

/// 효과음 재생. 설정에서 끄면 아무 소리도 안 난다.
///
/// [init]을 부르기 전(테스트 등)에는 꺼져 있다.
abstract final class Sound {
  static const _prefKey = 'sound_on';
  static bool _enabled = false;
  static SharedPreferences? _prefs;
  static final _players = <Sfx, AudioPlayer>{};

  static bool get enabled => _enabled;

  /// 앱 시작 때 한 번. 저장된 설정을 읽는다 (처음엔 켜짐).
  static Future<void> init() async {
    try {
      _prefs = await SharedPreferences.getInstance();
      _enabled = _prefs!.getBool(_prefKey) ?? true;
      GameSettings.load(_prefs!);
    } catch (e) {
      debugPrint('사운드 설정 읽기 실패: $e');
      _enabled = true;
    }
  }

  static Future<void> setEnabled(bool on) async {
    _enabled = on;
    await _prefs?.setBool(_prefKey, on);
  }

  /// 소리 내기. 실패해도 앱 흐름은 막지 않는다.
  static void play(Sfx sfx) {
    if (!_enabled) return;
    try {
      final player = _players.putIfAbsent(sfx, () {
        final p = AudioPlayer()..setReleaseMode(ReleaseMode.stop);
        return p;
      });
      player
          .stop()
          .then(
            (_) => player.play(
              AssetSource('sounds/${sfx.file}'),
              volume: AppSound.maxVolume,
            ),
          )
          .catchError((Object e) => debugPrint('효과음 실패: $e'));
    } catch (e) {
      debugPrint('효과음 실패: $e');
    }
  }
}

/// 화면에서 사운드 켜짐 여부를 보고 바꾸기 위한 상태
class SoundOn extends Notifier<bool> {
  @override
  bool build() => Sound.enabled;

  Future<void> toggle() async {
    await Sound.setEnabled(!state);
    state = Sound.enabled;
  }
}

final soundOnProvider = NotifierProvider<SoundOn, bool>(SoundOn.new);
