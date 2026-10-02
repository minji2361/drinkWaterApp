import 'dart:math' as math;

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/decoration_seed.dart';
import '../../../core/database/database_provider.dart';
import '../../../core/utils/date_utils.dart';
import '../domain/intake_rules.dart';

/// 일일 상한을 넘는 기록 시도.
class IntakeBlocked implements Exception {
  const IntakeBlocked(this.kind);
  final LimitKind kind;
}

class IntakeResult {
  const IntakeResult({
    required this.ids,
    required this.amountMl,
    required this.previousTotalMl,
    required this.summary,
    required this.justAchieved,
    required this.celebrate,
    required this.fastAchieve,
    this.newlyUnlocked = const [],
  });

  /// 생성된 intake_log id (묶음이면 여러 건).
  final List<int> ids;
  final int amountMl;
  final int previousTotalMl;
  final DailySummaryRow summary;

  /// 이번 기록으로 목표를 처음 달성했는지 (스트릭 +1 발생).
  final bool justAchieved;

  /// 축하 연출 재생 여부 (하루 1회).
  final bool celebrate;

  /// 목표를 첫 기록 후 10분 이내에 달성했는지 (기획서 5.6.5).
  final bool fastAchieve;

  /// 이번 달성으로 새로 해금된 꾸미기 아이템 (기획서 S3 해금 조건).
  final List<DecorationItemRow> newlyUnlocked;
}

extension CupSettings on AppSettingsRow {
  int cupMl(CupType type) => switch (type) {
        CupType.paper => cupPaperMl,
        CupType.mug => cupMugMl,
        CupType.tumbler => cupTumblerMl,
        CupType.other => cupOtherMl,
      };

  int get defaultCupMl => cupMl(defaultCupType);
}

class IntakeRepository {
  IntakeRepository(this._db);

  final AppDatabase _db;

  static const Duration fastAchieveWindow = Duration(minutes: 10);

  // ---- 조회 -------------------------------------------------------------

  Stream<DailySummaryRow?> watchSummary(String logDate) =>
      (_db.select(_db.dailySummary)..where((t) => t.logDate.equals(logDate)))
          .watchSingleOrNull();

  Stream<StreakRow> watchStreak() => _db.select(_db.streak).watchSingle();

  Stream<AppSettingsRow> watchSettings() =>
      _db.select(_db.appSettings).watchSingle();

  Stream<UserProfileRow?> watchProfile() =>
      _db.select(_db.userProfile).watchSingleOrNull();

  Future<AppSettingsRow> getSettings() =>
      _db.select(_db.appSettings).getSingle();

  // ---- 날짜 전환 (기획서 5.4) ----------------------------------------------

  /// 오늘 날짜의 daily_summary를 보장하고 스트릭을 갱신한다.
  /// 앱 시작, 포그라운드 복귀(resumed), 자정 경과 시 호출한다.
  Future<void> ensureToday(DateTime now) {
    final today = toLogDate(now);
    return _db.transaction(() async {
      await _ensureSummary(today);
      await (_db.update(_db.appSettings))
          .write(AppSettingsCompanion(lastOpenedDate: Value(today)));

      // 전날 목표를 달성하지 못했다면 스트릭을 끊는다.
      final streak = await _db.select(_db.streak).getSingle();
      final last = streak.lastAchievedDate;
      if (streak.currentStreak > 0 &&
          last != today &&
          last != previousLogDate(today)) {
        await (_db.update(_db.streak))
            .write(const StreakCompanion(currentStreak: Value(0)));
      }
    });
  }

  Future<DailySummaryRow> _ensureSummary(String date) async {
    final existing = await (_db.select(_db.dailySummary)
          ..where((t) => t.logDate.equals(date)))
        .getSingleOrNull();
    if (existing != null) return existing;

    final profile = await _db.select(_db.userProfile).getSingleOrNull();
    if (profile == null) {
      throw StateError('user_profile이 없습니다. 온보딩 완료 후에만 기록할 수 있습니다.');
    }
    await _db.into(_db.dailySummary).insert(DailySummaryCompanion.insert(
          logDate: date,
          goalMl: profile.dailyGoalMl,
        ));
    return (_db.select(_db.dailySummary)..where((t) => t.logDate.equals(date)))
        .getSingle();
  }

  // ---- 기록 / 되돌리기 -----------------------------------------------------

