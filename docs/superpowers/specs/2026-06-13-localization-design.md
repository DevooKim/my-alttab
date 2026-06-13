# 현지화 (영어 / 한국어) 설계

**날짜**: 2026-06-13
**대상**: My AltTab (v0.4.0 기준)

UI 문자열을 영어/한국어로 현지화한다. 기본은 시스템 언어 자동, 설정에서
수동 선택(자동/한국어/영어)도 제공한다.

---

## 메커니즘 (검증 완료)

SPM 리소스로 `.lproj`를 번들에 포함한다. `/tmp` 실험으로 Xcode 없이
동작 확인함:
- `Package.swift`: `defaultLocalization: "en"` + 코어 타겟에
  `resources: [.process("Resources")]`
- `Sources/MinimalTabCore/Resources/{en,ko}.lproj/Localizable.strings`
- 코드: `String(localized:)` 또는 `NSLocalizedString(_:bundle:comment:)`로
  `Bundle.module` 참조
- `swift run`에서도 동작 → 테스트 러너 영향 없음

## 언어 선택

- 기본: 시스템 언어 자동 (`Bundle.module`이 시스템 로케일에 맞는 .lproj 선택)
- 수동: 설정 UI 탭(또는 일반 탭)에 "언어: 자동 / 한국어 / English" Picker.
  `Preferences.languageOverride`에 저장 ("system" | "ko" | "en").
- 적용:
  - "자동"이면 `Bundle.module` 기본 동작 (시스템 언어)
  - "ko"/"en"이면 해당 .lproj 번들을 강제 로드해 문자열 조회
  - 런타임에 모든 뷰를 즉시 바꾸는 것은 복잡하므로, 변경 시 "재시작 후
    적용" 안내 + 기존 relaunch 로직(Updater.relaunch / ScreenRecording의
    재시작 패턴) 재사용해 자동 재시작. (재시작 한 번이면 SwiftUI/AppKit
    전체가 새 언어로 다시 그려짐 — 가장 단순하고 확실)

## 문자열 조회 진입점

`L10n` (또는 함수 `localized(_:)`) 헬퍼를 코어에 두어, languageOverride를
반영한 번들에서 문자열을 가져온다:

```
enum L10n {
    static func string(_ key: String) -> String {
        let bundle = overrideBundle ?? .module
        return bundle.localizedString(forKey: key, value: key, table: nil)
    }
    // overrideBundle: languageOverride가 ko/en이면 해당 .lproj Bundle, else nil
}
```

- 헬퍼 하나로 모든 호출을 통일 → 수동 선택이 일관되게 반영됨.
- 키 네이밍: 화면·맥락 기반 (예: "onboarding.start", "permission.title",
  "switcher.empty", "settings.tab.ui"). 영어 .strings가 사실상 기본/원문.

## 번역 대상 (사용자 노출 전부)

코드에서 한국어 리터럴을 키로 추출:
- AccessibilityPermission: 권한 알림 제목/본문/버튼
- ScreenRecordingPermission: 화면 기록 알림
- OnboardingView: 제목/소개/단축키 라벨/권한 행/시작하기
- SettingsView: 탭 이름, 섹션, 토글/피커 라벨, 블랙리스트, 정보 탭
- SwitcherView: "전환할 창이 없습니다", "(최소화됨)" 접미사, "Untitled"
- StatusBarController: 메뉴 항목 ("정보", "업데이트 확인…", Settings…, Quit)
- Updater: 업데이트 알림/버튼/에러 메시지
- SettingsWindowController / OnboardingWindowController: 창 제목

제외: `NSLog` 디버그 메시지 (개발자용, 번역 불필요).

주의:
- "(최소화됨)" 같은 접미사는 `WindowInfo.displayTitle`(Models, 순수 로직)에
  있음. Models는 시스템 의존이 없어야 하므로, 접미사 텍스트를 주입받거나
  표시 시점(View)에서 처리하도록 조정. → displayTitle에서 접미사를 분리하고
  View에서 현지화된 접미사를 붙이는 방식이 모델 순수성 유지에 맞음.

## 테스트

- `L10n` 헬퍼: 같은 키가 en/ko에서 다른 값을 반환하는지, 누락 키는 키
  자체를 반환(fallback)하는지 단위 테스트.
- .strings 파일 정합성: en/ko가 같은 키 집합을 갖는지 점검하는 테스트
  (키 누락 = 번역 빠짐 조기 발견).
- 실제 언어 전환·재시작은 수동 스모크 테스트.

## 영향 범위
- 신규: `Resources/en.lproj/Localizable.strings`,
  `Resources/ko.lproj/Localizable.strings`, `L10n.swift`
- 수정: `Package.swift`(defaultLocalization + resources), 위 모든 UI 파일의
  문자열, `Preferences.swift`(languageOverride), `WindowInfo.swift`(접미사
  분리), `SettingsView.swift`(언어 Picker), bundle.sh는 SPM이 .lproj를
  번들에 넣으므로 추가 작업 확인 필요(빌드 산출물 검증).
- 버전: 기능 추가 → minor (0.5.0)

## 번들링 (검증 완료)
`swift build -c release`는 리소스를 `.build/release/<Package>_<Target>.bundle`
(우리의 경우 `MinimalTab_MinimalTabCore.bundle`)에 모으고, 그 안에
`{en,ko}.lproj/Localizable.strings`가 들어간다 (/tmp 실험으로 확인).
`Bundle.module`은 실행 바이너리 옆(같은 디렉터리)에서 이 .bundle을 찾는다.
따라서 bundle.sh가 이 .bundle을 `Contents/MacOS/`(바이너리 옆) 또는
`Contents/Resources/`로 복사해야 한다 — 정확한 탐색 위치는 구현 시
`Bundle.module`이 해석되는지로 확정. 추가:
```
cp -R ".build/release/MinimalTab_MinimalTabCore.bundle" "$APP/Contents/Resources/"
```
그리고 `Bundle.module`이 못 찾으면 `Contents/MacOS/` 옆으로 이동해 재확인.
