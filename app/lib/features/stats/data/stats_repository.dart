import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/database_provider.dart';
import '../domain/stats_models.dart';

/// 통계 조회. 집계는 SQL로 수행한다 (기획서 S4).
class StatsRepository {
  StatsRepository(this._db);

  final AppDatabase _db;

  Future<int> _profileGoal() async {
    final p = await _db.select(_db.userProfile).getSingleOrNull();
    return p?.dailyGoalMl ?? 0;
  }

  /// 일간: 시간대별(2시간 단위) 합계, 첫/마지막 기록 시각.
  Future<DayStats> dayStats(String logDate) async {
    final summary = await (_db.select(_db.dailySummary)
          ..where((t) => t.logDate.equals(logDate)))
        .getSingleOrNull();

    // 저장 시각(UTC epoch)을 그날의 로컬 UTC 오프셋만큼 밀어 시(hour)를 구한다.
    // SQLite의 'localtime'은 기기 설정에 의존하므로 쓰지 않는다.
    final d = DateTime.parse(logDate);
    final offsetSec = DateTime(d.year, d.month, d.day, 12)
        .timeZoneOffset
        .inSeconds;

    final rows = await _db.customSelect(
      "SELECT CAST(strftime('%H', logged_at + ?, 'unixepoch') AS INTEGER) / 2 "
      'AS bucket, SUM(amount_ml) AS ml '
      'FROM intake_log WHERE log_date = ? GROUP BY bucket',
      variables: [Variable.withInt(offsetSec), Variable.withString(logDate)],
      readsFrom: {_db.intakeLog},
    ).get();

    final hourly = List<int>.filled(DayStats.bucketCount, 0);
    for (final r in rows) {
      final bucket = r.read<int>('bucket');
      if (bucket >= 0 && bucket < DayStats.bucketCount) {
        hourly[bucket] = r.read<int>('ml');
      }
    }

    final first = _db.intakeLog.loggedAt.min();
    final last = _db.intakeLog.loggedAt.max();
    final range = await (_db.selectOnly(_db.intakeLog)
          ..addColumns([first, last])
          ..where(_db.intakeLog.logDate.equals(logDate)))
        .getSingle();

    return DayStats(
      date: logDate,
      totalMl: summary?.totalMl ?? 0,
      goalMl: summary?.goalMl ?? await _profileGoal(),
      logCount: summary?.logCount ?? 0,
      hourlyMl: hourly,
      firstAt: range.read(first),
      lastAt: range.read(last),
    );
  }

  /// [from] ~ [to] (양 끝 포함, `YYYY-MM-DD`)의 일별 집계.
  Future<List<DaySummary>> summariesBetween(String from, String to) async {
    final rows = await (_db.select(_db.dailySummary)
          ..where((t) => t.logDate.isBetweenValues(from, to))
          ..orderBy([(t) => OrderingTerm.asc(t.logDate)]))
        .get();
    return [
      for (final r in rows)
        DaySummary(
          date: r.logDate,
          totalMl: r.totalMl,
          goalMl: r.goalMl,
          achieved: r.isAchieved,
        ),
    ];
  }

  Future<int> fallbackGoal() => _profileGoal();

  /// 기록이 있는 날의 수 (신규 사용자 안내 판정용).
  Future<int> recordedDayCount() async {
    final cnt = _db.dailySummary.logDate.count();
    final row = await (_db.selectOnly(_db.dailySummary)
          ..addColumns([cnt])
          ..where(_db.dailySummary.totalMl.isBiggerThanValue(0)))
        .getSingle();
    return row.read(cnt) ?? 0;
  }
}

final statsRepositoryProvider = Provider<StatsRepository>(
  (ref) => StatsRepository(ref.watch(appDatabaseProvider)),
);

