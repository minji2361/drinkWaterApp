import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/date_utils.dart';
import '../data/stats_repository.dart';
import '../domain/stats_calculator.dart';
import '../domain/stats_models.dart';

class StatsState {
  const StatsState({required this.period, required this.anchor});

  final StatsPeriod period;

  /// 보고 있는 기간에 속한 임의의 날짜 (일간=그날, 주간=그 주 아무 날, 월간=그 달 1일).
  final DateTime anchor;

  StatsState copyWith({StatsPeriod? period, DateTime? anchor}) => StatsState(
        period: period ?? this.period,
        anchor: anchor ?? this.anchor,
      );
}

class StatsController extends Notifier<StatsState> {
  @override
  StatsState build() => StatsState(
        period: StatsPeriod.day,
        anchor: StatsCalculator.dateOnly(ref.read(clockProvider)()),
      );

  DateTime get _today => ref.read(clockProvider)();

  /// 미래 기간으로는 이동할 수 없다 (기획서 S4).
  bool get canGoNext =>
      !StatsCalculator.containsToday(state.period, state.anchor, _today);

  void setPeriod(StatsPeriod period) {
    if (period == state.period) return;
    state = state.copyWith(period: period);
  }

  void previous() => state = state.copyWith(
        anchor: StatsCalculator.shift(state.period, state.anchor, -1),
      );

  void next() {
    if (!canGoNext) return;
    state = state.copyWith(
      anchor: StatsCalculator.shift(state.period, state.anchor, 1),
    );
  }
}

final statsControllerProvider =
    NotifierProvider.autoDispose<StatsController, StatsState>(
  StatsController.new,
);

final dayStatsProvider =
    FutureProvider.autoDispose.family<DayStats, String>((ref, date) {
  return ref.watch(statsRepositoryProvider).dayStats(date);
});

/// 키: 주의 월요일 `YYYY-MM-DD`
final weekStatsProvider =
    FutureProvider.autoDispose.family<WeekStats, String>((ref, start) async {
  final repo = ref.watch(statsRepositoryProvider);
  final s = DateTime.parse(start);
  final end = DateTime(s.year, s.month, s.day + 6);
  return StatsCalculator.buildWeek(
    weekStart: s,
    summaries: await repo.summariesBetween(start, toLogDate(end)),
    today: ref.read(clockProvider)(),
    fallbackGoalMl: await repo.fallbackGoal(),
  );
});

/// 키: 달의 1일 `YYYY-MM-01`
final monthStatsProvider =
    FutureProvider.autoDispose.family<MonthStats, String>((ref, start) async {
  final repo = ref.watch(statsRepositoryProvider);
  final s = DateTime.parse(start);
  final end = DateTime(s.year, s.month + 1, 0);
  return StatsCalculator.buildMonth(
    year: s.year,
    month: s.month,
    summaries: await repo.summariesBetween(start, toLogDate(end)),
    today: ref.read(clockProvider)(),
  );
});

final recordedDayCountProvider = FutureProvider.autoDispose<int>(
  (ref) => ref.watch(statsRepositoryProvider).recordedDayCount(),
);
