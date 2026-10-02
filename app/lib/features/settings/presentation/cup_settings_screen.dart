import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/database/app_database.dart';
import '../../../core/theme/app_theme.dart';
import '../../../l10n/app_localizations.dart';
import '../../home/data/intake_repository.dart';
import '../../home/domain/intake_rules.dart';
import '../../home/presentation/home_controller.dart';
import '../../home/presentation/home_providers.dart';
import '../../home/presentation/widgets/cup_icon.dart';

/// S5-1 기본 컵 설정 (기획서 6장). 저장 버튼 없이 즉시 적용한다.
class CupSettingsScreen extends ConsumerWidget {
  const CupSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final settings = ref.watch(appSettingsProvider).valueOrNull;
    final controller = ref.read(homeControllerProvider.notifier);

    Future<void> run(Future<void> Function() action) async {
      try {
        await action();
      } catch (_) {
        // 저장 실패 시 DB 값이 그대로이므로 화면은 이전 값을 유지한다. 오류만 알린다.
        if (context.mounted) {
          ScaffoldMessenger.of(context)
            ..clearSnackBars()
            ..showSnackBar(SnackBar(content: Text(l10n.settingsSaveFailed)));
        }
      }
    }

    return Scaffold(
      body: SafeArea(
        child: settings == null
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                    child: Row(
                      children: [
                        IconButton.filled(
                          tooltip: l10n.commonBack,
                          style: IconButton.styleFrom(
                            backgroundColor: AppColors.surface,
                            foregroundColor: AppColors.textPrimary,
                          ),
                          onPressed: () => context.pop(),
                          icon: const Icon(Icons.chevron_left),
                        ),
                        Expanded(
                          child: Text(l10n.cupSettingsTitle,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                  fontSize: 20, fontWeight: FontWeight.w800)),
                        ),
                        const SizedBox(width: 48),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                      children: [
                        Text(l10n.cupSettingsGuide,
                            style: const TextStyle(
                                color: AppColors.textSecondary, height: 1.5)),
                        const SizedBox(height: 16),
                        for (final type in CupType.values) ...[
                          _CupRow(
                            type: type,
                            ml: settings.cupMl(type),
                            selected: settings.defaultCupType == type,
                            onSelect: () =>
                                run(() => controller.selectCup(type)),
                            onChange: (ml) =>
                                run(() => controller.updateCupMl(type, ml)),
                          ),
                          const SizedBox(height: 10),
                        ],
                        Center(
                          child: Text(l10n.cupSettingsRange,
                              style: const TextStyle(
                                  fontSize: 13,
                                  color: AppColors.textSecondary)),
                        ),
                        const SizedBox(height: 24),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceTint,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(l10n.cupSettingsCurrent,
                                  style: const TextStyle(
                                      fontSize: 13,
                                      color: AppColors.textSecondary)),
                              const SizedBox(height: 4),
                              Text(
                                l10n.cupSettingsCurrentValue(
                                  cupName(l10n, settings.defaultCupType),
                                  settings.defaultCupMl,
                                ),
                                style: const TextStyle(
                                    fontSize: 18, fontWeight: FontWeight.w800),
                              ),
                              const SizedBox(height: 4),
                              Text(l10n.cupSettingsNote,
                                  style: const TextStyle(
                                      fontSize: 13,
                                      color: AppColors.textSecondary)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _CupRow extends StatelessWidget {
  const _CupRow({
    required this.type,
    required this.ml,
    required this.selected,
    required this.onSelect,
    required this.onChange,
  });

  final CupType type;
  final int ml;
  final bool selected;
  final VoidCallback onSelect;
  final ValueChanged<int> onChange;

  static const _defaults = {
    CupType.paper: 200,
    CupType.mug: 300,
    CupType.tumbler: 500,
    CupType.other: 350,
  };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Material(
      color: selected ? AppColors.surfaceTint : AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(
          color: selected ? AppColors.primary : Colors.transparent,
          width: 2,
        ),
      ),
      child: InkWell(
        customBorder:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        onTap: onSelect,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          child: Row(
            children: [
              Icon(
                selected
                    ? Icons.radio_button_checked
                    : Icons.radio_button_unchecked,
                color: AppColors.primary,
              ),
              const SizedBox(width: 10),
              Icon(cupIcon(type), color: AppColors.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(cupName(l10n, type),
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w600)),
                    Text(
                      type == CupType.other
                          ? l10n.cupSettingsOtherHint
                          : l10n.cupSettingsDefaultHint(_defaults[type]!),
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              IconButton.outlined(
                visualDensity: VisualDensity.compact,
                onPressed: () => onChange(_step(ml, -IntakeRules.cupAdjustStepMl)),
                icon: const Icon(Icons.remove),
              ),
              InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () async {
                  final v = await showDialog<int>(
                    context: context,
                    builder: (_) => _VolumeDialog(initial: ml),
                  );
                  if (v != null) onChange(v);
                },
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                  child: SizedBox(
                    width: 58,
                    child: Text('${ml}ml',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w800)),
                  ),
                ),
              ),
              IconButton.outlined(
                visualDensity: VisualDensity.compact,
                onPressed: () => onChange(_step(ml, IntakeRules.cupAdjustStepMl)),
                icon: const Icon(Icons.add),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 50ml씩 증감하되 10~2,000ml 경계에서 고정한다.
  static int _step(int ml, int delta) =>
      (ml + delta).clamp(IntakeRules.minCupMl, IntakeRules.maxCupMl);
}

/// 용량 직접 입력. 범위(10~2,000ml)를 벗어나면 저장을 막고, 10ml 단위가 아니면 반올림한다.
class _VolumeDialog extends StatefulWidget {
  const _VolumeDialog({required this.initial});
  final int initial;

  @override
  State<_VolumeDialog> createState() => _VolumeDialogState();
}

class _VolumeDialogState extends State<_VolumeDialog> {
  late final _text = TextEditingController(text: '${widget.initial}');
  bool _error = false;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  void _submit() {
    final normalized = int.tryParse(_text.text) == null
        ? null
        : IntakeRules.normalizeCupMl(int.parse(_text.text));
    if (normalized == null) {
      setState(() => _error = true);
      return;
    }
    if ('$normalized' != _text.text) {
      // 반올림한 값을 입력창에 반영한 뒤 저장한다.
      _text.text = '$normalized';
    }
    Navigator.of(context).pop(normalized);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l10n.volumeDialogTitle),
      content: TextField(
        controller: _text,
        autofocus: true,
        textAlign: TextAlign.center,
        keyboardType: TextInputType.number,
        inputFormatters: [
          FilteringTextInputFormatter.digitsOnly,
          LengthLimitingTextInputFormatter(4),
        ],
        decoration: InputDecoration(
          suffixText: 'ml',
          errorText: _error ? l10n.volumeError : null,
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
