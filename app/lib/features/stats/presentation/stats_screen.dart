import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/date_utils.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/stats_calculator.dart';
import '../domain/stats_models.dart';
import 'stats_providers.dart';
import 'widgets/day_view.dart';
import 'widgets/month_view.dart';
import 'widgets/stats_common.dart';
import 'widgets/week_view.dart';

/// S4 통계 화면 (기획서 6장). 일간 / 주간 / 월간 탭, 좌우 스와이프로 기간 이동.
class StatsScreen extends ConsumerWidget {
  const StatsScreen({super.key});

  /// 스와이프로 인식할 최소 속도 (px/s).
  static const double _swipeVelocity = 300;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(statsControllerProvider);
    final controller = ref.read(statsControllerProvider.notifier);
    final today = ref.watch(clockProvider)();
    final canNext = controller.canGoNext;
    final recordedDays = ref.watch(recordedDayCountProvider).valueOrNull;
    final fewDays =
        recordedDays != null && recordedDays < StatsCalculator.minDaysForTrend;

    return Scaffold(
      body: SafeArea(
        child: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onHorizontalDragEnd: (d) {
            final v = d.primaryVelocity ?? 0;
            if (v > _swipeVelocity) controller.previous();
            if (v < -_swipeVelocity) controller.next();
          },
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                child: Row(
                  children: [
                    IconButton.filled(
                      tooltip: l10n.commonBack,
                      style: IconButton.styleFrom(
                        backgroundColor: AppColors.surface,
                        foregroundColor: AppColors.textPrimary,
                      ),
                      onPressed: () => context.pop(),
                      icon: const Icon(Icons.chevron_left),
                    ),
                    Expanded(
                      child: Text(
                        l10n.statsTitle,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            fontSize: 20, fontWeight: FontWeight.w800),
                      ),
                    ),
                    const SizedBox(width: 48),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                child: _PeriodTabs(
                  selected: state.period,
                  onChanged: controller.setPeriod,
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: controller.previous,
                      icon: const Icon(Icons.chevron_left),
                    ),
                    Expanded(
                      child: Text(
                        _periodLabel(l10n, state, today),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            fontSize: 17, fontWeight: FontWeight.w800),
                      ),
                    ),
                    // 미래 기간으로는 이동할 수 없다.
                    IconButton(
                      onPressed: canNext ? controller.next : null,
                      icon: const Icon(Icons.chevron_right),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                  child: switch (state.period) {
                    StatsPeriod.day => DayView(anchor: state.anchor),
                    StatsPeriod.week =>
                      WeekView(anchor: state.anchor, fewDays: fewDays),
                    StatsPeriod.month =>
                      MonthView(anchor: state.anchor, fewDays: fewDays),
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _periodLabel(
      AppLocalizations l10n, StatsState state, DateTime today) {
    final a = state.anchor;
    switch (state.period) {
      case StatsPeriod.day:
        final isToday = StatsCalculator.dateOnly(a) ==
            StatsCalculator.dateOnly(today);
        return l10n.statsDateLabel(
          a.month,
          a.day,
          isToday ? l10n.statsToday : weekdayShort(l10n, a.weekday),
        );
      case StatsPeriod.week:
        final start = StatsCalculator.weekStart(a);
        final end = DateTime(start.year, start.month, start.day + 6);
        return l10n.statsWeekLabel(
            start.month, start.day, end.month, end.day);
      case StatsPeriod.month:
        return l10n.statsMonthLabel(a.year, a.month);
    }
  }
}

class _PeriodTabs extends StatelessWidget {
  const _PeriodTabs({required this.selected, required this.onChanged});

  final StatsPeriod selected;
  final ValueChanged<StatsPeriod> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final labels = {
      StatsPeriod.day: l10n.statsPeriodDay,
      StatsPeriod.week: l10n.statsPeriodWeek,
      StatsPeriod.month: l10n.statsPeriodMonth,
    };
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(28),
      ),
      child: Row(
        children: [
          for (final p in StatsPeriod.values)
            Expanded(
              child: GestureDetector(
                onTap: () => onChanged(p),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  height: 44,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: p == selected ? AppColors.primary : null,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Text(
                    labels[p]!,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: p == selected
                          ? Colors.white
                          : AppColors.textSecondary,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
