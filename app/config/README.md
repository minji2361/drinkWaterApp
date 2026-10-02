# 환경 설정 (서버·외부 도구)

MVP는 서버 없이 동작하므로 **이 설정을 안 해도 앱은 정상 실행된다.** 서버·분석 도구를 붙일 때
아래 방식으로 값을 주입한다. 값을 읽는 코드는 `lib/core/config/app_config.dart`.

## 사용법

```bash
cp config/dart_defines.example.json config/dart_defines.dev.json   # 값 채우기
flutter run --dart-define-from-file=config/dart_defines.dev.json
flutter build apk --dart-define-from-file=config/dart_defines.prod.json
```

`config/dart_defines.*.json`(예시 파일 제외)은 `.gitignore`에 들어 있어 커밋되지 않는다.

## 항목

| 키 | 용도 | 비고 |
|---|---|---|
| `APP_ENV` | `dev` / `staging` / `prod` | 기본 `dev` |
| `SUPABASE_URL`, `SUPABASE_ANON_KEY` | Supabase 연결 (소셜·클라우드 백업, P3) | 둘 다 있어야 `hasSupabase` |
| `API_BASE_URL` | 자체 API 서버 (Spring Boot 등) | prod는 https |
| `ANALYTICS_ENABLED` | Firebase Analytics | 기획서 8장 이벤트 |
| `CRASH_REPORTING_ENABLED` | Firebase Crashlytics | |
| `CLOUD_BACKUP_ENABLED` | 기기 간 백업·복원 | 서버 연결 정보 필요 |

## 주의

- 앱 번들의 값은 사용자가 꺼내 볼 수 있다. Supabase `anon` 키처럼 **공개를 전제로 한 키만** 넣고,
  `service_role` 키·서버 비밀키는 절대 넣지 않는다.
- Firebase는 이 설정이 아니라 네이티브 파일(`google-services.json`, `GoogleService-Info.plist`)로 연결한다.
  이 파일들도 저장소 공개 여부에 따라 커밋 정책을 정할 것.
- CI에서 값이 필요하면 GitHub Secrets를 쓰고 `--dart-define`으로 넘긴다.
