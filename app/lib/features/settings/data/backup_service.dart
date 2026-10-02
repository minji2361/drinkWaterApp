import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/decoration_seed.dart';
import '../../../core/database/database_provider.dart';

/// 백업 파일이 올바르지 않거나 이 앱 버전에서 읽을 수 없는 경우.
class BackupFormatException implements Exception {
  const BackupFormatException(this.message);
  final String message;

  @override
  String toString() => 'BackupFormatException: $message';
}

/// 데이터 내보내기 / 가져오기 / 전체 기록 삭제 (기획서 S5).
///
/// 백업 대상은 사용자 데이터 7개 테이블이다. 아이템 마스터(decoration_item)는 앱이 정의하는
/// 데이터라 제외하며, 마스터에 없는 장착·해금 행은 가져올 때 건너뛴다.
class BackupService {
  BackupService(this._db);

  final AppDatabase _db;

  static const String appId = 'drink_water_app';
  static const int formatVersion = 1;

  // ---- 내보내기 -------------------------------------------------------------

  Future<String> exportJson({DateTime? now}) async {
    final data = <String, dynamic>{
      'user_profile': [
        for (final r in await _db.select(_db.userProfile).get()) r.toJson()
      ],
      'intake_log': [
        for (final r in await _db.select(_db.intakeLog).get()) r.toJson()
      ],
      'daily_summary': [
        for (final r in await _db.select(_db.dailySummary).get()) r.toJson()
      ],
      'streak': [
        for (final r in await _db.select(_db.streak).get()) r.toJson()
      ],
      'app_settings': [
        for (final r in await _db.select(_db.appSettings).get()) r.toJson()
      ],
      'user_decoration': [
        for (final r in await _db.select(_db.userDecoration).get()) r.toJson()
      ],
      'user_unlocked_item': [
        for (final r in await _db.select(_db.userUnlockedItem).get())
          r.toJson()
      ],
    };

    return const JsonEncoder.withIndent('  ').convert({
      'app': appId,
      'format': formatVersion,
      'schemaVersion': _db.schemaVersion,
      'exportedAt': (now ?? DateTime.now()).toUtc().toIso8601String(),
      'data': data,
    });
  }

  // ---- 가져오기 -------------------------------------------------------------

  /// 현재 데이터를 모두 백업 내용으로 교체한다. 파일 검증을 마친 뒤 한 트랜잭션으로 처리하며,
  /// 검증에 실패하면 기존 데이터를 건드리지 않는다.
  Future<void> importJson(String json) async {
    final parsed = _parse(json);

    await _db.transaction(() async {
      final masterIds = (await _db.select(_db.decorationItem).get())
          .map((i) => i.id)
          .toSet();

      await _db.delete(_db.userDecoration).go();
      await _db.delete(_db.userUnlockedItem).go();
      await _db.delete(_db.intakeLog).go();
      await _db.delete(_db.dailySummary).go();
      await _db.delete(_db.streak).go();
      await _db.delete(_db.appSettings).go();
      await _db.delete(_db.userProfile).go();

      await _db.into(_db.userProfile).insert(parsed.profile);
      await _db.into(_db.streak).insert(parsed.streak);
      await _db.into(_db.appSettings).insert(parsed.settings);
      await _db.batch((b) {
        b.insertAll(_db.dailySummary, parsed.summaries);
        b.insertAll(_db.intakeLog, parsed.logs);
        b.insertAll(_db.userDecoration,
            parsed.decorations.where((d) => d.itemId == null || masterIds.contains(d.itemId)));
        b.insertAll(_db.userUnlockedItem,
            parsed.unlocked.where((u) => masterIds.contains(u.itemId)));
      });
      // 기본 지급·기본 장착이 빠진 백업도 정상 상태가 되도록 보정한다.
      await seedDecorations(_db);
    });
  }

  _ParsedBackup _parse(String json) {
    try {
      final root = jsonDecode(json);
      if (root is! Map<String, dynamic> || root['app'] != appId) {
        throw const BackupFormatException('이 앱의 백업 파일이 아닙니다.');
      }
      if (root['format'] != formatVersion) {
        throw const BackupFormatException('지원하지 않는 백업 형식입니다.');
      }
      final schema = root['schemaVersion'];
      if (schema is! int || schema > _db.schemaVersion) {
        throw const BackupFormatException('더 새로운 버전의 앱에서 만든 백업입니다.');
      }
      final data = root['data'];
      if (data is! Map<String, dynamic>) {
        throw const BackupFormatException('백업 데이터가 없습니다.');
      }

      List<T> table<T>(String name, T Function(Map<String, dynamic>) from) {
        final list = data[name];
        if (list is! List) throw BackupFormatException('$name 항목이 없습니다.');
        return [for (final e in list) from(e as Map<String, dynamic>)];
      }

      final profiles = table('user_profile', UserProfileRow.fromJson);
      final streaks = table('streak', StreakRow.fromJson);
      // 스키마 v1 백업에는 없는 컬럼은 기본값으로 채운다.
      final settings = table('app_settings', (m) {
        m.putIfAbsent('decorateHintSeen', () => false);
        return AppSettingsRow.fromJson(m);
      });
      if (profiles.length != 1 || streaks.length != 1 || settings.length != 1) {
        throw const BackupFormatException('프로필·설정 데이터가 올바르지 않습니다.');
      }

      return _ParsedBackup(
        profile: profiles.single,
        streak: streaks.single,
        settings: settings.single,
        summaries: table('daily_summary', DailySummaryRow.fromJson),
        logs: table('intake_log', IntakeLogRow.fromJson),
        decorations: table('user_decoration', UserDecorationRow.fromJson),
        unlocked: table('user_unlocked_item', UserUnlockedItemRow.fromJson),
      );
    } on BackupFormatException {
      rethrow;
    } catch (e) {
      // 형식 오류(JSON 문법, 타입 불일치, 알 수 없는 enum 값 등)
      throw BackupFormatException('백업 파일을 읽을 수 없습니다. ($e)');
    }
  }

  // ---- 전체 기록 삭제 -------------------------------------------------------

  /// 물 기록·일별 요약·스트릭을 삭제한다. 프로필, 설정, 꾸미기 상태는 유지한다.
  Future<void> deleteAllRecords() {
    return _db.transaction(() async {
      await _db.delete(_db.intakeLog).go();
      await _db.delete(_db.dailySummary).go();
      await (_db.update(_db.streak)).write(const StreakCompanion(
        currentStreak: Value(0),
        bestStreak: Value(0),
        lastAchievedDate: Value(null),
      ));
    });
  }
}

class _ParsedBackup {
  const _ParsedBackup({
    required this.profile,
    required this.streak,
    required this.settings,
    required this.summaries,
    required this.logs,
    required this.decorations,
    required this.unlocked,
  });

  final UserProfileRow profile;
  final StreakRow streak;
  final AppSettingsRow settings;
  final List<DailySummaryRow> summaries;
  final List<IntakeLogRow> logs;
  final List<UserDecorationRow> decorations;
  final List<UserUnlockedItemRow> unlocked;
}

final backupServiceProvider = Provider<BackupService>(
  (ref) => BackupService(ref.watch(appDatabaseProvider)),
);
