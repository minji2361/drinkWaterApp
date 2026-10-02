import 'package:drift/drift.dart';

import '../enums.dart';

/// 단일 행 (id = 1). 나이는 저장하지 않고 birth_year로 계산한다.
@DataClassName('UserProfileRow')
class UserProfile extends Table {
  IntColumn get id => integer().withDefault(const Constant(1))();
  TextColumn get nickname => text().withLength(min: 1, max: 10)();
  TextColumn get gender => text().map(genderConverter)();
  IntColumn get birthYear => integer()();
  IntColumn get heightCm => integer().nullable()();
  IntColumn get weightKg => integer()();
  IntColumn get dailyGoalMl => integer()();
  BoolColumn get isGoalCustom =>
      boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<String> get customConstraints => ['CHECK (id = 1)'];
}
