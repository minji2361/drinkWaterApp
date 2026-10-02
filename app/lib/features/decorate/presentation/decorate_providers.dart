import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../data/decoration_repository.dart';

final decorationItemsProvider = StreamProvider.autoDispose<List<DecorationItemRow>>(
  (ref) => ref.watch(decorationRepositoryProvider).watchItems(),
);

final equippedIdsProvider =
    StreamProvider.autoDispose<Map<DecorationCategory, String?>>(
  (ref) => ref.watch(decorationRepositoryProvider).watchEquipped(),
);

final unlockedIdsProvider = StreamProvider.autoDispose<Set<String>>(
  (ref) => ref.watch(decorationRepositoryProvider).watchUnlockedIds(),
);

/// 카테고리 → 장착 중인 아이템 (해제·미장착은 null). 홈과 꾸미기 미리보기가 공유한다.
/// 데이터가 아직 로드되지 않았으면 null.
final equippedItemsProvider =
    Provider.autoDispose<Map<DecorationCategory, DecorationItemRow?>?>((ref) {
  final items = ref.watch(decorationItemsProvider).valueOrNull;
  final ids = ref.watch(equippedIdsProvider).valueOrNull;
  if (items == null || ids == null) return null;
  final byId = {for (final i in items) i.id: i};
  return {
    for (final c in DecorationCategory.values)
      c: ids[c] == null ? null : byId[ids[c]],
  };
});
