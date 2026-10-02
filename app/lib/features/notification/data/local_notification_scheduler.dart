import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

import '../../../l10n/app_localizations.dart';
import 'reminder_scheduler.dart';

/// `flutter_local_notifications` 기반 구현 (Android / iOS).
///
/// 예약은 "특정 시각 1회" 알림을 여러 개 만드는 방식이다. 시각은 절대 시각으로 넘기므로
/// 기기 시간대를 따로 설정할 필요가 없다 (UTC로 변환해 전달).
/// 정확한 알람 권한은 쓰지 않고(`inexactAllowWhileIdle`) 몇 분 정도의 지연을 허용한다.
///
/// 네이티브 설정(AndroidManifest, iOS AppDelegate)은 `flutter create` 후 `app/README.md`의
/// "알림 플랫폼 설정"을 따라 추가해야 한다.
class LocalNotificationScheduler implements ReminderScheduler {
  LocalNotificationScheduler({FlutterLocalNotificationsPlugin? plugin})
      : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;
  bool _initialized = false;

  static const String _channelId = 'water_reminder';

  bool get _supported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  Future<void> _init() async {
    if (_initialized) return;
    await _plugin.initialize(const InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      // 권한은 설정에서 알림을 직접 켤 때 요청한다 (맥락 없는 요청은 거부율이 높다).
      iOS: DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      ),
    ));
    _initialized = true;
  }

  @override
  Future<ReminderPermission> requestPermission() async {
    if (!_supported) return ReminderPermission.unavailable;
    await _init();

    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android != null) {
      final granted = await android.requestNotificationsPermission();
      return granted == true
          ? ReminderPermission.granted
          : ReminderPermission.denied;
    }

    final ios = _plugin.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>();
    if (ios != null) {
      final granted =
          await ios.requestPermissions(alert: true, badge: false, sound: true);
      return granted == true
          ? ReminderPermission.granted
          : ReminderPermission.denied;
    }
    return ReminderPermission.unavailable;
  }

  @override
  Future<void> cancelAll() async {
    if (!_supported) return;
    await _init();
    await _plugin.cancelAll();
  }

  @override
  Future<void> replaceAll(List<ReminderNotification> items) async {
    if (!_supported) return;
    await _init();
    await _plugin.cancelAll();
    if (items.isEmpty) return;

    final l10n = lookupAppLocalizations(AppLocalizations.supportedLocales.first);
    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId,
        l10n.reminderChannelName,
        channelDescription: l10n.reminderChannelDescription,
        importance: Importance.defaultImportance,
        priority: Priority.defaultPriority,
      ),
      iOS: const DarwinNotificationDetails(),
    );

    for (var i = 0; i < items.length; i++) {
      final item = items[i];
      await _plugin.zonedSchedule(
        i,
        item.title,
        item.body,
        tz.TZDateTime.from(item.at, tz.UTC),
        details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
    }
  }
}
