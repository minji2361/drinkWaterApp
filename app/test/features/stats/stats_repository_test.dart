import 'package:drift/native.dart';
import 'package:drink_water_app/core/database/app_database.dart';
import 'package:drink_water_app/features/home/data/intake_repository.dart';
import 'package:drink_water_app/features/stats/data/stats_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late IntakeRepository intake;
  late StatsRepository stats;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    intake = IntakeRepository(db);
    stats = StatsRepository(db);
    await db.into(db.userProfile).insert(UserProfileCompanion.insert(
          nickname: '물방울',
          gender: Gender.female,
          birthYear: 1998,
          weightKg: 55,
          dailyGoalMl: 2000,
        ));
  });

  tearDown(() => db.close());

  Future<void> log(DateTime at, int ml) async {
    await intake.ensureToday(at);
    await intake.addIntake(
      amountMl: ml,
      source: IntakeSource.quick,
      cupType: CupType.paper,
      now: at,
    );
  }

  test('일간: 2시간 단위로 묶고 첫/마지막 시각을 반환한다', () async {
    await log(DateTime(2026, 10, 2, 7, 40), 200); // 6~8시 → 3번째 칸
    await log(DateTime(2026, 10, 2, 8, 10), 300); // 8~10시 → 4번째 칸
    await log(DateTime(2026, 10, 2, 9, 50), 100); // 8~10시
    await log(DateTime(2026, 10, 2, 19, 20), 500); // 18~20시 → 10번째 칸

    final s = await stats.dayStats('2026-10-02');
    expect(s.hasData, isTrue);
    expect(s.totalMl, 1100);
    expect(s.logCount, 4);
    expect(s.goalMl, 2000);
    expect(s.percent, 55);
    expect(s.hourlyMl, [0, 0, 0, 200, 400, 0, 0, 0, 0, 500, 0, 0]);
    expect(s.firstAt, DateTime(2026, 10, 2, 7, 40));
    expect(s.lastAt, DateTime(2026, 10, 2, 19, 20));
  });

  test('일간: 자정 직후(0~2시)와 23시대가 올바른 칸에 들어간다', () async {
    await log(DateTime(2026, 10, 2, 0, 30), 100);
    await log(DateTime(2026, 10, 2, 23, 30), 100);
    final s = await stats.dayStats('2026-10-02');
    expect(s.hourlyMl.first, 100);
    expect(s.hourlyMl.last, 100);
  });

  test('일간: 기록이 없는 날은 빈 상태이고 목표는 프로필 값', () async {
    final s = await stats.dayStats('2026-09-01');
    expect(s.hasData, isFalse);
    expect(s.totalMl, 0);
    expect(s.goalMl, 2000);
    expect(s.firstAt, isNull);
    expect(s.hourlyMl, everyElement(0));
  });

  test('기간 조회와 기록 일수', () async {
    await log(DateTime(2026, 9, 29, 9), 2000); // 달성
    await log(DateTime(2026, 10, 1, 9), 500);
    await intake.ensureToday(DateTime(2026, 10, 2, 9)); // 기록 없는 날(요약만 존재)

    final rows = await stats.summariesBetween('2026-09-28', '2026-10-04');
    expect(rows.map((r) => r.date),
        ['2026-09-29', '2026-10-01', '2026-10-02']);
    expect(rows.first.achieved, isTrue);

    expect(await stats.recordedDayCount(), 2);
  });
}
