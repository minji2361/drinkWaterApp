# backend (예정)

MVP(1.0)에는 서버가 없다 (기획서 3.1). 소셜 연동·기기 간 백업이 필요해지는 시점(P3)에 추가한다.

## 후보

| 선택지 | 사용 시점 |
|---|---|
| **Supabase** (기본 후보) | 별도 서버 개발 없이 인증·DB·스토리지를 빠르게 붙일 때. SQL 마이그레이션과 RLS 정책을 이 폴더에서 관리 |
| Kotlin + Spring Boot | 사내 표준을 따라야 할 때 |

## 이 폴더에 둘 것 (도입 시)

- Supabase: `supabase/migrations/*.sql`, `supabase/config.toml`, Row Level Security 정책
- Spring Boot: 서버 소스, OpenAPI 스펙
- 클라이언트와 공유하는 API 스키마

## 앱 연결

앱은 `app/lib/core/config/app_config.dart`의 설정으로 서버 주소·키를 받는다.
설정 방법은 [`app/config/README.md`](../app/config/README.md) 참고.

> 서버를 도입하면 5.6.5 아래 P3 주의사항대로 **서버 측 어뷰징 검증**(기록 간격·패턴)을 함께 설계해야 한다.
