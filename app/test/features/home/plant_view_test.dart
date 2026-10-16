import 'package:drink_water_app/features/home/presentation/widgets/plant_view.dart';
import 'package:drink_water_app/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _app({
  required int stage,
  required int pourSeq,
  bool disableAnimations = false,
}) {
  return MaterialApp(
    locale: const Locale('ko'),
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: AppLocalizations.supportedLocales,
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(disableAnimations: disableAnimations),
      child: child!,
    ),
    home: Scaffold(
      body: Center(child: PlantView(stage: stage, pourSeq: pourSeq)),
    ),
  );
}

void main() {
  testWidgets('성장하면 물 붓기(1.2초) 뒤에 단계가 바뀌고 기뻐하는 모션이 시작된다', (tester) async {
    await tester.pumpWidget(_app(stage: 1, pourSeq: 0));
    expect(find.text('성장 단계 1'), findsOneWidget);

    await tester.pumpWidget(_app(stage: 2, pourSeq: 1));
    // 물 붓기가 끝나기 전에는 아직 이전 단계
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('성장 단계 1'), findsOneWidget);

    // 물 붓기 뒤 단계가 올라가고 모션이 돌고 있다
    await tester.pump(const Duration(milliseconds: 650));
    expect(find.text('성장 단계 2'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.binding.hasScheduledFrame, isTrue);

    // 모션이 끝나면 정지한다
    await tester.pumpAndSettle();
    expect(tester.binding.hasScheduledFrame, isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('개화(5단계)도 문제없이 재생된다', (tester) async {
    await tester.pumpWidget(_app(stage: 4, pourSeq: 0));
    await tester.pumpWidget(_app(stage: 5, pourSeq: 1));
    await tester.pump(const Duration(milliseconds: 1250));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('성장 단계 5'), findsOneWidget);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('단계가 내려가면(되돌리기) 모션 없이 즉시 반영된다', (tester) async {
    await tester.pumpWidget(_app(stage: 3, pourSeq: 0));
    await tester.pumpWidget(_app(stage: 2, pourSeq: 1));
    await tester.pump();
    expect(find.text('성장 단계 2'), findsOneWidget);
    // 물 붓기 연출만 남아 있고, 끝나면 정지
    await tester.pumpAndSettle();
    expect(tester.binding.hasScheduledFrame, isFalse);
  });

  testWidgets('기록 없이 단계만 바뀌면 모션 없이 반영된다', (tester) async {
    await tester.pumpWidget(_app(stage: 1, pourSeq: 0));
    await tester.pumpWidget(_app(stage: 3, pourSeq: 0));
    await tester.pump();
    expect(find.text('성장 단계 3'), findsOneWidget);
    expect(tester.binding.hasScheduledFrame, isFalse);
  });

  testWidgets("시스템 '애니메이션 줄이기'가 켜져 있으면 튀는 모션을 생략한다", (tester) async {
    await tester.pumpWidget(_app(stage: 1, pourSeq: 0, disableAnimations: true));
    await tester.pumpWidget(_app(stage: 2, pourSeq: 1, disableAnimations: true));
    await tester.pump(const Duration(milliseconds: 1250));
    expect(find.text('성장 단계 2'), findsOneWidget);
    // 물 붓기는 이미 끝났고, 튀는 모션이 없으니 더 이상 프레임이 필요 없다
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.binding.hasScheduledFrame, isFalse);
  });
}
