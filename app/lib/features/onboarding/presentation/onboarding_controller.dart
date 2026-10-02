import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/enums.dart';
import '../data/onboarding_repository.dart';
import '../domain/goal_calculator.dart';
import '../domain/onboarding_validators.dart';

class OnboardingState {
  const OnboardingState({
    this.step = 1,
    this.nickname = '',
    this.gender,
    this.ageText = '',
    this.heightText = '',
    this.weightText = '',
    this.recommendedMl,
    this.goalMl,
    this.saving = false,
  });

  static const int totalSteps = 3;

  final int step;
  final String nickname;
  final Gender? gender;
  final String ageText;
  final String heightText;
  final String weightText;
  final int? recommendedMl;
  final int? goalMl;
  final bool saving;

  int? get age => int.tryParse(ageText);
  int? get weightKg => int.tryParse(weightText);
  int? get heightCm => heightText.isEmpty ? null : int.tryParse(heightText);

  bool get nicknameValid => OnboardingValidators.isValidNickname(nickname);
  bool get ageValid => OnboardingValidators.isValidAge(age);
  bool get weightValid => OnboardingValidators.isValidWeight(weightKg);

  /// 키는 비어 있으면 유효, 값이 있으면 숫자이면서 범위 안이어야 한다.
  bool get heightValid =>
      heightText.isEmpty ||
      (heightCm != null &&
          OnboardingValidators.isValidOptionalHeight(heightCm));

  bool get step1Valid => nicknameValid;
  bool get step2Valid =>
      gender != null && ageValid && weightValid && heightValid;
  bool get step3Valid => goalMl != null && GoalCalculator.isValidGoal(goalMl!);

  bool get canProceed => switch (step) {
        1 => step1Valid,
        2 => step2Valid,
        _ => step3Valid && !saving,
      };

  bool get isGoalCustom =>
      goalMl != null && recommendedMl != null && goalMl != recommendedMl;

  OnboardingState copyWith({
    int? step,
    String? nickname,
    Gender? gender,
    String? ageText,
    String? heightText,
    String? weightText,
    int? recommendedMl,
    int? goalMl,
    bool? saving,
  }) =>
      OnboardingState(
        step: step ?? this.step,
        nickname: nickname ?? this.nickname,
        gender: gender ?? this.gender,
        ageText: ageText ?? this.ageText,
        heightText: heightText ?? this.heightText,
        weightText: weightText ?? this.weightText,
        recommendedMl: recommendedMl ?? this.recommendedMl,
        goalMl: goalMl ?? this.goalMl,
        saving: saving ?? this.saving,
      );
}

class OnboardingController extends Notifier<OnboardingState> {
  @override
  OnboardingState build() => const OnboardingState();

  void setNickname(String v) => state = state.copyWith(nickname: v);
  void setGender(Gender v) => state = state.copyWith(gender: v);
  void setAge(String v) => state = state.copyWith(ageText: v);
  void setHeight(String v) => state = state.copyWith(heightText: v);
  void setWeight(String v) => state = state.copyWith(weightText: v);

  /// 스텝 3의 −/+ 버튼. 허용 범위를 벗어나면 경계값으로 고정한다.
  void adjustGoal(int deltaMl) {
    final current = state.goalMl;
    if (current == null) return;
    setGoal((current + deltaMl)
        .clamp(GoalCalculator.minGoalMl, GoalCalculator.maxGoalMl));
  }

  /// 직접 입력. 유효하지 않으면 false를 반환하고 상태를 바꾸지 않는다.
  bool setGoal(int ml) {
    if (!GoalCalculator.isValidGoal(ml)) return false;
    state = state.copyWith(goalMl: ml);
    return true;
  }

  void back() {
    if (state.step > 1) state = state.copyWith(step: state.step - 1);
  }

  /// 다음 스텝으로 이동. 스텝 3에서는 저장 후 완료(라우터가 홈으로 전환한다).
  Future<void> next() async {
    if (!state.canProceed) return;
    if (state.step < OnboardingState.totalSteps) {
      final nextStep = state.step + 1;
      state = nextStep == 3 ? _enterGoalStep(nextStep) : state.copyWith(step: nextStep);
      return;
    }
    state = state.copyWith(saving: true);
    try {
      await ref.read(onboardingRepositoryProvider).complete(
            OnboardingProfile(
              nickname: state.nickname.trim(),
              gender: state.gender!,
              birthYear: DateTime.now().year - state.age!,
              heightCm: state.heightCm,
              weightKg: state.weightKg!,
              dailyGoalMl: state.goalMl!,
              isGoalCustom: state.isGoalCustom,
            ),
          );
    } catch (_) {
      state = state.copyWith(saving: false);
      rethrow;
    }
  }

  /// 스텝 3 진입 시 권장량을 계산한다. 사용자가 직접 수정한 값이 있으면 유지하고,
  /// 수정하지 않았다면 프로필 변경을 반영해 재계산한다 (기획서 5.1).
  OnboardingState _enterGoalStep(int step) {
    final recommended = GoalCalculator.recommendedMl(
      weightKg: state.weightKg!,
      gender: state.gender!,
      age: state.age!,
    );
    final untouched = state.goalMl == null || !state.isGoalCustom;
    return state.copyWith(
      step: step,
      recommendedMl: recommended,
      goalMl: untouched ? recommended : state.goalMl,
    );
  }
}

final onboardingControllerProvider =
    NotifierProvider.autoDispose<OnboardingController, OnboardingState>(
  OnboardingController.new,
);
