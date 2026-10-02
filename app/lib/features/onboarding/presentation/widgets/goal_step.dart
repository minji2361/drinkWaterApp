import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/goal_calculator.dart';
import '../onboarding_controller.dart';
import 'medical_notice.dart';

class GoalStep extends ConsumerWidget {
  const GoalStep({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final goal = ref.watch(onboardingControllerProvider.select((s) => s.goalMl));
    final controller = ref.read(onboardingControllerProvider.notifier);
    final fmt = NumberFormat.decimalPattern(l10n.localeName);

    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(28),
          ),
          child: Column(
            children: [
              const CircleAvatar(
                radius: 29,
                backgroundColor: AppColors.surfaceTint,
                child: Icon(Icons.water_drop, color: AppColors.primary),
              ),
              const SizedBox(height: 16),
              InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => _editGoal(context, controller, goal),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      goal == null ? '' : fmt.format(goal),
                      style: const TextStyle(
                          fontSize: 56, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(width: 6),
                    Text(l10n.onboardingGoalUnit,
                        style: const TextStyle(
                            fontSize: 18, color: AppColors.textSecondary)),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _AdjustButton(
                      label: l10n.onboardingGoalAdjustMinus(
                          GoalCalculator.adjustStepMl),
                      onPressed: () =>
                          controller.adjustGoal(-GoalCalculator.adjustStepMl),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _AdjustButton(
                      label: l10n.onboardingGoalAdjustPlus(
                          GoalCalculator.adjustStepMl),
                      onPressed: () =>
                          controller.adjustGoal(GoalCalculator.adjustStepMl),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                l10n.onboardingGoalRange(
                  fmt.format(GoalCalculator.minGoalMl),
                  fmt.format(GoalCalculator.maxGoalMl),
                ),
                style: const TextStyle(
                    fontSize: 13, color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        const MedicalNotice(),
      ],
    );
  }

  Future<void> _editGoal(
    BuildContext context,
    OnboardingController controller,
    int? current,
  ) async {
    final input = await showDialog<int>(
      context: context,
      builder: (_) => _GoalInputDialog(initial: current),
    );
    if (input != null) controller.setGoal(input);
  }
}

class _AdjustButton extends StatelessWidget {
  const _AdjustButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return FilledButton.tonal(
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(52),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
      ),
      onPressed: onPressed,
      child: Text(label),
    );
  }
}

/// 목표량 직접 입력. 범위(500~4,000ml, 10ml 단위)를 벗어나면 확인을 막는다.
class _GoalInputDialog extends StatefulWidget {
  const _GoalInputDialog({this.initial});

  final int? initial;

  @override
  State<_GoalInputDialog> createState() => _GoalInputDialogState();
}

class _GoalInputDialogState extends State<_GoalInputDialog> {
  late final TextEditingController _text =
      TextEditingController(text: widget.initial?.toString() ?? '');
  bool _error = false;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  void _submit() {
    final value = int.tryParse(_text.text);
    if (value == null || !GoalCalculator.isValidGoal(value)) {
      setState(() => _error = true);
      return;
    }
    Navigator.of(context).pop(value);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l10n.onboardingGoalInputTitle),
      content: TextField(
        controller: _text,
        autofocus: true,
        keyboardType: TextInputType.number,
        inputFormatters: [
          FilteringTextInputFormatter.digitsOnly,
          LengthLimitingTextInputFormatter(4),
        ],
        decoration: InputDecoration(
          suffixText: l10n.onboardingGoalUnit,
          errorText: _error ? l10n.onboardingGoalInputError : null,
        ),
        onChanged: (_) {
          if (_error) setState(() => _error = false);
        },
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.commonCancel),
        ),
        TextButton(onPressed: _submit, child: Text(l10n.commonConfirm)),
      ],
    );
  }
}
