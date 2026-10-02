/// 화분 성장 단계 (기획서 5.3). 당일 달성률 기준 5단계.
int growthStage({required int totalMl, required int goalMl}) {
  if (goalMl <= 0) return 1;
  final percent = totalMl * 100 ~/ goalMl;
  if (percent <= 20) return 1;
  if (percent <= 40) return 2;
  if (percent <= 60) return 3;
  if (percent < 100) return 4;
  return 5;
}
