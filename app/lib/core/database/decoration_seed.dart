import 'package:drift/drift.dart';

import 'app_database.dart';

/// 아이템 마스터 정의. 마스터는 앱이 정의하는 데이터라 DB를 열 때마다 동기화한다 (기획서 7.1).
///
/// 총 33종 (기본 10 / 해금 23). 해금 지점 14개(스트릭 3·5·7·10·14·21·30일, 누적 5·10·20·30·50·70·100일)에
/// 아이템 1~2종씩 배분했다. 기획서의 배분표(디자인 확정 후 별도 시트)가 나오면 [decorationSeedItems]만 고치면 된다.
/// 초반 이탈 방지를 위해 3·5일 지점에 눈·입 같은 체감이 큰 카테고리를 두고, 배경·화분은 중후반에 둔다.
class DecorationSeedItem {
  const DecorationSeedItem(
    this.id,
    this.category,
    this.unlockType,
    this.unlockValue,
    this.sortOrder,
  );

  final String id;
  final DecorationCategory category;
  final UnlockType unlockType;
  final int unlockValue;
  final int sortOrder;

  bool get isDefault => unlockType == UnlockType.defaultGrant;

  /// 에셋 경로. 실제 에셋이 나오기 전까지는 placeholder 키를 쓴다.
  String get assetKey => 'placeholder/$id';
}

const _d = UnlockType.defaultGrant;
const _s = UnlockType.streak;
const _t = UnlockType.totalDays;

const List<DecorationSeedItem> decorationSeedItems = [
  // 배경 3 (기본 1)
  DecorationSeedItem('bg_1', DecorationCategory.background, _d, 0, 1),
  DecorationSeedItem('bg_2', DecorationCategory.background, _s, 30, 2),
  DecorationSeedItem('bg_3', DecorationCategory.background, _t, 70, 3),
  // 화분 4 (기본 1)
  DecorationSeedItem('pot_1', DecorationCategory.pot, _d, 0, 1),
  DecorationSeedItem('pot_2', DecorationCategory.pot, _s, 10, 2),
  DecorationSeedItem('pot_3', DecorationCategory.pot, _t, 30, 3),
  DecorationSeedItem('pot_4', DecorationCategory.pot, _t, 50, 4),
  // 눈 6 (기본 2)
  DecorationSeedItem('eyes_1', DecorationCategory.eyes, _d, 0, 1),
  DecorationSeedItem('eyes_2', DecorationCategory.eyes, _d, 0, 2),
  DecorationSeedItem('eyes_3', DecorationCategory.eyes, _s, 3, 3),
  DecorationSeedItem('eyes_4', DecorationCategory.eyes, _s, 5, 4),
  DecorationSeedItem('eyes_5', DecorationCategory.eyes, _s, 7, 5),
  DecorationSeedItem('eyes_6', DecorationCategory.eyes, _s, 14, 6),
  // 코 4 (기본 2)
  DecorationSeedItem('nose_1', DecorationCategory.nose, _d, 0, 1),
  DecorationSeedItem('nose_2', DecorationCategory.nose, _d, 0, 2),
  DecorationSeedItem('nose_3', DecorationCategory.nose, _s, 7, 3),
  DecorationSeedItem('nose_4', DecorationCategory.nose, _t, 20, 4),
  // 입 6 (기본 2)
  DecorationSeedItem('mouth_1', DecorationCategory.mouth, _d, 0, 1),
  DecorationSeedItem('mouth_2', DecorationCategory.mouth, _d, 0, 2),
  DecorationSeedItem('mouth_3', DecorationCategory.mouth, _s, 3, 3),
  DecorationSeedItem('mouth_4', DecorationCategory.mouth, _t, 5, 4),
  DecorationSeedItem('mouth_5', DecorationCategory.mouth, _s, 10, 5),
  DecorationSeedItem('mouth_6', DecorationCategory.mouth, _s, 21, 6),
  // 볼 4 (기본 1)
  DecorationSeedItem('cheek_1', DecorationCategory.cheek, _d, 0, 1),
  DecorationSeedItem('cheek_2', DecorationCategory.cheek, _s, 5, 2),
  DecorationSeedItem('cheek_3', DecorationCategory.cheek, _t, 10, 3),
  DecorationSeedItem('cheek_4', DecorationCategory.cheek, _t, 20, 4),
  // 머리장식 6 (기본 1)
  DecorationSeedItem('head_1', DecorationCategory.headwear, _d, 0, 1),
  DecorationSeedItem('head_2', DecorationCategory.headwear, _t, 5, 2),
  DecorationSeedItem('head_3', DecorationCategory.headwear, _t, 10, 3),
  DecorationSeedItem('head_4', DecorationCategory.headwear, _s, 14, 4),
  DecorationSeedItem('head_5', DecorationCategory.headwear, _s, 21, 5),
  DecorationSeedItem('head_6', DecorationCategory.headwear, _t, 100, 6),
];

