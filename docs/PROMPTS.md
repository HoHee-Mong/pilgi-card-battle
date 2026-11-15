# Claude Code에 보낼 명령어·지시문 모음

순서대로 복사해서 쓰면 된다. `[ ]` 안은 직접 바꿔 넣는다.

---

## 0. 처음 한 번 — 양승호(A) 컴퓨터에서

### 터미널 명령어
```bash
# 1) Flutter 프로젝트 만들기 (패키지 이름은 영어만)
flutter create --org com.[아이디] --platforms android,ios pilgi_card_battle
cd pilgi_card_battle

# 2) 받은 문서 세트(zip)를 이 폴더에 풀기: CLAUDE.md, README.md, docs/ 가 최상단에 오게
unzip ~/Downloads/pilgi-card-battle-docs.zip -d /tmp/pcb && cp -r /tmp/pcb/pilgi-card-battle/. .

# 3) Git 첫 커밋 + GitHub 올리기 (gh CLI 사용)
git init && git add . && git commit -m "init: Flutter 프로젝트와 기획 문서"
gh repo create pilgi-card-battle --private --source=. --push
gh repo edit --add-collaborator [장선우 GitHub 아이디]   # 안 되면 웹 Settings > Collaborators

# 4) Firebase 연결 (처음이면 npm i -g firebase-tools, dart pub global activate flutterfire_cli)
firebase login
flutterfire configure
```

### Claude Code 첫 메시지 (A)
```
CLAUDE.md와 docs 폴더 문서를 전부 읽어줘.
나는 A(양승호)야. docs/tasks/A.md의 1주차 작업을 위에서부터 진행할 거야.
먼저 git checkout -b feat/a-setup 으로 브랜치를 만들고,
1) pubspec에 A.md에 적힌 패키지 추가
2) lib/core/models 에 QuizCard, Attempt, Subject, MockExam 모델을 docs/DATA.md 필드와 똑같이 작성 (fromMap/toMap, QuizCard.sample() 더미 포함)
3) Firebase 초기화 + 익명 로그인 코드
까지 해줘. 끝나면 flutter analyze 통과 확인하고 커밋한 다음, PR 설명 초안을 써줘.
모르는 부분은 추측하지 말고 나한테 물어봐.
```

---

## 0. 처음 한 번 — 장선우(B) 컴퓨터에서

### 터미널 명령어
```bash
gh repo clone [양승호 GitHub 아이디]/pilgi-card-battle
cd pilgi-card-battle
flutter pub get
flutter run
```

### Claude Code 첫 메시지 (B)
```
CLAUDE.md와 docs 폴더 문서를 전부 읽어줘. 특히 docs/DESIGN.md는 꼼꼼히.
나는 B(장선우)야. docs/tasks/B.md의 1주차 작업을 위에서부터 진행할 거야.
git checkout -b feat/b-theme 으로 브랜치를 만들고,
1) google_fonts, flutter_animate, audioplayers 패키지 추가
2) lib/core/theme/tokens.dart, app_theme.dart를 DESIGN.md 색·글꼴 표 그대로 작성
3) 공용 위젯 ChunkyButton(3px 테두리, 아래 6px 딱딱한 그림자, 누르면 4px 내려감), ChunkyCard, StatChip
4) BossSprite: 시험지 보스 캐릭터(CustomPainter), 둥둥 떠다니는 모션, hit()/miss() 애니메이션
5) go_router + 하단 탭 4개(로비/문제은행/모의고사/내 카드) 뼈대
까지 해줘. A의 모델이 오기 전에는 QuizCard.sample() 더미로 작업해.
위젯 하나 만들 때마다 flutter analyze 통과 확인하고 커밋해줘.
```

---

## 매일 쓰는 지시문

### 작업 시작
```
git checkout main && git pull 한 다음, docs/tasks/[A 또는 B].md에서
체크 안 된 첫 항목을 골라 feat/[a 또는 b]-[기능이름] 브랜치를 만들고 시작해줘.
작업 전에 어떤 파일을 만들고 고칠지 먼저 짧게 알려줘.
```

### 작업 끝
```
flutter analyze 깨끗한지, 앱이 실행되는지 확인해줘.
docs/tasks의 해당 항목에 체크하고, 커밋 메시지는 docs/GIT.md 형식으로.
push 하고 gh pr create 로 PR 만들어줘. 공용 폴더(lib/core)를 건드렸으면 PR 설명 맨 위에 "공용 변경"이라고 써줘.
```

### 상대 PR 리뷰
```
gh pr list 로 열린 PR을 보여주고, [번호]번 PR의 변경 내용을 요약해줘.
docs/DATA.md 계약(모델 필드, VoteButton, BankRepository, BossSprite)을 깨는 부분이 있는지 확인해줘.
```

### 디자인 맞추기
```
이 화면을 docs/DESIGN.md 규칙대로 다듬어줘:
색은 tokens.dart 값만, 카드·버튼은 ChunkyCard/ChunkyButton, 제목은 Black Han Sans.
그라데이션·흐린 그림자·이모지가 있으면 없애줘.
```

---

## 기능별 지시문 예시

### A — AI 카드 생성
```
lib/core/ai/card_generator.dart 를 만들어줘.
firebase_ai 패키지로 Gemini를 쓰고, 이미지(또는 PDF) 바이트를 받아
docs/DATA.md의 QuizCard 필드에 맞는 JSON 배열 + summary 를 responseSchema로 강제해서 받아줘.
생성된 카드는 전부 status: draft. 프롬프트는 lib/core/ai/prompts.dart 에 따로 두고,
하루 생성 횟수·파일 크기 제한은 lib/core/config.dart 값으로 막아줘.
```

### A — 모의고사 보스전
```
lib/features/mock_exam 을 만들어줘.
B의 BankRepository.topVoted(roomId, weeks, limit)로 표 많은 순 문항을 받아
10/20/30문항, 주차 범위 선택 → 전체 제한 시간 → 문제 이동 → 마지막에 일괄 채점.
화면 위쪽엔 BossSprite(hp = 남은 문제 수), 정답이면 hit() + "적중!", 오답이면 miss() + "빗나감".
결과 화면은 랭크(S/A/B/C), 점수, 틀린 문제(각 문제 투표 수와 VoteButton), 오답은 attempts에 mode: mock 저장.
```

### B — 투표
```
lib/core/widgets/vote_button.dart 에 VoteButton(roomId, cardId)를 만들어줘.
rooms/{roomId}/bank/{cardId}의 voters·voteCount를 트랜잭션으로 토글(한 사람 1표, 다시 누르면 취소).
누르면 lime으로 바뀌고 "+1"이 튀어 올랐다 사라지고 HapticFeedback.lightImpact.
"선우 외 2명이 나올 것 같대요" 문구를 만드는 함수도 같이.
```

### B — 2인 배틀
```
lib/features/battle 을 만들어줘. docs/SPEC.md 8번과 docs/DATA.md rooms/answers 구조대로.
대기실 → 3-2-1 → 문제(15초) → 동시 제출 → 정답 공개 → 다음, 점수 = 500 + 남은시간비율×500, 콤보 +100.
출제는 bank에서 voteCount 높은 순 우선. 상대가 나가거나 앱이 백그라운드로 가는 경우도 처리해줘.
```

---

## 막혔을 때
```
지금 에러 로그야: [붙여넣기]
원인을 먼저 설명하고, 내 담당 폴더 안에서만 고쳐줘. 공용 파일을 고쳐야 하면 고치기 전에 물어봐.
```
