import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'local_notification_scheduler.dart';

enum ReminderPermission { granted, denied, unavailable }

/// 예약할 알림 한 건.
class ReminderNotification {
  const ReminderNotification({
    required this.at,
    required this.title,
    required this.body,
  });

  final DateTime at;
  final String title;
  final String body;
}

/// OS 알림 기능에 대한 포트. 플러그인 의존을 이 인터페이스 뒤에 가둔다.
/// 언제·무슨 문구로 보낼지는 [ReminderService]가 정하고, 이 포트는 OS에 맡기기만 한다.
abstract class ReminderScheduler {
  /// OS 알림 권한을 요청한다. 이미 허용 상태면 그대로 [ReminderPermission.granted].
  /// 알림을 지원하지 않는 환경이면 [ReminderPermission.unavailable].
  Future<ReminderPermission> requestPermission();

  /// 예약된 알림을 모두 취소한다.
  Future<void> cancelAll();

  /// 기존 예약을 모두 지우고 [items]로 교체한다.
  Future<void> replaceAll(List<ReminderNotification> items);
}

final reminderSchedulerProvider = Provider<ReminderScheduler>(
  (ref) => LocalNotificationScheduler(),
);
