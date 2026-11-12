# Git 규칙

## 처음 한 번
1. A가 GitHub에 레포 생성 → B를 Collaborator로 초대
2. Settings → Branches → `main` 보호: PR 필수, 승인 0명 (일정상 본인이 바로 merge)
3. A가 이 문서 세트 + `flutter create`로 만든 프로젝트를 `main`에 첫 커밋
4. 두 사람 각자 clone → `flutter pub get` → 실행 확인

## 브랜치
- `main` — 항상 실행되는 상태
- 작업 브랜치: `feat/a-<기능>`, `feat/b-<기능>`, 버그는 `fix/a-<내용>`
  - 예: `feat/a-card-generate`, `feat/b-room-lobby`
- 브랜치 하나 = 작업 목록의 항목 하나. 오래 끌지 않는다 (하루 안에 merge)

## 커밋 메시지
```
feat: 이미지에서 카드 생성
fix: 대기실에서 상대가 나가면 멈추는 문제
style: 버튼 눌림 모션 조정
docs: DATA.md에 emphasis 필드 추가
```

## 하루 루틴
1. 시작: `git checkout main && git pull` → 새 브랜치
2. 작업 → `flutter analyze` 통과 → 커밋
3. push → PR → `flutter analyze` 통과 확인 후 본인이 Squash merge → 상대에게 알림 (리뷰는 시간 날 때 merge 후에 훑기)
4. 상대 PR이 merge되면 내 브랜치에 `git pull origin main`으로 바로 반영

## 충돌 줄이는 법
- 자기 폴더만 고친다 (`docs/ROLES.md`)
- `pubspec.yaml` 패키지 추가는 PR 제목에 `[deps]`를 붙이고 merge 후 상대에게 알린다
- 공용 파일 수정은 작게, 따로 PR

## 올리면 안 되는 것
- API 키, 개인 녹음·강의자료 원본 (테스트용 샘플은 직접 만든 것만 `test_assets/`에)
