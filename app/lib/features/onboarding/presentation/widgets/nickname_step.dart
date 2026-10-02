import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../l10n/app_localizations.dart';
import '../onboarding_controller.dart';

class NicknameStep extends ConsumerWidget {
  const NicknameStep({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(onboardingControllerProvider);
    final showError = state.nickname.isNotEmpty && !state.nicknameValid;

    return TextFormField(
      initialValue: state.nickname,
      autofocus: true,
      textInputAction: TextInputAction.done,
      decoration: InputDecoration(
        labelText: l10n.onboardingNicknameLabel,
        errorText: showError ? l10n.onboardingNicknameError : null,
      ),
      onChanged: ref.read(onboardingControllerProvider.notifier).setNickname,
    );
  }
}
