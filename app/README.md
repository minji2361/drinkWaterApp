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

```bash
cd app
flutter pub get
flutter gen-l10n
dart run build_runner build   # Drift 코드 생성 (app_database.g.dart, 커밋하지 않음)
flutter run
```

- `android/`, `ios/`는 이미 생성되어 있다. 번들 ID는 임시값 `com.example.drink_water_app`이며, 확정되면
  Android(`android/app/build.gradle.kts`의 `namespace`, `applicationId`와 `MainActivity` 패키지)와
  iOS(Xcode의 Bundle Identifier)를 함께 바꾼다.

## 알림 플랫폼 설정

로컬 알림(`flutter_local_notifications` 17.x)에 필요한 네이티브 설정은 **이미 적용되어 있다.** 바꿀 때 참고용으로 남긴다.

**Android** (`android/app/src/main/AndroidManifest.xml`, `android/app/build.gradle.kts`)

- 권한: `POST_NOTIFICATIONS`(Android 13+ 알림 권한), `RECEIVE_BOOT_COMPLETED`(재부팅 후 예약 복원)
- 플러그인 수신기: `ScheduledNotificationReceiver`, `ScheduledNotificationBootReceiver`
- core library desugaring 활성화 (`isCoreLibraryDesugaringEnabled = true` + `desugar_jdk_libs`)
- 정확한 알람 권한은 쓰지 않는다. 알림이 몇 분 늦을 수 있다.

**iOS** (`ios/Runner/AppDelegate.swift`)

- `UNUserNotificationCenter` delegate를 설정해 포그라운드에서도 알림이 표시되게 한다.
- 권한은 설정에서 알림을 처음 켤 때 요청한다. 한 번 거부하면 앱에서 다시 요청할 수 없어 기기 설정에서 직접 켜야 한다.

**동작 요약** (`lib/features/notification/`)

- 오늘 포함 3일치를 "특정 시각 1회" 알림으로 예약하고, 앱을 열 때·물을 기록하거나 되돌릴 때·설정을 바꿀 때 다시 계산한다.
- 방금 마셨으면 마지막 기록 + 간격부터 다시 센다. 목표를 달성하면 오늘 남은 알림은 취소하고 내일부터 유지한다.
- 알림을 탭하면 앱만 열고 물은 자동으로 기록하지 않는다.
- 시각은 기기의 현재 시간대 기준이다. 시간대가 바뀌면 다음에 앱을 열 때 새 시간대로 다시 예약된다.
- 아직 실기기에서 확인하지 않았다 (특히 제조사별 배터리 최적화로 인한 지연).
