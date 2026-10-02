# app — Flutter 앱

기획서(`../docs/기획서_v1.4.md`) 3장 기술 스택 기준.

## 구조 (Feature-first + 3계층)

```
lib/
├── core/            # 공통: constants, theme, utils, router(go_router), database(Drift)
├── features/
│   ├── onboarding/  # S1  (P0)
│   ├── home/        # S2  (P0) 메인 + 물 기록
│   ├── decorate/    # S3  (P1) 식물 꾸미기
│   ├── stats/       # S4  (P2)
│   ├── settings/    # S5, S5-1 (P1)
│   └── notification/# 로컬 알림 (P1)
│       └── data / domain / presentation
└── l10n/            # ARB (app_ko.arb). 문구는 코드에 직접 쓰지 않는다 (기획서 3.2)
assets/              # rive, decoration, cups (에셋에 텍스트 금지)
```

## 시작하기

플랫폼 폴더(android/ios)는 아직 생성하지 않았다. Flutter SDK 설치 후:

```bash
cd app
flutter create . --org com.example --project-name drink_water_app
flutter pub get
flutter gen-l10n
dart run build_runner build   # Drift 코드 생성 (app_database.g.dart, 커밋하지 않음)
flutter run
```

> `--org`는 확정된 번들 ID에 맞게 변경할 것.

## 알림 플랫폼 설정

로컬 알림(`flutter_local_notifications`)은 `flutter create .`로 플랫폼 폴더를 만든 뒤 네이티브 설정이 필요하다.
(플러그인 버전 17.x 기준. 자세한 내용은 플러그인 문서를 확인할 것.)

**Android**

- `android/app/src/main/AndroidManifest.xml`의 `<manifest>` 아래에 권한 추가:
  `<uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>` (Android 13+ 알림 권한),
  `<uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED"/>`
- `<application>` 안에 플러그인 수신기 추가:
  `com.dexterous.flutterlocalnotifications.ScheduledNotificationReceiver`,
  `com.dexterous.flutterlocalnotifications.ScheduledNotificationBootReceiver`(재부팅 후 예약 복원)
- `android/app/build.gradle`에서 core library desugaring 활성화
  (`compileOptions { coreLibraryDesugaringEnabled true }` + `coreLibraryDesugaring` 의존성)
- 정확한 알람 권한은 쓰지 않는다. 알림이 몇 분 늦을 수 있다.

**iOS**

- `ios/Runner/AppDelegate.swift`의 `didFinishLaunchingWithOptions`에서
  `UNUserNotificationCenter.current().delegate = self as? UNUserNotificationCenterDelegate` 설정
- 권한은 설정에서 알림을 처음 켤 때 요청한다. 한 번 거부하면 앱에서 다시 요청할 수 없어 기기 설정에서 직접 켜야 한다.

**동작 요약** (`lib/features/notification/`)

- 오늘 포함 3일치를 "특정 시각 1회" 알림으로 예약하고, 앱을 열 때·물을 기록하거나 되돌릴 때·설정을 바꿀 때 다시 계산한다.
- 방금 마셨으면 마지막 기록 + 간격부터 다시 센다. 목표를 달성하면 오늘 남은 알림은 취소하고 내일부터 유지한다.
- 알림을 탭하면 앱만 열고 물은 자동으로 기록하지 않는다.
- 아직 실기기에서 확인하지 않았다 (특히 제조사별 배터리 최적화로 인한 지연).
