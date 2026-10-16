import 'dart:math' as math;

/// 화분이 기뻐할 때 한 프레임의 변형값.
class JoyFrame {
  const JoyFrame({
    this.dy = 0,
    this.scaleX = 1,
    this.scaleY = 1,
    this.angle = 0,
  });

  static const rest = JoyFrame();

  /// 위쪽 이동량. 캔버스 한 변에 대한 비율이며 음수가 위쪽이다.
  final double dy;
  final double scaleX;
  final double scaleY;

  /// 회전(라디안).
  final double angle;
}

/// 성장할 때 화분이 통통 튀며 기뻐하는 모션 (순수 함수).
///
/// 점프(3번, 점점 작아짐) + 공중에서 늘어나고 착지할 때 눌리는 찌그러짐 + 좌우 흔들림.
/// 시작(t=0)과 끝(t=1)은 정확히 원래 모양이라 연출이 튀지 않는다.
///
/// 화분 전체(식물·얼굴 부위·머리장식)가 한 덩어리로 움직이므로 화분 기준 앵커의 상대 위치는
/// 변하지 않는다 (기획서 S3). 배경은 움직이지 않는다.
class JoyMotion {
  const JoyMotion._();

  static const Duration duration = Duration(milliseconds: 800);

  /// 5단계(개화)는 더 크고 길게 축하한다.
  static const Duration bloomDuration = Duration(milliseconds: 1100);

  static const double intensity = 1.0;
  static const double bloomIntensity = 1.6;

  static JoyFrame at(double t, {double strength = intensity}) {
    final p = t.clamp(0.0, 1.0).toDouble();
    final decay = 1 - p;
    final jump = math.sin(p * math.pi * 3).abs() * decay;
    final ground = (1 - jump) * math.sin(p * math.pi);
    final wiggle = math.sin(p * math.pi * 6) * decay;

    return JoyFrame(
      dy: -0.05 * strength * jump,
      scaleX: 1 + strength * (-0.03 * jump + 0.04 * ground * decay),
      scaleY: 1 + strength * (0.06 * jump - 0.05 * ground * decay),
      angle: 0.07 * strength * wiggle,
    );
  }
}
