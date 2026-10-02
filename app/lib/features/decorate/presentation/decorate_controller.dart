import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../data/decoration_repository.dart';
import '../domain/decoration_rules.dart';

class DecorateState {
  const DecorateState({
    this.category = DecorationRules.defaultTab,
    this.undo = const UndoStack.empty(),
  });

  final DecorationCategory category;
  final UndoStack undo;

  bool get canUndo => !undo.isEmpty;

  DecorateState copyWith({DecorationCategory? category, UndoStack? undo}) =>
      DecorateState(
        category: category ?? this.category,
        undo: undo ?? this.undo,
      );
}

/// 꾸미기 화면 상태. 되돌리기 스택은 화면에 머무는 동안만 유지하고 이탈 시 폐기한다
/// (autoDispose). 재진입 시 이전 스택을 복원하지 않는다 (기획서 S3).
class DecorateController extends Notifier<DecorateState> {
  DecorationRepository get _repo => ref.read(decorationRepositoryProvider);

  @override
  DecorateState build() => const DecorateState();

  void selectCategory(DecorationCategory c) =>
      state = state.copyWith(category: c);

  /// 아이템 탭 → 즉시 저장 + 되돌리기 스택 push.
  /// 저장에 실패하면 예외를 던지고 스택에는 쌓지 않는다 (화면은 DB 스트림을 따르므로 자동 롤백).
  Future<void> equip(DecorationCategory category, String? itemId) async {
    final previous = await _repo.equip(category, itemId);
    if (previous == itemId) return; // 이미 같은 상태: 변경 없음
    state = state.copyWith(
      undo: state.undo.push(UndoEntry(category, previous)),
    );
  }

  /// 마지막 변경 1건을 복원하고 해당 카테고리 탭으로 전환한다.
  /// 복원할 아이템이 더 이상 유효하지 않으면 그 항목은 건너뛴다.
  Future<void> undo() async {
    var stack = state.undo;
    while (true) {
      final popped = stack.pop();
      if (popped == null) {
        state = state.copyWith(undo: stack);
        return;
      }
      final (entry, rest) = popped;
      stack = rest;
      try {
        await _repo.equip(entry.category, entry.previousItemId);
        state = state.copyWith(category: entry.category, undo: stack);
        return;
      } on DecorationRejected {
        continue;
      }
    }
  }
}

final decorateControllerProvider =
    NotifierProvider.autoDispose<DecorateController, DecorateState>(
  DecorateController.new,
);
