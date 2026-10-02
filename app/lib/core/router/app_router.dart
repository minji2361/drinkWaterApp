import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/decorate/presentation/decorate_screen.dart';
import '../../features/home/presentation/home_screen.dart';
import '../../features/onboarding/data/onboarding_repository.dart';
import '../../features/onboarding/presentation/onboarding_screen.dart';
import '../../features/settings/presentation/cup_settings_screen.dart';
import '../../features/settings/presentation/settings_screen.dart';
import '../../features/stats/presentation/stats_screen.dart';

class AppRoutes {
  const AppRoutes._();

  static const splash = '/splash';
  static const onboarding = '/onboarding';
  static const home = '/';
  static const stats = '/stats';
  static const decorate = '/decorate';
  static const settings = '/settings';
  static const settingsCup = '/settings/cup';
}

/// 온보딩 완료 여부에 따라 S1 / S2로 분기한다 (기획서 4.2).
/// 완료 플래그가 바뀌면 redirect가 다시 평가되어 화면이 자동 전환된다.
final routerProvider = Provider<GoRouter>((ref) {
  final completed = ValueNotifier<AsyncValue<bool>>(
    ref.read(onboardingCompletedProvider),
  );
  ref.listen(onboardingCompletedProvider, (_, next) => completed.value = next);
  ref.onDispose(completed.dispose);

  return GoRouter(
    initialLocation: AppRoutes.splash,
    refreshListenable: completed,
    redirect: (context, state) {
      final done = completed.value.valueOrNull;
      final loc = state.matchedLocation;
      if (done == null) return loc == AppRoutes.splash ? null : AppRoutes.splash;
      if (!done) return loc == AppRoutes.onboarding ? null : AppRoutes.onboarding;
      return (loc == AppRoutes.onboarding || loc == AppRoutes.splash)
          ? AppRoutes.home
          : null;
    },
    routes: [
      GoRoute(
        path: AppRoutes.splash,
        builder: (_, __) =>
            const Scaffold(body: Center(child: CircularProgressIndicator())),
      ),
      GoRoute(
        path: AppRoutes.onboarding,
        builder: (_, __) => const OnboardingScreen(),
      ),
      GoRoute(
        path: AppRoutes.home,
        builder: (_, __) => const HomeScreen(),
        routes: [
          // S2 위에 push되며 뒤로가기 시 S2로 복귀한다 (기획서 4.2).
          GoRoute(
            path: 'stats',
            builder: (_, __) => const StatsScreen(),
          ),
          GoRoute(
            path: 'decorate',
            builder: (_, __) => const DecorateScreen(),
          ),
          GoRoute(
            path: 'settings',
            builder: (_, __) => const SettingsScreen(),
            routes: [
              GoRoute(
                path: 'cup',
                builder: (_, __) => const CupSettingsScreen(),
              ),
            ],
          ),
        ],
      ),
    ],
  );
});
