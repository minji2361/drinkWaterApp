import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/database/app_database.dart';
import '../../../core/theme/app_theme.dart';
import '../../../l10n/app_localizations.dart';
import '../../home/domain/growth_stage.dart';
import '../../home/presentation/home_providers.dart';
import '../data/decoration_repository.dart';
import '../domain/decoration_rules.dart';
import 'decorate_controller.dart';
import 'decorate_providers.dart';
import 'widgets/decorated_pot.dart';
import 'widgets/item_thumb.dart';

String categoryLabel(AppLocalizations l10n, DecorationCategory c) => switch (c) {
      DecorationCategory.background => l10n.decorCatBackground,
      DecorationCategory.pot => l10n.decorCatPot,
      DecorationCategory.eyes => l10n.decorCatEyes,
      DecorationCategory.nose => l10n.decorCatNose,
      DecorationCategory.mouth => l10n.decorCatMouth,
      DecorationCategory.cheek => l10n.decorCatCheek,
      DecorationCategory.headwear => l10n.decorCatHeadwear,
    };

String unlockCondition(AppLocalizations l10n, DecorationItemRow item) =>
    switch (item.unlockType) {
      UnlockType.streak => l10n.unlockStreak(item.unlockValue),
      UnlockType.totalDays => l10n.unlockTotalDays(item.unlockValue),
      _ => l10n.unlockOther,
    };

/// S3 꾸미기 화면 (기획서 6장). 즉시 적용 + 되돌리기. 저장/취소 버튼 없음.
class DecorateScreen extends ConsumerStatefulWidget {
  const DecorateScreen({super.key});

  @override
  ConsumerState<DecorateScreen> createState() => _DecorateScreenState();
}

class _DecorateScreenState extends ConsumerState<DecorateScreen> {
  bool _showHint = false;
  Timer? _hintTimer;

  @override
  void initState() {
    super.initState();
    _maybeShowHint();
  }

  @override
  void dispose() {
    _hintTimer?.cancel();
    super.dispose();
  }

