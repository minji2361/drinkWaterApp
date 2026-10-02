import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/database/enums.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../l10n/app_localizations.dart';
import 'cup_icon.dart';

/// 물 마시기 버튼. 짧게 탭 = 기본 컵 즉시 기록, 길게 누름(500ms) = 기록 시트.
///
/// 쿨다운 중에도 탭은 받아서 shake 피드백만 준다 (기획서 5.6.1).
/// [disabled]는 일일 상한 도달로 당일 비활성화된 상태다.
class DrinkButton extends StatefulWidget {
  const DrinkButton({
    super.key,
    required this.cup,
    required this.ml,
    required this.cooling,
    required this.disabled,
    required this.onTap,
    required this.onLongPress,
  });

  final CupType cup;
  final int ml;
  final bool cooling;
  final bool disabled;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  State<DrinkButton> createState() => _DrinkButtonState();
}

class _DrinkButtonState extends State<DrinkButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _shake = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 200),
  );

  @override
  void dispose() {
    _shake.dispose();
    super.dispose();
  }

  void _handleTap() {
    if (widget.cooling) {
      _shake.forward(from: 0);
      return;
    }
    widget.onTap();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final inactive = widget.cooling || widget.disabled;

    return AnimatedBuilder(
      animation: _shake,
      builder: (_, child) => Transform.translate(
        offset: Offset(math.sin(_shake.value * math.pi * 4) * 6, 0),
        child: child,
      ),
      child: Opacity(
        opacity: inactive ? 0.5 : 1,
        child: Material(
          color: AppColors.primary,
          borderRadius: BorderRadius.circular(36),
          elevation: inactive ? 0 : 4,
          child: InkWell(
            borderRadius: BorderRadius.circular(36),
            onTap: widget.disabled ? null : _handleTap,
            onLongPress: widget.disabled || widget.cooling
                ? null
                : widget.onLongPress,
            child: ConstrainedBox(
              // 최소 터치 영역 64dp (기획서 S2)
              constraints: const BoxConstraints(minHeight: 72),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(cupIcon(widget.cup), color: Colors.white),
                    const SizedBox(width: 12),
                    Flexible(
                      child: Text(
                        l10n.homeDrinkButton(
                            cupName(l10n, widget.cup), widget.ml),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
