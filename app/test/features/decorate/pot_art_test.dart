import 'package:drink_water_app/features/decorate/presentation/widgets/pot_art.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('모든 단계·아이템·표정 조합이 예외 없이 그려진다', (tester) async {
    for (var stage = 1; stage <= 5; stage++) {
      for (var n = 1; n <= 6; n++) {
        for (final happy in [false, true]) {
          await tester.pumpWidget(Directionality(
            textDirection: TextDirection.ltr,
            child: CustomPaint(
              size: const Size(280, 280),
              painter: PotArtPainter(
                stage: stage,
                potId: 'pot_${(n - 1) % 4 + 1}',
                eyesId: 'eyes_$n',
                noseId: 'nose_${(n - 1) % 4 + 1}',
                mouthId: 'mouth_$n',
                cheekId: 'cheek_${(n - 1) % 4 + 1}',
                happy: happy,
              ),
            ),
          ));
          expect(tester.takeException(), isNull);
        }
      }
    }
  });
}
