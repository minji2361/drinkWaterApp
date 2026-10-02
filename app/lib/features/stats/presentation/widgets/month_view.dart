import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/date_utils.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/stats_models.dart';
import '../stats_providers.dart';
import 'stats_common.dart';

/// 월간 탭: 달력 히트맵(일요일 시작) + 지표 3개.
class MonthView extends ConsumerWidget {
  const MonthView({super.key, required this.anchor, required this.fewDays});

  final DateTime anchor;
  final bool fewDays;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final key = toLogDate(DateTime(anchor.year, anchor.month, 1));
    final async = ref.watch(monthStatsProvider(key));

    return async.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(48),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (_, __) => StatsNote(l10n.statsLoadError),
      data: (s) {
        final fmt = NumberFormat.decimalPattern(l10n.localeName);
        // 일요일 시작 달력 헤더: 일 월 화 수 목 금 토
        final headers = [7, 1, 2, 3, 4, 5, 6];

        return Column(
          children: [
            StatsCard(
              padding: const EdgeInsets.fromLTRB(14, 18, 14, 14),
              child: Column(
                children: [
                  Row(
                    children: [
                      for (final wd in headers)
                        Expanded(
                          child: Text(
                            weekdayShort(l10n, wd),
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                                fontSize: 13, color: AppColors.textSecondary),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _Grid(stats: s),
                  const SizedBox(height: 14),
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 14,
                    runSpacing: 6,
                    children: [
                      _Legend(_heatColor(HeatLevel.none), l10n.statsHeatNone),
                      _Legend(_heatColor(HeatLevel.low), l10n.statsHeatLow),
                      _Legend(_heatColor(HeatLevel.mid), l10n.statsHeatMid),
                      _Legend(_heatColor(HeatLevel.done), l10n.statsHeatDone),
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
                  label: l10n.statsMonthAvg,
                  value: '${fmt.format(s.averageMl)}ml',
                ),
                StatTile(
                  label: l10n.statsAchievedDays,
                  value: l10n.statsDaysUnit(s.achievedDays),
                ),
                StatTile(
                  label: l10n.statsLongestStreak,
                  value: l10n.statsDaysUnit(s.longestStreak),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}

Color _heatColor(HeatLevel level) => switch (level) {
      HeatLevel.none => AppColors.surfaceTint,
      HeatLevel.low => AppColors.chartLight,
      HeatLevel.mid => AppColors.chartMid,
      HeatLevel.done => AppColors.primary,
    };

class _Grid extends StatelessWidget {
  const _Grid({required this.stats});

  final MonthStats stats;

  @override
  Widget build(BuildContext context) {
    final cells = <Widget>[
      for (var i = 0; i < stats.leadingBlanks; i++) const SizedBox(),
      for (final c in stats.cells) _Cell(cell: c),
    ];
    return GridView.count(
      crossAxisCount: 7,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 6,
      crossAxisSpacing: 6,
      children: cells,
    );
  }
}

class _Cell extends StatelessWidget {
  const _Cell({required this.cell});

  final DayCell cell;

  @override
  Widget build(BuildContext context) {
    final done = cell.level == HeatLevel.done;
    return Container(
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: _heatColor(cell.level),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        '${cell.day}',
        style: TextStyle(
          fontSize: 14,
          color: done
              ? Colors.white
              : cell.isFuture
                  ? AppColors.textSecondary.withOpacity(0.5)
                  : AppColors.textPrimary,
        ),
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend(this.color, this.label);

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
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
