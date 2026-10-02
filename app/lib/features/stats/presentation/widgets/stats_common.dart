import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../l10n/app_localizations.dart';

/// 요일 짧은 이름. [weekday]는 1(월)~7(일).
String weekdayShort(AppLocalizations l10n, int weekday) => switch (weekday) {
      1 => l10n.wdMon,
      2 => l10n.wdTue,
      3 => l10n.wdWed,
      4 => l10n.wdThu,
      5 => l10n.wdFri,
      6 => l10n.wdSat,
      _ => l10n.wdSun,
    };

/// 흰 카드 컨테이너.
class StatsCard extends StatelessWidget {
  const StatsCard({super.key, required this.child, this.padding});

  final Widget child;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: padding ?? const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(24),
        ),
        child: child,
      );
}

/// 지표 한 칸 (라벨 + 값).
class StatTile extends StatelessWidget {
  const StatTile({super.key, required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: const TextStyle(
                    fontSize: 13, color: AppColors.textSecondary)),
            const SizedBox(height: 6),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(value,
                  style: const TextStyle(
                      fontSize: 20, fontWeight: FontWeight.w800)),
            ),
          ],
        ),
      );
}

/// 지표 칸 배치. [columns]개씩 한 줄에 놓는다.
class StatTileGrid extends StatelessWidget {
  const StatTileGrid({super.key, required this.tiles, required this.columns});

  final List<StatTile> tiles;
  final int columns;

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    for (var i = 0; i < tiles.length; i += columns) {
      final chunk = tiles.skip(i).take(columns).toList();
      rows.add(Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var j = 0; j < columns; j++) ...[
            Expanded(child: j < chunk.length ? chunk[j] : const SizedBox()),
            if (j < columns - 1) const SizedBox(width: 10),
          ],
        ],
      ));
      if (i + columns < tiles.length) rows.add(const SizedBox(height: 10));
    }
    return Column(children: rows);
  }
}

class StatsNote extends StatelessWidget {
  const StatsNote(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppColors.textSecondary, height: 1.5),
        ),
      );
}

/// 막대 한 개.
class BarItem {
  const BarItem({
    required this.value,
    required this.label,
    required this.color,
    this.valueLabel,
    this.emphasized = false,
  });

  final double value;
  final String label;
  final Color color;

  /// 막대 위에 표시할 값 (없으면 생략).
  final String? valueLabel;

  /// 축 라벨 강조 (예: 오늘).
  final bool emphasized;
}

/// 라이브러리 없이 그리는 막대 차트. 선택적으로 가로 목표선을 그린다.
class SimpleBarChart extends StatelessWidget {
  const SimpleBarChart({
    super.key,
    required this.items,
    this.target,
    this.targetLabel,
    this.chartHeight = 180,
  });

  final List<BarItem> items;
  final double? target;
  final String? targetLabel;
  final double chartHeight;

  static const double _valueLabelHeight = 18;

  @override
  Widget build(BuildContext context) {
    var maxValue = items.fold<double>(0, (m, b) => b.value > m ? b.value : m);
    if (target != null && target! > maxValue) maxValue = target! * 1.1;
    if (maxValue <= 0) maxValue = 1;
    final barArea = chartHeight - _valueLabelHeight;

    return Column(
      children: [
        SizedBox(
          height: chartHeight,
          child: Stack(
            children: [
              if (target != null)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: barArea * (target! / maxValue),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: Container(height: 1.5, color: AppColors.target),
                      ),
                    ],
                  ),
                ),
              if (target != null && targetLabel != null)
                Positioned(
                  right: 0,
                  bottom: barArea * (target! / maxValue) + 2,
                  child: Text(targetLabel!,
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.target)),
                ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  for (final item in items)
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 3),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            if (item.valueLabel != null)
                              SizedBox(
                                height: _valueLabelHeight,
                                child: FittedBox(
                                  child: Text(item.valueLabel!,
                                      style: const TextStyle(
                                          color: AppColors.textSecondary)),
                                ),
                              ),
                            Container(
                              height: item.value <= 0
                                  ? 3
                                  : (barArea * item.value / maxValue)
                                      .clamp(3.0, barArea),
                              decoration: BoxDecoration(
                                color: item.value <= 0
                                    ? AppColors.surfaceTint
                                    : item.color,
                                borderRadius: BorderRadius.circular(6),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            for (final item in items)
              Expanded(
                child: Text(
                  item.label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                    fontWeight:
                        item.emphasized ? FontWeight.w800 : FontWeight.w400,
                    decoration:
                        item.emphasized ? TextDecoration.underline : null,
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}
