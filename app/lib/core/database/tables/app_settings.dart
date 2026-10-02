import 'package:drift/drift.dart';

import '../enums.dart';

/// 단일 행 (id = 1).
@DataClassName('AppSettingsRow')
class AppSettings extends Table {
  IntColumn get id => integer().withDefault(const Constant(1))();

  BoolColumn get reminderEnabled =>
      boolean().withDefault(const Constant(false))();
  TextColumn get reminderStart => text().withDefault(const Constant('08:00'))();
  TextColumn get reminderEnd => text().withDefault(const Constant('22:00'))();
  IntColumn get reminderIntervalMin =>
      integer().withDefault(const Constant(120))();

  BoolColumn get onboardingCompleted =>
      boolean().withDefault(const Constant(false))();

  /// `YYYY-MM-DD`. 자정 경과 판정용 (기획서 5.4). 최초 실행 전에는 null.
  TextColumn get lastOpenedDate => text().nullable()();

  /// 짧게 탭 시 기록되는 기본 컵. 용량은 해당 cup_*_ml 값 (기획서 5.2).
  /// 초기값 paper는 시드 시 지정한다 (변환 컬럼은 withDefault에 enum을 쓸 수 없음).
  TextColumn get defaultCupType => text().map(cupTypeConverter)();
  IntColumn get cupPaperMl => integer().withDefault(const Constant(200))();
  IntColumn get cupMugMl => integer().withDefault(const Constant(300))();
  IntColumn get cupTumblerMl => integer().withDefault(const Constant(500))();
  IntColumn get cupOtherMl => integer().withDefault(const Constant(350))();

  /// 꾸미기 첫 진입 안내("고르면 바로 적용돼요")를 이미 보여줬는지 (스키마 v2).
  BoolColumn get decorateHintSeen =>
      boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<String> get customConstraints => ['CHECK (id = 1)'];
}
