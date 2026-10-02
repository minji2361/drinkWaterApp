import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/database/app_database.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/medical_notice.dart';
import '../../../l10n/app_localizations.dart';
import '../../home/data/intake_repository.dart';
import '../../home/presentation/home_providers.dart';
import '../../home/presentation/widgets/cup_icon.dart';
import '../../onboarding/domain/goal_calculator.dart';
import '../../onboarding/domain/onboarding_validators.dart';
import '../data/backup_service.dart';
import 'settings_controller.dart';
import 'widgets/profile_dialogs.dart';
import 'widgets/settings_widgets.dart';

/// S5 설정 화면 (기획서 6장).
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final profile = ref.watch(userProfileProvider).valueOrNull;
    final settings = ref.watch(appSettingsProvider).valueOrNull;
    final version = ref.watch(appVersionProvider).valueOrNull ?? '-';
    final fmt = NumberFormat.decimalPattern(l10n.localeName);
    final actions = ref.read(settingsActionsProvider);

    return Scaffold(
      body: SafeArea(
        child: Column(
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
                    child: Text(l10n.settingsTitle,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            fontSize: 20, fontWeight: FontWeight.w800)),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
            ),
            Expanded(
              child: profile == null || settings == null
                  ? const Center(child: CircularProgressIndicator())
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                      children: [
                        _profileSection(
                            context, ref, l10n, fmt, profile, actions),
                        _reminderSection(context, ref, l10n, settings, actions),
                        _recordSection(
                            context, ref, l10n, settings, actions),
                        SettingsSection(
                          title: l10n.settingsSectionEtc,
                          children: [
                            SettingsRow(
                                label: l10n.settingsAppVersion, value: version),
                            SettingsRow(
                              label: l10n.settingsTerms,
                              showChevron: true,
                              onTap: () => _comingSoon(context),
                            ),
                            SettingsRow(
                              label: l10n.settingsPrivacy,
                              showChevron: true,
                              onTap: () => _comingSoon(context),
                            ),
                            SettingsRow(
                              label: l10n.settingsContact,
                              showChevron: true,
                              onTap: () => _comingSoon(context),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        const MedicalNotice(),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  // ---- 프로필 ---------------------------------------------------------------

  Widget _profileSection(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n,
    NumberFormat fmt,
    UserProfileRow p,
    SettingsActions actions,
  ) {
    final age = actions.ageOf(p.birthYear);
    final genderLabel = switch (p.gender) {
      Gender.male => l10n.onboardingGenderMale,
      Gender.female => l10n.onboardingGenderFemale,
      Gender.unspecified => l10n.onboardingGenderUnspecified,
    };

    Future<void> save({
      String? nickname,
      Gender? gender,
      int? newAge,
      Object? height = _keep,
      int? weight,
    }) async {
      try {
        final outcome = await actions.saveProfile(ProfileInput(
          nickname: nickname ?? p.nickname,
          gender: gender ?? p.gender,
          age: newAge ?? age,
          heightCm: identical(height, _keep) ? p.heightCm : height as int?,
          weightKg: weight ?? p.weightKg,
        ));
        if (!context.mounted) return;
        if (outcome.autoGoalMl != null) {
          _toast(context,
              l10n.settingsGoalAutoUpdated(fmt.format(outcome.autoGoalMl)));
        } else if (outcome.askRecalcMl != null) {
          final yes = await _confirm(
            context,
            title: l10n.settingsRecalcAskTitle,
            message: l10n.settingsRecalcAskMessage(
                fmt.format(outcome.askRecalcMl)),
            confirm: l10n.settingsRecalc,
          );
          if (yes == true) {
            await actions.applyGoal(outcome.askRecalcMl!, custom: false);
          }
        }
      } catch (_) {
        if (context.mounted) _toast(context, l10n.settingsSaveFailed);
      }
    }

    return SettingsSection(
      title: l10n.settingsSectionProfile,
      children: [
        SettingsRow(
          label: l10n.settingsNickname,
          value: p.nickname,
          onTap: () async {
            final v = await showNicknameDialog(context, p.nickname);
            if (v != null) await save(nickname: v);
          },
        ),
        SettingsRow(
          label: l10n.settingsGenderAge,
          value: l10n.settingsGenderAgeValue(genderLabel, age),
          onTap: () async {
            final v = await showGenderAgeDialog(context,
                gender: p.gender, age: age);
            if (v != null) await save(gender: v.gender, newAge: v.age);
          },
        ),
        SettingsRow(
          label: l10n.settingsHeight,
          value: p.heightCm == null
              ? l10n.settingsHeightNone
              : '${p.heightCm}cm',
          onTap: () async {
            final r = await showIntDialog(
              context,
              title: l10n.onboardingHeightLabel,
              initial: p.heightCm,
              suffix: l10n.onboardingHeightSuffix,
              isValid: (v) => OnboardingValidators.isValidOptionalHeight(v),
              errorText: l10n.onboardingHeightError,
              allowEmpty: true,
              maxLength: 3,
            );
            if (r != null) await save(height: r.value);
          },
        ),
        SettingsRow(
          label: l10n.onboardingWeightLabel,
          value: '${p.weightKg}kg',
          onTap: () async {
            final r = await showIntDialog(
              context,
              title: l10n.onboardingWeightLabel,
              initial: p.weightKg,
              suffix: l10n.onboardingWeightSuffix,
              isValid: (v) => OnboardingValidators.isValidWeight(v),
              errorText: l10n.onboardingWeightError,
              maxLength: 3,
            );
            if (r?.value != null) await save(weight: r!.value);
          },
        ),
        SettingsRow(
          label: l10n.settingsDailyGoal,
          value: '${fmt.format(p.dailyGoalMl)}ml',
          onTap: () async {
            final r = await showIntDialog(
              context,
              title: l10n.settingsDailyGoal,
              initial: p.dailyGoalMl,
              suffix: l10n.onboardingGoalUnit,
              isValid: GoalCalculator.isValidGoal,
              errorText: l10n.onboardingGoalInputError,
            );
            if (r?.value == null) return;
            try {
              await actions.setGoalManually(r!.value!);
            } catch (_) {
              if (context.mounted) _toast(context, l10n.settingsSaveFailed);
            }
          },
          trailing: OutlinedButton(
            style: OutlinedButton.styleFrom(
              visualDensity: VisualDensity.compact,
              shape: const StadiumBorder(),
            ),
            onPressed: () async {
              try {
                final rec = await actions.recalculateGoal();
                if (context.mounted) {
                  _toast(context,
                      l10n.settingsGoalAutoUpdated(fmt.format(rec)));
                }
              } catch (_) {
                if (context.mounted) _toast(context, l10n.settingsSaveFailed);
              }
            },
            child: Text(l10n.settingsRecalc),
          ),
        ),
      ],
    );
  }

  // ---- 알림 ---------------------------------------------------------------

  Widget _reminderSection(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n,
    AppSettingsRow s,
    SettingsActions actions,
  ) {
    return SettingsSection(
      title: l10n.settingsSectionReminder,
      children: [
        SettingsRow(
          label: l10n.settingsReminderEnabled,
          trailing: Switch(
            value: s.reminderEnabled,
            onChanged: (on) async {
              final result = await actions.setReminderEnabled(on);
              if (!context.mounted) return;
              switch (result) {
                case ReminderToggleResult.unavailable:
                  _toast(context, l10n.settingsReminderUnavailable);
                case ReminderToggleResult.denied:
                  _toast(context, l10n.settingsReminderDenied);
                case ReminderToggleResult.enabled ||
                      ReminderToggleResult.disabled:
                  break;
              }
            },
          ),
        ),
        SettingsRow(
          label: l10n.settingsReminderRange,
          value: '${s.reminderStart} – ${s.reminderEnd}',
          onTap: () => _pickRange(context, l10n, s, actions),
        ),
        SettingsRow(
          label: l10n.settingsReminderInterval,
          value: l10n.settingsHours(s.reminderIntervalMin ~/ 60),
          onTap: () async {
            final v = await showDialog<int>(
              context: context,
              builder: (_) => SimpleDialog(
                title: Text(l10n.settingsReminderInterval),
                children: [
                  for (final m in const [60, 120, 180])
                    ListTile(
                      title: Text(l10n.settingsHours(m ~/ 60)),
                      trailing: m == s.reminderIntervalMin
                          ? const Icon(Icons.check, color: AppColors.primary)
                          : null,
                      onTap: () => Navigator.of(context).pop(m),
                    ),
                ],
              ),
            );
            if (v != null) await actions.setReminderInterval(v);
          },
        ),
      ],
    );
  }

  /// 시작 → 종료 순서로 시간을 고른다. 시작이 종료보다 빠르지 않으면 저장하지 않는다.
  Future<void> _pickRange(BuildContext context, AppLocalizations l10n,
      AppSettingsRow s, SettingsActions actions) async {
    final start = await showTimePicker(
        context: context,
        helpText: l10n.settingsReminderStart,
        initialTime: _parse(s.reminderStart));
    if (start == null || !context.mounted) return;
    final end = await showTimePicker(
        context: context,
        helpText: l10n.settingsReminderEnd,
        initialTime: _parse(s.reminderEnd));
    if (end == null || !context.mounted) return;

    final startMin = start.hour * 60 + start.minute;
    final endMin = end.hour * 60 + end.minute;
    if (startMin >= endMin) {
      _toast(context, l10n.settingsReminderRangeError);
      return;
    }
    await actions.setReminderRange(_format(start), _format(end));
  }

  static TimeOfDay _parse(String hhmm) {
    final parts = hhmm.split(':');
    return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
  }

  static String _format(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  // ---- 기록 / 데이터 --------------------------------------------------------

  Widget _recordSection(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n,
    AppSettingsRow s,
    SettingsActions actions,
  ) {
    return SettingsSection(
      title: l10n.settingsSectionRecord,
      children: [
        SettingsRow(
          label: l10n.settingsDefaultCup,
          value: '${cupName(l10n, s.defaultCupType)} ${s.defaultCupMl}ml',
          showChevron: true,
          onTap: () => context.push(AppRoutes.settingsCup),
        ),
        SettingsRow(
          label: l10n.settingsExport,
          value: 'JSON',
          onTap: () async {
            try {
              await actions.exportData();
            } catch (_) {
              if (context.mounted) _toast(context, l10n.settingsExportFailed);
            }
          },
        ),
        SettingsRow(
          label: l10n.settingsImport,
          value: l10n.settingsImportValue,
          onTap: () => _import(context, l10n, actions),
        ),
        SettingsRow(
          label: l10n.settingsDeleteAll,
          value: l10n.settingsDeleteAllValue,
          destructive: true,
          onTap: () => _deleteAll(context, l10n, actions),
        ),
      ],
    );
  }

  Future<void> _import(BuildContext context, AppLocalizations l10n,
      SettingsActions actions) async {
    final ok = await _confirm(
      context,
      title: l10n.settingsImport,
      message: l10n.settingsImportConfirm,
      confirm: l10n.commonConfirm,
    );
    if (ok != true || !context.mounted) return;
    try {
      final restored = await actions.importData();
      if (restored && context.mounted) _toast(context, l10n.settingsImportDone);
    } on BackupFormatException {
      if (context.mounted) _toast(context, l10n.settingsImportInvalid);
    } catch (_) {
      if (context.mounted) _toast(context, l10n.settingsImportFailed);
    }
  }

  /// 되돌릴 수 없으므로 2단계 확인: 경고 대화상자 → "삭제" 문구 직접 입력.
  Future<void> _deleteAll(BuildContext context, AppLocalizations l10n,
      SettingsActions actions) async {
    final first = await _confirm(
      context,
      title: l10n.settingsDeleteAll,
      message: l10n.settingsDeleteAllWarning,
      confirm: l10n.commonNext,
      destructive: true,
    );
    if (first != true || !context.mounted) return;

    final typed = await showDialog<bool>(
      context: context,
      builder: (_) => _TypeToConfirmDialog(
        keyword: l10n.settingsDeleteKeyword,
        title: l10n.settingsDeleteAll,
        message: l10n.settingsDeleteTypePrompt(l10n.settingsDeleteKeyword),
      ),
    );
    if (typed != true || !context.mounted) return;

    try {
      await actions.deleteAllRecords();
      if (context.mounted) _toast(context, l10n.settingsDeleteDone);
    } catch (_) {
      if (context.mounted) _toast(context, l10n.settingsSaveFailed);
    }
  }

  // ---- 공통 -----------------------------------------------------------------

  static const Object _keep = Object();

  void _comingSoon(BuildContext context) =>
      _toast(context, AppLocalizations.of(context).commonComingSoon);

  void _toast(BuildContext context, String text) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  Future<bool?> _confirm(
    BuildContext context, {
    required String title,
    required String message,
    required String confirm,
    bool destructive = false,
  }) {
    final l10n = AppLocalizations.of(context);
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.commonCancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: destructive
                ? TextButton.styleFrom(foregroundColor: AppColors.error)
                : null,
            child: Text(confirm),
          ),
        ],
      ),
    );
  }
}

/// 지정한 문구를 직접 입력해야 확인되는 대화상자.
class _TypeToConfirmDialog extends StatefulWidget {
  const _TypeToConfirmDialog(
      {required this.keyword, required this.title, required this.message});

  final String keyword;
  final String title;
  final String message;

  @override
  State<_TypeToConfirmDialog> createState() => _TypeToConfirmDialogState();
}

class _TypeToConfirmDialogState extends State<_TypeToConfirmDialog> {
  final _text = TextEditingController();

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final matches = _text.text.trim() == widget.keyword;
    return AlertDialog(
      title: Text(widget.title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.message),
          const SizedBox(height: 12),
          TextField(
            controller: _text,
            autofocus: true,
            onChanged: (_) => setState(() {}),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(l10n.commonCancel),
        ),
        TextButton(
          onPressed: matches ? () => Navigator.of(context).pop(true) : null,
          style: TextButton.styleFrom(foregroundColor: AppColors.error),
          child: Text(l10n.settingsDeleteButton),
        ),
      ],
    );
  }
}
