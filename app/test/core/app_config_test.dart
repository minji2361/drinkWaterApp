import 'package:drink_water_app/core/config/app_config.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('기본값은 서버·분석 연동이 모두 꺼져 있고 문제도 없다 (MVP)', () {
    const c = AppConfig();
    expect(c.env, AppEnv.dev);
    expect(c.isProd, isFalse);
    expect(c.hasSupabase, isFalse);
    expect(c.hasApiServer, isFalse);
    expect(c.analyticsEnabled, isFalse);
    expect(c.crashReportingEnabled, isFalse);
    expect(c.cloudBackupEnabled, isFalse);
    expect(c.validate(), isEmpty);
  });

  test('빌드 시 값을 주입하지 않으면 fromEnvironment도 기본값과 같다', () {
    const c = AppConfig.fromEnvironment();
    expect(c.env, AppEnv.dev);
    expect(c.hasSupabase, isFalse);
    expect(c.cloudBackupEnabled, isFalse);
  });

  test('APP_ENV 파싱: 알 수 없는 값은 dev', () {
    expect(AppEnv.parse('prod'), AppEnv.prod);
    expect(AppEnv.parse('staging'), AppEnv.staging);
    expect(AppEnv.parse('???'), AppEnv.dev);
    expect(AppEnv.parse(''), AppEnv.dev);
  });

  test('Supabase는 URL과 키가 모두 있어야 사용 가능', () {
    expect(const AppConfig(supabaseUrl: 'https://x.supabase.co').hasSupabase,
        isFalse);
    expect(
      const AppConfig(
        supabaseUrl: 'https://x.supabase.co',
        supabaseAnonKey: 'anon',
      ).hasSupabase,
      isTrue,
    );
  });

  group('validate', () {
    test('클라우드 백업을 켰는데 연결 정보가 없으면 문제로 보고한다', () {
      expect(const AppConfig(cloudBackupEnabled: true).validate(),
          hasLength(1));
      expect(
        const AppConfig(
          cloudBackupEnabled: true,
          supabaseUrl: 'https://x.supabase.co',
          supabaseAnonKey: 'anon',
        ).validate(),
        isEmpty,
      );
      expect(
        const AppConfig(
          cloudBackupEnabled: true,
          apiBaseUrl: 'https://api.example.com',
        ).validate(),
        isEmpty,
      );
    });

    test('Supabase URL과 키는 한쪽만 설정하면 문제', () {
      expect(const AppConfig(supabaseAnonKey: 'anon').validate(),
          hasLength(1));
      expect(
          const AppConfig(supabaseUrl: 'https://x.supabase.co').validate(),
          hasLength(1));
    });

    test('prod의 API 주소는 https여야 한다', () {
      expect(
        const AppConfig(env: AppEnv.prod, apiBaseUrl: 'http://api.example.com')
            .validate(),
        hasLength(1),
      );
      expect(
        const AppConfig(env: AppEnv.dev, apiBaseUrl: 'http://localhost:8080')
            .validate(),
        isEmpty,
      );
    });
  });
}
