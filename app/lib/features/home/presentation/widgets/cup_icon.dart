import 'package:flutter/material.dart';

import '../../../../core/database/enums.dart';
import '../../../../l10n/app_localizations.dart';

/// 컵 종류별 아이콘. 에셋에는 텍스트를 넣지 않는다 (기획서 3.2).
/// 최종 아이콘 에셋이 나오기 전까지 Material 아이콘으로 대체한다.
IconData cupIcon(CupType type) => switch (type) {
      CupType.paper => Icons.local_drink_outlined,
      CupType.mug => Icons.coffee_outlined,
      CupType.tumbler => Icons.sports_bar_outlined,
      CupType.other => Icons.add_circle_outline,
    };

String cupName(AppLocalizations l10n, CupType type) => switch (type) {
      CupType.paper => l10n.cupPaper,
      CupType.mug => l10n.cupMug,
      CupType.tumbler => l10n.cupTumbler,
      CupType.other => l10n.cupOther,
    };
