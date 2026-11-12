# 역할 분담과 폴더 소유권

| | A: 양승호 | B: 장선우 |
|---|---|---|
| 한 줄 | 문제를 **만들고 푸는** 쪽: 자료 → AI 카드 → 족보 노트 → 혼자 풀기·모의고사 | 문제를 **모으고 고르는** 쪽: 스터디 방 → 공동 문제은행 → "나올 것 같아요" 투표 → 배틀 → 연출 |
| P1 | 과목·주차, 이미지/PDF 입력, AI 요약·카드 생성, 직접 문제 쓰기, 검수·수정·출처, 족보 노트, 혼자 풀기·오답 노트, **우리가 만든 모의고사** | 방 생성·초대 코드, **공동 문제은행**, **"나올 것 같아요" 투표**, 2인 배틀(투표 많은 문제 우선 출제), 결과·오답 연동, 기본 연출·사운드·진동, 반응형 |
| P2 | 녹음 전사·카드, 교수님 강조 발언 탐지, 즐겨찾기·취약 개념 | 모의고사 점수 비교, 투표 기여도("예상 적중왕") |
| 공용 | Firebase 초기 설정, `QuizCard`·`Attempt`·`MockExam` 모델, AI 모듈 | 디자인 토큰, 공용 위젯(`VoteButton` 포함), 라우터, `Room`·`BankEntry` 모델, `BankRepository` |

## 폴더
```
lib/
  main.dart                 # 공동 (1주차 세팅 때만 같이 수정)
  core/
    theme/                  # B
    widgets/                # B — PressableScale, PrimaryButton, VoteButton 등
    router.dart             # B — 새 화면 경로 추가는 각자 한 줄씩 가능
    models/                 # card/subject/attempt/mock_exam = A, room/bank = B
    ai/                     # A
    config.dart             # A
  features/
    subjects/ sources/ cards/ notebook/ solo/ mock_exam/   # A
    room/ bank/ battle/                                     # B
  fx/                       # B — 사운드·햅틱·모션 헬퍼
assets/sounds/              # B
```

## 공용 폴더를 상대가 바꿔야 할 때
1. PR 설명에 "공용 변경"이라고 쓰고 상대 리뷰를 꼭 받는다
2. 모델은 필드 추가만 한다
3. `router.dart`는 자기 경로 한 줄 추가까지만

## 두 사람이 만나는 지점
- A의 카드 화면 "방에 공유" → B의 `bank` 컬렉션에 추가 (B가 만든 `BankRepository.addCard` 호출)
- A의 모의고사는 B의 `BankRepository.topVoted`로 문항을 뽑는다
- A의 혼자 풀기·모의고사 결과 화면에 B의 `VoteButton`을 넣는다
- B의 배틀 결과는 `users/{uid}/attempts`에 `mode: battle`로 저장 → A의 오답 노트에 자동 반영
