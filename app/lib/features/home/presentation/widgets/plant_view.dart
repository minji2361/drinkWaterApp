import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../l10n/app_localizations.dart';

/// 화분 영역 자리표시자. 성장 단계별 이모지로 대신하며, Rive 에셋이 준비되면 교체한다.
///
/// 기록 시 물 붓기 연출(1.2초)을 재생하고, 단계가 올라가는 경우 물 붓기 뒤에
/// 성장 연출을 이어서 보여준다. 단계가 내려가는 경우(되돌리기)는 즉시 반영한다 (기획서 5.3).
class PlantView extends StatefulWidget {
  const PlantView({super.key, required this.stage, required this.pourSeq});

  final int stage;

  /// 값이 바뀔 때마다 물 붓기 연출을 재생한다.
  final int pourSeq;

  @override
  State<PlantView> createState() => _PlantViewState();
}

class _PlantViewState extends State<PlantView>
    with SingleTickerProviderStateMixin {
  static const _pourDuration = Duration(milliseconds: 1200);
  static const _stageEmoji = ['🌰', '🌱', '🌿', '🌷', '🌸'];

  late final AnimationController _pour =
      AnimationController(vsync: this, duration: _pourDuration);
  late int _shownStage = widget.stage;
  Timer? _stageTimer;

  @override
  void didUpdateWidget(PlantView old) {
    super.didUpdateWidget(old);
    if (widget.pourSeq != old.pourSeq) _pour.forward(from: 0);
    if (widget.stage != old.stage) {
      _stageTimer?.cancel();
      if (widget.stage > old.stage && widget.pourSeq != old.pourSeq) {
        _stageTimer = Timer(_pourDuration, () {
          if (mounted) setState(() => _shownStage = widget.stage);
        });
      } else {
        _shownStage = widget.stage;
      }
    }
  }

  @override
  void dispose() {
    _stageTimer?.cancel();
    _pour.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 280,
          height: 280,
          decoration: const BoxDecoration(
            color: AppColors.surfaceTint,
            shape: BoxShape.circle,
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 400),
                child: Text(
                  _stageEmoji[(_shownStage - 1).clamp(0, 4)],
                  key: ValueKey(_shownStage),
                  style: const TextStyle(fontSize: 120),
                ),
              ),
              AnimatedBuilder(
                animation: _pour,
                builder: (_, __) {
                  final t = _pour.value;
                  if (t == 0 || t == 1) return const SizedBox.shrink();
                  return Align(
                    alignment: Alignment(0, -1 + 1.2 * t),
                    child: Opacity(
                      opacity: 1 - t,
                      child: const Text('💧', style: TextStyle(fontSize: 40)),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Text(
          l10n.homeGrowthStage(_shownStage),
          style: const TextStyle(color: AppColors.textSecondary),
        ),
      ],
    );
  }
}
