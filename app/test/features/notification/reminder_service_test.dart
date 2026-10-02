import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:drink_water_app/core/database/app_database.dart';
import 'package:drink_water_app/features/home/data/intake_repository.dart';
import 'package:drink_water_app/features/notification/data/reminder_scheduler.dart';
import 'package:drink_water_app/features/notification/data/reminder_service.dart';
import 'package:drink_water_app/l10n/app_localizations.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeScheduler implements ReminderScheduler {
  List<ReminderNotification>? last;
  int cancelled = 0;

  @override
  Future<ReminderPermission> requestPermission() async =>
      ReminderPermission.granted;

  @override
  Future<void> cancelAll() async => cancelled++;

  @override
  Future<void> replaceAll(List<ReminderNotification> items) async =>
      last = items;
}

void main() {
  late AppDatabase db;
  late IntakeRepository intake;
  late _FakeScheduler scheduler;
  final l10n = lookupAppLocalizations(const Locale('ko'));

  // 2026-10-02 09:00. 기본 설정(08:00~22:00, 2시간 간격), 목표 1,000ml
  var now = DateTime(2026, 10, 2, 9);

  ReminderService service() => ReminderService(db, scheduler, () => now);

  Future<void> enable() => (db.update(db.appSettings))
      .write(const AppSettingsCompanion(reminderEnabled: Value(true)));

  setUp(() async {
    now = DateTime(2026, 10, 2, 9);
    db = AppDatabase.forTesting(NativeDatabase.memory());
    intake = IntakeRepository(db);
    scheduler = _FakeScheduler();
    await db.into(db.userProfile).insert(UserProfileCompanion.insert(
          nickname: '물방울',
          gender: Gender.female,
          birthYear: 1998,
          weightKg: 55,
          dailyGoalMl: 1000,
        ));
    await intake.ensureToday(now);
  });

  tearDown(() => db.close());

  test('알림이 꺼져 있으면 예약하지 않고 기존 예약을 취소한다', () async {
    await service().refresh();
    expect(scheduler.last, isNull);
    expect(scheduler.cancelled, 1);
  });

  test('켜져 있으면 지금 이후 시각만, 앱 이름을 제목으로 예약한다', () async {
    await enable();
    await service().refresh();

    final items = scheduler.last!;
    expect(items.first.at, DateTime(2026, 10, 2, 10));
    expect(items.every((n) => n.at.isAfter(now)), isTrue);
    expect(items.every((n) => n.title == l10n.appName), isTrue);
    expect(items.every((n) => n.body.isNotEmpty), isTrue);
    // 오늘 + 내일 + 모레
    expect(items.map((n) => n.at.day).toSet(), {2, 3, 4});
  });

  test('물을 마시면 다음 알림이 마지막 기록 + 간격으로 다시 계산된다', () async {
    await enable();
    now = DateTime(2026, 10, 2, 14);
    await intake.addIntake(
        amountMl: 200,
        source: IntakeSource.quick,
        cupType: CupType.paper,
        now: now);
    await service().refresh();

    final today = scheduler.last!.where((n) => n.at.day == 2).toList();
    expect(today.first.at, DateTime(2026, 10, 2, 16));
  });

  test('목표를 달성하면 오늘 남은 알림이 없고 내일 알림은 남는다', () async {
    await enable();
    now = DateTime(2026, 10, 2, 11);
    await intake.addIntake(
        amountMl: 1000,
        source: IntakeSource.quick,
        cupType: CupType.paper,
        now: now);
    await service().refresh();

    final items = scheduler.last!;
    expect(items.where((n) => n.at.day == 2), isEmpty);
    expect(items.where((n) => n.at.day == 3), isNotEmpty);
  });

  test('활동 시간대·간격 설정이 반영된다', () async {
    await enable();
    await (db.update(db.appSettings)).write(const AppSettingsCompanion(
      reminderStart: Value('09:00'),
      reminderEnd: Value('12:00'),
      reminderIntervalMin: Value(60),
    ));
    now = DateTime(2026, 10, 2, 8);
    await service().refresh();

    final today =
        scheduler.last!.where((n) => n.at.day == 2).map((n) => n.at).toList();
    expect(today, [
      DateTime(2026, 10, 2, 9),
      DateTime(2026, 10, 2, 10),
      DateTime(2026, 10, 2, 11),
      DateTime(2026, 10, 2, 12),
    ]);
  });

  group('문구 (buildNotifications)', () {
    final today = DateTime(2026, 10, 2);
    final times = [
      for (var h = 8; h <= 20; h++) DateTime(2026, 10, 2, h),
      for (var h = 8; h <= 20; h++) DateTime(2026, 10, 3, h),
    ];

    test('오늘 알림에만 "목표까지 N ml 남았어요" 문구가 후보로 들어간다', () {
      final remaining = l10n.reminderMsgRemaining('700');
      final items = ReminderService.buildNotifications(
          times: times, today: today, remainingMl: 700, l10n: l10n);
      expect(items.where((n) => n.at.day == 3 && n.body == remaining), isEmpty);
      expect(items.any((n) => n.at.day == 2 && n.body == remaining), isTrue);
    });

    test('남은 양이 없으면 잔여량 문구는 쓰지 않는다', () {
      final items = ReminderService.buildNotifications(
          times: times, today: today, remainingMl: 0, l10n: l10n);
      expect(items.any((n) => n.body.contains('남았어요')), isFalse);
    });

    test('같은 입력이면 같은 문구 (다시 예약해도 문구가 바뀌지 않음)', () {
      List<String> bodies() => ReminderService.buildNotifications(
              times: times, today: today, remainingMl: 700, l10n: l10n)
          .map((n) => n.body)
          .toList();
      expect(bodies(), bodies());
    });
  });
}
