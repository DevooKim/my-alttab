# Liquid Glass UI 개선 계획

> Status: planned · Author: SwiftUI expert + Claude · Date: 2026-06-13

## 목표

macOS 26의 **Liquid Glass** 디자인 언어를 도입해 스위처 패널·설정·온보딩 UI를 다듬는다.
손으로 만든 `NSVisualEffectView` 글래스를 네이티브 `glassEffect`로 대체하고,
선택 하이라이트에 모핑되는 틴트 글래스를 적용한다.

## 결정 사항 (사용자 확정)

1. **하위 호환:** `#available(macOS 26, *)`로 게이팅하고, macOS 13–15에서는
   현재 머티리얼(`NSVisualEffectView` / `.ultraThinMaterial`) 폴백을 유지한다. 사용자 손실 없음.
2. **범위:** 스위처 패널 + 설정 창 + 온보딩 창 — 세 표면 전부.
3. **선택 하이라이트:** 액센트 틴트 글래스 + 선택 이동 시 모핑(`glassEffectID` + `@Namespace`).

## 핵심 제약 (CLAUDE.md + 코드에서 확인됨)

- **배포 타깃 macOS 13** (`Package.swift: .macOS(.v13)`, `Info.plist: LSMinimumSystemVersion 13.0`).
  Liquid Glass API는 전부 macOS 26+ → 모든 호출을 `#available`로 게이팅 필수.
- **이 머신은 macOS 26.5.1** → 글래스 효과를 실제로 보고 스모크 테스트 가능.
- **패널은 non-activating 유지** (`canBecomeKey == false`). 글래스 적용이 포커스 스틸을 유발하면 안 됨.
- **Swift 언어 모드 5** (tools 5.10) 유지 — 동시성 모드 변경 금지.
- System/UI 코드는 단위 테스트 불가 → `docs/smoke-test.md` 수동 검증 필요.
- 글래스는 다른 글래스를 샘플링 못 함 → 묶음은 `GlassEffectContainer`로 감싼다.

## 공통 인프라

### 1. `glassEffectWithFallback` 뷰 확장 (신규: `UI/GlassEffect+Fallback.swift`)

스위처/설정/온보딩이 공유할 단일 게이팅 헬퍼. macOS 13 빌드에서도 컴파일되도록
`@ViewBuilder` + `#available`로 분기.

```swift
extension View {
    @ViewBuilder
    func glassEffectWithFallback<S: Shape>(
        tint: Color? = nil,
        interactive: Bool = false,
        in shape: S,
        fallbackMaterial: Material = .ultraThinMaterial
    ) -> some View {
        if #available(macOS 26, *) {
            var glass = Glass.regular
            if let tint { glass = glass.tint(tint) }
            if interactive { glass = glass.interactive() }
            self.glassEffect(glass, in: shape)
        } else {
            self.background(fallbackMaterial, in: shape)
        }
    }
}
```

> 참고: `liquid-glass.md`에 `.prominent`는 없음 — 강조는 tint opacity로 처리.
> 토글/버튼 등 인터랙티브 요소에만 `.interactive()` 사용.

## 표면별 작업

### 2. 스위처 패널 (`SwitcherView.swift`, `SwitcherPanel.swift`) — 최우선

현재: `VisualEffectBackground`(NSVisualEffectView `.hudWindow`) + `clipShape` +
흰색 `strokeBorder`. 선택 행은 `Color.accentColor.opacity(0.85)` 솔리드 채움.

변경:
- **패널 배경:** macOS 26에서는 루트 콘텐츠에 `.glassEffect(.regular, in: RoundedRectangle(cornerRadius: 16, style: .continuous))`
  적용, 수동 stroke 제거(글래스가 자체 테두리/광택 제공). macOS 13–15는 기존
  `VisualEffectBackground` + stroke 폴백 유지.
  - `SwitcherPanel`은 이미 `isOpaque=false`, `backgroundColor=.clear` → 글래스 호환. 변경 없음.
- **선택 하이라이트(모핑):** `list` 의 `VStack`을 `GlassEffectContainer(spacing: 2)`로 감싸고,
  선택된 행의 `selectionBackground`를 `.fill` 스타일일 때
  `.glassEffect(.regular.tint(.accentColor.opacity(0.5)), in: RoundedRectangle(cornerRadius: 8))`
  + `.glassEffectID("selection", in: namespace)`로 구현.
  - `@Namespace private var selection` 을 `SwitcherView`에 추가, `SwitcherRow`로 전달.
  - 선택 인덱스 변경 시 `withAnimation(.smooth)`로 감싸 모핑 발생(기존 scrollTo 애니메이션과 병행).
  - `.border` 하이라이트 스타일은 글래스 없이 현행 유지(미니멀 의도 존중).
  - macOS 13–15 폴백: 현재 솔리드 액센트 채움 그대로.
