/// 온보딩 입력값 유효성 (기획서 6장 S1). 모두 순수 함수.
class OnboardingValidators {
  const OnboardingValidators._();

  static const int nicknameMaxLength = 10;
  static const int minAge = 14;
  static const int maxAge = 100;
  static const int minHeightCm = 100;
  static const int maxHeightCm = 250;
  static const int minWeightKg = 30;
  static const int maxWeightKg = 200;

  /// 1~10자, 공백만 입력 불가, 이모지 허용.
  /// DB의 length() 검사와 맞추기 위해 코드포인트(runes) 기준으로 센다.
  static bool isValidNickname(String input) {
    final trimmed = input.trim();
    return trimmed.isNotEmpty && trimmed.runes.length <= nicknameMaxLength;
  }

  static bool isValidAge(int? age) =>
      age != null && age >= minAge && age <= maxAge;

  static bool isValidWeight(int? kg) =>
      kg != null && kg >= minWeightKg && kg <= maxWeightKg;

  /// 키는 선택 입력. 비어 있으면(null) 유효.
  static bool isValidOptionalHeight(int? cm) =>
      cm == null || (cm >= minHeightCm && cm <= maxHeightCm);
}
