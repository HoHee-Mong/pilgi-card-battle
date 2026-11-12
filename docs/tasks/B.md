# B (장선우) 작업 목록 — 위에서부터 순서대로

## 1주차
- [ ] A의 레포 초대 수락, clone, 실행 확인
- [ ] 패키지: flutter_animate, audioplayers, (선택) lottie
- [ ] `lib/core/theme/tokens.dart`, `app_theme.dart` — `docs/DESIGN.md` 값 그대로
- [ ] 공용 위젯: `PressableScale`, `PrimaryButton`, `SectionCard`
- [ ] `router.dart` + 하단 탭 4개(홈/족보 노트/스터디 방/내 카드) 뼈대, 홈 레이아웃
- [ ] A의 모델이 오기 전까지 `QuizCard.sample()` 더미로 작업
- [ ] 모델 `Room`, `BankEntry`
- [ ] 방 만들기(과목 선택) → 6자리 초대 코드 → 코드로 입장
- [ ] `BankRepository`: `addCard`, `watchBank(정렬: 투표순/최신순/주차)`, `toggleVote`(트랜잭션), `topVoted(roomId, weeks, limit)` → A에게 알림
- [ ] 공동 문제은행 화면: 카드 목록, 작성자·출처, 정렬

## 2주차
- [ ] **"나올 것 같아요" 투표**: `VoteButton` 공용 위젯(투표/취소, 숫자 올라가는 모션 + 진동), "선우 외 2명이 나올 것 같대요" 표시 → A에게 알림
- [ ] 대기실 (참가자 실시간, 준비, 방장 시작)
- [ ] 배틀 출제: bank에서 투표 많은 순 우선으로 `cardIds`
- [ ] 라운드: 3-2-1 → 문제 → 15초 → 제출(`answers`) → 정답 공개 → 다음
- [ ] 점수·콤보, 실시간 점수 막대
- [ ] 결과: 순위, 정답률, 문제별 `VoteButton`, 오답 → `attempts`(mode: battle)
- [ ] 예외: 상대 나감, 백그라운드, 동시 제출

## 3주차
- [ ] 연출 다듬기: 카드 뒤집기, 버튼 스프링, 정답/오답 색·진동·효과음, 리스트 등장 모션
- [ ] 사운드 on/off, 태블릿 폭 점검
- [ ] P1 버그 수정, A와 통합 테스트
- [ ] P2: 같은 방 모의고사 점수 비교, 투표 기여도("예상 적중왕")

## P3 — P1·P2 끝난 뒤
- [ ] 3~8인 배틀, 보스전, 약점 공략 배틀, 고대 문자 카드·희귀도 연출
