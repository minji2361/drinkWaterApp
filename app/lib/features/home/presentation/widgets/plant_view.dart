import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../decorate/domain/joy_motion.dart';
import '../../../decorate/presentation/widgets/decorated_pot.dart';
import '../../../../l10n/app_localizations.dart';

/// 화분 영역 자리표시자. 성장 단계별 이모지로 대신하며, Rive 에셋이 준비되면 교체한다.
///
/// 기록 시 물 붓기 연출(1.2초)을 재생하고, 단계가 올라가는 경우 물 붓기 뒤에
/// 성장 연출(화분이 기뻐하며 통통 튀는 모션)을 이어서 보여준다. 5단계(개화)는 더 크게 축하한다.
/// 단계가 내려가는 경우(되돌리기)는 모션 없이 즉시 반영한다 (기획서 5.3).
/// 시스템의 '애니메이션 줄이기' 설정이 켜져 있으면 튀는 모션은 생략한다.
class PlantView extends StatefulWidget {
  const PlantView({
    super.key,
    required this.stage,
    required this.pourSeq,
    this.equipped,
  });

  final int stage;

  /// 값이 바뀔 때마다 물 붓기 연출을 재생한다.
  final int pourSeq;

  /// 장착 중인 꾸미기 아이템 (카테고리 → 아이템, null = 해제).
  final Map<DecorationCategory, DecorationItemRow?>? equipped;

  @override
  State<PlantView> createState() => _PlantViewState();
}

class _PlantViewState extends State<PlantView> with TickerProviderStateMixin {
  static const _pourDuration = Duration(milliseconds: 1200);

  late final AnimationController _pour =
      AnimationController(vsync: this, duration: _pourDuration);
  late final AnimationController _joy = AnimationController(vsync: this);
  late int _shownStage = widget.stage;
  double _joyStrength = JoyMotion.intensity;
  Timer? _stageTimer;

  @override
  void didUpdateWidget(PlantView old) {
    super.didUpdateWidget(old);
    if (widget.pourSeq != old.pourSeq) _pour.forward(from: 0);
    if (widget.stage != old.stage) {
      _stageTimer?.cancel();
      if (widget.stage > old.stage && widget.pourSeq != old.pourSeq) {
        _stageTimer = Timer(_pourDuration, () {
          if (!mounted) return;
          setState(() => _shownStage = widget.stage);
          _playJoy(widget.stage);
        });
      } else {
        _shownStage = widget.stage;
      }
    }
  }

  /// 성장한 순간 화분이 기뻐하는 모션을 재생한다. 개화(5단계)는 더 크고 길다.
  void _playJoy(int stage) {
    if (MediaQuery.of(context).disableAnimations) return;
    final bloom = stage >= 5;
    _joyStrength = bloom ? JoyMotion.bloomIntensity : JoyMotion.intensity;
    _joy.duration = bloom ? JoyMotion.bloomDuration : JoyMotion.duration;
    _joy.forward(from: 0);
  }

  @override
  void dispose() {
    _stageTimer?.cancel();
    _joy.dispose();
    _pour.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            AnimatedBuilder(
              animation: _joy,
              builder: (_, __) {
                final t = _joy.value;
                final running = t > 0 && t < 1;
                return DecoratedPot(
                  stage: _shownStage,
                  equipped: widget.equipped,
                  size: 280,
                  joy: running ? JoyMotion.at(t, strength: _joyStrength) : null,
                );
              },
            ),
            AnimatedBuilder(
              animation: _pour,
              builder: (_, __) {
                final t = _pour.value;
                if (t == 0 || t == 1) return const SizedBox.shrink();
                return SizedBox(
                  width: 280,
                  height: 280,
                  child: Align(
                    alignment: Alignment(0, -1 + 1.2 * t),
                    child: Opacity(
                      opacity: 1 - t,
                      child: const Text('💧', style: TextStyle(fontSize: 40)),
                    ),
                  ),
                );
              },
            ),
          ],
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
