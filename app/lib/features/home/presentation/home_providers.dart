import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/utils/date_utils.dart';
import '../data/intake_repository.dart';

/// 화면이 기준으로 삼는 오늘 날짜(`YYYY-MM-DD`).
/// 앱 시작·포그라운드 복귀·자정 경과 시 [refresh]로 갱신한다 (기획서 5.4).
class CurrentDate extends Notifier<String> {
  @override
  String build() => toLogDate(ref.read(clockProvider)());

  Future<void> refresh() async {
    final now = ref.read(clockProvider)();
    await ref.read(intakeRepositoryProvider).ensureToday(now);
    state = toLogDate(now);
  }
}

final currentDateProvider =
    NotifierProvider<CurrentDate, String>(CurrentDate.new);

final todaySummaryProvider = StreamProvider.autoDispose<DailySummaryRow?>(
  (ref) => ref
      .watch(intakeRepositoryProvider)
      .watchSummary(ref.watch(currentDateProvider)),
);

final streakProvider = StreamProvider.autoDispose<StreakRow>(
  (ref) => ref.watch(intakeRepositoryProvider).watchStreak(),
);

final appSettingsProvider = StreamProvider.autoDispose<AppSettingsRow>(
  (ref) => ref.watch(intakeRepositoryProvider).watchSettings(),
);

final userProfileProvider = StreamProvider.autoDispose<UserProfileRow?>(
  (ref) => ref.watch(intakeRepositoryProvider).watchProfile(),
);
