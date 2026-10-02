import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/enums.dart';
import '../../../core/utils/date_utils.dart';
import '../data/intake_repository.dart';
import '../domain/intake_rules.dart';
import '../domain/repeat_guard.dart';

/// 기록 시도의 결과. 화면은 이 결과에 따라 연출·안내를 표시한다.
sealed class RecordOutcome {
  const RecordOutcome();
}

class Recorded extends RecordOutcome {
  const Recorded(this.result);
  final IntakeResult result;
}

/// 쿨다운(1.2초) 중 탭. 기록하지 않고 shake 피드백만 준다 (기획서 5.6.1).
class RecordCooldown extends RecordOutcome {
  const RecordCooldown();
}

/// 60초 내 3회 기록 후 4회째 시도 (기획서 5.6.2).
class RecordNeedsConfirm extends RecordOutcome {
  const RecordNeedsConfirm({required this.count, required this.totalMl});
  final int count;
  final int totalMl;
}

class RecordLimitReached extends RecordOutcome {
  const RecordLimitReached(this.kind);
  final LimitKind kind;
}

class RecordFailed extends RecordOutcome {
  const RecordFailed();
}

class HomeUiState {
  const HomeUiState({this.cooling = false});

  /// 기록 직후 1.2초간 버튼을 비활성 상태로 보이게 한다.
  final bool cooling;
}

class HomeController extends Notifier<HomeUiState> {
  static const Duration cooldown = Duration(milliseconds: 1200);

  final RepeatGuard _guard = RepeatGuard();
  Timer? _timer;

  IntakeRepository get _repo => ref.read(intakeRepositoryProvider);
  DateTime _now() => ref.read(clockProvider)();

  @override
  HomeUiState build() {
    ref.onDispose(() => _timer?.cancel());
    return const HomeUiState();
  }

  /// 물 마시기 버튼 짧게 탭 → 기본 컵 용량 즉시 기록.
  /// [confirmed]는 반복 기록 확인 시트에서 "네, 1잔 더 기록"을 누른 경우.
  Future<RecordOutcome> quickRecord({bool confirmed = false}) async {
    if (state.cooling) return const RecordCooldown();
    final now = _now();
    if (!confirmed && _guard.needsConfirm(now)) {
      return RecordNeedsConfirm(
        count: _guard.recentCount(now),
        totalMl: _guard.recentMl(now),
      );
    }
    if (confirmed) _guard.reset();

    final settings = await _repo.getSettings();
    final cup = settings.defaultCupType;
    return _record(
      amountMl: settings.cupMl(cup),
      count: 1,
      source: IntakeSource.quick,
      cup: cup,
      now: now,
      trackGuard: true,
    );
  }

  /// 기록 시트에서의 기록. 묶음 기록은 반복 카운터에 포함하지 않는다.
  Future<RecordOutcome> sheetRecord({
    required CupType cup,
    required int amountMl,
    required int count,
  }) async {
    if (state.cooling) return const RecordCooldown();
    return _record(
      amountMl: amountMl,
      count: count,
      source: IntakeSource.custom,
      cup: cup,
      now: _now(),
      trackGuard: false,
    );
  }

  Future<RecordOutcome> _record({
    required int amountMl,
    required int count,
    required IntakeSource source,
    required CupType cup,
    required DateTime now,
    required bool trackGuard,
  }) async {
    // await 전에 잠가서 연속 탭이 중복 기록되는 경합을 막는다. 큐잉하지 않는다.
    _startCooldown();
    try {
      final result = await _repo.addIntake(
        amountMl: amountMl,
        count: count,
        source: source,
        cupType: cup,
        now: now,
      );
      if (trackGuard) {
        _guard.record(now, id: result.ids.first, amountMl: amountMl);
      }
      return Recorded(result);
    } on IntakeBlocked catch (e) {
      _endCooldown();
      return RecordLimitReached(e.kind);
    } catch (_) {
      _endCooldown();
      return const RecordFailed();
    }
  }

  Future<void> undo(List<int> ids) async {
    await _repo.undo(ids);
    _guard.remove(ids);
  }

  Future<void> selectCup(CupType type) => _repo.setDefaultCup(type);

  Future<void> updateCupMl(CupType type, int ml) => _repo.setCupMl(type, ml);

  void _startCooldown() {
    _timer?.cancel();
    state = const HomeUiState(cooling: true);
    _timer = Timer(cooldown, _endCooldown);
  }

  void _endCooldown() {
    _timer?.cancel();
    state = const HomeUiState();
  }
}

final homeControllerProvider =
    NotifierProvider<HomeController, HomeUiState>(HomeController.new);
