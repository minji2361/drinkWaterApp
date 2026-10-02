import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/date_utils.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/stats_models.dart';
import '../stats_providers.dart';
import 'stats_common.dart';

/// 일간 탭: 시간대별 막대 + 지표 4개.
class DayView extends ConsumerWidget {
  const DayView({super.key, required this.anchor});

  final DateTime anchor;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final date = toLogDate(anchor);
    final isToday =
        date == toLogDate(ref.watch(clockProvider)());
    final async = ref.watch(dayStatsProvider(date));

    return async.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(48),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (_, __) => StatsNote(l10n.statsLoadError),
      data: (s) {
        final fmt = NumberFormat.decimalPattern(l10n.localeName);
        final maxBucket = s.hourlyMl.fold<int>(0, (m, v) => v > m ? v : m);
        final items = [
          for (var i = 0; i < DayStats.bucketCount; i++)
            BarItem(
              value: s.hourlyMl[i].toDouble(),
              label: '${i * 2}',
              color: s.hourlyMl[i] == maxBucket
                  ? AppColors.primary
                  : AppColors.chartMid,
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
                      Text(l10n.statsDailyChartTitle,
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w600)),
                      const Spacer(),
                      Text(l10n.statsDailyChartUnit,
                          style: const TextStyle(
                              fontSize: 12, color: AppColors.textSecondary)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SimpleBarChart(items: items),
                  const SizedBox(height: 6),
                  Center(
                    child: Text(l10n.statsHourAxis,
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.textSecondary)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            if (!s.hasData) StatsNote(l10n.statsEmpty),
            StatTileGrid(
              columns: 2,
              tiles: [
                StatTile(
                  label: isToday ? l10n.statsTotalToday : l10n.statsTotal,
                  value: '${fmt.format(s.totalMl)}ml',
                ),
                StatTile(
                  label: l10n.statsVsGoal,
                  value: l10n.statsPercent(s.percent),
                ),
                StatTile(
                  label: l10n.statsLogCount,
                  value: l10n.statsCountTimes(s.logCount),
                ),
                StatTile(
                  label: l10n.statsFirstLast,
                  value: s.firstAt == null
                      ? '-'
                      : '${_hm(s.firstAt!)} / ${_hm(s.lastAt!)}',
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  static String _hm(DateTime t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
}
