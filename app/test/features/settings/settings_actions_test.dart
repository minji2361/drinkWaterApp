import 'dart:convert';

import 'package:drift/native.dart';
import 'package:drink_water_app/core/database/app_database.dart';
import 'package:drink_water_app/core/database/database_provider.dart';
import 'package:drink_water_app/core/utils/date_utils.dart';
import 'package:drink_water_app/features/home/data/intake_repository.dart';
import 'package:drink_water_app/features/settings/data/backup_file_gateway.dart';
import 'package:drink_water_app/features/settings/data/backup_service.dart';
import 'package:drink_water_app/features/settings/data/reminder_scheduler.dart';
import 'package:drink_water_app/features/settings/presentation/settings_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeGateway implements BackupFileGateway {
  String? sharedJson;
  String? sharedName;
  String? toPick;

  @override
  Future<void> shareJson(String json, String fileName) async {
    sharedJson = json;
    sharedName = fileName;
  }

  @override
  Future<String?> pickJson() async => toPick;
}

class _GrantingScheduler implements ReminderScheduler {
  bool enabled = false;
  int rescheduled = 0;

  @override
  Future<ReminderPermission> enable() async {
    enabled = true;
    return ReminderPermission.granted;
  }

  @override
  Future<void> disable() async => enabled = false;

  @override
  Future<void> reschedule(AppSettingsRow settings) async => rescheduled++;
}

