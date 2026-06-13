# 온보딩 & 빈 상태 피드백 설계

**날짜**: 2026-06-13
**대상**: My AltTab (v0.3.0 기준)

두 가지 UX 개선을 추가한다: (2) 첫 실행 온보딩 창, (3) 전환할 창이 없을
때의 빈 상태 피드백.

---

## 기능 3: 빈 상태 피드백

### 문제
`SwitcherController.begin()`은 필터링 후 창이 0개면 `guard !windows.isEmpty
else { return }`로 아무것도 표시하지 않는다. 사용자는 단축키를 눌렀는데
반응이 없는 것처럼 느낀다 (창이 아예 없거나 블랙리스트로 다 걸러진 경우).

### 동작
- 필터링 후 창이 0개여도 패널을 띄우고 "전환할 창이 없습니다" 메시지를
  표시한다. 기존 frosted-glass 패널을 그대로 재사용한다.
- 빈 세션도 `SwitcherSession(windows: [])`으로 생성한다. selectedIndex는
  0, selectedWindow는 nil (기존 로직 그대로).
- 빈 세션 동안 입력 처리:
  - 트리거 반복(Tab)/역방향/Quick Action(W·Q): 무시 (선택할 대상 없음)
  - modifier(Option) release: 닫기 (commit — selectedWindow가 nil이라
    활성화 동작 없음, 기존 `commit()`이 이미 처리)
  - Escape: 닫기 (cancel)
- 자동 타임아웃: 패널 표시 후 2초가 지나면 자동으로 닫는다. modifier
  release / Escape / 타임아웃 중 먼저 오는 것이 닫는다. 닫힐 때 타이머 무효화.

### 구현 지점
- `SwitcherView`: 윈도우 배열이 비었을 때 메시지 행을 렌더링하는 분기 추가.
  아이콘(`macwindow` SF Symbol) + "전환할 창이 없습니다" 텍스트.
- `SwitcherController.begin()`: `guard !windows.isEmpty` 제거. 빈 배열이면
  세션을 만들고 패널을 띄우되 2초 타임아웃 타이머를 건다.
- `SwitcherController`: 타임아웃 타이머 프로퍼티 추가. commit/cancel/새
  세션 시작 시 무효화.
- 빈 세션 식별: `SwitcherSession.windows.isEmpty`로 판단. 빈 세션에서
  advance/retreat/removeSelected/select는 이미 no-op (기존 가드).

---

## 기능 2: 첫 실행 온보딩 창

### 첫 실행 판정
- `Preferences`에 `hasCompletedOnboarding: Bool` (기본 false) 추가.
- AppDelegate가 launch 시 false면 온보딩 창을 띄운다. "시작하기"를 누르면
  true로 저장하고 다시 뜨지 않는다.

### 권한 흐름 순서 (핵심)
- **첫 실행** (`hasCompletedOnboarding == false`): 온보딩 창을 띄우고,
  기존 `AccessibilityPermission.promptIfNeeded()`는 **호출하지 않는다**.
  권한 유도는 온보딩 창 안에서 처리.
- **이후 실행**: 기존대로 `promptIfNeeded()`만 호출 (권한 미부여 시 알림).

### 온보딩 창 구성
`OnboardingWindowController` (NSWindowController) + `OnboardingView`
(SwiftUI). 일반 NSWindow (titled, closable), 화면 중앙. LSUIElement 앱이라
`NSApp.activate(ignoringOtherApps:)` 후 `makeKeyAndOrderFront` (기존
SettingsWindowController와 동일 패턴).

내용:
- 앱 아이콘 (`NSApp.applicationIconImage`) + "My AltTab" 제목 + 한 줄 소개
- 핵심 단축키 안내 (키캡 스타일):
  - Option+Tab — 전체 윈도우 전환
  - Option+` — 현재 앱 윈도우 전환
  - ← — 역방향 이동
  - W / Q — 선택한 창 닫기 / 앱 종료
- 손쉬운 사용 권한 섹션 (상태 표시 + 버튼):
  - 미부여: "⚠️ 손쉬운 사용 권한이 필요합니다" + [권한 허용] 버튼 →
    누르면 시스템 설정 deep link 열고 폴링 시작
  - 부여됨: "✓ 손쉬운 사용 권한 허용됨" (체크)
- [시작하기] 버튼 → `hasCompletedOnboarding = true`, 창 닫기

### 권한 상태 실시간 갱신
- 온보딩 창이 열려 있는 동안 1초 간격 타이머로
  `AccessibilityPermission.isGranted`를 폴링해 UI 상태(@State)를 갱신.
- 사용자가 시스템 설정에서 허용하면 창으로 돌아왔을 때 ✓로 전환.
- 창이 닫히면(onDisappear) 타이머 정지.

### 권한 유도 헬퍼
- 기존 `AccessibilityPermission`에 deep link만 여는 메서드가 알림과
  묶여 있으므로, 시스템 설정을 직접 여는 경로를 분리한다:
  `AccessibilityPermission.openSystemSettings()` (alert 없이 deep link).
  기존 `promptIfNeeded()`는 이 메서드를 재사용.

---

## 테스트

- 순수 로직 추가가 적다. `Preferences.hasCompletedOnboarding` 기본값/영속성
  단위 테스트 추가.
- 빈 상태/온보딩 창/권한 폴링은 시스템·UI 의존이라 단위 테스트 불가 →
  docs/smoke-test.md에 항목 추가:
  - 첫 실행 시 온보딩 창이 뜨고 권한 알림은 안 뜬다
  - 권한 허용 시 온보딩 창 상태가 ✓로 바뀐다
  - "시작하기" 후 재실행 시 온보딩이 안 뜬다
  - 모든 창을 블랙리스트에 넣고 Option+Tab → "전환할 창이 없습니다" 패널
  - 빈 패널이 modifier release / Escape / 2초 타임아웃으로 닫힌다

## 영향 범위
- 신규: `OnboardingWindowController.swift`, `OnboardingView.swift`
- 수정: `Preferences.swift` (키 추가), `SwitcherController.swift` (빈 상태 +
  타임아웃), `SwitcherView.swift` (빈 메시지), `AppDelegate.swift` (온보딩
  분기), `AccessibilityPermission.swift` (deep link 분리)
- 버전 영향: 기능 추가 → 다음 릴리스는 minor (0.4.0)
