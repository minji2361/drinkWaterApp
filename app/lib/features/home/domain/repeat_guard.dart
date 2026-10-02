/// 60초 내 반복 기록 확인 (기획서 5.6.2). 메모리 상태로만 관리한다.
///
/// 최근 60초 내 [threshold]회 기록 후 다음 시도에서 확인을 요구한다.
/// 묶음 기록과 되돌린 기록은 카운트하지 않는다.
class RepeatGuard {
  static const Duration window = Duration(seconds: 60);
  static const int threshold = 3;

  final List<_Entry> _entries = [];

  void _prune(DateTime now) =>
      _entries.removeWhere((e) => now.difference(e.at) >= window);

  bool needsConfirm(DateTime now) {
    _prune(now);
    return _entries.length >= threshold;
  }

  int recentCount(DateTime now) {
    _prune(now);
    return _entries.length;
  }

  int recentMl(DateTime now) {
    _prune(now);
    return _entries.fold(0, (sum, e) => sum + e.amountMl);
  }

  void record(DateTime now, {required int id, required int amountMl}) {
    _prune(now);
    _entries.add(_Entry(now, id, amountMl));
  }

  /// 되돌리기로 취소된 기록은 카운터에서 제외한다.
  void remove(Iterable<int> ids) =>
      _entries.removeWhere((e) => ids.contains(e.id));

  /// 확인을 거친 뒤 카운터를 초기화한다.
  void reset() => _entries.clear();
}

class _Entry {
  _Entry(this.at, this.id, this.amountMl);
  final DateTime at;
  final int id;
  final int amountMl;
}
