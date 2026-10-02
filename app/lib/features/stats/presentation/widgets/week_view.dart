import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/date_utils.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/stats_calculator.dart';
import '../stats_providers.dart';
import 'stats_common.dart';

/// 주간 탭: 요일별 막대(월~일) + 목표선 + 지표 3개.
class WeekView extends ConsumerWidget {
  const WeekView({super.key, required this.anchor, required this.fewDays});

  final DateTime anchor;
  final bool fewDays;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final key = toLogDate(StatsCalculator.weekStart(anchor));
    final todayKey = toLogDate(ref.watch(clockProvider)());
    final async = ref.watch(weekStatsProvider(key));

    return async.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(48),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (_, __) => StatsNote(l10n.statsLoadError),
      data: (s) {
        final fmt = NumberFormat.decimalPattern(l10n.localeName);
        final items = [
          for (final b in s.bars)
            BarItem(
              value: b.totalMl.toDouble(),
              label: b.date == todayKey
                  ? l10n.statsTodayShort
                  : weekdayShort(l10n, b.weekday),
              emphasized: b.date == todayKey,
              color: b.achieved ? AppColors.primary : AppColors.chartLight,
              valueLabel: b.hasRecord ? fmt.format(b.totalMl) : null,
            ),
        ];

        return Column(
          children: [
            StatsCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(l10n.statsWeeklyChartTitle,
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w600)),
                      const Spacer(),
                      Text(l10n.statsUnitMl,
                          style: const TextStyle(
                              fontSize: 12, color: AppColors.textSecondary)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SimpleBarChart(
                    items: items,
                    target: s.goalMl > 0 ? s.goalMl.toDouble() : null,
                    targetLabel: l10n.statsGoalLine(fmt.format(s.goalMl)),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _Legend(AppColors.primary, l10n.statsLegendAchieved),
                      const SizedBox(width: 20),
                      _Legend(AppColors.chartLight, l10n.statsLegendMissed),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            if (!s.hasData) StatsNote(l10n.statsEmpty),
            if (fewDays) StatsNote(l10n.statsFewDays),
            StatTileGrid(
              columns: 3,
              tiles: [
                StatTile(
                  label: l10n.statsWeekAvg,
                  value: '${fmt.format(s.averageMl)}ml',
                ),
                StatTile(
                  label: l10n.statsAchievedDays,
                  value: l10n.statsDaysUnit(s.achievedDays),
                ),
                StatTile(
                  label: l10n.statsMaxMin,
                  value: s.maxWeekday == null
                      ? '-'
                      : '${weekdayShort(l10n, s.maxWeekday!)} / '
                          '${weekdayShort(l10n, s.minWeekday!)}',
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend(this.color, this.label);

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Container(
            width: 14,
            height: 14,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(width: 6),
          Text(label,
              style: const TextStyle(
                  fontSize: 12, color: AppColors.textSecondary)),
        ],
      );
}
