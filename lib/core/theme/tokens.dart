import 'package:flutter/animation.dart';
import 'package:flutter/painting.dart';

/// 디자인 토큰 — "형광펜과 볼펜". 값은 `docs/DESIGN.md`와 1:1.
/// 위젯에서는 색·간격·폰트·라운드·모션 값을 직접 쓰지 말고 여기 값만 쓴다.
abstract final class AppColors {
  /// 기본 바탕
  static const bg = Color(0xFFF4F5F7);

  /// 카드·리스트 면
  static const surface = Color(0xFFFFFFFF);

  /// 본문·주요 버튼
  static const ink = Color(0xFF17181C);

  /// 보조 텍스트
  static const inkSub = Color(0xFF5B6170);

  /// 구분선·비활성
  static const line = Color(0xFFE6E8EC);

  /// 볼펜 파랑 — 주요 동작·내 정보
  static const blue = Color(0xFF2F5BFF);

  /// 흰 바탕 위 파랑 글자
  static const blueText = Color(0xFF2447CC);

  /// 형광펜 — 강조·정답 (위 글자는 항상 [ink])
  static const lime = Color(0xFFD7F54A);

  /// 오답 배경
  static const wrong = Color(0xFFFFDDD6);

  /// 몰입 화면 배경 (카드 공개)
  static const dark = Color(0xFF14151A);
}

abstract final class AppSpacing {
  /// 화면 좌우 여백
  static const page = 20.0;

  /// 섹션 간격 (22~24)
  static const section = 24.0;
  static const sectionTight = 22.0;

  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;

  /// 최소 터치 영역
  static const minTouch = 44.0;
}

abstract final class AppRadius {
  static const card = 24.0;
  static const button = 18.0;
  static const chip = 15.0;

  /// 원형 아이콘 버튼 (지름 44 기준 반지름)
  static const iconButton = 22.0;
}

abstract final class AppFonts {
  static const family = 'Pretendard';
  static const fallback = ['Noto Sans KR'];
}

abstract final class AppTextStyles {
  /// 제목 28~36 / w800 / 자간 -0.8~-1.0
  static const titleL = TextStyle(
    fontFamily: AppFonts.family,
    fontFamilyFallback: AppFonts.fallback,
    fontSize: 34,
    fontWeight: FontWeight.w800,
    letterSpacing: -1.0,
    height: 1.25,
    color: AppColors.ink,
  );

  static const titleM = TextStyle(
    fontFamily: AppFonts.family,
    fontFamilyFallback: AppFonts.fallback,
    fontSize: 28,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.8,
    height: 1.25,
    color: AppColors.ink,
  );

  /// 카드·섹션 제목 (본문보다 크고 제목보다 작은 단계)
  static const heading = TextStyle(
    fontFamily: AppFonts.family,
    fontFamilyFallback: AppFonts.fallback,
    fontSize: 19,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.4,
    height: 1.35,
    color: AppColors.ink,
  );

  /// 본문 15~16 / w500 / 줄간격 1.5
  static const body = TextStyle(
    fontFamily: AppFonts.family,
    fontFamilyFallback: AppFonts.fallback,
    fontSize: 16,
    fontWeight: FontWeight.w500,
    height: 1.5,
    color: AppColors.ink,
  );

  static const bodyS = TextStyle(
    fontFamily: AppFonts.family,
    fontFamilyFallback: AppFonts.fallback,
    fontSize: 15,
    fontWeight: FontWeight.w500,
    height: 1.5,
    color: AppColors.ink,
  );

  /// 보조 13~14 / w500 / inkSub
  static const caption = TextStyle(
    fontFamily: AppFonts.family,
    fontFamilyFallback: AppFonts.fallback,
    fontSize: 13,
    fontWeight: FontWeight.w500,
    height: 1.45,
    color: AppColors.inkSub,
  );

  static const label = TextStyle(
    fontFamily: AppFonts.family,
    fontFamilyFallback: AppFonts.fallback,
    fontSize: 14,
    fontWeight: FontWeight.w500,
    height: 1.45,
    color: AppColors.inkSub,
  );

  /// 버튼 글자
  static const button = TextStyle(
    fontFamily: AppFonts.family,
    fontFamilyFallback: AppFonts.fallback,
    fontSize: 16,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.2,
    height: 1.2,
  );
}

abstract final class AppMotion {
  /// 기본 스프링 커브 — easeOutBack보다 overshoot를 살짝 줄인 값
  static const spring = Cubic(0.34, 1.36, 0.64, 1.0);

  /// 버튼 눌림
  static const pressScale = 0.96;
  static const press = Duration(milliseconds: 280);

  /// 화면 전환
  static const pageTransition = Duration(milliseconds: 380);

  /// 카드 뒤집기 (Y축, 원근감 0.001)
  static const cardFlip = Duration(milliseconds: 800);
  static const perspective = 0.001;

  /// 점수 막대
  static const scoreBar = Duration(milliseconds: 900);

  /// 리스트 등장: 아이템마다 지연, 위로 이동 거리
  static const listStagger = Duration(milliseconds: 40);
  static const listItem = Duration(milliseconds: 360);
  static const listOffsetY = 8.0;
}

abstract final class AppSound {
  /// 효과음 최대 볼륨
  static const maxVolume = 0.6;
}
