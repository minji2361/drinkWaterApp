import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:drink_water_app/core/database/app_database.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  test('최초 생성 시 단일 행 테이블이 기본값으로 시드된다', () async {
    final settings = await db.select(db.appSettings).getSingle();
    expect(settings.onboardingCompleted, isFalse);
    expect(settings.defaultCupType, CupType.paper);
    expect(settings.cupPaperMl, 200);
    expect(settings.cupMugMl, 300);
    expect(settings.cupTumblerMl, 500);
    expect(settings.cupOtherMl, 350);
    expect(settings.reminderIntervalMin, 120);

    final streak = await db.select(db.streak).getSingle();
    expect(streak.currentStreak, 0);
    expect(streak.lastAchievedDate, isNull);

    expect(await db.select(db.userProfile).get(), isEmpty);
  });

  test('intake_log를 저장하고 log_date로 집계할 수 있다', () async {
    final now = DateTime(2026, 10, 2, 9);
    for (final ml in [200, 300]) {
      await db.into(db.intakeLog).insert(IntakeLogCompanion.insert(
            amountMl: ml,
            loggedAt: now,
            logDate: '2026-10-02',
            source: IntakeSource.quick,
          ));
    }
    final sum = db.intakeLog.amountMl.sum();
    final row = await (db.selectOnly(db.intakeLog)
          ..addColumns([sum])
          ..where(db.intakeLog.logDate.equals('2026-10-02')))
        .getSingle();
    expect(row.read(sum), 500);
  });

  test('log_date 인덱스가 생성된다', () async {
    final rows = await db
        .customSelect(
            "SELECT name FROM sqlite_master WHERE type='index' AND name='idx_intake_log_date'")
        .get();
    expect(rows, hasLength(1));
  });

  test('단일 행 테이블은 id=1 외의 행을 허용하지 않는다', () async {
    await expectLater(
      db.into(db.streak).insert(StreakCompanion.insert(id: const Value(2))),
      throwsA(anything),
    );
  });

  test('user_decoration은 존재하지 않는 아이템을 참조할 수 없다', () async {
    // 기본 장착 행이 이미 있으므로 upsert로 외래키 위반만 검증한다.
    await expectLater(
      db.into(db.userDecoration).insertOnConflictUpdate(
            UserDecorationCompanion.insert(
              category: DecorationCategory.eyes,
              itemId: const Value('missing'),
            ),
          ),
      throwsA(anything),
    );
  });
}
