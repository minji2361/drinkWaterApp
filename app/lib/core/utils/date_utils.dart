import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 로컬 날짜를 `YYYY-MM-DD`로 변환한다. 하루의 경계는 로컬 00:00 (기획서 5.4).
String toLogDate(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

/// 주어진 `YYYY-MM-DD`의 전날.
String previousLogDate(String logDate) {
  final d = DateTime.parse(logDate);
  return toLogDate(DateTime(d.year, d.month, d.day - 1));
}

/// 테스트에서 시각을 고정할 수 있도록 현재 시각을 프로바이더로 노출한다.
final clockProvider = Provider<DateTime Function()>((_) => DateTime.now);
