import '../../../core/utils/date_utils.dart';
import 'stats_models.dart';

/// 통계 기간 계산과 요약 지표 산출. 모두 순수 함수.
class StatsCalculator {
  const StatsCalculator._();

  /// 기록이 이 일수 미만이면 주간/월간에 안내를 띄운다 (기획서 S4).
  static const int minDaysForTrend = 3;

  static DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  /// 월요일 시작 주의 첫날.
  static DateTime weekStart(DateTime d) =>
      dateOnly(d).subtract(Duration(days: d.weekday - 1));

  static DateTime monthStart(DateTime d) => DateTime(d.year, d.month, 1);

  /// [anchor]를 [period] 단위로 [delta]만큼 이동한다.
  static DateTime shift(StatsPeriod period, DateTime anchor, int delta) =>
      switch (period) {
        StatsPeriod.day =>
          DateTime(anchor.year, anchor.month, anchor.day + delta),
        StatsPeriod.week =>
          DateTime(anchor.year, anchor.month, anchor.day + 7 * delta),
        StatsPeriod.month => DateTime(anchor.year, anchor.month + delta, 1),
      };

  /// [anchor]가 속한 기간이 [today]를 포함하는지. 포함하면 다음 기간으로 이동할 수 없다.
  static bool containsToday(
      StatsPeriod period, DateTime anchor, DateTime today) {
    final t = dateOnly(today);
    return switch (period) {
      StatsPeriod.day => dateOnly(anchor) == t,
      StatsPeriod.week => weekStart(anchor) == weekStart(t),
      StatsPeriod.month => anchor.year == t.year && anchor.month == t.month,
    };
  }

  static WeekStats buildWeek({
    required DateTime weekStart,
    required List<DaySummary> summaries,
    required DateTime today,
    required int fallbackGoalMl,
  }) {
    final byDate = {for (final s in summaries) s.date: s};
    final todayOnly = dateOnly(today);

    final bars = <DayBar>[];
    int goal = fallbackGoalMl;
    for (var i = 0; i < 7; i++) {
      final d = DateTime(weekStart.year, weekStart.month, weekStart.day + i);
      final s = byDate[toLogDate(d)];
      if (s != null) goal = s.goalMl; // 가장 최근 날의 목표를 목표선으로 사용
      bars.add(DayBar(
        date: toLogDate(d),
        weekday: d.weekday,
        totalMl: s?.totalMl ?? 0,
        achieved: s?.achieved ?? false,
        isFuture: d.isAfter(todayOnly),
      ));
    }

    final recorded = bars.where((b) => b.hasRecord).toList();
    int? maxDay;
    int? minDay;
    if (recorded.isNotEmpty) {
      maxDay = recorded
          .reduce((a, b) => b.totalMl > a.totalMl ? b : a)
          .weekday;
      minDay = recorded
          .reduce((a, b) => b.totalMl < a.totalMl ? b : a)
          .weekday;
    }

    return WeekStats(
      bars: bars,
      goalMl: goal,
      averageMl: _average(recorded.map((b) => b.totalMl)),
      achievedDays: bars.where((b) => b.achieved).length,
      maxWeekday: maxDay,
      minWeekday: minDay,
    );
  }

  static MonthStats buildMonth({
    required int year,
    required int month,
    required List<DaySummary> summaries,
    required DateTime today,
  }) {
    final byDate = {for (final s in summaries) s.date: s};
    final todayOnly = dateOnly(today);
    final daysInMonth = DateTime(year, month + 1, 0).day;

    final cells = <DayCell>[];
    var achievedDays = 0;
    var longest = 0;
    var run = 0;
    final totals = <int>[];

    for (var day = 1; day <= daysInMonth; day++) {
      final date = DateTime(year, month, day);
      final s = byDate[toLogDate(date)];
      final total = s?.totalMl ?? 0;
      final achieved = s?.achieved ?? false;

      final level = total == 0
          ? HeatLevel.none
          : achieved
              ? HeatLevel.done
              : (s!.goalMl > 0 && total * 2 < s.goalMl)
                  ? HeatLevel.low
                  : HeatLevel.mid;

      if (achieved) {
        achievedDays++;
        run++;
        if (run > longest) longest = run;
      } else {
        run = 0;
      }
      if (total > 0) totals.add(total);

      cells.add(DayCell(
        day: day,
        totalMl: total,
        level: level,
        isFuture: date.isAfter(todayOnly),
      ));
    }

    return MonthStats(
      year: year,
      month: month,
      cells: cells,
      averageMl: _average(totals),
      achievedDays: achievedDays,
      longestStreak: longest,
    );
  }

  static int _average(Iterable<int> values) {
    final list = values.toList();
    if (list.isEmpty) return 0;
    return (list.reduce((a, b) => a + b) / list.length).round();
  }
}
