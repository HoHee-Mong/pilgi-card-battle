# A (양승호) 작업 목록 — 위에서부터 순서대로

## 1주차
- [x] (B와 같이) GitHub 레포 생성, B 초대, `main` 보호 설정
- [x] `flutter create`, 패키지: firebase_core, firebase_auth, cloud_firestore, firebase_storage, firebase_ai, go_router, flutter_riverpod, image_picker, file_picker
- [ ] Firebase 프로젝트, `flutterfire configure`, 익명 로그인, AI Logic(Gemini Developer API) 활성화
- [ ] 모델 `QuizCard`, `Attempt`, `Subject`, `MockExam` 먼저 merge → B에게 알림
- [ ] 과목 목록·생성, 주차 선택
- [ ] 자료 업로드: 이미지(촬영·갤러리), PDF → Storage → `sources`
- [ ] `CardGenerator`: Gemini + JSON 스키마 → 요약 + 카드 N개(draft)
- [ ] 생성 옵션 화면 (카드 수, 유형)
- [ ] 검수 화면: 수정, 출처 표시, 검수 완료 / 직접 문제 쓰기
- [ ] 카드 "방에 공유" 버튼 (B의 `BankRepository.addCard`)

## 2주차
- [ ] 비슷한 카드 안내 (문자열 유사도)
- [ ] 족보 노트: 주차별 카드, 요약, 출처, 필터
- [ ] 혼자 풀기: 범위·유형·문항 수 → 풀이 → 결과(`VoteButton` 포함), `attempts` 저장
- [ ] 오답 노트: 모아보기, 다시 풀기, 복습 완료
- [ ] **우리가 만든 모의고사**: 방에서 시작 → `topVoted`로 문항 구성(10/20/30, 주차 범위) → 전체 제한 시간 → 일괄 제출·채점 → 결과(점수, 틀린 문제, 문제별 투표 수, `VoteButton`) → 오답 노트, `mockExams` 저장

## 3주차
- [ ] P1 버그 수정, B와 통합 테스트
- [ ] P2: 녹음 업로드 → 전사(시간) → 요약 → 카드
- [ ] P2: 교수님 강조 발언 탐지 (AI 추정 / 실제 발언 / 친구 투표 구분 표시)
- [ ] P2: 즐겨찾기, 취약 개념 TOP 3

## P3 — P1·P2 끝난 뒤
- [ ] 근거 기반 AI 자유 질문, PDF+녹음 통합 분석, 스캔 PDF OCR, 시험 후 "실제로 나왔어요" 체크
