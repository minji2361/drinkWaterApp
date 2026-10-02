import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/database/enums.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/date_utils.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/growth_stage.dart';
import '../domain/intake_rules.dart';
import 'home_controller.dart';
import 'home_providers.dart';
import 'widgets/drink_button.dart';
import 'widgets/plant_view.dart';
import 'widgets/record_sheet.dart';
import 'widgets/repeat_confirm_sheet.dart';

/// S2 메인 화면 (기획서 6장). 설정·꾸미기·통계 화면은 아직 없어 "준비 중" 안내만 한다.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen>
    with WidgetsBindingObserver {
  int _pourSeq = 0;
  Timer? _midnightTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refreshDate();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _midnightTimer?.cancel();
    super.dispose();
  }

  /// 백그라운드에서 자정을 넘긴 뒤 복귀하는 경우를 처리한다 (기획서 5.4).
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refreshDate();
  }

  Future<void> _refreshDate() async {
    await ref.read(currentDateProvider.notifier).refresh();
    _scheduleMidnight();
  }

  /// 앱을 켠 채로 자정을 넘기는 경우를 위한 타이머.
  void _scheduleMidnight() {
    _midnightTimer?.cancel();
    final now = ref.read(clockProvider)();
    final next = DateTime(now.year, now.month, now.day + 1);
    _midnightTimer =
        Timer(next.difference(now) + const Duration(seconds: 1), _refreshDate);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final fmt = NumberFormat.decimalPattern(l10n.localeName);

    final summary = ref.watch(todaySummaryProvider).valueOrNull;
    final streak = ref.watch(streakProvider).valueOrNull;
    final settings = ref.watch(appSettingsProvider).valueOrNull;
    final profile = ref.watch(userProfileProvider).valueOrNull;
    final ui = ref.watch(homeControllerProvider);

    final total = summary?.totalMl ?? 0;
    final count = summary?.logCount ?? 0;
    final goal = summary?.goalMl ?? profile?.dailyGoalMl ?? 0;
    final stage = growthStage(totalMl: total, goalMl: goal);
    final cup = settings?.defaultCupType ?? CupType.paper;
    final cupMl = settings?.defaultCupMl ?? 200;
    final limit = IntakeRules.reached(totalMl: total, logCount: count);
    final progress = goal > 0 ? (total / goal).clamp(0.0, 1.0) : 0.0;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
          child: Column(
            children: [
              _TopBar(
                streak: streak?.currentStreak ?? 0,
                onSettings: () => context.push(AppRoutes.settings),
              ),
              const SizedBox(height: 16),
              _ProgressCard(
                text: l10n.homeProgress(fmt.format(total), fmt.format(goal)),
                value: progress,
              ),
              Expanded(
                child: Center(
                  child: GestureDetector(
                    onTap: () => _comingSoon(context),
                    child: PlantView(stage: stage, pourSeq: _pourSeq),
                  ),
                ),
              ),
              DrinkButton(
                cup: cup,
                ml: cupMl,
                cooling: ui.cooling,
                disabled: limit != null,
                onTap: _onQuickTap,
                onLongPress: _onLongPress,
              ),
              const SizedBox(height: 10),
              Text(
                limit != null
                    ? _limitMessage(l10n, limit)
                    : l10n.homeSummaryHint(count, cupMl),
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 13, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _RoundAction(
                    icon: Icons.local_florist_outlined,
                    label: l10n.homeDecorate,
                    onTap: () => _comingSoon(context),
                  ),
                  const SizedBox(width: 40),
                  _RoundAction(
                    icon: Icons.bar_chart_rounded,
                    label: l10n.homeStats,
                    onTap: () => context.push(AppRoutes.stats),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _comingSoon(BuildContext context) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context).commonComingSoon)));
  }

  String _limitMessage(AppLocalizations l10n, LimitKind kind) =>
      kind == LimitKind.totalMl ? l10n.limitTotal : l10n.limitCount;

  // ---- 기록 ---------------------------------------------------------------

  Future<void> _onQuickTap() async {
    final controller = ref.read(homeControllerProvider.notifier);
    var outcome = await controller.quickRecord();

    final pending = outcome;
    if (pending is RecordNeedsConfirm && mounted) {
      final choice = await showModalBottomSheet<RepeatChoice>(
        context: context,
        showDragHandle: true,
        builder: (_) =>
            RepeatConfirmSheet(count: pending.count, totalMl: pending.totalMl),
      );
      if (!mounted) return;
      switch (choice) {
        case RepeatChoice.bulk:
          return _onLongPress();
        case RepeatChoice.one:
          outcome = await controller.quickRecord(confirmed: true);
        case null:
          return;
      }
    }
    await _handleOutcome(outcome);
  }

  Future<void> _onLongPress() async {
    final request = await showModalBottomSheet<SheetRecordRequest>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => const RecordSheet(),
    );
    if (request == null || !mounted) return;
    final outcome = await ref.read(homeControllerProvider.notifier).sheetRecord(
          cup: request.cup,
          amountMl: request.amountMl,
          count: request.count,
        );
    await _handleOutcome(outcome);
  }

  Future<void> _handleOutcome(RecordOutcome outcome) async {
    if (!mounted) return;
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);

    switch (outcome) {
      case Recorded(:final result):
        HapticFeedback.mediumImpact();
        setState(() => _pourSeq++);
        messenger
          ..clearSnackBars()
          ..showSnackBar(SnackBar(
            duration: const Duration(seconds: 5),
            content: Text(l10n.homeRecorded(
                result.amountMl * result.ids.length)),
            action: SnackBarAction(
              label: l10n.homeUndo,
              onPressed: () => ref
                  .read(homeControllerProvider.notifier)
                  .undo(result.ids),
            ),
          ));
        if (result.celebrate) await _celebrate(result.fastAchieve);
      case RecordLimitReached(:final kind):
        messenger
          ..clearSnackBars()
          ..showSnackBar(SnackBar(content: Text(_limitMessage(l10n, kind))));
      case RecordFailed():
        messenger
          ..clearSnackBars()
          ..showSnackBar(SnackBar(content: Text(l10n.homeRecordFailed)));
      case RecordCooldown() || RecordNeedsConfirm():
        break;
    }
  }

  /// 개화 축하. 물 붓기(1.2초)와 성장 연출이 끝난 뒤 표시한다 (기획서 5.3).
  Future<void> _celebrate(bool fastAchieve) async {
    await Future<void>.delayed(const Duration(milliseconds: 1300));
    if (!mounted) return;
    HapticFeedback.heavyImpact();
    final l10n = AppLocalizations.of(context);
    await showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(l10n.celebrateTitle),
        content: fastAchieve ? Text(l10n.celebrateFastNote) : null,
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l10n.commonConfirm),
          ),
        ],
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.streak, required this.onSettings});

  final int streak;
  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Row(
      children: [
        Text(l10n.appName,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
        const Spacer(),
        // 0일이면 스트릭 배지를 표시하지 않는다.
        if (streak > 0)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                const Icon(Icons.local_fire_department,
                    size: 18, color: Colors.deepOrange),
                const SizedBox(width: 4),
                Text(l10n.homeStreak(streak)),
              ],
            ),
          ),
        const SizedBox(width: 8),
        IconButton.filled(
          style: IconButton.styleFrom(
            backgroundColor: AppColors.surface,
            foregroundColor: AppColors.textPrimary,
          ),
          onPressed: onSettings,
          icon: const Icon(Icons.settings_outlined),
        ),
      ],
    );
  }
}

class _ProgressCard extends StatelessWidget {
  const _ProgressCard({required this.text, required this.value});

  final String text;
  final double value;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceTint,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(text, style: const TextStyle(fontSize: 16)),
          const SizedBox(height: 10),
          // 퍼센트 숫자는 표시하지 않고 진행바로만 표현한다 (기획서 S2).
          TweenAnimationBuilder<double>(
            tween: Tween(end: value),
            duration: const Duration(milliseconds: 400),
            builder: (_, v, __) => ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: v,
                minHeight: 10,
                backgroundColor: Colors.white54,
                color: AppColors.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RoundAction extends StatelessWidget {
  const _RoundAction(
      {required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Material(
          color: AppColors.surfaceTint,
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: SizedBox(
              width: 64,
              height: 64,
              child: Icon(icon, color: AppColors.primary),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(label, style: const TextStyle(fontSize: 13)),
      ],
    );
  }
}
