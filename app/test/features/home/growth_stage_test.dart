import 'package:drink_water_app/features/home/domain/growth_stage.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  int stage(int total) => growthStage(totalMl: total, goalMl: 2000);

  test('달성률 구간별 성장 단계 (기획서 5.3)', () {
    expect(stage(0), 1);
    expect(stage(400), 1); // 20%
    expect(stage(420), 2); // 21%
    expect(stage(800), 2); // 40%
    expect(stage(820), 3); // 41% — AC: 41%가 되는 순간 3단계
    expect(stage(1200), 3); // 60%
    expect(stage(1240), 4); // 62%
    expect(stage(1980), 4); // 99%
    expect(stage(2000), 5); // 100%
    expect(stage(3000), 5);
  });

  test('목표가 0 이하이면 1단계', () {
    expect(growthStage(totalMl: 500, goalMl: 0), 1);
  });
}
