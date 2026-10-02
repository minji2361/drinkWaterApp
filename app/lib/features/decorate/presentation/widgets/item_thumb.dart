import 'package:flutter/material.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/theme/app_theme.dart';
import 'item_art.dart';

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
        return Container(
          width: 40,
          height: 32,
          decoration: BoxDecoration(
            color: ItemArt.pot(item.id),
            borderRadius: const BorderRadius.vertical(
                top: Radius.circular(6), bottom: Radius.circular(14)),
          ),
        );
      case DecorationCategory.cheek:
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < 2; i++) ...[
              Container(
                width: 18,
                height: 12,
                decoration: BoxDecoration(
                  color: ItemArt.cheek(item.id),
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              if (i == 0) const SizedBox(width: 6),
            ],
          ],
        );
      case DecorationCategory.eyes:
        return _glyph(ItemArt.eyes(item.id));
      case DecorationCategory.nose:
        return _glyph(ItemArt.nose(item.id));
      case DecorationCategory.mouth:
        return _glyph(ItemArt.mouth(item.id));
      case DecorationCategory.headwear:
        return Text(ItemArt.headwear(item.id),
            style: const TextStyle(fontSize: 28));
    }
  }

  Widget _glyph(String text) => Text(
        text,
        style: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
        ),
      );
}
