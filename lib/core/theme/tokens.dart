import 'package:flutter/animation.dart';
import 'package:flutter/painting.dart';

/// 디자인 토큰 — "시험지 보스를 잡는 아케이드". 값은 `docs/DESIGN.md`와 1:1.
/// 위젯에서는 색·간격·폰트·라운드·모션 값을 직접 쓰지 말고 여기 값만 쓴다.
abstract final class AppColors {
  // ── 새 팔레트 (DESIGN.md 색 표) ──────────────────────────────

  /// 테두리·그림자·본문 글자·어두운 배경(보스전)
  static const ink = Color(0xFF1A0B3B);

  /// 로비 배경, 주요 강조 (흰 글자 OK)
  static const grape = Color(0xFF6C3BFF);

  /// 보스·1위·주요 버튼 (글자는 ink)
  static const pink = Color(0xFFFF4D8D);

  /// 정답·투표 완료·성공 (글자는 ink)
  static const lime = Color(0xFFB8FF3B);

  /// 결과 배경·연속 출석·코인류 (글자는 ink)
  static const sun = Color(0xFFFFD23F);

  /// 보조 강조 (글자는 ink)
  static const cyan = Color(0xFF33E1FF);

  /// 문제은행 등 밝은 화면 배경
  static const cream = Color(0xFFFFF1D6);

  /// 카드 면
  static const paper = Color(0xFFFFF8EE);

  /// 보조 텍스트 (밝은 배경 위)
  static const inkSub = Color(0xFF4A3B6B);

  /// 오답 보기
  static const wrong = Color(0xFFFF8AB3);

  // ── 이전 이름 (기존 화면 호환용) ────────────────────────────
  // 새 코드에서는 위의 새 이름을 쓴다. 기존 화면이 깨지지 않도록 새 색으로 연결해 둔다.

  /// 기본 바탕 → [cream]
  static const bg = cream;

  /// 카드·리스트 면 → [paper]
  static const surface = paper;

  /// 구분선·비활성 → ink 20%
  static const line = Color(0x331A0B3B);

  /// 주요 동작 → [grape]
  static const blue = grape;

  /// 밝은 바탕 위 강조 글자 → [grape]
  static const blueText = grape;

  /// 몰입 화면 배경 → [ink]
  static const dark = ink;
}

abstract final class AppSpacing {
  /// 화면 좌우 여백
  static const page = 18.0;

  /// 섹션 간격
  static const section = 14.0;
  static const sectionTight = 12.0;

  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;

  /// 최소 터치 영역
  static const minTouch = 44.0;

  /// 버튼 높이 (보통 / 화면 대표 버튼)
  static const button = 56.0;
  static const buttonLarge = 72.0;
}

abstract final class AppRadius {
  /// 큰 카드
  static const card = 26.0;

  /// 버튼
  static const button = 22.0;

  /// 작은 칩 (12~16)
  static const chip = 14.0;

  /// 알약 모양 (StatChip)
  static const pill = 999.0;

  /// 원형 아이콘 버튼 (지름 44 기준 반지름)
  static const iconButton = 22.0;
}

/// 블록(Chunky) UI — 굵은 테두리 + 아래로 딱딱한 그림자
abstract final class AppBlock {
  /// 테두리 두께 (색은 [AppColors.ink])
  static const border = 3.0;

  /// 평소 그림자 높이 (blur 0)
  static const shadow = 6.0;

  /// 눌렸을 때 그림자 높이
  static const shadowPressed = 2.0;

  /// 눌렸을 때 내려가는 거리
  static const pressDepth = 4.0;
}

abstract final class AppFonts {
  /// 본문 — Noto Sans KR (안드로이드 기본 한글 글꼴)
  static const family = 'Noto Sans KR';
  static const fallback = ['NotoSansKR', 'Noto Sans CJK KR'];

  /// 제목·숫자·버튼 — Black Han Sans (굵기 하나뿐, weight 지정 X)
  static const display = 'BlackHanSans';
}

abstract final class AppTextStyles {
  /// 큰 제목 / 숫자
  static const titleL = TextStyle(
    fontFamily: AppFonts.display,
    fontFamilyFallback: AppFonts.fallback,
    fontSize: 34,
    height: 1.2,
    color: AppColors.ink,
  );

  static const titleM = TextStyle(
    fontFamily: AppFonts.display,
    fontFamilyFallback: AppFonts.fallback,
    fontSize: 26,
    height: 1.2,
    color: AppColors.ink,
  );

  /// 카드·섹션 제목
  static const heading = TextStyle(
    fontFamily: AppFonts.display,
    fontFamilyFallback: AppFonts.fallback,
    fontSize: 19,
    height: 1.3,
    color: AppColors.ink,
  );

  /// 본문 15~16 / w500
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

  /// 보조 13 / inkSub
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
    fontWeight: FontWeight.w700,
    height: 1.45,
    color: AppColors.inkSub,
  );

  /// 버튼 글자
  static const button = TextStyle(
    fontFamily: AppFonts.display,
    fontFamilyFallback: AppFonts.fallback,
    fontSize: 17,
    height: 1.2,
  );

  /// 상태 알약 글자 (StatChip)
  static const chip = TextStyle(
    fontFamily: AppFonts.display,
    fontFamilyFallback: AppFonts.fallback,
    fontSize: 15,
    height: 1.2,
  );

  /// 화면 대표 버튼 글자 (큰 버튼)
  static const buttonL = TextStyle(
    fontFamily: AppFonts.display,
    fontFamilyFallback: AppFonts.fallback,
    fontSize: 22,
    height: 1.2,
  );
}

abstract final class AppMotion {
  /// 기본 스프링 커브 — 도장 "쾅" 등
  static const spring = Cubic(0.34, 1.36, 0.64, 1.0);

  /// 버튼 눌림 (4px 내려감)
  static const press = Duration(milliseconds: 120);

  /// 화면 전환
  static const pageTransition = Duration(milliseconds: 380);

  /// 카드 뒤집기 (Y축, 원근감 0.001)
  static const cardFlip = Duration(milliseconds: 800);
  static const perspective = 0.001;

  /// 점수 막대
  static const scoreBar = Duration(milliseconds: 900);

  /// 투표 "+1" 튀어 올랐다 사라짐
  static const votePop = Duration(milliseconds: 900);

  /// 보스 둥둥 (반복, ±8px, ±3도)
  static const bossFloat = Duration(milliseconds: 2400);
  static const bossFloatY = 8.0;
  static const bossFloatDeg = 3.0;

  /// 정답: 보스 흔들림·축소 / "적중!" 도장 / 체력바 감소
  static const bossHit = Duration(milliseconds: 600);
  static const stamp = Duration(milliseconds: 500);

  /// "적중!"/"빗나감" 도장이 쾅 찍히고(앞 [stamp]) 잠깐 머물다 사라지는 전체 시간
  static const stampShow = Duration(milliseconds: 1250);
  static const hpBar = Duration(milliseconds: 700);

  /// 오답: 좌우 두 번 흔들림
  static const shake = Duration(milliseconds: 420);
  static const shakeDistance = 10.0;

  /// 1위 왕관 살랑
  static const crownSway = Duration(milliseconds: 1800);

  /// 리스트 등장: 아이템마다 지연, 위로 이동 거리
  static const listStagger = Duration(milliseconds: 40);
  static const listItem = Duration(milliseconds: 360);
  static const listOffsetY = 8.0;
}

abstract final class AppSound {
  /// 효과음 최대 볼륨
  static const maxVolume = 0.6;
}
