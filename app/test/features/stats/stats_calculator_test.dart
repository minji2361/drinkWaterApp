import 'package:drink_water_app/features/stats/domain/stats_calculator.dart';
import 'package:drink_water_app/features/stats/domain/stats_models.dart';
import 'package:flutter_test/flutter_test.dart';

DaySummary day(String date, int total, {int goal = 2000, bool? achieved}) =>
    DaySummary(
      date: date,
      totalMl: total,
      goalMl: goal,
      achieved: achieved ?? total >= goal,
    );

void main() {
  // 2026-10-02는 금요일. 해당 주(월~일) = 9/28 ~ 10/4
  final today = DateTime(2026, 10, 2);

  test('주의 시작은 월요일', () {
    expect(StatsCalculator.weekStart(DateTime(2026, 10, 2)),
        DateTime(2026, 9, 28));
    expect(StatsCalculator.weekStart(DateTime(2026, 9, 28)),
        DateTime(2026, 9, 28));
    expect(StatsCalculator.weekStart(DateTime(2026, 10, 4)),
        DateTime(2026, 9, 28));
  });

  test('기간 이동과 미래 이동 판정', () {
    expect(StatsCalculator.shift(StatsPeriod.day, today, -1),
        DateTime(2026, 10, 1));
    expect(StatsCalculator.shift(StatsPeriod.week, today, -1),
        DateTime(2026, 9, 25));
    expect(StatsCalculator.shift(StatsPeriod.month, DateTime(2026, 1, 1), -1),
        DateTime(2025, 12, 1));

    expect(StatsCalculator.containsToday(StatsPeriod.day, today, today), isTrue);
    expect(
        StatsCalculator.containsToday(
            StatsPeriod.day, DateTime(2026, 10, 1), today),
        isFalse);
    expect(
        StatsCalculator.containsToday(
            StatsPeriod.week, DateTime(2026, 9, 28), today),
        isTrue);
    expect(
        StatsCalculator.containsToday(
            StatsPeriod.month, DateTime(2026, 10, 1), today),
        isTrue);
    expect(
        StatsCalculator.containsToday(
            StatsPeriod.month, DateTime(2026, 9, 1), today),
        isFalse);
  });

  group('buildWeek (시안 예시: 1,800 / 2,100 / 1,500 / 2,300 / 1,400)', () {
    final week = StatsCalculator.buildWeek(
      weekStart: DateTime(2026, 9, 28),
      today: today,
      fallbackGoalMl: 2000,
      summaries: [
        day('2026-09-28', 1800),
        day('2026-09-29', 2100),
        day('2026-09-30', 1500),
        day('2026-10-01', 2300),
        day('2026-10-02', 1400),
      ],
    );

    test('평균은 기록이 있는 날만, 달성일은 목표 달성 수', () {
      expect(week.averageMl, 1820);
      expect(week.achievedDays, 2);
      expect(week.goalMl, 2000);
      expect(week.hasData, isTrue);
    });

    test('최다/최소 요일', () {
      expect(week.maxWeekday, DateTime.thursday);
      expect(week.minWeekday, DateTime.friday);
    });

    test('7칸이며 미래 요일은 isFuture', () {
      expect(week.bars, hasLength(7));
      expect(week.bars[0].weekday, DateTime.monday);
      expect(week.bars[4].isFuture, isFalse); // 오늘(금)
      expect(week.bars[5].isFuture, isTrue); // 토
      expect(week.bars[6].isFuture, isTrue); // 일
    });
  });

  test('기록 없는 주는 hasData=false, 평균 0, 최다/최소 없음', () {
    final week = StatsCalculator.buildWeek(
      weekStart: DateTime(2026, 9, 21),
      today: today,
      fallbackGoalMl: 1700,
      summaries: [],
    );
    expect(week.hasData, isFalse);
    expect(week.averageMl, 0);
    expect(week.maxWeekday, isNull);
    expect(week.goalMl, 1700);
  });

  group('buildMonth', () {
    final month = StatsCalculator.buildMonth(
      year: 2026,
      month: 9,
      today: today,
      summaries: [
        day('2026-09-01', 2000), // done
        day('2026-09-02', 2100), // done
        day('2026-09-03', 2200), // done
        day('2026-09-04', 900), // low (<50%)
        day('2026-09-05', 1500), // mid
        day('2026-09-06', 2000), // done
        day('2026-09-10', 1000), // 정확히 50% → mid
      ],
    );

    test('달 일수와 시작 요일(일요일 시작 달력)', () {
      expect(month.cells, hasLength(30));
      // 2026-09-01은 화요일 → 일·월 두 칸이 비어 있다
      expect(month.leadingBlanks, 2);
    });

    test('히트 레벨', () {
      HeatLevel lv(int d) => month.cells[d - 1].level;
      expect(lv(1), HeatLevel.done);
      expect(lv(4), HeatLevel.low);
      expect(lv(5), HeatLevel.mid);
      expect(lv(10), HeatLevel.mid);
      expect(lv(7), HeatLevel.none);
    });

    test('달성일 / 최장 연속 / 평균(기록 있는 날)', () {
      expect(month.achievedDays, 4);
      expect(month.longestStreak, 3);
      // (2000+2100+2200+900+1500+2000+1000) / 7 = 1671.4
      expect(month.averageMl, 1671);
      expect(month.hasData, isTrue);
    });

    test('오늘 이후 날짜는 isFuture', () {
      final oct = StatsCalculator.buildMonth(
          year: 2026, month: 10, today: today, summaries: []);
      expect(oct.cells[1].isFuture, isFalse); // 10/2
      expect(oct.cells[2].isFuture, isTrue); // 10/3
      expect(oct.hasData, isFalse);
    });
  });
}
