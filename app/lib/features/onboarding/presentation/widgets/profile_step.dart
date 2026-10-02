import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/database/enums.dart';
import '../../../../l10n/app_localizations.dart';
import '../onboarding_controller.dart';

class ProfileStep extends ConsumerWidget {
  const ProfileStep({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(onboardingControllerProvider);
    final controller = ref.read(onboardingControllerProvider.notifier);

    final genderLabels = {
      Gender.male: l10n.onboardingGenderMale,
      Gender.female: l10n.onboardingGenderFemale,
      Gender.unspecified: l10n.onboardingGenderUnspecified,
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.onboardingGenderLabel,
            style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [
            for (final g in Gender.values)
              ChoiceChip(
                label: Text(genderLabels[g]!),
                selected: state.gender == g,
                onSelected: (_) => controller.setGender(g),
              ),
          ],
        ),
        const SizedBox(height: 20),
        _NumberField(
          label: l10n.onboardingAgeLabel,
          suffix: l10n.onboardingAgeSuffix,
          initial: state.ageText,
          errorText: state.ageText.isNotEmpty && !state.ageValid
              ? l10n.onboardingAgeError
              : null,
          onChanged: controller.setAge,
        ),
        const SizedBox(height: 16),
        _NumberField(
          label: l10n.onboardingHeightLabel,
          suffix: l10n.onboardingHeightSuffix,
          initial: state.heightText,
          errorText: !state.heightValid ? l10n.onboardingHeightError : null,
          onChanged: controller.setHeight,
        ),
        const SizedBox(height: 16),
        _NumberField(
          label: l10n.onboardingWeightLabel,
          suffix: l10n.onboardingWeightSuffix,
          initial: state.weightText,
          errorText: state.weightText.isNotEmpty && !state.weightValid
              ? l10n.onboardingWeightError
              : null,
          onChanged: controller.setWeight,
        ),
      ],
    );
  }
}

class _NumberField extends StatelessWidget {
  const _NumberField({
    required this.label,
    required this.suffix,
    required this.initial,
    required this.errorText,
    required this.onChanged,
  });

  final String label;
  final String suffix;
  final String initial;
  final String? errorText;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      initialValue: initial,
      keyboardType: TextInputType.number,
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(3),
      ],
      decoration: InputDecoration(
        labelText: label,
        suffixText: suffix,
        errorText: errorText,
      ),
      onChanged: onChanged,
    );
  }
}
