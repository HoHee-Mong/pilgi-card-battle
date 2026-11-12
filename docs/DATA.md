# 데이터 구조와 공용 모델 (A·B 공통 계약)

Firebase: Auth(익명 로그인 + 닉네임), Firestore, Storage, AI Logic(`firebase_ai`, Gemini).

규칙: 필드는 **추가만** 한다. 삭제·이름 변경은 두 사람이 합의한 뒤 이 문서와 모델을 같이 고친다.

## Firestore

```
users/{uid}
  nickname: string
  createdAt: timestamp

users/{uid}/attempts/{attemptId}        # 풀이 기록 (A가 쓰고, B도 배틀 결과를 여기에 쓴다)
  cardId, subjectId, concept: string
  correct: bool
  mode: "solo" | "battle" | "mock"
  at: timestamp

users/{uid}/cardMeta/{cardId}           # 사용자별 카드 상태 (A)
  favorite: bool
  inWrongNote: bool
  reviewedDone: bool

subjects/{subjectId}                     # (A)
  ownerId, name: string
  examDate: timestamp?
  createdAt: timestamp

sources/{sourceId}                       # 업로드 원본 (A), 항상 비공개
  ownerId, subjectId: string
  week: int
  kind: "image" | "pdf" | "audio"
  fileName, storagePath: string
  status: "uploaded" | "processing" | "done" | "failed"
  summary: string?                       # 핵심 요약
  transcript: [{ t: int(초), text }]?    # 녹음일 때 (P2)
  emphasis: [{ t: int(초), quote }]?     # 교수님 강조 발언 (P2)
  createdAt: timestamp

cards/{cardId}                           # (A가 생성, B는 읽기 + visibility/roomIds 갱신)
  ownerId, ownerNickname, subjectId: string
  week: int
  sourceId: string
  sourceLabel: string                    # 예: "3주차 강의자료.pdf p.12" / "3주차 녹음 23:41"
  type: "mcq" | "ox" | "short"
  question: string
  choices: [string]                      # mcq만
  answer: string                         # mcq는 정답 보기 텍스트, ox는 "O"/"X"
  explanation: string
  concept: string                        # 개념 태그
  status: "draft" | "verified"
  visibility: "private" | "room"
  roomIds: [string]
  createdAt, updatedAt: timestamp

rooms/{roomId}                           # (B)
  code: string(6)                        # 초대 코드
  hostId, subjectId, name: string
  weeks: [int]                           # 배틀 범위
  questionCount: int                     # 배틀 5 | 10
  status: "waiting" | "playing" | "finished"
  players: { uid: { nickname, score, combo, ready } }
  cardIds: [string]                      # 배틀 출제 순서 (bank에서 voteCount 높은 순 우선)
  round: int                             # 현재 문제 index
  roundStartedAt: timestamp
  createdAt: timestamp

rooms/{roomId}/bank/{cardId}             # 공동 문제은행 + 투표 (B)
  cardId, addedBy, addedByNickname: string
  week: int
  voteCount: int                         # 트랜잭션으로 증감
  voters: [uid]                          # 한 사람 1표, 다시 누르면 제거
  addedAt: timestamp

rooms/{roomId}/mockExams/{examId}        # 모의고사 기록 (A)
  uid, nickname: string
  cardIds: [string]                      # voteCount 내림차순으로 뽑은 문항
  weeks: [int]
  timeLimitSec: int
  score: int, total: int
  wrongCardIds: [string]
  startedAt, submittedAt: timestamp

rooms/{roomId}/answers/{round_uid}       # (B)
  uid, round: int
  choice: string
  correct: bool
  elapsedMs: int
```

## Dart 공용 모델 (`lib/core/models/`)
- `card.dart` — `QuizCard` (A 소유). 위 `cards` 필드와 1:1, `fromMap`/`toMap`
- `subject.dart` — `Subject` (A 소유)
- `attempt.dart` — `Attempt` (A 소유, B도 사용)
- `room.dart` — `Room`, `RoomPlayer`, `BankEntry` (B 소유)
- `mock_exam.dart` — `MockExam` (A 소유)

## 공용 위젯 계약
- `VoteButton(roomId, cardId)` — B가 `lib/core/widgets/vote_button.dart`에 만든다. 누르면 투표/취소, 숫자 올라가는 모션 + 진동. A는 혼자 풀기·모의고사 결과 화면에서 이 위젯만 가져다 쓴다
- `BankRepository.topVoted(roomId, weeks, limit)` — B가 만든다. A의 모의고사가 문항을 뽑을 때 사용

1일차 공통 세팅에서 A가 `QuizCard`·`Attempt`를 먼저 만들어 `main`에 올린다. B는 그 전까지 `QuizCard.sample()` 더미 데이터로 작업한다.

## AI 호출 (A 소유, `lib/core/ai/`)
- `CardGenerator.fromImage(bytes)`, `fromPdf(bytes)`, `fromAudio(bytes)` → `List<QuizCard>`(draft) + `summary`
- Gemini에 JSON 스키마(responseSchema)를 넘겨 구조화된 출력만 받는다
- 프롬프트는 `lib/core/ai/prompts.dart` 한 곳에서 관리
- 제한값은 `lib/core/config.dart`: 최대 파일 20MB, 녹음 30분, 하루 생성 20회 (임시값)

## 점수 규칙 (B)
- 정답: `500 + 남은시간비율 * 500` (최대 1000), 오답 0
- 콤보: 연속 정답 2회부터 문제당 +100