void main() {
  final now = DateTime(2026, 10, 2, 9);
  late AppDatabase db;
  late ProviderContainer container;
  late _FakeGateway gateway;

  SettingsActions actions() => container.read(settingsActionsProvider);

  Future<UserProfileRow> profile() => db.select(db.userProfile).getSingle();

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    gateway = _FakeGateway();
    container = ProviderContainer(overrides: [
      appDatabaseProvider.overrideWithValue(db),
      clockProvider.overrideWithValue(() => now),
      backupFileGatewayProvider.overrideWithValue(gateway),
    ]);
    // 여성 / 28세 / 55kg → 권장 1,700ml
    await db.into(db.userProfile).insert(UserProfileCompanion.insert(
          nickname: '물방울',
          gender: Gender.female,
          birthYear: 1998,
          weightKg: 55,
          dailyGoalMl: 1700,
        ));
    await IntakeRepository(db).ensureToday(now);
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  ProfileInput input({String? nickname, Gender? gender, int age = 28, int? height, int weight = 55}) =>
      ProfileInput(
        nickname: nickname ?? '물방울',
        gender: gender ?? Gender.female,
        age: age,
        heightCm: height,
        weightKg: weight,
      );

  group('프로필 수정과 목표 재계산 (기획서 S5)', () {
    test('별명·키만 바꾸면 목표는 그대로다', () async {
      final r = await actions().saveProfile(input(nickname: '새싹', height: 165));
      expect(r.autoGoalMl, isNull);
      expect(r.askRecalcMl, isNull);
      final p = await profile();
      expect(p.nickname, '새싹');
      expect(p.heightCm, 165);
      expect(p.dailyGoalMl, 1700);
    });

    test('직접 수정하지 않은 목표는 체중 변경 시 자동 재계산된다', () async {
      final r = await actions().saveProfile(input(weight: 60));
      // 60×33×0.95 = 1881 → 1,900
      expect(r.autoGoalMl, 1900);
      final p = await profile();
      expect(p.dailyGoalMl, 1900);
      expect(p.isGoalCustom, isFalse);
      // 오늘 요약의 목표도 같이 바뀐다
      final s = await (db.select(db.dailySummary)
            ..where((t) => t.logDate.equals(toLogDate(now))))
          .getSingle();
      expect(s.goalMl, 1900);
    });

    test('직접 수정한 목표는 확인이 필요하고 값은 바뀌지 않는다', () async {
      await actions().setGoalManually(2200);
      expect((await profile()).isGoalCustom, isTrue);

      final r = await actions().saveProfile(input(weight: 60));
      expect(r.autoGoalMl, isNull);
      expect(r.askRecalcMl, 1900);
      expect((await profile()).dailyGoalMl, 2200);

      // 확인하면 적용되고 직접 수정 상태가 풀린다
      await actions().applyGoal(1900, custom: false);
      expect((await profile()).isGoalCustom, isFalse);
    });

    test('나이를 바꾸면 출생연도가 갱신된다', () async {
      await actions().saveProfile(input(age: 35));
      expect((await profile()).birthYear, 2026 - 35);
    });

    test('키를 비우면 null로 저장된다', () async {
      await actions().saveProfile(input(height: 170));
      await actions().saveProfile(input(height: null));
      expect((await profile()).heightCm, isNull);
    });
  });

  group('목표량', () {
    test('권장량과 같은 값을 직접 입력하면 직접 수정으로 보지 않는다', () async {
      await actions().setGoalManually(1700);
      expect((await profile()).isGoalCustom, isFalse);
      await actions().setGoalManually(2000);
      expect((await profile()).isGoalCustom, isTrue);
    });

    test('범위를 벗어난 목표는 저장되지 않는다', () async {
      expect(() => actions().applyGoal(4010, custom: true),
          throwsA(isA<ArgumentError>()));
      expect(() => actions().applyGoal(1705, custom: true),
          throwsA(isA<ArgumentError>()));
      expect((await profile()).dailyGoalMl, 1700);
    });

    test('권장량 재계산은 권장값으로 되돌리고 custom을 해제한다', () async {
      await actions().setGoalManually(3000);
      final rec = await actions().recalculateGoal();
      expect(rec, 1700);
      final p = await profile();
      expect(p.dailyGoalMl, 1700);
      expect(p.isGoalCustom, isFalse);
    });
  });

  group('알림 설정', () {
    test('스케줄러가 없으면 켜지지 않는다 (기본 구현)', () async {
      final r = await actions().setReminderEnabled(true);
      expect(r, ReminderToggleResult.unavailable);
      final s = await db.select(db.appSettings).getSingle();
      expect(s.reminderEnabled, isFalse);
    });

    test('권한이 허용되면 저장하고 재예약한다. 시간대·간격 변경도 재예약', () async {
      final scheduler = _GrantingScheduler();
      final c = ProviderContainer(overrides: [
        appDatabaseProvider.overrideWithValue(db),
        clockProvider.overrideWithValue(() => now),
        reminderSchedulerProvider.overrideWithValue(scheduler),
      ]);
      addTearDown(c.dispose);
      final a = c.read(settingsActionsProvider);

      expect(await a.setReminderEnabled(true), ReminderToggleResult.enabled);
      expect(scheduler.rescheduled, 1);

      await a.setReminderRange('09:00', '21:00');
      await a.setReminderInterval(180);
      expect(scheduler.rescheduled, 3);
      final s = await db.select(db.appSettings).getSingle();
      expect(s.reminderEnabled, isTrue);
      expect(s.reminderStart, '09:00');
      expect(s.reminderEnd, '21:00');
      expect(s.reminderIntervalMin, 180);

      expect(await a.setReminderEnabled(false), ReminderToggleResult.disabled);
      expect(scheduler.enabled, isFalse);
      expect((await db.select(db.appSettings).getSingle()).reminderEnabled,
          isFalse);
    });
  });

  group('데이터 내보내기 / 가져오기 / 삭제', () {
    Future<void> seedRecords() async {
      final repo = IntakeRepository(db);
      await repo.setDefaultCup(CupType.mug);
      await repo.setCupMl(CupType.mug, 350);
      await repo.addIntake(
          amountMl: 350,
          source: IntakeSource.quick,
          cupType: CupType.mug,
          now: now);
      await repo.addIntake(
          amountMl: 350,
          count: 4,
          source: IntakeSource.custom,
          cupType: CupType.mug,
          now: now.add(const Duration(minutes: 5)));
    }

    test('내보낸 파일을 다른 DB에 가져오면 기록이 동일하게 복구된다', () async {
      await seedRecords();
      await actions().exportData();
      expect(gateway.sharedName, 'drink_water_backup_2026-10-02.json');
      final json = gateway.sharedJson!;
      expect(jsonDecode(json)['app'], 'drink_water_app');

      final db2 = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db2.close);
      await BackupService(db2).importJson(json);

      final logs1 = await db.select(db.intakeLog).get();
      final logs2 = await db2.select(db2.intakeLog).get();
      expect(logs2.map((l) => l.toJson()), logs1.map((l) => l.toJson()));

      expect((await db2.select(db2.userProfile).getSingle()).toJson(),
          (await profile()).toJson());
      expect((await db2.select(db2.dailySummary).get()).map((r) => r.toJson()),
          (await db.select(db.dailySummary).get()).map((r) => r.toJson()));
      expect((await db2.select(db2.streak).getSingle()).toJson(),
          (await db.select(db.streak).getSingle()).toJson());

      final settings = await db2.select(db2.appSettings).getSingle();
      expect(settings.defaultCupType, CupType.mug);
      expect(settings.cupMugMl, 350);
    });

    test('가져오기는 기존 데이터를 백업 내용으로 교체한다', () async {
      await seedRecords();
      final json = await BackupService(db).exportJson(now: now);

      // 백업 이후에 더 기록하고, 가져오면 백업 시점으로 돌아간다
      await IntakeRepository(db).addIntake(
          amountMl: 200,
          source: IntakeSource.quick,
          cupType: CupType.paper,
          now: now.add(const Duration(hours: 1)));
      gateway.toPick = json;
      expect(await actions().importData(), isTrue);

      final logs = await db.select(db.intakeLog).get();
      expect(logs, hasLength(5));
      expect(logs.fold<int>(0, (s, l) => s + l.amountMl), 1750);
    });

    test('파일 선택을 취소하면 아무것도 바꾸지 않는다', () async {
      await seedRecords();
      gateway.toPick = null;
      expect(await actions().importData(), isFalse);
      expect(await db.select(db.intakeLog).get(), hasLength(5));
    });

    test('잘못된 백업 파일은 거부하고 기존 데이터를 건드리지 않는다', () async {
      await seedRecords();
      final service = BackupService(db);

      for (final bad in [
        'not json',
        '[]',
        jsonEncode({'app': 'other', 'format': 1}),
        jsonEncode({'app': 'drink_water_app', 'format': 99}),
        jsonEncode({
          'app': 'drink_water_app',
          'format': 1,
          'schemaVersion': 999,
          'data': {}
        }),
        jsonEncode({
          'app': 'drink_water_app',
          'format': 1,
          'schemaVersion': 1,
          'data': {'user_profile': []}
        }),
      ]) {
        await expectLater(
            service.importJson(bad), throwsA(isA<BackupFormatException>()),
            reason: bad);
      }
      expect(await db.select(db.intakeLog).get(), hasLength(5));
      expect((await profile()).nickname, '물방울');
    });

    test('전체 기록 삭제는 기록·요약·스트릭만 지우고 프로필·설정은 유지한다', () async {
      await seedRecords();
      await IntakeRepository(db).addIntake(
          amountMl: 400,
          source: IntakeSource.quick,
          cupType: CupType.paper,
          now: now.add(const Duration(hours: 2)));
      expect((await db.select(db.streak).getSingle()).currentStreak, 1);

      await actions().deleteAllRecords();

      expect(await db.select(db.intakeLog).get(), isEmpty);
      final streak = await db.select(db.streak).getSingle();
      expect(streak.currentStreak, 0);
      expect(streak.bestStreak, 0);
      expect(streak.lastAchievedDate, isNull);
      expect((await profile()).nickname, '물방울');
      expect((await db.select(db.appSettings).getSingle()).defaultCupType,
          CupType.mug);

      // 삭제 직후 오늘 요약이 0으로 다시 만들어진다
      final today = await (db.select(db.dailySummary)
            ..where((t) => t.logDate.equals(toLogDate(now))))
          .getSingle();
      expect(today.totalMl, 0);
    });
  });
}
