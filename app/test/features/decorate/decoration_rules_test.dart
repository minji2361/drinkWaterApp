import 'package:drink_water_app/core/database/enums.dart';
import 'package:drink_water_app/features/decorate/domain/decoration_rules.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('코·볼·머리장식만 해제할 수 있다', () {
    expect(DecorationRules.canClear(DecorationCategory.nose), isTrue);
    expect(DecorationRules.canClear(DecorationCategory.cheek), isTrue);
    expect(DecorationRules.canClear(DecorationCategory.headwear), isTrue);
    expect(DecorationRules.canClear(DecorationCategory.eyes), isFalse);
    expect(DecorationRules.canClear(DecorationCategory.mouth), isFalse);
    expect(DecorationRules.canClear(DecorationCategory.pot), isFalse);
    expect(DecorationRules.canClear(DecorationCategory.background), isFalse);
  });

  test('렌더링 순서: 배경→화분→식물→볼→입→코→눈→머리장식', () {
    const z = DecorationRules.zIndex;
    final order = [
      z[DecorationCategory.background]!,
      z[DecorationCategory.pot]!,
      DecorationRules.plantZIndex,
      z[DecorationCategory.cheek]!,
      z[DecorationCategory.mouth]!,
      z[DecorationCategory.nose]!,
      z[DecorationCategory.eyes]!,
      z[DecorationCategory.headwear]!,
    ];
    expect(order, [...order]..sort());
    expect(order.toSet(), hasLength(order.length));
  });

  test('기본 활성 탭은 눈이다', () {
    expect(DecorationRules.defaultTab, DecorationCategory.eyes);
  });

  group('UndoStack', () {
    test('LIFO로 pop한다', () {
      var s = const UndoStack.empty();
      expect(s.isEmpty, isTrue);
      expect(s.pop(), isNull);

      s = s.push(const UndoEntry(DecorationCategory.eyes, 'eyes_1'));
      s = s.push(const UndoEntry(DecorationCategory.nose, null));
      final (last, rest) = s.pop()!;
      expect(last.category, DecorationCategory.nose);
      expect(last.previousItemId, isNull);
      expect(rest.length, 1);
    });

    test('최대 20단계, 넘치면 가장 오래된 항목을 버린다', () {
      var s = const UndoStack.empty();
      for (var i = 0; i < 25; i++) {
        s = s.push(UndoEntry(DecorationCategory.eyes, 'e$i'));
      }
      expect(s.length, DecorationRules.undoDepth);
      // 가장 최근 20개(e5~e24)만 남는다
      var cur = s;
      String? lastId;
      while (true) {
        final p = cur.pop();
        if (p == null) break;
        lastId = p.$1.previousItemId;
        cur = p.$2;
      }
      expect(lastId, 'e5');
    });
  });
}
