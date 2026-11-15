# UPDATE-001: 기획 확정본 반영 (작업 지시서)

> Claude Code에게: 이 문서는 레포를 처음 만들 때 넣은 문서 세트 이후 **확정된 변경 사항**이다.
> 끝까지 읽고, 아래 "진행 순서"대로 작업해라. 큰 리팩터링이나 상대 담당 폴더를 건드리는 일은 시작 전에 반드시 사용자에게 계획을 보여주고 확인받는다.

## 같이 들어온 파일
| 위치 | 내용 |
|---|---|
| `UPDATE.md` | 이 문서 |
| `docs/_update/` | 새 버전 문서 전체 (CLAUDE.md, README.md, SPEC, DATA, ROLES, GIT, DESIGN, SCHEDULE, PROMPTS, tasks/A.md, tasks/B.md) |
| `docs/design/game-*.png` | 최종 디자인 시안 캡처 4장 (로비 / 예상 문제 랭킹 / 모의고사 보스전 / 보스 격파 결과). **UI는 이 이미지를 기준으로 만든다** |

---

## 무엇이 바뀌었나

레포를 만든 시점에 따라 이미 반영된 항목이 있을 수 있다. 현재 문서·코드와 비교해서 **아직 반영 안 된 것만** 적용한다.

### 1. 콘셉트: "우리가 만드는 시험문제"
- 같이 공부하는 친구들이 **"나올 것 같아요"를 누른 문제를 모아 모의고사로 푸는 앱**. 투표와 모의고사가 핵심 차별점이다
- 게임 톤: 다가오는 시험 = **보스**, 모의고사 = **보스전**(남은 문제 = 보스 체력)
- 투표 수는 친구들의 예상일 뿐이다. "출제 확률 ○%"처럼 표시하지 않는다

### 2. 팀원 이름
- B = **장선우** (문서의 `[팀원 이름]`을 전부 교체)

### 3. 기능과 우선순위
| 기능 | 이전 | 지금 | 담당 |
|---|---|---|---|
| "나올 것 같아요" 투표 | 없음 | **P1 핵심** | B |
| 우리가 만든 모의고사 (보스전) | 없음 | **P1 핵심** | A |
| 공동 문제은행 | P2 | **P1** (투표가 여기서 일어남) | B |
| 배틀 출제 방식 | 랜덤 | **투표 많은 문제 우선** | B |
| 직접 문제 쓰기 (AI 없이) | 없음 | P1 | A |
| 모의고사 점수 비교, 예상 적중왕 | 없음 | P2 | B |
| 레벨·XP·연속 출석·퀘스트·랭크 | 없음 | P2 | B |
| 화려한 연출 | P3 | 기본 게임 연출은 **P1** (DESIGN.md) | B |

### 4. 역할
- **A 양승호** = 문제를 **만들고 푸는** 쪽: 자료 입력, AI 카드, 직접 쓰기, 검수, 족보 노트, 혼자 풀기, 오답 노트, **모의고사(보스전)**
- **B 장선우** = 문제를 **모으고 고르는** 쪽: 스터디 방, **공동 문제은행**, **투표**, 2인 배틀, 디자인 시스템·공용 위젯, 연출·사운드

### 5. 폴더
- 추가: `lib/features/mock_exam/` (A), `lib/features/bank/` (B)
- 공용 위젯 (B 소유, `lib/core/widgets/`): `ChunkyButton`, `ChunkyCard`, `StatChip`, `BossSprite`, `VoteButton`
- 이전 이름 `PressableScale`, `PrimaryButton`, `SectionCard`는 **ChunkyButton / ChunkyCard로 대체**

### 6. 데이터 (docs/_update/DATA.md 기준)
- 새 컬렉션: `rooms/{roomId}/bank/{cardId}` (voteCount, voters 등), `rooms/{roomId}/mockExams/{examId}`
- `users/{uid}/attempts.mode`에 `"mock"` 추가
- `rooms`에 `name` 필드 추가
- 새 모델: `MockExam` (A), `BankEntry` (B)
- 새 계약: `BankRepository.addCard / watchBank / toggleVote / topVoted`, `VoteButton(roomId, cardId)`, `BossSprite(hp, maxHp)` + `hit()/miss()`
- 규칙은 그대로: **필드는 추가만 한다. 삭제·이름 변경 금지**

