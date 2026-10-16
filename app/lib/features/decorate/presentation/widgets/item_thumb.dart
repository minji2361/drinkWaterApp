import 'package:flutter/material.dart';

import '../../../../core/database/app_database.dart';
import 'item_art.dart';
import 'pot_art.dart';

/// 그리드 칸에 표시하는 아이템 썸네일.
class ItemThumb extends StatelessWidget {
  const ItemThumb({super.key, required this.item});

  final DecorationItemRow item;

  @override
  Widget build(BuildContext context) {
    switch (item.category) {
      case DecorationCategory.background:
        return Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: ItemArt.background(item.id),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2),
          ),
        );
      case DecorationCategory.pot:
      case DecorationCategory.cheek:
      case DecorationCategory.eyes:
      case DecorationCategory.nose:
      case DecorationCategory.mouth:
        return CustomPaint(
          size: const Size(44, 44),
          painter: PotPartThumbPainter(category: item.category, id: item.id),
        );
      case DecorationCategory.headwear:
        return Text(ItemArt.headwear(item.id),
            style: const TextStyle(fontSize: 28));
    }
  }
}
