import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/database/enums.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../l10n/app_localizations.dart';
import '../../data/intake_repository.dart';
import '../../domain/intake_rules.dart';
import '../home_controller.dart';
import '../home_providers.dart';
import 'cup_icon.dart';

/// 기록 시트에서 확정한 기록 요청. 화면이 컨트롤러로 실행한다.
class SheetRecordRequest {
  const SheetRecordRequest({
    required this.cup,
    required this.amountMl,
    required this.count,
  });
  final CupType cup;
  final int amountMl;
  final int count;
}

/// 길게 누름 시 나타나는 기록 시트 (기획서 5.2).
/// 컵 카드를 탭하면 즉시 기본 컵으로 저장되고, 잔 수 스테퍼로 묶음 기록을 할 수 있다.
class RecordSheet extends ConsumerStatefulWidget {
  const RecordSheet({super.key, this.initialCount = 1});

  final int initialCount;

  @override
  ConsumerState<RecordSheet> createState() => _RecordSheetState();
}

class _RecordSheetState extends ConsumerState<RecordSheet> {
  late int _count = widget.initialCount;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final settings = ref.watch(appSettingsProvider).valueOrNull;
    if (settings == null) return const SizedBox(height: 200);

    final fmt = NumberFormat.decimalPattern(l10n.localeName);
    final cup = settings.defaultCupType;
    final ml = settings.cupMl(cup);
    final total = ml * _count;
    final controller = ref.read(homeControllerProvider.notifier);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(l10n.sheetTitle,
                          style: const TextStyle(
                              fontSize: 22, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 4),
                      Text(l10n.sheetSubtitle,
                          style: const TextStyle(
                              color: AppColors.textSecondary)),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: _openCupSettings,
                  child: Text(l10n.sheetEditVolume),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                for (final type in CupType.values) ...[
                  Expanded(
                    child: _CupCard(
                      type: type,
                      ml: settings.cupMl(type),
                      selected: type == cup,
                      onTap: () => controller.selectCup(type),
                    ),
                  ),
                  if (type != CupType.values.last) const SizedBox(width: 8),
                ],
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surfaceTint,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Text(l10n.sheetCupCount,
                          style: const TextStyle(fontSize: 16)),
                      const Spacer(),
                      IconButton.filled(
                        onPressed: _count > IntakeRules.minBulkCount
                            ? () => setState(() => _count--)
                            : null,
                        icon: const Icon(Icons.remove),
                      ),
                      SizedBox(
                        width: 56,
                        child: Text(
                          '$_count',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              fontSize: 26, fontWeight: FontWeight.w800),
                        ),
                      ),
                      IconButton.filled(
                        onPressed: _count < IntakeRules.maxBulkCount
                            ? () => setState(() => _count++)
                            : null,
                        icon: const Icon(Icons.add),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    l10n.sheetCupSummary(
                        cupName(l10n, cup), ml, _count, fmt.format(total)),
                    style: const TextStyle(color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(
                SheetRecordRequest(cup: cup, amountMl: ml, count: _count),
              ),
              child: Text(l10n.sheetConfirm(fmt.format(total))),
            ),
            const SizedBox(height: 8),
            Center(
              child: Text(
                l10n.sheetSplitNote(ml, _count),
                style: const TextStyle(
                    fontSize: 13, color: AppColors.textSecondary),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 용량 수정은 S5-1(기본 컵 설정)에서 한다 (기획서 S5-1 진입 경로).
  void _openCupSettings() {
    final router = GoRouter.of(context);
    Navigator.of(context).pop();
    router.push(AppRoutes.settingsCup);
  }
}

class _CupCard extends StatelessWidget {
  const _CupCard({
    required this.type,
    required this.ml,
    required this.selected,
    required this.onTap,
  });

  final CupType type;
  final int ml;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: selected ? AppColors.surfaceTint : AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.surfaceTint,
            width: selected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(cupIcon(type), color: AppColors.primary, size: 28),
            const SizedBox(height: 6),
            Text(cupName(l10n, type),
                style: const TextStyle(fontWeight: FontWeight.w600)),
            Text('${ml}ml',
                style: const TextStyle(
                    fontSize: 12, color: AppColors.textSecondary)),
          ],
        ),
      ),
    );
  }
}