- **Space 배지:** 선택 시 글래스 위 대비 확보 위해 현재 흰색 로직 유지. 변경 없음.
- **컨테이너 간격 규칙:** `GlassEffectContainer(spacing:)` 값을 실제 `VStack(spacing:)`와 일치(=2).

> 주의: 글래스 위 텍스트 가독성. `.fill` 선택 시 현재 `foregroundColor(.white)` 유지하되,
> 틴트 opacity를 0.5 근처로 잡아 미니맥스 대비 확인(스모크 테스트에서 라이트/다크 모두 점검).

### 3. 설정 창 (`SettingsView.swift`, `SettingsWindowController.swift`)

현재: `TabView` + `Form(.grouped)`. macOS 26는 Form/TabView가 기본적으로 글래스
머티리얼을 자동 채택하므로 **과한 수동 글래스는 지양**(liquid-glass.md: "use sparingly").

변경(보수적):
- **About 탭의 액션 버튼**("업데이트 확인")에 macOS 26 한정 `.buttonStyle(.glass)` 적용,
  폴백은 기본 버튼 스타일. (인터랙티브 요소에만)
- **`SettingsWindowController`** 가 윈도우 배경을 불투명하게 강제하는 코드가 있으면 제거해
  시스템 글래스 머티리얼이 드러나게 함(컨트롤러 확인 후 결정).
- Form 자체에는 수동 `glassEffect` 적용하지 않음(시스템 기본에 맡김 → 스크롤 엣지 이펙트와 충돌 방지).

### 4. 온보딩 창 (`OnboardingView.swift`, `OnboardingWindowController.swift`)

현재: 단색 카드 레이아웃, 단축키 칩은 `Color.secondary.opacity(0.15)` 라운드 사각형.

변경:
- **단축키 칩:** `.background(RoundedRectangle...)` → `glassEffectWithFallback(in: .capsule)` 또는
  `RoundedRectangle(cornerRadius: 6)`. 4개 칩을 `GlassEffectContainer`로 묶어 일관 샘플링.
- **시작 버튼:** macOS 26에서 `.buttonStyle(.glassProminent)`(주요 액션), 폴백은 현재
  `.controlSize(.large)` 기본 버튼. `.defaultAction` 키보드 단축키 유지.
- **권한 "허용" 버튼:** `.buttonStyle(.glass)` (보조 액션), 폴백 기본.
- 카드 배경 자체는 온보딩 윈도우 컨트롤러가 이미 머티리얼/불투명 처리하는지 확인 후 최소 변경.

## 구현 순서

1. `UI/GlassEffect+Fallback.swift` 확장 추가 → `make app` 로 macOS 13 게이팅 컴파일 확인.
2. 스위처 패널 배경 글래스화 + 폴백 (시각 임팩트 최대, 먼저 검증).
3. 스위처 선택 하이라이트 모핑(`@Namespace` + `GlassEffectContainer` + `glassEffectID`).
4. 온보딩 칩/버튼 글래스화.
5. 설정 About 버튼 + 윈도우 배경 정리.
6. 각 단계마다 `make run` 으로 실제 글래스 렌더 육안 확인(머신이 macOS 26).

## 검증

- `make test` — 단위 테스트(모델 로직)는 영향 없어야 함. 글래스는 전부 UI 계층.
- `docs/smoke-test.md` 워크스루 — System/UI 변경이므로 필수. 특히:
  - 스위처가 hold-modifier 인터랙션 중 포커스를 훔치지 않는지(non-activating 유지).
  - 빠른 재오픈(페이드 중 재호출) 시 패널이 사라지지 않는지(generation 로직 회귀 없음).
  - 라이트/다크 모드 양쪽에서 선택 행 텍스트 대비.
  - 멀티 디스플레이에서 글래스 배경 정상 렌더.
- macOS 13–15 폴백 경로: 이 머신에선 직접 못 보지만, `#available` else 분기가
  기존 코드와 동일해야 함(diff로 폴백이 현행 동작과 일치하는지 검토).

## 리스크 / 메모

- **글래스 위 가독성**이 가장 큰 리스크 — 틴트 opacity와 텍스트 색을 스모크에서 튜닝.
- `glassEffectID` 모핑이 `ScrollViewReader.scrollTo` 애니메이션과 겹칠 때 점프/깜빡임
  가능 → 애니메이션 커브/타이밍 조정 여지 둠.
- 설정/온보딩은 시스템 기본 글래스에 최대한 위임 — 수동 글래스 남발 금지(WWDC25 가이드).
- 버전 bump/릴리스는 별도(작업 완료 후 `make bump-minor && make publish`).
```
