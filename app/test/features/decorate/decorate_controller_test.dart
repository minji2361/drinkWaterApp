import 'package:drift/native.dart';
import 'package:drink_water_app/core/database/app_database.dart';
import 'package:drink_water_app/core/database/database_provider.dart';
import 'package:drink_water_app/features/decorate/data/decoration_repository.dart';
import 'package:drink_water_app/features/decorate/presentation/decorate_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late ProviderContainer container;
  late DecorationRepository repo;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = DecorationRepository(db);
    container = ProviderContainer(
      overrides: [appDatabaseProvider.overrideWithValue(db)],
    );
    container.listen(decorateControllerProvider, (_, __) {});
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  DecorateController ctl() =>
      container.read(decorateControllerProvider.notifier);
  DecorateState state() => container.read(decorateControllerProvider);

  Future<String?> equippedId(DecorationCategory c) async {
    final row = await (db.select(db.userDecoration)
          ..where((t) => t.category.equalsValue(c)))
        .getSingle();
    return row.itemId;
  }

  Future<void> unlock(String id) =>
      db.into(db.userUnlockedItem).insert(UserUnlockedItemCompanion.insert(itemId: id));

  group('DecorationRepository.equip', () {
    test('해금된 아이템을 장착하고 이전 아이템을 돌려준다', () async {
      final previous = await repo.equip(DecorationCategory.eyes, 'eyes_2');
      expect(previous, 'eyes_1');
      expect(await equippedId(DecorationCategory.eyes), 'eyes_2');
    });

    test('같은 카테고리의 다른 아이템은 교체되고 다른 부위는 영향이 없다', () async {
      await repo.equip(DecorationCategory.eyes, 'eyes_2');
      expect(await equippedId(DecorationCategory.mouth), 'mouth_1');
      expect(await equippedId(DecorationCategory.cheek), 'cheek_1');
    });

    test('미해금 아이템은 거부된다', () async {
      await expectLater(
        repo.equip(DecorationCategory.eyes, 'eyes_3'),
        throwsA(isA<DecorationRejected>()
            .having((e) => e.reason, 'reason', DecorationRejection.notUnlocked)),
      );
      expect(await equippedId(DecorationCategory.eyes), 'eyes_1');
    });

    test('다른 카테고리·없는 아이템은 거부된다', () async {
      await expectLater(
        repo.equip(DecorationCategory.eyes, 'mouth_1'),
        throwsA(isA<DecorationRejected>()
            .having((e) => e.reason, 'reason', DecorationRejection.wrongCategory)),
      );
      await expectLater(
        repo.equip(DecorationCategory.eyes, 'nope'),
        throwsA(isA<DecorationRejected>()
            .having((e) => e.reason, 'reason', DecorationRejection.unknownItem)),
      );
    });

    test('눈·입은 해제할 수 없고 코·볼·머리는 해제할 수 있다', () async {
      await expectLater(
        repo.equip(DecorationCategory.eyes, null),
        throwsA(isA<DecorationRejected>()
            .having((e) => e.reason, 'reason', DecorationRejection.cannotClear)),
      );
      final prev = await repo.equip(DecorationCategory.cheek, null);
      expect(prev, 'cheek_1');
      expect(await equippedId(DecorationCategory.cheek), isNull);
    });

    test('첫 진입 안내는 한 번만', () async {
      expect(await repo.isHintSeen(), isFalse);
      await repo.markHintSeen();
      expect(await repo.isHintSeen(), isTrue);
    });
  });

  group('되돌리기 스택', () {
    test('진입 직후에는 되돌릴 수 없다', () {
      expect(state().canUndo, isFalse);
    });

    test('교체 1회 → 활성, 되돌리기 → 원복·비활성, 탭도 해당 카테고리로 전환', () async {
      ctl().selectCategory(DecorationCategory.mouth);
      await ctl().equip(DecorationCategory.eyes, 'eyes_2');
      expect(state().canUndo, isTrue);

      await ctl().undo();
      expect(await equippedId(DecorationCategory.eyes), 'eyes_1');
      expect(state().canUndo, isFalse);
      expect(state().category, DecorationCategory.eyes);
    });

    test('되돌리기 1탭은 마지막 변경만 원복한다', () async {
      await ctl().equip(DecorationCategory.eyes, 'eyes_2');
      await ctl().equip(DecorationCategory.mouth, 'mouth_2');
      await ctl().undo();
      expect(await equippedId(DecorationCategory.mouth), 'mouth_1');
      expect(await equippedId(DecorationCategory.eyes), 'eyes_2');
    });

    test('없음 해제도 되돌리기로 복원된다', () async {
      await ctl().equip(DecorationCategory.cheek, null);
      expect(await equippedId(DecorationCategory.cheek), isNull);
      await ctl().undo();
      expect(await equippedId(DecorationCategory.cheek), 'cheek_1');
    });

    test('이미 해제된 슬롯을 다시 해제해도 스택에 쌓이지 않는다', () async {
      await ctl().equip(DecorationCategory.nose, null); // 기본값이 이미 해제
      expect(state().canUndo, isFalse);
    });

    test('미해금 아이템 시도는 스택에 쌓이지 않는다', () async {
      await expectLater(ctl().equip(DecorationCategory.eyes, 'eyes_6'),
          throwsA(isA<DecorationRejected>()));
      expect(state().canUndo, isFalse);
    });

    test('복원할 아이템이 유효하지 않으면 그 항목을 건너뛴다', () async {
      await unlock('eyes_3');
      await ctl().equip(DecorationCategory.eyes, 'eyes_3'); // prev eyes_1
      await ctl().equip(DecorationCategory.mouth, 'mouth_2'); // prev mouth_1
      await ctl().equip(DecorationCategory.eyes, 'eyes_2'); // prev eyes_3

      // eyes_3의 해금이 사라진 상황 → 해당 복원은 건너뛰고 다음 항목(mouth)을 복원
      await (db.delete(db.userUnlockedItem)
            ..where((t) => t.itemId.equals('eyes_3')))
          .go();
      await ctl().undo();
      expect(await equippedId(DecorationCategory.eyes), 'eyes_2');
      expect(await equippedId(DecorationCategory.mouth), 'mouth_1');
    });

    test('20단계를 넘게 교체해도 최근 20단계까지 되돌릴 수 있다', () async {
      for (var i = 0; i < 25; i++) {
        await ctl().equip(
            DecorationCategory.eyes, i.isEven ? 'eyes_2' : 'eyes_1');
      }
      var undone = 0;
      while (state().canUndo) {
        await ctl().undo();
        undone++;
      }
      expect(undone, 20);
    });
  });
}
