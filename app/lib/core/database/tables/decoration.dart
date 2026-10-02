import 'package:drift/drift.dart';

import '../enums.dart';

/// 아이템 마스터. z_index와 앵커 좌표는 카테고리별 앱 상수로 관리하므로 두지 않는다.
class DecorationItem extends Table {
  TextColumn get id => text()();
  TextColumn get category => text().map(decorationCategoryConverter)();
  TextColumn get name => text()();

  /// 에셋 경로.
  TextColumn get assetKey => text()();
  TextColumn get unlockType => text().map(unlockTypeConverter)();

  /// 해금 조건 수치 (기본 제공은 0).
  IntColumn get unlockValue => integer().withDefault(const Constant(0))();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  BoolColumn get isPremium => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

/// 장착 상태. 카테고리당 1행 고정 (최대 7행).
class UserDecoration extends Table {
  TextColumn get category => text().map(decorationCategoryConverter)();

  /// null = 해제(없음). 코·볼·머리장식만 허용 (앱 레이어에서 검증).
  TextColumn get itemId =>
      text().nullable().references(DecorationItem, #id)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {category};
}

/// 해금 이력.
class UserUnlockedItem extends Table {
  TextColumn get itemId => text().references(DecorationItem, #id)();
  DateTimeColumn get unlockedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {itemId};
}
