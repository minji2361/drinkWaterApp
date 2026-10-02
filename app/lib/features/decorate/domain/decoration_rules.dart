import '../../../core/database/enums.dart';

/// 꾸미기 규칙 (기획서 6장 S3). 모두 순수 상수·함수.
class DecorationRules {
  const DecorationRules._();

  /// 되돌리기 스택 최대 깊이.
  static const int undoDepth = 20;

  /// "없음"(해제)을 허용하는 카테고리. 눈·입은 캐릭터 정체성이라 해제할 수 없다.
  static const Set<DecorationCategory> clearable = {
    DecorationCategory.nose,
    DecorationCategory.cheek,
    DecorationCategory.headwear,
  };

  static bool canClear(DecorationCategory c) => clearable.contains(c);

  /// 카테고리 탭 순서 (UI 시안). 진입 시 기본 활성 탭은 눈이다.
  static const List<DecorationCategory> tabOrder = [
    DecorationCategory.pot,
    DecorationCategory.eyes,
    DecorationCategory.nose,
    DecorationCategory.mouth,
    DecorationCategory.cheek,
    DecorationCategory.headwear,
    DecorationCategory.background,
  ];

  static const DecorationCategory defaultTab = DecorationCategory.eyes;

  /// 렌더링 순서 (z_index). 런타임 계산 없이 카테고리별 고정값이다.
  /// 배경 → 화분 → (식물 20) → 볼 → 입 → 코 → 눈 → 머리장식
  static const Map<DecorationCategory, int> zIndex = {
    DecorationCategory.background: 0,
    DecorationCategory.pot: 10,
    DecorationCategory.cheek: 30,
    DecorationCategory.mouth: 40,
    DecorationCategory.nose: 50,
    DecorationCategory.eyes: 60,
    DecorationCategory.headwear: 70,
  };

  static const int plantZIndex = 20;
}

/// 얼굴 부위의 고정 앵커. 화분(용기) 본체 영역 기준 정규화 좌표(0~1)다.
/// 식물이 아니라 화분에 붙으므로 성장 단계가 바뀌어도 위치가 변하지 않는다.
class FaceAnchor {
  const FaceAnchor(this.dx, this.dy);
  final double dx;
  final double dy;
}

class DecorationAnchors {
  const DecorationAnchors._();

  static const eyes = FaceAnchor(0.5, 0.30);
  static const nose = FaceAnchor(0.5, 0.52);
  static const mouth = FaceAnchor(0.5, 0.70);
  static const cheekLeft = FaceAnchor(0.17, 0.55);
  static const cheekRight = FaceAnchor(0.83, 0.55);
}

/// 되돌리기 항목: 이 카테고리를 [previousItemId]로 복원한다 (null = 해제 상태였음).
class UndoEntry {
  const UndoEntry(this.category, this.previousItemId);
  final DecorationCategory category;
  final String? previousItemId;
}

/// 단계별 Undo 스택. 최대 [DecorationRules.undoDepth]개, 넘치면 가장 오래된 항목을 버린다.
class UndoStack {
  UndoStack(Iterable<UndoEntry> entries) : _entries = List.of(entries);

  const UndoStack.empty() : _entries = const [];

  final List<UndoEntry> _entries;

  bool get isEmpty => _entries.isEmpty;
  int get length => _entries.length;

  UndoStack push(UndoEntry e) {
    final next = [..._entries, e];
    if (next.length > DecorationRules.undoDepth) next.removeAt(0);
    return UndoStack(next);
  }

  /// 마지막 항목과, 그것을 뺀 스택. 비어 있으면 null.
  (UndoEntry, UndoStack)? pop() {
    if (_entries.isEmpty) return null;
    return (_entries.last, UndoStack(_entries.sublist(0, _entries.length - 1)));
  }
}
