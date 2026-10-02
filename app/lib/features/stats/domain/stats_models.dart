// 통계 화면용 값 객체. 화면·저장소와 무관한 순수 Dart 모델이다.

enum StatsPeriod { day, week, month }

/// 하루치 집계 한 건 (daily_summary 기준).
class DaySummary {
  const DaySummary({
    required this.date,
    required this.totalMl,
    required this.goalMl,
    required this.achieved,
  });

  /// `YYYY-MM-DD`
  final String date;
  final int totalMl;
  final int goalMl;
  final bool achieved;

  bool get hasRecord => totalMl > 0;
}

/// 일간 탭. 시간대별 막대는 2시간 단위 12칸(0~2시, 2~4시, ... 22~24시).
class DayStats {
  const DayStats({
    required this.date,
    required this.totalMl,
    required this.goalMl,
    required this.logCount,
    required this.hourlyMl,
    this.firstAt,
    this.lastAt,
  });

  static const int bucketCount = 12;

  final String date;
  final int totalMl;
  final int goalMl;
  final int logCount;
  final List<int> hourlyMl;
  final DateTime? firstAt;
  final DateTime? lastAt;

  bool get hasData => logCount > 0;

  /// 목표 대비 달성률(%). 목표가 없으면 0.
  int get percent => goalMl > 0 ? (totalMl * 100 / goalMl).round() : 0;
}

class DayBar {
  const DayBar({
    required this.date,
    required this.weekday,
    required this.totalMl,
    required this.achieved,
    required this.isFuture,
  });

  final String date;

  /// `DateTime.monday`(1) ~ `DateTime.sunday`(7)
  final int weekday;
  final int totalMl;
  final bool achieved;
  final bool isFuture;

  bool get hasRecord => totalMl > 0;
}

/// 주간 탭 (월~일).
class WeekStats {
  const WeekStats({
    required this.bars,
    required this.goalMl,
    required this.averageMl,
    required this.achievedDays,
    this.maxWeekday,
    this.minWeekday,
  });

  final List<DayBar> bars;
  final int goalMl;

  /// 기록이 있는 날만 평균.
  final int averageMl;
  final int achievedDays;
  final int? maxWeekday;
  final int? minWeekday;

  bool get hasData => bars.any((b) => b.hasRecord);
}

enum HeatLevel { none, low, mid, done }

class DayCell {
  const DayCell({
    required this.day,
    required this.totalMl,
    required this.level,
    required this.isFuture,
  });

  final int day;
  final int totalMl;
  final HeatLevel level;
  final bool isFuture;
}

/// 월간 탭 (달력 히트맵).
class MonthStats {
  const MonthStats({
    required this.year,
    required this.month,
    required this.cells,
    required this.averageMl,
    required this.achievedDays,
    required this.longestStreak,
  });

  final int year;
  final int month;
  final List<DayCell> cells;
  final int averageMl;
  final int achievedDays;
  final int longestStreak;

  bool get hasData => cells.any((c) => c.totalMl > 0);

  /// 1일의 요일 (일요일 시작 달력 기준 앞쪽 빈 칸 수, 0~6).
  int get leadingBlanks => DateTime(year, month, 1).weekday % 7;
}
