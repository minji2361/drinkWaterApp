/// 알림 시각 계산 (기획서 5.5). 모두 순수 함수라 시계·DB·플러그인 없이 테스트할 수 있다.
class ReminderPlanner {
  const ReminderPlanner._();

  /// 오늘 포함 며칠 앞까지 예약할지. 앱을 열 때마다 다시 채운다.
  static const int horizonDays = 3;

  /// 한 번에 예약하는 알림 수의 상한. iOS는 앱당 64개까지만 예약할 수 있어서 여유를 둔다.
  /// 기본 설정(08~22시, 2시간 간격)은 3일에 24개지만, 1시간 간격에 활동 시간대를 하루 종일로
  /// 잡으면 한도를 넘을 수 있어 가까운 시각부터 자른다.
  static const int maxNotifications = 60;

  static int parseMinutes(String hhmm) {
    final parts = hhmm.split(':');
    return int.parse(parts[0]) * 60 + int.parse(parts[1]);
  }

  /// 예약할 알림 시각 목록 (오름차순).
  ///
  /// - 활동 시간대([startMinute] ~ [endMinute], 하루 기준 분) 밖에는 알림을 보내지 않는다.
  /// - 오늘 목표를 달성했으면([achievedToday]) 당일 잔여 알림을 전부 없앤다. 내일 이후는 유지한다.
  /// - 오늘 이미 물을 마셨으면([lastLoggedAt]) 방금 마시고 곧바로 알림이 오지 않도록
  ///   마지막 기록 + 간격부터 다시 센다. 활동 시간대 시작보다 이르면 시작 시각부터.
  /// - 기록이 없으면 시작 시각부터 간격마다. 이미 지난 시각은 제외한다.
  static List<DateTime> plan({
    required DateTime now,
    required int startMinute,
    required int endMinute,
    required int intervalMinutes,
    DateTime? lastLoggedAt,
    bool achievedToday = false,
    int days = horizonDays,
  }) {
    if (intervalMinutes <= 0 || endMinute <= startMinute) return const [];

    final step = Duration(minutes: intervalMinutes);
    final result = <DateTime>[];

    for (var d = 0; d < days; d++) {
      if (d == 0 && achievedToday) continue;

      // 분 인자 오버플로를 이용해 자정 기준 분을 시각으로 바꾼다.
      DateTime at(int minute) =>
          DateTime(now.year, now.month, now.day + d, 0, minute);
      final windowStart = at(startMinute);
      final windowEnd = at(endMinute);

      var first = windowStart;
      if (d == 0 && lastLoggedAt != null) {
        final next = lastLoggedAt.add(step);
        first = next.isBefore(windowStart) ? windowStart : next;
      }

      for (var t = first; !t.isAfter(windowEnd); t = t.add(step)) {
        if (t.isAfter(now)) result.add(t);
      }
    }
    return result.length > maxNotifications
        ? result.sublist(0, maxNotifications)
        : result;
  }
}