### 7. 디자인: 전면 교체
- 흰색 미니멀("형광펜과 볼펜") → **게임 아케이드 스타일**. 이전 색 토큰(#F4F5F7, #2F5BFF, #D7F54A 등)은 폐기
- 굵은 3px 테두리 + 아래로 6px 딱딱한 그림자(blur 0), 누르면 4px 내려감
- 색: ink #1A0B3B / grape #6C3BFF / pink #FF4D8D / lime #B8FF3B / sun #FFD23F / cyan #33E1FF / cream #FFF1D6 / paper #FFF8EE
- 제목·숫자·버튼 글꼴: **Black Han Sans** (`google_fonts`), 본문 Noto Sans KR
- 하단 탭: **로비 / 문제은행 / 모의고사 / 내 카드**
- 자세한 값과 모션 타이밍: `docs/_update/DESIGN.md`, 모습: `docs/design/game-*.png`

### 8. 일정
- 날짜 대신 **3주**: 1주차 카드 생성 → 방 공유 / 2주차 투표·모의고사·배틀 / 3주차 기능 동결·연출·테스트

---

## 진행 순서

### 단계 1. 문서 반영 — **A(양승호)만 한 번** 한다
1. `git checkout main && git pull`, `git checkout -b chore/update-001-docs`
2. `docs/_update/`의 각 파일을 현재 파일과 비교해서 차이를 요약해 사용자에게 보여준다
3. 아래 파일은 새 버전으로 **교체**한다: `CLAUDE.md`, `README.md`, `docs/SPEC.md`, `docs/DATA.md`, `docs/ROLES.md`, `docs/GIT.md`, `docs/DESIGN.md`, `docs/SCHEDULE.md`, `docs/PROMPTS.md`
   - 단, 현재 파일에 우리가 직접 추가한 내용(새 결정, 메모)이 있으면 지우지 말고 새 버전에 옮겨 넣는다
4. `docs/tasks/A.md`, `docs/tasks/B.md`는 **교체하지 말고 병합**한다
   - 이미 `[x]`로 체크된 항목은 체크를 유지한다 (새 버전에서 이름이 바뀐 항목이면 대응되는 새 항목에 체크)
   - 새 항목은 새 버전 순서대로 추가한다
   - 없어진 항목이 이미 완료돼 있으면 맨 아래 "이전 완료 항목"에 남긴다
5. `docs/design/` 이미지는 그대로 둔다. `docs/_update/` 폴더와 루트의 `UPDATE.md`는 `docs/updates/UPDATE-001.md`로 옮겨 기록을 남기고 `_update`는 삭제한다
6. 커밋 `docs: UPDATE-001 기획 확정본 반영` → PR(설명 맨 위 "공용 변경") → B에게 알림

### 단계 2. 코드 점검 — **각자 자기 담당 범위**만 한다 (B는 단계 1 PR이 merge된 뒤 pull 받고 시작)
1. `git checkout main && git pull`, `git checkout -b chore/update-001-<a|b>`
2. 새 문서 기준으로 현재 코드를 점검하고 **어긋나는 점 목록**을 먼저 보고한다. 예:
   - 색·글꼴이 tokens.dart 새 값이 아닌 곳, 위젯에 하드코딩된 색
   - `PressableScale`/`PrimaryButton`/`SectionCard` 사용처
   - 모델 필드가 DATA.md와 다른 곳, 없는 모델(MockExam, BankEntry)
   - 폴더 구조, 하단 탭 이름, 라우터 경로
   - 투표·모의고사처럼 아직 없는 기능
3. 고칠 계획(파일 단위)과 순서를 보여주고 **사용자 확인 후** 진행한다
4. 작은 단위로 커밋하고, 커밋마다 `flutter analyze` 통과와 앱 실행을 확인한다
5. 공용 폴더(`lib/core`)는 소유자만 바꾼다: theme·widgets·router·room/bank 모델은 B, card/attempt/subject/mock_exam 모델·ai·config는 A
6. 끝나면 `docs/tasks/<A|B>.md` 체크 상태를 갱신하고 PR

### 우선순위 (B 기준, 상대가 기다리는 것부터)
1. `tokens.dart` 새 색·글꼴 → `ChunkyButton`·`ChunkyCard` → 기존 화면 교체
2. `BankEntry` 모델 + `BankRepository` (A의 모의고사가 `topVoted`를 씀)
3. `VoteButton`, `BossSprite` (A의 결과·모의고사 화면에서 씀)

### 우선순위 (A 기준)
1. `MockExam` 모델 추가, `Attempt.mode`에 `mock` 허용
2. 카드 "방에 공유" → `BankRepository.addCard` 연결 (B가 만들기 전엔 인터페이스만 맞춰 둠)
3. `lib/features/mock_exam` 보스전 (B의 `BossSprite`가 없으면 임시 위젯으로 두고 나중에 교체)

## 하지 말 것
- 상대 담당 폴더 직접 수정 (필요하면 사용자에게 알리고 상대가 하게 한다)
- 모델 필드 삭제·이름 변경
- 디자인 시안에 없는 색, 그라데이션, 흐린 그림자, 이모지 아이콘
- 확인 없이 대량 파일 삭제
