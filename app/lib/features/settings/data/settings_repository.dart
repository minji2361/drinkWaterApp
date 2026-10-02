import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/database_provider.dart';

class SettingsRepository {
  SettingsRepository(this._db);

  final AppDatabase _db;

  Future<UserProfileRow?> getProfile() =>
      _db.select(_db.userProfile).getSingleOrNull();

  Future<AppSettingsRow> getSettings() =>
      _db.select(_db.appSettings).getSingle();

  /// 프로필 수정. 목표량은 [setGoal]로 따로 처리한다.
  Future<void> updateProfile({
    required String nickname,
    required Gender gender,
    required int birthYear,
    required int? heightCm,
    required int weightKg,
    required DateTime now,
  }) {
    return (_db.update(_db.userProfile)).write(UserProfileCompanion(
      nickname: Value(nickname),
      gender: Value(gender),
      birthYear: Value(birthYear),
      heightCm: Value(heightCm),
      weightKg: Value(weightKg),
      updatedAt: Value(now),
    ));
  }

  /// 목표량 변경. 오늘의 daily_summary 목표도 함께 바꾼다.
  /// 과거 날짜의 목표는 소급 변경하지 않는다 (기획서 7.1).
  Future<void> setGoal(
    int ml, {
    required bool custom,
    required String today,
    required DateTime now,
  }) {
    return _db.transaction(() async {
      await (_db.update(_db.userProfile)).write(UserProfileCompanion(
        dailyGoalMl: Value(ml),
        isGoalCustom: Value(custom),
        updatedAt: Value(now),
      ));
      await (_db.update(_db.dailySummary)
            ..where((t) => t.logDate.equals(today)))
          .write(DailySummaryCompanion(goalMl: Value(ml)));
    });
  }

  Future<void> setReminderEnabled(bool enabled) =>
      (_db.update(_db.appSettings))
          .write(AppSettingsCompanion(reminderEnabled: Value(enabled)));

  /// [start], [end]는 `HH:mm`.
  Future<void> setReminderRange(String start, String end) =>
      (_db.update(_db.appSettings)).write(AppSettingsCompanion(
        reminderStart: Value(start),
        reminderEnd: Value(end),
      ));

  Future<void> setReminderInterval(int minutes) =>
      (_db.update(_db.appSettings))
          .write(AppSettingsCompanion(reminderIntervalMin: Value(minutes)));
}

final settingsRepositoryProvider = Provider<SettingsRepository>(
  (ref) => SettingsRepository(ref.watch(appDatabaseProvider)),
);
