/// 일일 상한 종류.
enum LimitKind { totalMl, count }

/// 하루 기록 상한 (기획서 5.6.4). 건강 안전과 어뷰징 방지의 최종 방어선.
class IntakeRules {
  const IntakeRules._();

  static const int maxDailyMl = 4000;
  static const int maxDailyCount = 30;

  /// 묶음 기록 잔 수 범위 (기획서 5.2).
  static const int minBulkCount = 1;
  static const int maxBulkCount = 10;

  /// 컵 용량 허용 범위 / 단위 (기획서 5.2).
  static const int minCupMl = 10;
  static const int maxCupMl = 2000;
  static const int cupStepMl = 10;
  static const int cupAdjustStepMl = 50;

  static bool isValidCupMl(int ml) =>
      ml >= minCupMl && ml <= maxCupMl && ml % cupStepMl == 0;

  /// 직접 입력한 컵 용량을 10ml 단위로 반올림한다. 범위(10~2,000ml)를 벗어나면 null.
  /// 범위 검사를 먼저 하므로 5ml 같은 값은 0으로 반올림되지 않고 거부된다 (기획서 S5-1).
  static int? normalizeCupMl(int input) {
    if (input < minCupMl || input > maxCupMl) return null;
    final rounded = (input / cupStepMl).round() * cupStepMl;
    return rounded.clamp(minCupMl, maxCupMl);
  }

  /// 기록을 추가했을 때 상한을 넘으면 어떤 상한인지 반환한다. 넘지 않으면 null.
  static LimitKind? exceeded({
    required int totalMl,
    required int logCount,
    required int addMl,
    required int addCount,
  }) {
    if (totalMl + addMl > maxDailyMl) return LimitKind.totalMl;
    if (logCount + addCount > maxDailyCount) return LimitKind.count;
    return null;
  }

  /// 이미 상한에 도달했는지. 하나라도 도달하면 당일 기록 버튼을 비활성화한다.
  static LimitKind? reached({required int totalMl, required int logCount}) {
    if (totalMl >= maxDailyMl) return LimitKind.totalMl;
    if (logCount >= maxDailyCount) return LimitKind.count;
    return null;
  }
}
