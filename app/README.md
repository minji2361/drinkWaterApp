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
dart run build_runner build   # Drift 코드 생성 (DB 정의 추가 후)
flutter run
```

> `--org`는 확정된 번들 ID에 맞게 변경할 것.
