import 'package:drift/drift.dart';

import '../enums.dart';

/// 물 기록. 기록 1건 = 1잔. amount_ml이 모든 집계의 기준이다.
/// 되돌리기는 soft delete가 아닌 물리 삭제.
@TableIndex(name: 'idx_intake_log_date', columns: {#logDate})
@DataClassName('IntakeLogRow')
class IntakeLog extends Table {
  IntColumn get id => integer().autoIncrement()();

  /// 기록 시점의 컵 용량(ml).
  IntColumn get amountMl => integer()();
  DateTimeColumn get loggedAt => dateTime()();

  /// `YYYY-MM-DD` (저장 시점의 로컬 날짜). 집계 성능용 비정규화 컬럼.
  TextColumn get logDate => text().withLength(min: 10, max: 10)();
  TextColumn get source => text().map(intakeSourceConverter)();

  /// 묶음 기록 시 동일 값. 되돌리기를 묶음 단위로 처리하기 위함.
  TextColumn get batchId => text().nullable()();

  /// 분석용 보조 컬럼 (집계에는 사용하지 않음).
  TextColumn get cupType => text().map(cupTypeConverter).nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}
