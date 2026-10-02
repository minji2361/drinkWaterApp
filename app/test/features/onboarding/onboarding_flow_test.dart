import 'package:drift/native.dart';
import 'package:drink_water_app/core/database/app_database.dart';
import 'package:drink_water_app/core/database/database_provider.dart';
import 'package:drink_water_app/features/onboarding/presentation/onboarding_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late ProviderContainer container;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    container = ProviderContainer(
      overrides: [appDatabaseProvider.overrideWithValue(db)],
    );
    // autoDispose 상태가 테스트 중 사라지지 않도록 구독을 유지한다.
    container.listen(onboardingControllerProvider, (_, __) {});
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  OnboardingController ctl() =>
      container.read(onboardingControllerProvider.notifier);
  OnboardingState state() => container.read(onboardingControllerProvider);

  Future<void> fillToGoalStep() async {
    ctl().setNickname('물방울');
    await ctl().next();
    ctl().setGender(Gender.female);
    ctl().setAge('28');
    ctl().setWeight('55');
    await ctl().next();
  }

  test('필수값을 채우기 전에는 다음으로 진행할 수 없다', () async {
    expect(state().canProceed, isFalse);
    await ctl().next();
    expect(state().step, 1);

    ctl().setNickname('물방울');
    await ctl().next();
    expect(state().step, 2);

    ctl().setGender(Gender.female);
    ctl().setAge('13');
    ctl().setWeight('55');
    expect(state().canProceed, isFalse);
    ctl().setAge('28');
    expect(state().canProceed, isTrue);
  });

  test('여성/28세/55kg 입력 시 목표량이 1,700ml로 제시된다', () async {
    await fillToGoalStep();
    expect(state().step, 3);
    expect(state().goalMl, 1700);
    expect(state().isGoalCustom, isFalse);
  });

  test('목표량 4,001ml는 거부되고 값이 바뀌지 않는다', () async {
    await fillToGoalStep();
    expect(ctl().setGoal(4001), isFalse);
    expect(state().goalMl, 1700);
  });

  test('−/+ 버튼은 허용 범위 경계에서 고정된다', () async {
    await fillToGoalStep();
    ctl().setGoal(3980);
    ctl().adjustGoal(50);
    expect(state().goalMl, 4000);
    ctl().setGoal(520);
    ctl().adjustGoal(-50);
    expect(state().goalMl, 500);
  });

  test('수정하지 않았다면 프로필 변경 시 권장량을 재계산하고, 수정했다면 유지한다', () async {
    await fillToGoalStep();
    ctl().back();
    ctl().setWeight('78');
    await ctl().next();
    expect(state().recommendedMl, 2450);
    expect(state().goalMl, 2450);
    expect(state().isGoalCustom, isFalse);

    ctl().setGoal(2000);
    expect(state().isGoalCustom, isTrue);
    ctl().back();
    ctl().setWeight('50');
    await ctl().next();
    expect(state().goalMl, 2000);
  });

  test('완료 시 프로필이 저장되고 온보딩 완료 플래그가 켜진다', () async {
    await fillToGoalStep();
    ctl().setGoal(1800);
    await ctl().next();

    final profile = await db.select(db.userProfile).getSingle();
    expect(profile.nickname, '물방울');
    expect(profile.gender, Gender.female);
    expect(profile.birthYear, DateTime.now().year - 28);
    expect(profile.heightCm, isNull);
    expect(profile.weightKg, 55);
    expect(profile.dailyGoalMl, 1800);
    expect(profile.isGoalCustom, isTrue);

    final settings = await db.select(db.appSettings).getSingle();
    expect(settings.onboardingCompleted, isTrue);
  });
}
