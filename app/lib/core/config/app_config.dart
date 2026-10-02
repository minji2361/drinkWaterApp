import 'package:flutter_riverpod/flutter_riverpod.dart';

enum AppEnv {
  dev,
  staging,
  prod;

  static AppEnv parse(String value) => AppEnv.values.firstWhere(
        (e) => e.name == value,
        orElse: () => AppEnv.dev,
      );
}

/// 추후 연결할 서버·외부 도구 설정. 빌드 시점에 `--dart-define`으로 주입한다.
///
/// ```
/// flutter run --dart-define-from-file=config/dart_defines.dev.json
/// ```
///
/// MVP(1.0)는 서버 없이 동작하므로 모든 연동 플래그의 기본값은 꺼짐이다 (기획서 3.1).
/// 값이 비어 있어도 앱은 정상 동작해야 하며, 연동 코드는 [AppConfig.hasSupabase] 같은
/// getter로 사용 가능 여부를 확인한 뒤에만 호출한다.
///
/// **비밀 값 주의**: 앱 번들에 들어가는 값은 사용자가 꺼내 볼 수 있다. Supabase의
/// `anon` 키처럼 공개를 전제로 한 키만 넣고, `service_role` 키·서버 비밀키는 절대 넣지 않는다.
class AppConfig {
  const AppConfig({
    this.env = AppEnv.dev,
    this.supabaseUrl = '',
    this.supabaseAnonKey = '',
    this.apiBaseUrl = '',
    this.analyticsEnabled = false,
    this.crashReportingEnabled = false,
    this.cloudBackupEnabled = false,
  });

  /// 빌드 시 주입된 값을 읽는다. `String.fromEnvironment`는 컴파일 타임 상수라
  /// 이 생성자는 const 컨텍스트에서만 환경값을 반영한다.
  const AppConfig.fromEnvironment()
      : env = const String.fromEnvironment('APP_ENV') == 'prod'
            ? AppEnv.prod
            : const String.fromEnvironment('APP_ENV') == 'staging'
                ? AppEnv.staging
                : AppEnv.dev,
        supabaseUrl = const String.fromEnvironment('SUPABASE_URL'),
        supabaseAnonKey = const String.fromEnvironment('SUPABASE_ANON_KEY'),
        apiBaseUrl = const String.fromEnvironment('API_BASE_URL'),
        analyticsEnabled = const bool.fromEnvironment('ANALYTICS_ENABLED'),
        crashReportingEnabled =
            const bool.fromEnvironment('CRASH_REPORTING_ENABLED'),
        cloudBackupEnabled =
            const bool.fromEnvironment('CLOUD_BACKUP_ENABLED');

  final AppEnv env;

  // ---- Supabase (소셜·클라우드 백업, P3) --------------------------------------
  final String supabaseUrl;
  final String supabaseAnonKey;

  // ---- 자체 API 서버 (Kotlin + Spring Boot 등, 사내 표준을 따를 경우) -----------
  final String apiBaseUrl;

  // ---- 기능 플래그 -----------------------------------------------------------
  /// Firebase Analytics (기획서 8장 이벤트). Firebase 프로젝트 파일
  /// (google-services.json / GoogleService-Info.plist)은 이 설정이 아니라 네이티브 설정으로 넣는다.
  final bool analyticsEnabled;

  /// Firebase Crashlytics.
  final bool crashReportingEnabled;

  /// 기기 간 백업·복원 (서버 필요, P3).
  final bool cloudBackupEnabled;

  bool get isProd => env == AppEnv.prod;

  bool get hasSupabase => supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;

  bool get hasApiServer => apiBaseUrl.isNotEmpty;

  /// 서버가 필요한 기능을 켠 상태에서 연결 정보가 비어 있으면 그 이유를 돌려준다.
  /// 시작 시 로그에 남기거나 CI에서 prod 설정을 검증하는 데 쓴다.
  List<String> validate() {
    final problems = <String>[];
    if (cloudBackupEnabled && !hasSupabase && !hasApiServer) {
      problems.add(
          'CLOUD_BACKUP_ENABLED가 켜져 있지만 SUPABASE_URL/SUPABASE_ANON_KEY 또는 API_BASE_URL이 없습니다.');
    }
    if ((supabaseUrl.isEmpty) != (supabaseAnonKey.isEmpty)) {
      problems.add('SUPABASE_URL과 SUPABASE_ANON_KEY는 함께 설정해야 합니다.');
    }
    if (apiBaseUrl.isNotEmpty && !apiBaseUrl.startsWith('https://') && isProd) {
      problems.add('prod 환경의 API_BASE_URL은 https여야 합니다.');
    }
    return problems;
  }
}

/// 앱 전역 설정. 테스트에서는 `overrideWithValue`로 바꿀 수 있다.
final appConfigProvider =
    Provider<AppConfig>((ref) => const AppConfig.fromEnvironment());
