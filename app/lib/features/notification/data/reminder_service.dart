import 'dart:ui';

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/database_provider.dart';
import '../../../core/utils/date_utils.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/reminder_messages.dart';
import '../domain/reminder_planner.dart';
import 'reminder_scheduler.dart';

/// 알림 정책 (기획서 5.5). DB 상태로 알림 시각과 문구를 정해 [ReminderScheduler]에 맡긴다.
///
/// - 기록할 때마다 [refresh]로 다음 알림을 다시 계산한다 (방금 마셨는데 10분 뒤 알림 방지).
/// - 목표를 달성한 날의 잔여 알림은 계획에서 빠진다.
/// - 알림 문구 때문에 기록·화면 동작이 깨지면 안 되므로 [refresh]는 예외를 삼킨다.
class ReminderService {
  ReminderService(this._db, this._scheduler, this._now);

  final AppDatabase _db;
  final ReminderScheduler _scheduler;
  final DateTime Function() _now;

  Future<ReminderPermission> requestPermission() =>
      _scheduler.requestPermission();

  Future<void> disable() => _scheduler.cancelAll();

  /// 설정과 오늘의 기록 상태에 맞게 알림을 다시 예약한다. 알림이 꺼져 있으면 예약을 모두 취소한다.
  Future<void> refresh() async {
    try {
      final settings = await _db.select(_db.appSettings).getSingle();
      if (!settings.reminderEnabled) {
        // 가져오기 등으로 꺼진 상태가 되었는데 이전 예약이 남아 있는 경우를 정리한다.
        await _scheduler.cancelAll();
        return;
      }

      final now = _now();
      final today = toLogDate(now);

      final summary = await (_db.select(_db.dailySummary)
            ..where((t) => t.logDate.equals(today)))
          .getSingleOrNull();
      final lastAt = _db.intakeLog.loggedAt.max();
      final lastRow = await (_db.selectOnly(_db.intakeLog)
            ..addColumns([lastAt])
            ..where(_db.intakeLog.logDate.equals(today)))
          .getSingle();

      final times = ReminderPlanner.plan(
        now: now,
        startMinute: ReminderPlanner.parseMinutes(settings.reminderStart),
        endMinute: ReminderPlanner.parseMinutes(settings.reminderEnd),
        intervalMinutes: settings.reminderIntervalMin,
        lastLoggedAt: lastRow.read(lastAt),
        achievedToday: summary?.isAchieved ?? false,
      );

      final remainingMl = summary == null
          ? 0
          : (summary.goalMl - summary.totalMl).clamp(0, summary.goalMl);

      await _scheduler.replaceAll(
        buildNotifications(
          times: times,
          today: DateTime(now.year, now.month, now.day),
          remainingMl: remainingMl,
          l10n: _l10n(),
        ),
      );
    } catch (_) {
      // 알림 실패가 앱 동작을 막지 않는다.
    }
  }

  static AppLocalizations _l10n() {
    final device = PlatformDispatcher.instance.locale;
    final locale = AppLocalizations.supportedLocales.firstWhere(
      (l) => l.languageCode == device.languageCode,
      orElse: () => AppLocalizations.supportedLocales.first,
    );
    return lookupAppLocalizations(locale);
  }

  /// 예약 시각마다 문구를 붙인다. 오늘 알림에만 "목표까지 N ml 남았어요"를 후보에 넣는다
  /// (다른 날은 그 시점의 잔여량을 알 수 없다).
  static List<ReminderNotification> buildNotifications({
    required List<DateTime> times,
    required DateTime today,
    required int remainingMl,
    required AppLocalizations l10n,
  }) {
    final fmt = NumberFormat.decimalPattern(l10n.localeName);
    final generic = [
      l10n.reminderMsg1,
      l10n.reminderMsg2,
      l10n.reminderMsg3,
      l10n.reminderMsg4,
    ];

    return [
      for (final t in times)
        () {
          final isToday = t.year == today.year &&
              t.month == today.month &&
              t.day == today.day;
          final candidates = [
            ...generic,
            if (isToday && remainingMl > 0)
              l10n.reminderMsgRemaining(fmt.format(remainingMl)),
          ];
          return ReminderNotification(
            at: t,
            title: l10n.appName,
            body: candidates[ReminderMessages.pickIndex(t, candidates.length)],
          );
        }(),
    ];
  }
}

final reminderServiceProvider = Provider<ReminderService>((ref) {
  return ReminderService(
    ref.watch(appDatabaseProvider),
    ref.watch(reminderSchedulerProvider),
    ref.watch(clockProvider),
  );
});
