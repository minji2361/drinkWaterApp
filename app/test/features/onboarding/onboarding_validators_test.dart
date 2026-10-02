import 'package:drink_water_app/features/onboarding/domain/onboarding_validators.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('별명: 1~10자, 공백만 불가, 이모지 허용', () {
    expect(OnboardingValidators.isValidNickname(''), isFalse);
    expect(OnboardingValidators.isValidNickname('   '), isFalse);
    expect(OnboardingValidators.isValidNickname('물방울'), isTrue);
    expect(OnboardingValidators.isValidNickname('1234567890'), isTrue);
    expect(OnboardingValidators.isValidNickname('12345678901'), isFalse);
    expect(OnboardingValidators.isValidNickname('물💧'), isTrue);
  });

  test('나이: 14~100', () {
    expect(OnboardingValidators.isValidAge(13), isFalse);
    expect(OnboardingValidators.isValidAge(14), isTrue);
    expect(OnboardingValidators.isValidAge(100), isTrue);
    expect(OnboardingValidators.isValidAge(101), isFalse);
    expect(OnboardingValidators.isValidAge(null), isFalse);
  });

  test('몸무게: 30~200', () {
    expect(OnboardingValidators.isValidWeight(29), isFalse);
    expect(OnboardingValidators.isValidWeight(30), isTrue);
    expect(OnboardingValidators.isValidWeight(200), isTrue);
    expect(OnboardingValidators.isValidWeight(201), isFalse);
  });

  test('키: 선택 입력, 값이 있으면 100~250', () {
    expect(OnboardingValidators.isValidOptionalHeight(null), isTrue);
    expect(OnboardingValidators.isValidOptionalHeight(99), isFalse);
    expect(OnboardingValidators.isValidOptionalHeight(100), isTrue);
    expect(OnboardingValidators.isValidOptionalHeight(250), isTrue);
    expect(OnboardingValidators.isValidOptionalHeight(251), isFalse);
  });
}
