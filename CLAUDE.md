# 필기 카드 배틀 — Claude Code 작업 지침

이 레포는 2인 팀(Flutter) 수업 프로젝트다. 콘셉트는 **"우리가 만드는 시험문제"**: 친구들이 "나올 것 같아요"를 누른 문제를 모아 모의고사로 푼다. 이 투표와 모의고사가 앱의 핵심 차별점이다. 작업 전에 아래 문서를 먼저 읽는다.

1. `docs/SPEC.md` — 확정 기능 명세 (무엇을 만들지, 우선순위)
2. `docs/DATA.md` — Firestore 구조와 공용 모델 (두 사람이 공유하는 계약)
3. `docs/ROLES.md` — 담당 범위와 폴더 소유권
4. `docs/tasks/A.md` 또는 `docs/tasks/B.md` — 내 작업 목록 (위에서부터 순서대로)
5. `docs/GIT.md` — 브랜치·커밋·PR 규칙
6. `docs/DESIGN.md` — 디자인 토큰과 모션 규칙

## 절대 규칙
- **내 폴더만 수정한다.** A는 `lib/features/{subjects,sources,cards,notebook,solo,mock_exam}`, B는 `lib/features/{room,bank,battle}`와 `lib/fx`. 공용 폴더(`lib/core`)는 `docs/ROLES.md`의 규칙대로만 바꾼다.
- **공용 모델(`lib/core/models`)의 필드를 바꾸면 `docs/DATA.md`도 같이 고친다.** 상대방 코드가 깨질 수 있으므로 필드는 추가만 하고 삭제·이름 변경은 하지 않는다.
- **API 키를 코드에 넣지 않는다.** AI 호출은 Firebase AI Logic(`firebase_ai`)을 통해서만 한다.
- **색·간격·폰트 값을 위젯에 직접 쓰지 않는다.** `lib/core/theme/tokens.dart`의 값만 쓴다.
- **AI가 만든 문제는 항상 `draft` 상태로 저장한다.** 사용자가 검수해야 `verified`가 된다.
- `main`에 직접 커밋하지 않는다. 작업 단위마다 `docs/GIT.md`대로 브랜치를 만든다.

## 작업 방식
- `docs/tasks/<내 역할>.md`에서 체크 안 된 첫 항목을 고르고, 끝나면 체크한다.
- 기능 하나가 끝날 때마다 `flutter analyze`가 깨끗하고 앱이 실행되는지 확인한 뒤 커밋한다.
- 확장(P3) 기능은 P1·P2가 전부 끝나기 전에는 시작하지 않는다.
- 판단이 필요한 애매한 부분은 추측해서 구현하지 말고 사용자에게 묻는다.
