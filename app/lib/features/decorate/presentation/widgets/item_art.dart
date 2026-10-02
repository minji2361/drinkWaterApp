import 'package:flutter/material.dart';

/// 아이템 에셋이 나오기 전까지 쓰는 placeholder 표현.
///
/// 아이템 id별로 색·글리프를 정해 둔다. 실제 에셋(PNG/SVG)이 준비되면 이 파일의 매핑을
/// `asset_key` 기반 이미지 로딩으로 바꾸면 되고, 앵커·z-index 같은 배치 규칙은 그대로다.
/// (에셋에 텍스트를 넣지 않는다는 원칙에 따라 실제 에셋에는 글자가 없다. 아래 글리프는 임시 도형이다.)
class ItemArt {
  const ItemArt._();

  static const _bg = {
    'bg_1': Color(0xFFDDEBE8),
    'bg_2': Color(0xFFFBE5C8),
    'bg_3': Color(0xFFD3E3F6),
  };

  static const _pot = {
    'pot_1': Color(0xFFE8975B),
    'pot_2': Color(0xFFF2C14E),
    'pot_3': Color(0xFF7FB9C2),
    'pot_4': Color(0xFFE59AB6),
  };

  static const _cheek = {
    'cheek_1': Color(0xFFF4A8A8),
    'cheek_2': Color(0xFFF7C873),
    'cheek_3': Color(0xFFB8A9E8),
    'cheek_4': Color(0xFF9ED8B5),
  };

  static const _eyes = {
    'eyes_1': '●  ●',
    'eyes_2': '^  ^',
    'eyes_3': '◉  ◉',
    'eyes_4': '—  —',
    'eyes_5': '★  ★',
    'eyes_6': '♥  ♥',
  };

  static const _nose = {
    'nose_1': '•',
    'nose_2': '▾',
    'nose_3': '◆',
    'nose_4': '▴',
  };

  static const _mouth = {
    'mouth_1': '‿',
    'mouth_2': 'ᴗ',
    'mouth_3': 'ω',
    'mouth_4': 'o',
    'mouth_5': '▽',
    'mouth_6': '3',
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
  static Color pot(String id) => _pot[id] ?? const Color(0xFFE8975B);
  static Color cheek(String id) => _cheek[id] ?? const Color(0xFFF4A8A8);
  static String eyes(String id) => _eyes[id] ?? '●  ●';
  static String nose(String id) => _nose[id] ?? '•';
  static String mouth(String id) => _mouth[id] ?? '‿';
  static String headwear(String id) => _head[id] ?? '🎀';
}
