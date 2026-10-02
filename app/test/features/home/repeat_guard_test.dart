import 'package:drink_water_app/features/home/domain/intake_rules.dart';
import 'package:drink_water_app/features/home/domain/repeat_guard.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final t0 = DateTime(2026, 10, 2, 9);

  test('60초 내 3회 기록 후 4회째 시도에서 확인을 요구한다', () {
    final g = RepeatGuard();
    for (var i = 0; i < 3; i++) {
      expect(g.needsConfirm(t0.add(Duration(seconds: i * 10))), isFalse);
      g.record(t0.add(Duration(seconds: i * 10)), id: i, amountMl: 200);
    }
    final now = t0.add(const Duration(seconds: 30));
    expect(g.needsConfirm(now), isTrue);
    expect(g.recentCount(now), 3);
    expect(g.recentMl(now), 600);
  });

  test('60초가 지나면 카운터가 풀린다', () {
    final g = RepeatGuard();
    for (var i = 0; i < 3; i++) {
      g.record(t0, id: i, amountMl: 200);
    }
    expect(g.needsConfirm(t0.add(const Duration(seconds: 60))), isFalse);
  });

  test('되돌린 기록은 카운터에서 제외된다', () {
    final g = RepeatGuard();
    for (var i = 0; i < 3; i++) {
      g.record(t0, id: i, amountMl: 200);
    }
    g.remove([2]);
    expect(g.needsConfirm(t0), isFalse);
  });

  test('확인 후 reset하면 카운터가 초기화된다', () {
    final g = RepeatGuard();
    for (var i = 0; i < 3; i++) {
      g.record(t0, id: i, amountMl: 200);
    }
    g.reset();
    expect(g.needsConfirm(t0), isFalse);
  });

  group('IntakeRules', () {
    test('총량 4,000ml / 30회 상한', () {
      expect(
        IntakeRules.exceeded(
            totalMl: 3900, logCount: 5, addMl: 200, addCount: 1),
        LimitKind.totalMl,
      );
      expect(
        IntakeRules.exceeded(
            totalMl: 3800, logCount: 5, addMl: 200, addCount: 1),
        isNull,
      );
      expect(
        IntakeRules.exceeded(
            totalMl: 100, logCount: 30, addMl: 10, addCount: 1),
        LimitKind.count,
      );
      expect(IntakeRules.reached(totalMl: 4000, logCount: 3),
          LimitKind.totalMl);
      expect(IntakeRules.reached(totalMl: 100, logCount: 30), LimitKind.count);
      expect(IntakeRules.reached(totalMl: 3999, logCount: 29), isNull);
    });

    test('컵 용량: 10~2,000ml, 10ml 단위', () {
      expect(IntakeRules.isValidCupMl(10), isTrue);
      expect(IntakeRules.isValidCupMl(2000), isTrue);
      expect(IntakeRules.isValidCupMl(5), isFalse);
      expect(IntakeRules.isValidCupMl(2010), isFalse);
      expect(IntakeRules.isValidCupMl(255), isFalse);
    });
  });
}
