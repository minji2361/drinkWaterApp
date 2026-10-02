import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/database_provider.dart';

class OnboardingProfile {
  const OnboardingProfile({
    required this.nickname,
    required this.gender,
    required this.birthYear,
    this.heightCm,
    required this.weightKg,
    required this.dailyGoalMl,
    required this.isGoalCustom,
  });

  final String nickname;
  final Gender gender;
  final int birthYear;
  final int? heightCm;
  final int weightKg;
  final int dailyGoalMl;
  final bool isGoalCustom;
}

class OnboardingRepository {
  OnboardingRepository(this._db);

  final AppDatabase _db;

  /// 온보딩 완료 여부. 값이 바뀌면 새로 방출된다.
  Stream<bool> watchCompleted() => _db
      .select(_db.appSettings)
      .watchSingle()
      .map((s) => s.onboardingCompleted);

  /// 프로필 저장과 완료 플래그를 한 트랜잭션으로 처리한다.
  Future<void> complete(OnboardingProfile p) {
    return _db.transaction(() async {
      await _db.into(_db.userProfile).insertOnConflictUpdate(
            UserProfileCompanion.insert(
              nickname: p.nickname,
              gender: p.gender,
              birthYear: p.birthYear,
              heightCm: Value(p.heightCm),
              weightKg: p.weightKg,
              dailyGoalMl: p.dailyGoalMl,
              isGoalCustom: Value(p.isGoalCustom),
            ),
          );
      await (_db.update(_db.appSettings))
          .write(const AppSettingsCompanion(onboardingCompleted: Value(true)));
    });
  }
}

final onboardingRepositoryProvider = Provider<OnboardingRepository>(
  (ref) => OnboardingRepository(ref.watch(appDatabaseProvider)),
);

final onboardingCompletedProvider = StreamProvider<bool>(
  (ref) => ref.watch(onboardingRepositoryProvider).watchCompleted(),
);
