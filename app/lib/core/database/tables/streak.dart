import 'package:drift/drift.dart';

/// 단일 행 (id = 1).
class Streak extends Table {
  IntColumn get id => integer().withDefault(const Constant(1))();
  IntColumn get currentStreak => integer().withDefault(const Constant(0))();
  IntColumn get bestStreak => integer().withDefault(const Constant(0))();

  /// `YYYY-MM-DD`. 아직 달성 이력이 없으면 null.
  TextColumn get lastAchievedDate => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<String> get customConstraints => ['CHECK (id = 1)'];
}
