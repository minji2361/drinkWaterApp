import 'package:flutter/material.dart';

import '../../../../core/database/app_database.dart';
import '../../domain/joy_motion.dart';
import 'item_art.dart';
import 'pot_art.dart';

/// 화분 + 식물 + 꾸미기 아이템 합성 (기획서 S3). 홈과 꾸미기 미리보기가 같이 쓴다.
///
/// - 모든 얼굴 부위와 머리장식은 **화분(용기)** 기준 고정 앵커에 놓인다. 화분은 5단계 내내 크기·위치가
///   고정이고 식물만 위로 자라므로, 성장 단계가 바뀌어도 아이템 위치가 변하지 않는다.
/// - 렌더링 순서: 배경 → 화분 → 식물 → 볼 → 입 → 코 → 눈 → 머리장식 ([DecorationRules.zIndex]).
/// - 제스처를 받지 않는다 (보기 전용).
class DecoratedPot extends StatelessWidget {
  const DecoratedPot({
    super.key,
    required this.stage,
    required this.equipped,
    this.size = 280,
    this.joy,
  });

  /// 성장 단계 1~5.
  final int stage;

  /// 카테고리 → 장착 아이템 (null = 로딩 중이라 기본 아이템으로 그린다).
  final Map<DecorationCategory, DecorationItemRow?>? equipped;

  /// 정사각 캔버스 한 변.
  final double size;

  /// 성장 시 기뻐하는 모션의 현재 프레임. 배경을 뺀 화분 전체가 화분 바닥을 기준으로 함께 움직인다.
  /// null이거나 [JoyFrame.rest]이면 정지 상태.
  final JoyFrame? joy;

  /// true면 기쁨 모션이 재생되는 동안 표정이 "신난 얼굴"로 바뀐다.
  static const happyWhileJoy = true;

  @override
  Widget build(BuildContext context) {
    final e = equipped;
    final s = size;

    // equipped가 아직 없으면(로딩) 기본 아이템, 있으면 null은 "해제"로 본다.
    String? id(DecorationCategory c, String? fallback) =>
        e == null ? fallback : e[c]?.id;

    final j = joy;
    final art = Stack(children: [
      Positioned.fill(
        child: CustomPaint(
          painter: PotArtPainter(
            stage: stage,
            potId: id(DecorationCategory.pot, 'pot_1') ?? 'pot_1',
            eyesId: id(DecorationCategory.eyes, 'eyes_1'),
            noseId: id(DecorationCategory.nose, null),
            mouthId: id(DecorationCategory.mouth, 'mouth_1'),
            cheekId: id(DecorationCategory.cheek, 'cheek_1'),
            happy: happyWhileJoy && j != null,
          ),
        ),
      ),
      if (id(DecorationCategory.headwear, null) != null)
        // 머리장식은 식물이 아니라 화분 테두리 위에 놓여 개화해도 꽃을 가리지 않는다.
        Positioned(
          left: 0,
          right: 0,
          top: s * 0.45,
          child: Center(
            child: Text(
              ItemArt.headwear(id(DecorationCategory.headwear, null)!),
              style: TextStyle(fontSize: s * 0.11, height: 1),
            ),
          ),
        ),
    ]);

    Widget potGroup = art;
    if (j != null) {
      // 화분 바닥(캔버스 높이의 약 92%)을 축으로 움직여 바닥에서 튀어 오르는 느낌을 준다.
      potGroup = Transform.translate(
        offset: Offset(0, j.dy * s),
        child: Transform(
          alignment: const Alignment(0, 0.84),
          transform: Matrix4.identity()
            ..rotateZ(j.angle)
            ..multiply(Matrix4.diagonal3Values(j.scaleX, j.scaleY, 1.0)),
          child: art,
        ),
      );
    }

    return IgnorePointer(
      child: SizedBox(
        width: s,
        height: s,
        child: Stack(children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: ItemArt.background(
                    id(DecorationCategory.background, 'bg_1') ?? 'bg_1'),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned.fill(
            child: CustomPaint(painter: PotShadowPainter(lift: j?.dy ?? 0)),
          ),
          Positioned.fill(child: potGroup),
        ]),
      ),
    );
  }
}
