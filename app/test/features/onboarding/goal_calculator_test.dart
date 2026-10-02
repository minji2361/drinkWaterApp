import 'package:drink_water_app/core/database/enums.dart';
import 'package:drink_water_app/features/onboarding/domain/goal_calculator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('GoalCalculator.recommendedMl (기획서 5.1 계산 예시)', () {
    test('여성 / 28세 / 55kg → 1,700ml', () {
      expect(
        GoalCalculator.recommendedMl(
            weightKg: 55, gender: Gender.female, age: 28),
        1700,
      );
    });

    test('남성 / 35세 / 78kg → 2,450ml', () {
      expect(
        GoalCalculator.recommendedMl(
            weightKg: 78, gender: Gender.male, age: 35),
        2450,
      );
    });

    test('여성 / 60세 / 48kg → 1,350ml', () {
      expect(
        GoalCalculator.recommendedMl(
            weightKg: 48, gender: Gender.female, age: 60),
        1350,
      );
    });

    test('연령 경계: 30세는 1.00, 31세는 0.95, 56세는 0.90', () {
      int rec(int age) => GoalCalculator.recommendedMl(
          weightKg: 100, gender: Gender.male, age: age);
      expect(rec(30), 3300);
      expect(rec(31), 3150);
      expect(rec(55), 3150);
      expect(rec(56), 2950);
    });

    test('1,000 ~ 3,500ml 범위로 제한한다', () {
      expect(
        GoalCalculator.recommendedMl(
            weightKg: 30, gender: Gender.female, age: 60),
        1000,
      );
      expect(
        GoalCalculator.recommendedMl(
            weightKg: 200, gender: Gender.male, age: 20),
        3500,
      );
    });
  });

  group('GoalCalculator.isValidGoal', () {
    test('500~4,000ml, 10ml 단위만 허용', () {
      expect(GoalCalculator.isValidGoal(500), isTrue);
      expect(GoalCalculator.isValidGoal(4000), isTrue);
      expect(GoalCalculator.isValidGoal(4001), isFalse);
      expect(GoalCalculator.isValidGoal(490), isFalse);
      expect(GoalCalculator.isValidGoal(1705), isFalse);
    });
  });
}
