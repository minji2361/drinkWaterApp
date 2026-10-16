import 'package:flutter/material.dart';

/// 배경색·머리장식 placeholder 표현. 화분·얼굴 부품은 [PotArt]가 그린다.
///
/// 아이템 id별로 색·이모지를 정해 둔다. 실제 에셋(PNG/SVG)이 준비되면 이 파일의 매핑을
/// `asset_key` 기반 이미지 로딩으로 바꾸면 되고, 앵커·z-index 같은 배치 규칙은 그대로다.
/// (에셋에 텍스트를 넣지 않는다는 원칙에 따라 실제 에셋에는 글자가 없다. 아래 글리프는 임시 도형이다.)
class ItemArt {
  const ItemArt._();

  static const _bg = {
    'bg_1': Color(0xFFDDEBE8),
    'bg_2': Color(0xFFFBE5C8),
    'bg_3': Color(0xFFD3E3F6),
  };

  static const _head = {
    'head_1': '🎀',
    'head_2': '🌼',
    'head_3': '🎩',
    'head_4': '👑',
    'head_5': '🍀',
    'head_6': '🎧',
  };

  static Color background(String id) => _bg[id] ?? const Color(0xFFDDEBE8);
  static String headwear(String id) => _head[id] ?? '🎀';
}
