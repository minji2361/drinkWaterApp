import 'package:flutter/material.dart';

import '../../../../core/database/app_database.dart';
import '../../domain/decoration_rules.dart';
import 'item_art.dart';

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
  });

  /// 성장 단계 1~5.
  final int stage;

  /// 카테고리 → 장착 아이템 (null = 해제).
  final Map<DecorationCategory, DecorationItemRow?>? equipped;

  /// 정사각 캔버스 한 변.
  final double size;

  static const _plantEmoji = ['🌰', '🌱', '🌿', '🌷', '🌸'];

  @override
  Widget build(BuildContext context) {
    final e = equipped;
    final s = size;

    // 화분 기하. 모든 앵커가 이 영역에서 계산된다.
    final potWidth = s * 0.52;
    final potHeight = s * 0.40;
    final potLeft = (s - potWidth) / 2;
    final potTop = s * 0.52;
    final rimHeight = potHeight * 0.22;
    final bodyTop = potTop + rimHeight;
    final bodyHeight = potHeight - rimHeight;
    final bodyWidth = potWidth * 0.9;
    final bodyLeft = (s - bodyWidth) / 2;

    Widget at(FaceAnchor a, Widget child) => Positioned(
          left: bodyLeft + a.dx * bodyWidth,
          top: bodyTop + a.dy * bodyHeight,
          child: FractionalTranslation(
            translation: const Offset(-0.5, -0.5),
            child: child,
          ),
        );

    DecorationItemRow? item(DecorationCategory c) => e?[c];

    final layers = <int, List<Widget>>{
      DecorationRules.zIndex[DecorationCategory.background]!: [
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: ItemArt.background(
                  item(DecorationCategory.background)?.id ?? 'bg_1'),
              shape: BoxShape.circle,
            ),
          ),
        ),
      ],
      DecorationRules.zIndex[DecorationCategory.pot]!: [
        Positioned(
          left: potLeft - potWidth * 0.04,
          top: potTop,
          child: _Pot(
            color: ItemArt.pot(item(DecorationCategory.pot)?.id ?? 'pot_1'),
            width: potWidth * 1.08,
            height: potHeight,
            rimHeight: rimHeight,
          ),
        ),
      ],
      DecorationRules.plantZIndex: [
        Positioned(
          left: 0,
          right: 0,
          bottom: s - potTop - s * 0.03,
          child: Center(
            child: Text(
              _plantEmoji[(stage - 1).clamp(0, 4)],
              style: TextStyle(fontSize: s * 0.30, height: 1),
            ),
          ),
        ),
      ],
      if (item(DecorationCategory.cheek) != null)
        DecorationRules.zIndex[DecorationCategory.cheek]!: [
          for (final a in [
            DecorationAnchors.cheekLeft,
            DecorationAnchors.cheekRight
          ])
            at(
              a,
              Container(
                width: s * 0.07,
                height: s * 0.05,
                decoration: BoxDecoration(
                  color: ItemArt.cheek(item(DecorationCategory.cheek)!.id)
                      .withValues(alpha: 0.75),
                  borderRadius: BorderRadius.circular(s),
                ),
              ),
            ),
        ],
      if (item(DecorationCategory.mouth) != null)
        DecorationRules.zIndex[DecorationCategory.mouth]!: [
          at(
            DecorationAnchors.mouth,
            Text(
              ItemArt.mouth(item(DecorationCategory.mouth)!.id),
              style: TextStyle(
                  fontSize: s * 0.08,
                  height: 1,
                  color: const Color(0xFF3A2A22),
                  fontWeight: FontWeight.w700),
            ),
          ),
        ],
      if (item(DecorationCategory.nose) != null)
        DecorationRules.zIndex[DecorationCategory.nose]!: [
          at(
            DecorationAnchors.nose,
            Text(
              ItemArt.nose(item(DecorationCategory.nose)!.id),
              style: TextStyle(
                  fontSize: s * 0.05,
                  height: 1,
                  color: const Color(0xFF3A2A22)),
            ),
          ),
        ],
      if (item(DecorationCategory.eyes) != null)
        DecorationRules.zIndex[DecorationCategory.eyes]!: [
          at(
            DecorationAnchors.eyes,
            Text(
              ItemArt.eyes(item(DecorationCategory.eyes)!.id),
              style: TextStyle(
                  fontSize: s * 0.075,
                  height: 1,
                  color: const Color(0xFF2B2320),
                  fontWeight: FontWeight.w700),
            ),
          ),
        ],
      if (item(DecorationCategory.headwear) != null)
        DecorationRules.zIndex[DecorationCategory.headwear]!: [
          // 머리장식은 식물이 아니라 화분 테두리 위에 놓여 개화해도 꽃을 가리지 않는다.
          Positioned(
            left: 0,
            right: 0,
            top: potTop - s * 0.07,
            child: Center(
              child: Text(
                ItemArt.headwear(item(DecorationCategory.headwear)!.id),
                style: TextStyle(fontSize: s * 0.11, height: 1),
              ),
            ),
          ),
        ],
    };

    final order = layers.keys.toList()..sort();
    return IgnorePointer(
      child: SizedBox(
        width: s,
        height: s,
        child: Stack(children: [
          for (final z in order) ...layers[z]!,
        ]),
      ),
    );
  }
}

class _Pot extends StatelessWidget {
  const _Pot({
    required this.color,
    required this.width,
    required this.height,
    required this.rimHeight,
  });

  final Color color;
  final double width;
  final double height;
  final double rimHeight;

  @override
  Widget build(BuildContext context) {
    final rim = HSLColor.fromColor(color)
        .withLightness(
            (HSLColor.fromColor(color).lightness - 0.06).clamp(0.0, 1.0))
        .toColor();
    return SizedBox(
      width: width,
      height: height,
      child: Column(
        children: [
          Container(
            height: rimHeight,
            decoration: BoxDecoration(
              color: rim,
              borderRadius: BorderRadius.circular(rimHeight * 0.3),
            ),
          ),
          Expanded(
            child: Container(
              width: width * 0.9,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.vertical(
                    bottom: Radius.circular(width * 0.2)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