  /// 첫 진입 1회에 한해 안내를 보여준다.
  Future<void> _maybeShowHint() async {
    final repo = ref.read(decorationRepositoryProvider);
    if (await repo.isHintSeen() || !mounted) return;
    setState(() => _showHint = true);
    await repo.markHintSeen();
    _hintTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => _showHint = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(decorateControllerProvider);
    final controller = ref.read(decorateControllerProvider.notifier);
    final items = ref.watch(decorationItemsProvider).valueOrNull;
    final equippedIds = ref.watch(equippedIdsProvider).valueOrNull;
    final unlocked = ref.watch(unlockedIdsProvider).valueOrNull;
    final equipped = ref.watch(equippedItemsProvider);
    final summary = ref.watch(todaySummaryProvider).valueOrNull;
    final profile = ref.watch(userProfileProvider).valueOrNull;

    final stage = growthStage(
      totalMl: summary?.totalMl ?? 0,
      goalMl: summary?.goalMl ?? profile?.dailyGoalMl ?? 0,
    );

    final category = state.category;
    final gridItems =
        items?.where((i) => i.category == category).toList() ?? const [];

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Row(
                children: [
                  IconButton.filled(
                    tooltip: l10n.commonBack,
                    style: IconButton.styleFrom(
                      backgroundColor: AppColors.surface,
                      foregroundColor: AppColors.textPrimary,
                    ),
                    // 확인 다이얼로그 없이 즉시 복귀한다. 이미 저장되어 있다.
                    onPressed: () => context.pop(),
                    icon: const Icon(Icons.chevron_left),
                  ),
                  Expanded(
                    child: Text(l10n.decorateTitle,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            fontSize: 20, fontWeight: FontWeight.w800)),
                  ),
                  _UndoButton(
                    enabled: state.canUndo,
                    label: l10n.decorateUndo,
                    onPressed: () => _run(controller.undo),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            // 미리보기: 보기 전용. 제스처를 받지 않는다.
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Stack(
                  alignment: Alignment.topCenter,
                  children: [
                    Center(
                      child: DecoratedPot(
                        stage: stage,
                        equipped: equipped,
                        size: 240,
                      ),
                    ),
                    if (_showHint)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: AppColors.textPrimary,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(l10n.decorateHint,
                            style: const TextStyle(
                                color: Colors.white, fontSize: 13)),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            SizedBox(
              height: 44,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: DecorationRules.tabOrder.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (_, i) {
                  final c = DecorationRules.tabOrder[i];
                  return ChoiceChip(
                    label: Text(categoryLabel(l10n, c)),
                    selected: c == category,
                    showCheckmark: false,
                    selectedColor: AppColors.primary,
                    labelStyle: TextStyle(
                      color: c == category
                          ? Colors.white
                          : AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                    onSelected: (_) => controller.selectCategory(c),
                  );
                },
              ),
            ),
            Expanded(
              child: items == null || unlocked == null || equippedIds == null
                  ? const Center(child: CircularProgressIndicator())
                  : GridView.count(
                      crossAxisCount: 4,
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      children: [
                        if (DecorationRules.canClear(category))
                          _Cell(
                            selected: equippedIds[category] == null,
                            onTap: () =>
                                _run(() => controller.equip(category, null)),
                            child: const Icon(Icons.block,
                                color: AppColors.textSecondary),
                          ),
                        for (final item in gridItems)
                          _Cell(
                            selected: equippedIds[category] == item.id,
                            locked: !unlocked.contains(item.id),
                            onTap: unlocked.contains(item.id)
                                ? () => _run(
                                    () => controller.equip(category, item.id))
                                : () => _showLockedInfo(context, l10n, item),
                            child: ItemThumb(item: item),
                          ),
                      ],
                    ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Text(l10n.decorateLockedHint,
                  style: const TextStyle(
                      fontSize: 13, color: AppColors.textSecondary)),
            ),
          ],
        ),
      ),
    );
  }

  /// 저장 실패 시 오류 토스트. 화면은 DB 스트림을 따르므로 변경 전 상태로 남는다.
  Future<void> _run(Future<void> Function() action) async {
    try {
      await action();
      HapticFeedback.selectionClick();
    } catch (_) {
      if (!mounted) return;
      final l10n = AppLocalizations.of(context);
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(SnackBar(content: Text(l10n.decorateSaveFailed)));
    }
  }

  /// 미해금 아이템 탭: 교체하지 않고 해금 조건만 안내한다 (되돌리기 스택에 쌓이지 않는다).
  void _showLockedInfo(
      BuildContext context, AppLocalizations l10n, DecorationItemRow item) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.lock_outline,
                  size: 36, color: AppColors.textSecondary),
              const SizedBox(height: 12),
              Text(unlockCondition(l10n, item),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(l10n.commonConfirm),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _UndoButton extends StatelessWidget {
  const _UndoButton(
      {required this.enabled, required this.label, required this.onPressed});

  final bool enabled;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      // 스택이 비면 투명도 40%로 비활성.
      opacity: enabled ? 1 : 0.4,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: enabled ? onPressed : null,
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.undo, color: AppColors.textPrimary),
              Text(label, style: const TextStyle(fontSize: 11)),
            ],
          ),
        ),
      ),
    );
  }
}

class _Cell extends StatelessWidget {
  const _Cell({
    required this.child,
    required this.onTap,
    this.selected = false,
    this.locked = false,
  });

  final Widget child;
  final VoidCallback onTap;
  final bool selected;
  final bool locked;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      customBorder: const CircleBorder(),
      onTap: onTap,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: locked ? AppColors.surfaceTint : AppColors.surface,
              border: Border.all(
                color: selected ? AppColors.primary : Colors.transparent,
                width: 3,
              ),
            ),
            alignment: Alignment.center,
            child: locked
                ? const Icon(Icons.lock_outline,
                    color: AppColors.textSecondary)
                : child,
          ),
          if (selected)
            const Positioned(
              top: 2,
              right: 2,
              child: CircleAvatar(
                radius: 10,
                backgroundColor: AppColors.primary,
                child: Icon(Icons.check, size: 13, color: Colors.white),
              ),
            ),
        ],
      ),
    );
  }
}
