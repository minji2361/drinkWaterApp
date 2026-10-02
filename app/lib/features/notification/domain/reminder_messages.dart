import 'dart:math';

/// 알림 문구를 고르는 규칙. 문구 3~5종을 랜덤하게 노출한다 (기획서 5.5).
class ReminderMessages {
  const ReminderMessages._();

  /// 같은 시각이면 항상 같은 문구가 나오도록 시각을 시드로 쓰는 의사 난수.
  /// 앱을 열 때마다 알림을 다시 예약해도 문구가 바뀌지 않는다.
  static int pickIndex(DateTime slot, int count) {
    assert(count > 0);
    final minutes = slot.millisecondsSinceEpoch ~/ 60000;
    return Random(minutes).nextInt(count);
  }
}
