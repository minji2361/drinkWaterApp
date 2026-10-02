import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'decoration_seed.dart';
import 'enums.dart';
import 'tables/app_settings.dart';
import 'tables/daily_summary.dart';
import 'tables/decoration.dart';
import 'tables/intake_log.dart';
import 'tables/streak.dart';
import 'tables/user_profile.dart';

export 'enums.dart';

part 'app_database.g.dart';

@DriftDatabase(tables: [
  UserProfile,
  IntakeLog,
  DailySummary,
  Streak,
  DecorationItem,
  UserDecoration,
  UserUnlockedItem,
  AppSettings,
])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  /// 테스트용 (예: `NativeDatabase.memory()`).
  AppDatabase.forTesting(super.executor);

  /// 스키마 버전을 올릴 때는 반드시 [onUpgrade] 마이그레이션을 작성한다.
  /// 테이블·컬럼 삭제는 금지 (기획서 7.2).
  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();
          await _seedSingletons();
        },
        onUpgrade: (m, from, to) async {
          if (from < 2) {
            await m.addColumn(appSettings, appSettings.decorateHintSeen);
          }
        },
        beforeOpen: (details) async {
          await customStatement('PRAGMA foreign_keys = ON');
          // 아이템 마스터·기본 지급·기본 장착 (멱등)
          await seedDecorations(this);
        },
      );

  /// 단일 행 테이블의 초기 행. user_profile은 온보딩 완료 시 생성한다.
  Future<void> _seedSingletons() async {
    await into(streak).insert(StreakCompanion.insert());
    await into(appSettings).insert(AppSettingsCompanion.insert(defaultCupType: CupType.paper));
  }
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File(p.join(dir.path, 'drink_water.sqlite'));
    return NativeDatabase.createInBackground(file);
  });
}
