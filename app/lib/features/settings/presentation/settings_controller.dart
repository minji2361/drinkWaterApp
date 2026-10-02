import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../../core/database/enums.dart';
import '../../../core/utils/date_utils.dart';
import '../../home/presentation/home_providers.dart';
import '../../onboarding/domain/goal_calculator.dart';
import '../data/backup_file_gateway.dart';
import '../data/backup_service.dart';
import '../data/reminder_scheduler.dart';
import '../data/settings_repository.dart';

class ProfileInput {
  const ProfileInput({
    required this.nickname,
    required this.gender,
    required this.age,
    required this.heightCm,
    required this.weightKg,
  });

  final String nickname;
  final Gender gender;
  final int age;
  final int? heightCm;
  final int weightKg;
}

/// 프로필 저장 후 목표량이 어떻게 처리되었는지.
class ProfileSaveOutcome {
  const ProfileSaveOutcome({this.autoGoalMl, this.askRecalcMl});

  /// 직접 수정한 목표가 아니어서 자동으로 재계산·반영한 값 (토스트로 알린다).
  final int? autoGoalMl;

  /// 직접 수정한 목표가 있어 사용자 확인이 필요한 권장량 ("목표량을 다시 계산할까요?").
  final int? askRecalcMl;
}

enum ReminderToggleResult { enabled, disabled, denied, unavailable }

class SettingsActions {
  SettingsActions(this._ref);

  final Ref _ref;

  SettingsRepository get _repo => _ref.read(settingsRepositoryProvider);
  DateTime get _now => _ref.read(clockProvider)();

  int ageOf(int birthYear) => _now.year - birthYear;

  int recommendedFor({
    required int weightKg,
    required Gender gender,
    required int age,
  }) =>
      GoalCalculator.recommendedMl(
          weightKg: weightKg, gender: gender, age: age);

  /// 프로필 수정 (S1과 같은 규칙으로 호출 전에 검증한다).
  /// 체중·나이·성별이 바뀌면 목표 재계산 정책(기획서 S5)을 적용한다.
  Future<ProfileSaveOutcome> saveProfile(ProfileInput input) async {
    final old = await _repo.getProfile();
    if (old == null) throw StateError('프로필이 없습니다.');
    final oldAge = ageOf(old.birthYear);

    await _repo.updateProfile(
      nickname: input.nickname,
      gender: input.gender,
      birthYear: _now.year - input.age,
      heightCm: input.heightCm,
      weightKg: input.weightKg,
      now: _now,
    );

    final factorsChanged = input.weightKg != old.weightKg ||
        input.gender != old.gender ||
        input.age != oldAge;
    if (!factorsChanged) return const ProfileSaveOutcome();

    final rec = recommendedFor(
      weightKg: input.weightKg,
      gender: input.gender,
      age: input.age,
    );
    if (rec == old.dailyGoalMl) return const ProfileSaveOutcome();

    if (!old.isGoalCustom) {
      await applyGoal(rec, custom: false);
      return ProfileSaveOutcome(autoGoalMl: rec);
    }
    return ProfileSaveOutcome(askRecalcMl: rec);
  }

  /// 목표량 저장. 허용 범위(500~4,000ml, 10ml 단위)를 벗어나면 [ArgumentError].
  Future<void> applyGoal(int ml, {required bool custom}) {
    if (!GoalCalculator.isValidGoal(ml)) {
      throw ArgumentError.value(ml, 'ml', '목표량은 500~4,000ml, 10ml 단위');
    }
    return _repo.setGoal(ml,
        custom: custom, today: toLogDate(_now), now: _now);
  }

  /// 직접 입력한 목표량. 권장량과 같으면 직접 수정으로 보지 않는다.
  Future<void> setGoalManually(int ml) async {
    final p = await _repo.getProfile();
    if (p == null) return;
    final rec = recommendedFor(
      weightKg: p.weightKg,
      gender: p.gender,
      age: ageOf(p.birthYear),
    );
    await applyGoal(ml, custom: ml != rec);
  }

  /// "권장량 재계산": 현재 프로필 기준 권장량으로 되돌린다. 반영한 값을 반환한다.
  Future<int> recalculateGoal() async {
    final p = await _repo.getProfile();
    if (p == null) throw StateError('프로필이 없습니다.');
    final rec = recommendedFor(
      weightKg: p.weightKg,
      gender: p.gender,
      age: ageOf(p.birthYear),
    );
    await applyGoal(rec, custom: false);
    return rec;
  }

  // ---- 알림 ---------------------------------------------------------------

  Future<ReminderToggleResult> setReminderEnabled(bool enabled) async {
    final scheduler = _ref.read(reminderSchedulerProvider);
    if (!enabled) {
      await scheduler.disable();
      await _repo.setReminderEnabled(false);
      return ReminderToggleResult.disabled;
    }
    switch (await scheduler.enable()) {
      case ReminderPermission.granted:
        await _repo.setReminderEnabled(true);
        await scheduler.reschedule(await _repo.getSettings());
        return ReminderToggleResult.enabled;
      case ReminderPermission.denied:
        return ReminderToggleResult.denied;
      case ReminderPermission.unavailable:
        return ReminderToggleResult.unavailable;
    }
  }

  Future<void> setReminderRange(String start, String end) async {
    await _repo.setReminderRange(start, end);
    await _reschedule();
  }

  Future<void> setReminderInterval(int minutes) async {
    await _repo.setReminderInterval(minutes);
    await _reschedule();
  }

  Future<void> _reschedule() async {
    final s = await _repo.getSettings();
    if (s.reminderEnabled) {
      await _ref.read(reminderSchedulerProvider).reschedule(s);
    }
  }

  // ---- 데이터 -------------------------------------------------------------

  Future<void> exportData() async {
    final json = await _ref.read(backupServiceProvider).exportJson();
    final d = _now;
    final name = 'drink_water_backup_${toLogDate(d)}.json';
    await _ref.read(backupFileGatewayProvider).shareJson(json, name);
  }

  /// 파일을 골라 복원한다. 취소하면 false, 복원하면 true. 형식이 틀리면 [BackupFormatException].
  Future<bool> importData() async {
    final json = await _ref.read(backupFileGatewayProvider).pickJson();
    if (json == null) return false;
    await _ref.read(backupServiceProvider).importJson(json);
    await _ref.read(currentDateProvider.notifier).refresh();
    return true;
  }

  Future<void> deleteAllRecords() async {
    await _ref.read(backupServiceProvider).deleteAllRecords();
    await _ref.read(currentDateProvider.notifier).refresh();
  }
}

final settingsActionsProvider =
    Provider<SettingsActions>((ref) => SettingsActions(ref));

final appVersionProvider = FutureProvider<String>((ref) async {
  final info = await PackageInfo.fromPlatform();
  return info.version;
});