/// 처음 장착되는 기본 아이템. 코·머리장식은 해제 상태(null)로 시작한다.
const Map<DecorationCategory, String?> defaultEquipped = {
  DecorationCategory.background: 'bg_1',
  DecorationCategory.pot: 'pot_1',
  DecorationCategory.eyes: 'eyes_1',
  DecorationCategory.nose: null,
  DecorationCategory.mouth: 'mouth_1',
  DecorationCategory.cheek: 'cheek_1',
  DecorationCategory.headwear: null,
};

/// 마스터 동기화 + 기본 지급 + 기본 장착. 여러 번 호출해도 안전하다(멱등).
/// 기본 제공 10종은 온보딩과 무관하게 항상 지급한다 (기획서 S3).
Future<void> seedDecorations(AppDatabase db) async {
  await db.batch((b) {
    b.insertAllOnConflictUpdate(db.decorationItem, [
      for (final i in decorationSeedItems)
        DecorationItemCompanion.insert(
          id: i.id,
          category: i.category,
          name: i.id,
          assetKey: i.assetKey,
          unlockType: i.unlockType,
          unlockValue: Value(i.unlockValue),
          sortOrder: Value(i.sortOrder),
        ),
    ]);
    b.insertAll(
      db.userUnlockedItem,
      [
        for (final i in decorationSeedItems.where((i) => i.isDefault))
          UserUnlockedItemCompanion.insert(itemId: i.id),
      ],
      mode: InsertMode.insertOrIgnore,
    );
  });

  final equipped = (await db.select(db.userDecoration).get())
      .map((r) => r.category)
      .toSet();
  final missing = defaultEquipped.entries.where((e) => !equipped.contains(e.key));
  if (missing.isNotEmpty) {
    await db.batch((b) {
      b.insertAll(db.userDecoration, [
        for (final e in missing)
          UserDecorationCompanion.insert(
            category: e.key,
            itemId: Value(e.value),
          ),
      ]);
    });
  }
}

/// 스트릭·누적 달성일 조건을 충족했지만 아직 해금되지 않은 아이템을 해금하고 돌려준다.
/// 해금 조건은 전부 "일수" 기준이다 (기획서 5.6.3 — 총량 기반 조건 금지).
Future<List<DecorationItemRow>> grantEligibleUnlocks(AppDatabase db) async {
  final streak = (await db.select(db.streak).getSingle()).currentStreak;

  final cnt = db.dailySummary.logDate.count();
  final row = await (db.selectOnly(db.dailySummary)
        ..addColumns([cnt])
        ..where(db.dailySummary.isAchieved.equals(true)))
      .getSingle();
  final achievedDays = row.read(cnt) ?? 0;

  final unlocked = (await db.select(db.userUnlockedItem).get())
      .map((u) => u.itemId)
      .toSet();
  final items = await db.select(db.decorationItem).get();

  final granted = items.where((i) {
    if (unlocked.contains(i.id)) return false;
    return switch (i.unlockType) {
      UnlockType.streak => streak >= i.unlockValue,
      UnlockType.totalDays => achievedDays >= i.unlockValue,
      _ => false,
    };
  }).toList();

  if (granted.isNotEmpty) {
    await db.batch((b) {
      b.insertAll(db.userUnlockedItem, [
        for (final i in granted) UserUnlockedItemCompanion.insert(itemId: i.id),
      ]);
    });
  }
  return granted;
}
