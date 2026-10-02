import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/database_provider.dart';
import '../domain/decoration_rules.dart';

enum DecorationRejection { unknownItem, wrongCategory, notUnlocked, cannotClear }

/// 장착할 수 없는 요청. UI는 이를 막은 상태로 두므로 정상 흐름에서는 발생하지 않는다.
class DecorationRejected implements Exception {
  const DecorationRejected(this.reason);
  final DecorationRejection reason;

  @override
  String toString() => 'DecorationRejected($reason)';
}

class DecorationRepository {
  DecorationRepository(this._db);

  final AppDatabase _db;

  Stream<List<DecorationItemRow>> watchItems() => (_db.select(_db.decorationItem)
        ..orderBy([(t) => OrderingTerm.asc(t.sortOrder)]))
      .watch();

  /// 카테고리 → 장착 중인 item_id (null = 해제).
  Stream<Map<DecorationCategory, String?>> watchEquipped() =>
      _db.select(_db.userDecoration).watch().map(
            (rows) => {for (final r in rows) r.category: r.itemId},
          );

  Stream<Set<String>> watchUnlockedIds() => _db
      .select(_db.userUnlockedItem)
      .watch()
      .map((rows) => {for (final r in rows) r.itemId});

  /// [category]에 [itemId]를 장착한다 (null이면 해제). 이전에 장착되어 있던 item_id를 돌려준다.
  /// 해금되지 않았거나 카테고리가 다르거나 해제할 수 없는 슬롯이면 [DecorationRejected].
  Future<String?> equip(
    DecorationCategory category,
    String? itemId, {
    DateTime? now,
  }) {
    return _db.transaction(() async {
      if (itemId == null) {
        if (!DecorationRules.canClear(category)) {
          throw const DecorationRejected(DecorationRejection.cannotClear);
        }
      } else {
        final item = await (_db.select(_db.decorationItem)
              ..where((t) => t.id.equals(itemId)))
            .getSingleOrNull();
        if (item == null) {
          throw const DecorationRejected(DecorationRejection.unknownItem);
        }
        if (item.category != category) {
          throw const DecorationRejected(DecorationRejection.wrongCategory);
        }
        final unlocked = await (_db.select(_db.userUnlockedItem)
              ..where((t) => t.itemId.equals(itemId)))
            .getSingleOrNull();
        if (unlocked == null) {
          throw const DecorationRejected(DecorationRejection.notUnlocked);
        }
      }

      final current = await (_db.select(_db.userDecoration)
            ..where((t) => t.category.equalsValue(category)))
          .getSingleOrNull();
      await _db.into(_db.userDecoration).insertOnConflictUpdate(
            UserDecorationCompanion.insert(
              category: category,
              itemId: Value(itemId),
              updatedAt: Value(now ?? DateTime.now()),
            ),
          );
      return current?.itemId;
    });
  }

  Future<bool> isHintSeen() async =>
      (await _db.select(_db.appSettings).getSingle()).decorateHintSeen;

  Future<void> markHintSeen() => (_db.update(_db.appSettings))
      .write(const AppSettingsCompanion(decorateHintSeen: Value(true)));
}

final decorationRepositoryProvider = Provider<DecorationRepository>(
  (ref) => DecorationRepository(ref.watch(appDatabaseProvider)),
);
