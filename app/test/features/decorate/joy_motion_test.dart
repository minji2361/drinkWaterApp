import 'dart:math' as math;

import 'package:drink_water_app/features/decorate/domain/joy_motion.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  void expectRest(JoyFrame f) {
    expect(f.dy, closeTo(0, 1e-9));
    expect(f.scaleX, closeTo(1, 1e-9));
    expect(f.scaleY, closeTo(1, 1e-9));
    expect(f.angle, closeTo(0, 1e-9));
  }

  test('시작과 끝은 정확히 원래 모양이다 (튀지 않고 이어진다)', () {
    expectRest(JoyMotion.at(0));
    expectRest(JoyMotion.at(1));
    expectRest(JoyMotion.at(0, strength: JoyMotion.bloomIntensity));
    expectRest(JoyMotion.at(1, strength: JoyMotion.bloomIntensity));
  });

  test('범위를 벗어난 t는 0~1로 고정된다', () {
    expectRest(JoyMotion.at(-0.5));
    expectRest(JoyMotion.at(1.5));
  });

  test('점프는 위쪽(음수)으로만 일어나고 양수 dy는 없다', () {
    for (var i = 0; i <= 100; i++) {
      expect(JoyMotion.at(i / 100).dy, lessThanOrEqualTo(0));
    }
  });

  test('움직임은 작은 범위에 머문다 (화분이 화면 밖으로 튀지 않음)', () {
    for (final strength in [JoyMotion.intensity, JoyMotion.bloomIntensity]) {
      for (var i = 0; i <= 200; i++) {
        final f = JoyMotion.at(i / 200, strength: strength);
        expect(f.dy.abs(), lessThanOrEqualTo(0.05 * strength + 1e-9));
        expect(f.angle.abs(), lessThanOrEqualTo(0.07 * strength + 1e-9));
        expect(f.scaleX, inInclusiveRange(0.9, 1.1));
        expect(f.scaleY, inInclusiveRange(0.9, 1.1));
      }
    }
  });

  test('개화(5단계)는 일반 성장보다 크게 움직인다', () {
    double maxJump(double strength) => [
          for (var i = 0; i <= 200; i++)
            JoyMotion.at(i / 200, strength: strength).dy.abs()
        ].reduce(math.max);

    expect(maxJump(JoyMotion.bloomIntensity),
        greaterThan(maxJump(JoyMotion.intensity)));
    expect(JoyMotion.bloomDuration, greaterThan(JoyMotion.duration));
  });

  test('점프 높이는 시간이 갈수록 줄어든다 (점점 잦아듦)', () {
    double peak(double from, double to) => [
          for (var i = 0; i <= 100; i++)
            JoyMotion.at(from + (to - from) * i / 100).dy.abs()
        ].reduce(math.max);

    expect(peak(0, 0.33), greaterThan(peak(0.33, 0.66)));
    expect(peak(0.33, 0.66), greaterThan(peak(0.66, 1)));
  });
}
