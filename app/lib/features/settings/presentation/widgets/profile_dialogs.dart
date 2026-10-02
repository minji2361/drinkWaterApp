import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/database/enums.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../onboarding/domain/onboarding_validators.dart';

/// 별명 수정. 취소하면 null.
Future<String?> showNicknameDialog(BuildContext context, String initial) {
  return showDialog<String>(
    context: context,
    builder: (_) => _NicknameDialog(initial: initial),
  );
}

class _NicknameDialog extends StatefulWidget {
  const _NicknameDialog({required this.initial});
  final String initial;

  @override
  State<_NicknameDialog> createState() => _NicknameDialogState();
}

class _NicknameDialogState extends State<_NicknameDialog> {
  late final _text = TextEditingController(text: widget.initial);
  bool _error = false;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  void _submit() {
    if (!OnboardingValidators.isValidNickname(_text.text)) {
      setState(() => _error = true);
      return;
    }
    Navigator.of(context).pop(_text.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l10n.settingsNickname),
      content: TextField(
        controller: _text,
        autofocus: true,
        decoration: InputDecoration(
          errorText: _error ? l10n.onboardingNicknameError : null,
        ),
        onChanged: (_) {
          if (_error) setState(() => _error = false);
        },
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l10n.commonCancel)),
        TextButton(onPressed: _submit, child: Text(l10n.commonConfirm)),
      ],
    );
  }
}

/// 성별 / 나이 수정.
Future<({Gender gender, int age})?> showGenderAgeDialog(
  BuildContext context, {
  required Gender gender,
  required int age,
}) {
  return showDialog<({Gender gender, int age})>(
    context: context,
    builder: (_) => _GenderAgeDialog(gender: gender, age: age),
  );
}

class _GenderAgeDialog extends StatefulWidget {
  const _GenderAgeDialog({required this.gender, required this.age});
  final Gender gender;
  final int age;

  @override
  State<_GenderAgeDialog> createState() => _GenderAgeDialogState();
}

class _GenderAgeDialogState extends State<_GenderAgeDialog> {
  late Gender _gender = widget.gender;
  late final _age = TextEditingController(text: '${widget.age}');
  bool _error = false;

  @override
  void dispose() {
    _age.dispose();
    super.dispose();
  }

  void _submit() {
    final age = int.tryParse(_age.text);
    if (!OnboardingValidators.isValidAge(age)) {
      setState(() => _error = true);
      return;
    }
    Navigator.of(context).pop((gender: _gender, age: age!));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final labels = {
      Gender.male: l10n.onboardingGenderMale,
      Gender.female: l10n.onboardingGenderFemale,
      Gender.unspecified: l10n.onboardingGenderUnspecified,
    };
    return AlertDialog(
      title: Text(l10n.settingsGenderAge),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            children: [
              for (final g in Gender.values)
                ChoiceChip(
                  label: Text(labels[g]!),
                  selected: _gender == g,
                  onSelected: (_) => setState(() => _gender = g),
                ),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _age,
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(3),
            ],
            decoration: InputDecoration(
              labelText: l10n.onboardingAgeLabel,
              suffixText: l10n.onboardingAgeSuffix,
              errorText: _error ? l10n.onboardingAgeError : null,
            ),
            onChanged: (_) {
              if (_error) setState(() => _error = false);
            },
          ),
        ],
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l10n.commonCancel)),
        TextButton(onPressed: _submit, child: Text(l10n.commonConfirm)),
      ],
    );
  }
}

/// [showIntDialog]의 결과. 값을 비우고 확인한 경우 [value]가 null이다 (선택 입력 전용).
class IntDialogResult {
  const IntDialogResult(this.value);
  final int? value;
}

/// 숫자 하나를 입력받는 대화상자 (키 / 몸무게 / 목표량). 취소하면 null.
Future<IntDialogResult?> showIntDialog(
  BuildContext context, {
  required String title,
  required int? initial,
  required String suffix,
  required bool Function(int value) isValid,
  required String errorText,
  bool allowEmpty = false,
  int maxLength = 4,
}) {
  return showDialog<IntDialogResult>(
    context: context,
    builder: (_) => _IntDialog(
      title: title,
      initial: initial,
      suffix: suffix,
      isValid: isValid,
      errorText: errorText,
      allowEmpty: allowEmpty,
      maxLength: maxLength,
    ),
  );
}

class _IntDialog extends StatefulWidget {
  const _IntDialog({
    required this.title,
    required this.initial,
    required this.suffix,
    required this.isValid,
    required this.errorText,
    required this.allowEmpty,
    required this.maxLength,
  });

  final String title;
  final int? initial;
  final String suffix;
  final bool Function(int) isValid;
  final String errorText;
  final bool allowEmpty;
  final int maxLength;

  @override
  State<_IntDialog> createState() => _IntDialogState();
}

class _IntDialogState extends State<_IntDialog> {
  late final _text =
      TextEditingController(text: widget.initial?.toString() ?? '');
  bool _error = false;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  void _submit() {
    if (_text.text.isEmpty && widget.allowEmpty) {
      Navigator.of(context).pop(const IntDialogResult(null));
      return;
    }
    final v = int.tryParse(_text.text);
    if (v == null || !widget.isValid(v)) {
      setState(() => _error = true);
      return;
    }
    Navigator.of(context).pop(IntDialogResult(v));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _text,
        autofocus: true,
        keyboardType: TextInputType.number,
        inputFormatters: [
          FilteringTextInputFormatter.digitsOnly,
          LengthLimitingTextInputFormatter(widget.maxLength),
        ],
        decoration: InputDecoration(
          suffixText: widget.suffix,
          errorText: _error ? widget.errorText : null,
        ),
        onChanged: (_) {
          if (_error) setState(() => _error = false);
        },
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l10n.commonCancel)),
        TextButton(onPressed: _submit, child: Text(l10n.commonConfirm)),
      ],
    );
  }
}