  /// 물 기록. [count]가 2 이상이면 `amountMl`씩 분리 저장하고 source는 bulk가 된다 (기획서 5.2).
  /// 일일 상한을 넘으면 [IntakeBlocked]를 던지고 아무것도 저장하지 않는다.
  Future<IntakeResult> addIntake({
    required int amountMl,
    int count = 1,
    required IntakeSource source,
    required CupType cupType,
    required DateTime now,
  }) {
    final date = toLogDate(now);
    return _db.transaction(() async {
      final before = await _ensureSummary(date);

      final exceeded = IntakeRules.exceeded(
        totalMl: before.totalMl,
        logCount: before.logCount,
        addMl: amountMl * count,
        addCount: count,
      );
      if (exceeded != null) throw IntakeBlocked(exceeded);

      final isBulk = count > 1;
      final batchId = isBulk ? 'b${now.microsecondsSinceEpoch}' : null;
      final ids = <int>[];
      for (var i = 0; i < count; i++) {
        ids.add(await _db.into(_db.intakeLog).insert(IntakeLogCompanion.insert(
              amountMl: amountMl,
              loggedAt: now,
              logDate: date,
              source: isBulk ? IntakeSource.bulk : source,
              batchId: Value(batchId),
              cupType: Value(cupType),
            )));
      }

      var summary = await _recompute(date);
      final justAchieved = !before.isAchieved && summary.totalMl >= summary.goalMl;
      var celebrate = false;
      var fast = false;
      var unlocked = <DecorationItemRow>[];

      if (justAchieved) {
        await _applyAchievement(date);
        unlocked = await grantEligibleUnlocks(_db);
        // 과다 섭취는 성취로 연출하지 않는다 (기획서 5.1).
        celebrate = !before.celebrated && summary.totalMl <= IntakeRules.maxDailyMl;
        final first = summary.firstLoggedAt;
        fast = celebrate &&
            first != null &&
            now.difference(first) <= fastAchieveWindow;
        await (_db.update(_db.dailySummary)
              ..where((t) => t.logDate.equals(date)))
            .write(DailySummaryCompanion(
          isAchieved: const Value(true),
          celebrated: Value(before.celebrated || celebrate),
        ));
        summary = await _getSummary(date);
      }

      return IntakeResult(
        ids: ids,
        amountMl: amountMl,
        previousTotalMl: before.totalMl,
        summary: summary,
        justAchieved: justAchieved,
        celebrate: celebrate,
        fastAchieve: fast,
        newlyUnlocked: unlocked,
      );
    });
  }

  /// 되돌리기 (물리 삭제). 달성 상태가 풀리면 오늘 증가한 스트릭도 되돌린다.
  /// 축하 연출 플래그(celebrated)는 유지해 같은 날 재연출을 막는다.
  Future<void> undo(List<int> ids) {
    if (ids.isEmpty) return Future.value();
    return _db.transaction(() async {
      final rows = await (_db.select(_db.intakeLog)
            ..where((t) => t.id.isIn(ids)))
          .get();
      if (rows.isEmpty) return;
      final date = rows.first.logDate;

      await (_db.delete(_db.intakeLog)..where((t) => t.id.isIn(ids))).go();

      final before = await _getSummary(date);
      final after = await _recompute(date);
      if (before.isAchieved && after.totalMl < after.goalMl) {
        await (_db.update(_db.dailySummary)
              ..where((t) => t.logDate.equals(date)))
            .write(const DailySummaryCompanion(isAchieved: Value(false)));
        await _revertAchievement(date);
      }
    });
  }

  Future<DailySummaryRow> _getSummary(String date) =>
      (_db.select(_db.dailySummary)..where((t) => t.logDate.equals(date)))
          .getSingle();

  /// intake_log에서 당일 집계를 다시 계산해 daily_summary에 반영한다.
  Future<DailySummaryRow> _recompute(String date) async {
    final sum = _db.intakeLog.amountMl.sum();
    final cnt = _db.intakeLog.id.count();
    final first = _db.intakeLog.loggedAt.min();
    final row = await (_db.selectOnly(_db.intakeLog)
          ..addColumns([sum, cnt, first])
          ..where(_db.intakeLog.logDate.equals(date)))
        .getSingle();

    await (_db.update(_db.dailySummary)..where((t) => t.logDate.equals(date)))
        .write(DailySummaryCompanion(
      totalMl: Value(row.read(sum) ?? 0),
      logCount: Value(row.read(cnt) ?? 0),
      firstLoggedAt: Value(row.read(first)),
    ));
    return _getSummary(date);
  }

  Future<void> _applyAchievement(String date) async {
    final s = await _db.select(_db.streak).getSingle();
    final next = s.currentStreak + 1;
    await (_db.update(_db.streak)).write(StreakCompanion(
      currentStreak: Value(next),
      bestStreak: Value(math.max(s.bestStreak, next)),
      lastAchievedDate: Value(date),
    ));
  }

  Future<void> _revertAchievement(String date) async {
    final s = await _db.select(_db.streak).getSingle();
    if (s.lastAchievedDate != date) return;
    final next = math.max(0, s.currentStreak - 1);
    await (_db.update(_db.streak)).write(StreakCompanion(
      currentStreak: Value(next),
      lastAchievedDate: Value(next > 0 ? previousLogDate(date) : null),
    ));
  }

  // ---- 컵 설정 -----------------------------------------------------------

  /// 기록 시트에서 컵을 고르면 즉시 기본 컵으로 저장한다 (기획서 5.2).
  Future<void> setDefaultCup(CupType type) => (_db.update(_db.appSettings))
      .write(AppSettingsCompanion(defaultCupType: Value(type)));

  /// 컵 용량 수정. 이미 저장된 과거 기록은 바뀌지 않는다.
  Future<void> setCupMl(CupType type, int ml) {
    if (!IntakeRules.isValidCupMl(ml)) {
      throw ArgumentError.value(ml, 'ml', '컵 용량은 10~2,000ml, 10ml 단위');
    }
    final c = switch (type) {
      CupType.paper => AppSettingsCompanion(cupPaperMl: Value(ml)),
      CupType.mug => AppSettingsCompanion(cupMugMl: Value(ml)),
      CupType.tumbler => AppSettingsCompanion(cupTumblerMl: Value(ml)),
      CupType.other => AppSettingsCompanion(cupOtherMl: Value(ml)),
    };
    return (_db.update(_db.appSettings)).write(c);
  }
}

final intakeRepositoryProvider = Provider<IntakeRepository>(
  (ref) => IntakeRepository(ref.watch(appDatabaseProvider)),
);
