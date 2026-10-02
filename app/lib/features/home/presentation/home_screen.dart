import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';

/// S2 메인 화면 자리표시자. 화분·기록 UI는 이후 구현한다.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(body: Center(child: Text(l10n.appName)));
  }
}
