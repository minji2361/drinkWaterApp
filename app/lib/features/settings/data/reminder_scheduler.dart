import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';

enum ReminderPermission { granted, denied, unavailable }

/// 로컬 알림 스케줄러 인터페이스 (기획서 5.5).
///
/// 실제 구현(flutter_local_notifications + timezone, OS 권한 요청, 기록 시 다음 알림 재계산,
/// 목표 달성 시 잔여 알림 취소)은 알림 기능 작업에서 이 인터페이스를 구현해 교체한다.
abstract class ReminderScheduler {
  /// 알림을 켠다. OS 권한을 요청하고 결과를 돌려준다.
  Future<ReminderPermission> enable();

  Future<void> disable();

  /// 활동 시간대·간격이 바뀌었을 때 다시 예약한다.
  Future<void> reschedule(AppSettingsRow settings);
}

/// 알림 기능이 구현되기 전까지의 기본 구현. 켤 수 없음을 알린다.
class UnavailableReminderScheduler implements ReminderScheduler {
  const UnavailableReminderScheduler();

  @override
  Future<ReminderPermission> enable() async => ReminderPermission.unavailable;

  @override
  Future<void> disable() async {}

  @override
  Future<void> reschedule(AppSettingsRow settings) async {}
}

final reminderSchedulerProvider = Provider<ReminderScheduler>(
  (ref) => const UnavailableReminderScheduler(),
);
