import 'package:drink_water_app/features/notification/domain/reminder_messages.dart';
import 'package:drink_water_app/features/notification/domain/reminder_planner.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // 기본 설정: 08:00 ~ 22:00, 2시간 간격
  const start = 8 * 60;
  const end = 22 * 60;
  const every2h = 120;

  DateTime d(int day, int h, [int m = 0]) => DateTime(2026, 10, day, h, m);

  List<DateTime> plan({
    required DateTime now,
    DateTime? last,
    bool achieved = false,
    int interval = every2h,
    int days = 1,
  }) =>
      ReminderPlanner.plan(
        now: now,
        startMinute: start,
        endMinute: end,
        intervalMinutes: interval,
        lastLoggedAt: last,
        achievedToday: achieved,
        days: days,
      );

  test('시간 문자열 파싱', () {
    expect(ReminderPlanner.parseMinutes('08:00'), 480);
    expect(ReminderPlanner.parseMinutes('22:30'), 1350);
  });

  group('오늘', () {
    test('기록이 없으면 시작 시각부터 간격마다, 지난 시각은 제외', () {
      expect(plan(now: d(2, 7)), [
        d(2, 8), d(2, 10), d(2, 12), d(2, 14), d(2, 16), d(2, 18), d(2, 20),
        d(2, 22),
      ]);
      expect(plan(now: d(2, 15)), [d(2, 16), d(2, 18), d(2, 20), d(2, 22)]);
    });

    test('정확히 지금인 시각은 제외한다 (이미 울릴 시각)', () {
      expect(plan(now: d(2, 16)).first, d(2, 18));
    });

    test('방금 마셨으면 마지막 기록 + 간격부터 다시 센다', () {
      // 14:00에 마셨고 지금 14:00 → 16:00, 18:00, 20:00, 22:00
      expect(plan(now: d(2, 14), last: d(2, 14)),
          [d(2, 16), d(2, 18), d(2, 20), d(2, 22)]);
      // 10분 뒤에 알림이 오지 않는다
      expect(plan(now: d(2, 14, 5), last: d(2, 14)).first, d(2, 16));
    });

    test('마지막 기록 + 간격이 종료 시각을 넘으면 오늘 알림은 없다', () {
      expect(plan(now: d(2, 21), last: d(2, 21)), isEmpty);
    });

    test('활동 시간대 시작 전에 마신 기록은 시작 시각부터 센다', () {
      expect(plan(now: d(2, 6, 30), last: d(2, 6)).first, d(2, 8));
    });

    test('종료 시각 이후에는 오늘 알림이 없다', () {
      expect(plan(now: d(2, 22, 30)), isEmpty);
    });

    test('목표를 달성했으면 오늘 남은 알림을 모두 없앤다', () {
      expect(plan(now: d(2, 9), achieved: true), isEmpty);
    });

    test('종료 시각이 간격에 딱 맞지 않으면 종료 이후 알림은 없다', () {
      // 3시간 간격: 08, 11, 14, 17, 20 (23은 22시 이후)
      expect(plan(now: d(2, 7), interval: 180),
          [d(2, 8), d(2, 11), d(2, 14), d(2, 17), d(2, 20)]);
    });
  });

  group('다음 날 이후', () {
    test('내일은 시작 시각부터 표준 간격으로 잡힌다', () {
      final times = plan(now: d(2, 21), days: 2);
      expect(times.where((t) => t.day == 3).first, d(3, 8));
      expect(times.where((t) => t.day == 3), hasLength(8));
    });

    test('오늘 달성해도 내일 알림은 유지된다', () {
      final times = plan(now: d(2, 9), achieved: true, days: 2);
      expect(times.every((t) => t.day == 3), isTrue);
      expect(times, isNotEmpty);
    });

    test('기본 예약 범위는 3일이고 08~22시 1시간 간격(하루 15개)도 iOS 한도 안', () {
      final times = ReminderPlanner.plan(
        now: d(2, 0),
        startMinute: start,
        endMinute: end,
        intervalMinutes: 60,
      );
      expect(times.map((t) => t.day).toSet(), {2, 3, 4});
      expect(times.length, lessThanOrEqualTo(64));
    });

    test('하루 종일 1시간 간격이어도 60개를 넘지 않고 가까운 시각부터 남긴다', () {
      final times = ReminderPlanner.plan(
        now: d(2, 0),
        startMinute: 0,
        endMinute: 23 * 60 + 59,
        intervalMinutes: 60,
      );
      expect(times, hasLength(ReminderPlanner.maxNotifications));
      expect(times.first, d(2, 1));
      expect(times, [...times]..sort());
    });

    test('월말을 넘겨도 날짜가 올바르다', () {
      final times = ReminderPlanner.plan(
        now: DateTime(2026, 10, 31, 21),
        startMinute: start,
        endMinute: end,
        intervalMinutes: every2h,
        days: 2,
      );
      expect(times.last, DateTime(2026, 11, 1, 22));
    });
  });

  group('잘못된 설정', () {
    test('종료가 시작보다 빠르거나 같으면 빈 목록', () {
      expect(
        ReminderPlanner.plan(
            now: d(2, 7), startMinute: 600, endMinute: 600, intervalMinutes: 60),
        isEmpty,
      );
      expect(
        ReminderPlanner.plan(
            now: d(2, 7), startMinute: 600, endMinute: 500, intervalMinutes: 60),
        isEmpty,
      );
    });

    test('간격이 0 이하면 빈 목록', () {
      expect(
        ReminderPlanner.plan(
            now: d(2, 7), startMinute: 480, endMinute: 1320, intervalMinutes: 0),
        isEmpty,
      );
    });
  });

  group('ReminderMessages.pickIndex', () {
    test('같은 시각이면 같은 문구, 범위를 벗어나지 않는다', () {
      final t = DateTime(2026, 10, 2, 16);
      expect(ReminderMessages.pickIndex(t, 5), ReminderMessages.pickIndex(t, 5));
      for (var h = 0; h < 24; h++) {
        final i = ReminderMessages.pickIndex(DateTime(2026, 10, 2, h), 5);
        expect(i, inInclusiveRange(0, 4));
      }
    });

    test('여러 시각에 걸쳐 문구가 섞여 나온다', () {
      final picks = {
        for (var h = 0; h < 24; h++)
          ReminderMessages.pickIndex(DateTime(2026, 10, 2, h), 5),
      };
      expect(picks.length, greaterThan(1));
    });
  });
}
