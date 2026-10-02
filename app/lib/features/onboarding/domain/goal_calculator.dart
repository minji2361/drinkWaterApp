import '../../../core/database/enums.dart';

/// 일일 목표 음수량 산정 (기획서 5.1). 의학적 조언이 아닌 일반 참고 기준이다.
class GoalCalculator {
  const GoalCalculator._();

  static const int minRecommendedMl = 1000;
  static const int maxRecommendedMl = 3500;

  /// 직접 입력 허용 범위 (기획서 5.1, S1).
  static const int minGoalMl = 500;
  static const int maxGoalMl = 4000;
  static const int goalStepMl = 10;

  /// 스텝 3의 −/+ 버튼 증감 단위.
  static const int adjustStepMl = 50;

  static double _genderFactor(Gender gender) => switch (gender) {
        Gender.male => 1.00,
        Gender.female => 0.95,
        Gender.unspecified => 0.97,
      };

  static double _ageFactor(int age) {
    if (age <= 30) return 1.00;
    if (age <= 55) return 0.95;
    return 0.90;
  }

  /// 권장량(ml). 50ml 단위 반올림 후 1,000 ~ 3,500ml로 제한한다.
  static int recommendedMl({
    required int weightKg,
    required Gender gender,
    required int age,
  }) {
    final raw = weightKg * 33 * _genderFactor(gender) * _ageFactor(age);
    final rounded = (raw / 50).round() * 50;
    return rounded.clamp(minRecommendedMl, maxRecommendedMl);
  }

  static bool isValidGoal(int ml) =>
      ml >= minGoalMl && ml <= maxGoalMl && ml % goalStepMl == 0;
}
