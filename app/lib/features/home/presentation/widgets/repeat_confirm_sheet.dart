import 'package:flutter/material.dart';

import '../../../../l10n/app_localizations.dart';

enum RepeatChoice { bulk, one }

/// 60초 내 3회 기록 후 4회째 시도 시 표시하는 확인 시트 (기획서 5.6.2).
/// 취소는 시트를 닫는 것(null)으로 처리한다.
class RepeatConfirmSheet extends StatelessWidget {
  const RepeatConfirmSheet(
      {super.key, required this.count, required this.totalMl});

  final int count;
  final int totalMl;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.repeatMessage(count, totalMl),
              style: const TextStyle(
                  fontSize: 18, fontWeight: FontWeight.w700, height: 1.5),
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(RepeatChoice.bulk),
              child: Text(l10n.repeatBulk),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(56)),
              onPressed: () => Navigator.of(context).pop(RepeatChoice.one),
              child: Text(l10n.repeatOne),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(l10n.commonCancel),
            ),
          ],
        ),
      ),
    );
  }
}
