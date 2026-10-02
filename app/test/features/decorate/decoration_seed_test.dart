import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:drink_water_app/core/database/app_database.dart';
import 'package:drink_water_app/core/database/decoration_seed.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  test('아이템 마스터는 총 33종, 기본 10 / 해금 23 (기획서 S3)', () async {
    final items = await db.select(db.decorationItem).get();
    expect(items, hasLength(33));
    expect(items.where((i) => i.unlockType == UnlockType.defaultGrant),
        hasLength(10));

    int count(DecorationCategory c) =>
        items.where((i) => i.category == c).length;
    expect(count(DecorationCategory.background), 3);
    expect(count(DecorationCategory.pot), 4);
    expect(count(DecorationCategory.eyes), 6);
    expect(count(DecorationCategory.nose), 4);
    expect(count(DecorationCategory.mouth), 6);
    expect(count(DecorationCategory.cheek), 4);
    expect(count(DecorationCategory.headwear), 6);
  });

  test('카테고리별 기본 제공 수', () {
    int defaults(DecorationCategory c) => decorationSeedItems
        .where((i) => i.category == c && i.isDefault)
        .length;
    expect(defaults(DecorationCategory.background), 1);
    expect(defaults(DecorationCategory.pot), 1);
    expect(defaults(DecorationCategory.eyes), 2);
    expect(defaults(DecorationCategory.nose), 2);
    expect(defaults(DecorationCategory.mouth), 2);
    expect(defaults(DecorationCategory.cheek), 1);
    expect(defaults(DecorationCategory.headwear), 1);
  });

  test('해금 지점은 14개이며 지점마다 1~2종, 총 23종 (총량 기반 조건 없음)', () {
    final unlockables =
        decorationSeedItems.where((i) => !i.isDefault).toList();
    expect(unlockables, hasLength(23));
    expect(
      unlockables.every((i) =>
          i.unlockType == UnlockType.streak ||
          i.unlockType == UnlockType.totalDays),
      isTrue,
    );

    final points = <String, int>{};
    for (final i in unlockables) {
      final key = '${i.unlockType.value}:${i.unlockValue}';
      points[key] = (points[key] ?? 0) + 1;
    }
    expect(points.keys.toSet(), {
      'streak:3', 'streak:5', 'streak:7', 'streak:10', 'streak:14',
      'streak:21', 'streak:30',
      'total_days:5', 'total_days:10', 'total_days:20', 'total_days:30',
      'total_days:50', 'total_days:70', 'total_days:100',
    });
    expect(points.values.every((n) => n == 1 || n == 2), isTrue);
  });

  test('3일·5일 지점에는 눈·입 등 체감이 큰 카테고리가 있다', () {
    DecorationCategory cat(String type, int v) => decorationSeedItems
        .firstWhere((i) => i.unlockType.value == type && i.unlockValue == v)
        .category;
    expect(cat('streak', 3), anyOf(DecorationCategory.eyes, DecorationCategory.mouth));
    expect(cat('streak', 5), anyOf(DecorationCategory.eyes, DecorationCategory.mouth));
  });

  test('기본 아이템 10종이 지급되고 7개 슬롯이 기본 장착된다', () async {
    final unlocked = await db.select(db.userUnlockedItem).get();
    expect(unlocked, hasLength(10));

    final rows = await db.select(db.userDecoration).get();
    final byCat = {for (final r in rows) r.category: r.itemId};
    expect(byCat, hasLength(7));
    expect(byCat[DecorationCategory.eyes], 'eyes_1');
    expect(byCat[DecorationCategory.mouth], 'mouth_1');
    expect(byCat[DecorationCategory.nose], isNull);
    expect(byCat[DecorationCategory.headwear], isNull);
  });

  test('seedDecorations는 멱등이며 사용자의 장착 상태를 덮어쓰지 않는다', () async {
    await (db.update(db.userDecoration)
          ..where((t) => t.category.equalsValue(DecorationCategory.eyes)))
        .write(const UserDecorationCompanion(itemId: Value('eyes_2')));
    await seedDecorations(db);
    await seedDecorations(db);

    expect(await db.select(db.decorationItem).get(), hasLength(33));
    expect(await db.select(db.userUnlockedItem).get(), hasLength(10));
    final eyes = await (db.select(db.userDecoration)
          ..where((t) => t.category.equalsValue(DecorationCategory.eyes)))
        .getSingle();
    expect(eyes.itemId, 'eyes_2');
  });

  group('grantEligibleUnlocks', () {
    Future<void> setStreak(int n) => (db.update(db.streak))
        .write(StreakCompanion(currentStreak: Value(n)));

    test('스트릭 3일이면 눈·입 하나씩 해금된다', () async {
      await setStreak(3);
      final granted = await grantEligibleUnlocks(db);
      expect(granted.map((i) => i.id).toSet(), {'eyes_3', 'mouth_3'});
      expect(await db.select(db.userUnlockedItem).get(), hasLength(12));

      // 같은 조건에서 다시 호출해도 중복 해금되지 않는다
      expect(await grantEligibleUnlocks(db), isEmpty);
    });

    test('누적 달성일 5일이면 total_days 5 아이템이 해금된다', () async {
      for (var d = 1; d <= 5; d++) {
        await db.into(db.dailySummary).insert(DailySummaryCompanion.insert(
              logDate: '2026-09-0$d',
              goalMl: 1000,
              isAchieved: const Value(true),
              totalMl: const Value(1000),
            ));
      }
      final granted = await grantEligibleUnlocks(db);
      expect(granted.map((i) => i.id).toSet(), {'mouth_4', 'head_2'});
    });

    test('달성하지 못한 날은 누적에 포함되지 않는다', () async {
      for (var d = 1; d <= 5; d++) {
        await db.into(db.dailySummary).insert(DailySummaryCompanion.insert(
              logDate: '2026-09-0$d',
              goalMl: 1000,
              totalMl: const Value(900),
            ));
      }
      expect(await grantEligibleUnlocks(db), isEmpty);
    });
  });
}
