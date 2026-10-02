import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../../l10n/app_localizations.dart';

/// 의학 고지 문구 (기획서 5.1). 목표 설정 단계와 설정 화면에 상시 노출한다.
class MedicalNotice extends StatelessWidget {
  const MedicalNotice({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.noticeBackground,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        AppLocalizations.of(context).medicalDisclaimer,
        style: const TextStyle(color: AppColors.noticeText, height: 1.5),
      ),
    );
  }
}
