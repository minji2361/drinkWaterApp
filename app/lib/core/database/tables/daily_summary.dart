import 'package:drift/drift.dart';

/// 일별 집계. goal_ml을 함께 저장해 목표 변경이 과거 달성 여부를 소급 변경하지 않게 한다.
@DataClassName('DailySummaryRow')
class DailySummary extends Table {
  /// `YYYY-MM-DD`
  TextColumn get logDate => text().withLength(min: 10, max: 10)();
  IntColumn get totalMl => integer().withDefault(const Constant(0))();

  /// 당일 기록 횟수. 30회 상한 판정용 (기획서 5.6.4).
  IntColumn get logCount => integer().withDefault(const Constant(0))();
  IntColumn get goalMl => integer()();
  BoolColumn get isAchieved => boolean().withDefault(const Constant(false))();

  /// 축하 연출 재생 여부 (하루 1회).
  BoolColumn get celebrated => boolean().withDefault(const Constant(false))();

  /// 10분 이내 급속 달성 판정용 (기획서 5.6.5).
  DateTimeColumn get firstLoggedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {logDate};
}
