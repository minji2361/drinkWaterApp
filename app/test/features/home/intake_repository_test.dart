import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:drink_water_app/core/database/app_database.dart';
import 'package:drink_water_app/features/home/data/intake_repository.dart';
import 'package:drink_water_app/features/home/domain/intake_rules.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late IntakeRepository repo;
  final day = DateTime(2026, 10, 2, 9);

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = IntakeRepository(db);
    await db.into(db.userProfile).insert(UserProfileCompanion.insert(
          nickname: '물방울',
          gender: Gender.female,
          birthYear: 1998,
          weightKg: 55,
          dailyGoalMl: 1000,
        ));
    await repo.ensureToday(day);
  });

  tearDown(() => db.close());

  Future<IntakeResult> quick(int ml, DateTime at) => repo.addIntake(
        amountMl: ml,
        source: IntakeSource.quick,
        cupType: CupType.paper,
        now: at,
      );

  Future<DailySummaryRow> summary(String date) => (db.select(db.dailySummary)
        ..where((t) => t.logDate.equals(date)))
      .getSingle();

  test('ensureToday는 오늘 요약을 프로필 목표로 만든다', () async {
    final s = await summary('2026-10-02');
    expect(s.goalMl, 1000);
    expect(s.totalMl, 0);
    final settings = await repo.getSettings();
    expect(settings.lastOpenedDate, '2026-10-02');
  });

  test('1탭 기록은 1건 저장되고 요약이 갱신된다', () async {
    final r = await quick(200, day);
    expect(r.ids, hasLength(1));
    expect(r.previousTotalMl, 0);
    final s = await summary('2026-10-02');
    expect(s.totalMl, 200);
    expect(s.logCount, 1);
    expect(s.firstLoggedAt, isNotNull);
  });

  test('묶음 기록은 컵 용량씩 분리 저장된다 (300ml × 3)', () async {
    final r = await repo.addIntake(
      amountMl: 300,
      count: 3,
      source: IntakeSource.custom,
      cupType: CupType.mug,
      now: day,
    );
    final logs = await db.select(db.intakeLog).get();
    expect(r.ids, hasLength(3));
    expect(logs, hasLength(3));
    expect(logs.every((l) => l.amountMl == 300), isTrue);
    expect(logs.every((l) => l.source == IntakeSource.bulk), isTrue);
    expect(logs.map((l) => l.batchId).toSet(), hasLength(1));
    expect(logs.first.batchId, isNotNull);
    expect((await summary('2026-10-02')).logCount, 3);
  });

  test('1잔 기록 시 source는 지정한 값을 유지한다', () async {
    await repo.addIntake(
      amountMl: 300,
      source: IntakeSource.custom,
      cupType: CupType.mug,
      now: day,
    );
    final log = await db.select(db.intakeLog).getSingle();
    expect(log.source, IntakeSource.custom);
    expect(log.batchId, isNull);
  });

  test('4,000ml 초과 시도는 차단되고 저장되지 않는다', () async {
    await repo.addIntake(
        amountMl: 2000,
        count: 1,
        source: IntakeSource.custom,
        cupType: CupType.other,
        now: day);
    await repo.addIntake(
        amountMl: 1900,
        count: 1,
        source: IntakeSource.custom,
        cupType: CupType.other,
        now: day);
    await expectLater(
      quick(200, day),
      throwsA(isA<IntakeBlocked>()
          .having((e) => e.kind, 'kind', LimitKind.totalMl)),
    );
    expect((await summary('2026-10-02')).totalMl, 3900);
  });

  test('30회 상한을 넘으면 차단된다', () async {
    for (var i = 0; i < 30; i++) {
      await quick(10, day);
    }
    await expectLater(
      quick(10, day),
      throwsA(isA<IntakeBlocked>()
          .having((e) => e.kind, 'kind', LimitKind.count)),
    );
  });

  test('목표 달성 시 스트릭 +1, 축하는 하루 1회', () async {
    final first = await quick(600, day);
    expect(first.justAchieved, isFalse);

    final reach = await quick(400, day.add(const Duration(minutes: 30)));
    expect(reach.justAchieved, isTrue);
    expect(reach.celebrate, isTrue);
    expect(reach.fastAchieve, isFalse);

    final streak = await db.select(db.streak).getSingle();
    expect(streak.currentStreak, 1);
    expect(streak.bestStreak, 1);
    expect(streak.lastAchievedDate, '2026-10-02');

    // 이미 달성한 날 추가 기록은 스트릭·축하에 영향이 없다.
    final more = await quick(200, day.add(const Duration(hours: 1)));
    expect(more.justAchieved, isFalse);
    expect(more.celebrate, isFalse);
    expect((await db.select(db.streak).getSingle()).currentStreak, 1);
  });

  test('첫 기록 후 10분 이내 달성하면 fastAchieve', () async {
    await quick(500, day);
    final r = await quick(500, day.add(const Duration(minutes: 5)));
    expect(r.celebrate, isTrue);
    expect(r.fastAchieve, isTrue);
  });

  test('되돌리기는 기록을 삭제하고 달성·스트릭을 되돌린다', () async {
    await quick(600, day);
    final reach = await quick(400, day.add(const Duration(minutes: 30)));
    await repo.undo(reach.ids);

    final s = await summary('2026-10-02');
    expect(s.totalMl, 600);
    expect(s.logCount, 1);
    expect(s.isAchieved, isFalse);
    expect(s.celebrated, isTrue); // 같은 날 재연출 방지
    final streak = await db.select(db.streak).getSingle();
    expect(streak.currentStreak, 0);
    expect(streak.lastAchievedDate, isNull);

    // 다시 달성하면 스트릭은 오르지만 축하는 재생하지 않는다.
    final again = await quick(400, day.add(const Duration(hours: 1)));
    expect(again.justAchieved, isTrue);
    expect(again.celebrate, isFalse);
    expect((await db.select(db.streak).getSingle()).currentStreak, 1);
  });

  test('묶음 기록은 batch 전체를 한 번에 되돌린다', () async {
    final r = await repo.addIntake(
      amountMl: 200,
      count: 3,
      source: IntakeSource.custom,
      cupType: CupType.paper,
      now: day,
    );
    await repo.undo(r.ids);
    expect(await db.select(db.intakeLog).get(), isEmpty);
    expect((await summary('2026-10-02')).totalMl, 0);
  });

  test('자정을 넘겨 전날 달성하지 못했으면 스트릭이 0이 된다', () async {
    await quick(1000, day); // 10/2 달성 → 스트릭 1
    expect((await db.select(db.streak).getSingle()).currentStreak, 1);

    // 다음 날: 어제 달성했으므로 유지
    await repo.ensureToday(DateTime(2026, 10, 3, 8));
    expect((await db.select(db.streak).getSingle()).currentStreak, 1);
    expect((await summary('2026-10-03')).totalMl, 0);

    // 10/3 미달성 후 10/4: 스트릭 끊김, best는 유지
    await repo.ensureToday(DateTime(2026, 10, 4, 8));
    final streak = await db.select(db.streak).getSingle();
    expect(streak.currentStreak, 0);
    expect(streak.bestStreak, 1);
  });

  test('컵 설정: 기본 컵 변경과 용량 수정', () async {
    await repo.setDefaultCup(CupType.mug);
    await repo.setCupMl(CupType.mug, 350);
    final s = await repo.getSettings();
    expect(s.defaultCupType, CupType.mug);
    expect(s.defaultCupMl, 350);

    await expectLater(
        () => repo.setCupMl(CupType.mug, 5), throwsA(isA<ArgumentError>()));
  });

  test('컵 용량을 수정해도 과거 기록은 바뀌지 않는다', () async {
    await repo.setDefaultCup(CupType.mug);
    await repo.addIntake(
        amountMl: 300,
        source: IntakeSource.quick,
        cupType: CupType.mug,
        now: day);
    await repo.setCupMl(CupType.mug, 400);
    final log = await db.select(db.intakeLog).getSingle();
    expect(log.amountMl, 300);
  });
}
