import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../l10n/app_localizations.dart';
import 'onboarding_controller.dart';
import 'widgets/goal_step.dart';
import 'widgets/nickname_step.dart';
import 'widgets/profile_step.dart';

/// S1 온보딩 (기획서 6장). 3단계 스텝. 첫 스텝에서는 뒤로가기로 건너뛸 수 없다.
class OnboardingScreen extends ConsumerWidget {
  const OnboardingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(onboardingControllerProvider);
    final controller = ref.read(onboardingControllerProvider.notifier);
    final isLast = state.step == OnboardingState.totalSteps;

    final (title, subtitle, body) = switch (state.step) {
      1 => (
          l10n.onboardingNicknameTitle,
          l10n.onboardingNicknameSubtitle,
          const NicknameStep()
        ),
      2 => (
          l10n.onboardingProfileTitle,
          l10n.onboardingProfileSubtitle,
          const ProfileStep()
        ),
      _ => (
          l10n.onboardingGoalTitle,
          l10n.onboardingGoalSubtitle,
          const GoalStep()
        ),
    };

    return PopScope(
      // 스텝 2·3에서는 이전 스텝으로, 스텝 1에서는 종료 불가로 처리한다.
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) controller.back();
      },
      child: Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Header(step: state.step, onBack: controller.back),
                const SizedBox(height: 24),
                Expanded(
                  child: SingleChildScrollView(
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w800,
                              height: 1.3),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          subtitle,
                          style: const TextStyle(
                              fontSize: 15,
                              height: 1.5,
                              color: AppColors.textSecondary),
                        ),
                        const SizedBox(height: 24),
                        body,
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: state.canProceed
                      ? () => _onNext(context, controller)
                      : null,
                  child: Text(isLast
                      ? l10n.onboardingStart
                      : l10n.onboardingNext),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _onNext(
      BuildContext context, OnboardingController controller) async {
    final messenger = ScaffoldMessenger.of(context);
    final failedText = AppLocalizations.of(context).onboardingSaveFailed;
    try {
      await controller.next();
    } catch (_) {
      messenger.showSnackBar(SnackBar(content: Text(failedText)));
    }
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.step, required this.onBack});

  final int step;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Row(
      children: [
        // 스텝 1에서는 자리만 유지하고 뒤로가기 버튼을 숨긴다.
        SizedBox(
          width: 44,
          height: 44,
          child: step > 1
              ? IconButton.filled(
                  tooltip: l10n.commonBack,
                  style: IconButton.styleFrom(
                    backgroundColor: AppColors.surface,
                    foregroundColor: AppColors.textPrimary,
                  ),
                  onPressed: onBack,
                  icon: const Icon(Icons.chevron_left),
                )
              : null,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Row(
            children: [
              for (var i = 1; i <= OnboardingState.totalSteps; i++) ...[
                Expanded(
                  child: Container(
                    height: 5,
                    decoration: BoxDecoration(
                      color: i <= step
                          ? AppColors.primary
                          : AppColors.surfaceTint,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
                if (i < OnboardingState.totalSteps) const SizedBox(width: 6),
              ],
            ],
          ),
        ),
        const SizedBox(width: 12),
        Text(
          l10n.onboardingStepIndicator(step, OnboardingState.totalSteps),
          style: const TextStyle(color: AppColors.textSecondary),
        ),
      ],
    );
  }
}
