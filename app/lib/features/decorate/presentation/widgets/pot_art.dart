import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../../../core/database/app_database.dart';

/// 화분·식물·얼굴 임시 일러스트 (최종 에셋이 오기 전까지 코드로 그린다).
///
/// 모든 좌표는 280×280 기준이며 painter가 `size / 280`으로 스케일한다.
/// 위치(화분 몸통 y170~258, 눈 y196 등)는 에셋 가이드의 앵커 규칙과 같은 비율이다.
class PotArt {
  const PotArt._();

  static const double base = 280;

  static const _ink = Color(0xFF3B2A25);
  static const _brow = Color(0xFF7A4A30);
  static const _mouthRed = Color(0xFFB9454C);

  // ── 화분 ────────────────────────────────────────────────────────────
  static const _pots = {
    'pot_1': _PotPalette(Color(0xFFF6AE7B), Color(0xFFE98C53),
        Color(0xFFF1A26C), Color(0xFFD57F45)),
    'pot_2': _PotPalette(Color(0xFFFFD76E), Color(0xFFF2B93F),
        Color(0xFFF7CB55), Color(0xFFD79F2A)),
    'pot_3': _PotPalette(Color(0xFF9BCBD3), Color(0xFF6AA9B4),
        Color(0xFF88BEC7), Color(0xFF4F8F9A)),
    'pot_4': _PotPalette(Color(0xFFF2B0C6), Color(0xFFE28FAD),
        Color(0xFFEEA3BD), Color(0xFFC97394)),
  };

  /// 아이템 썸네일에서 쓰는 대표색.
  static Color potColor(String id) => (_pots[id] ?? _pots['pot_1']!).bottom;

  static void drawPot(Canvas c, String id) {
    final p = _pots[id] ?? _pots['pot_1']!;
    final body = Path()
      ..moveTo(69.3, 170)
      ..lineTo(210.7, 170)
      ..lineTo(192, 238)
      ..quadraticBezierTo(188, 257.6, 168, 257.6)
      ..lineTo(112, 257.6)
      ..quadraticBezierTo(92, 257.6, 88, 238)
      ..close();
    c.drawPath(
      body,
      Paint()
        ..shader = ui.Gradient.linear(
            const Offset(69, 0), const Offset(211, 0), [p.top, p.bottom]),
    );
    c.drawRRect(
      RRect.fromRectAndRadius(const Rect.fromLTWH(61.4, 145.6, 157.2, 24.6),
          const Radius.circular(9)),
      Paint()..color = p.rim,
    );
    c.drawRRect(
      RRect.fromRectAndRadius(
          const Rect.fromLTWH(63, 167.4, 154, 3.4), const Radius.circular(1.7)),
      Paint()..color = p.rimLine,
    );
    c.drawOval(
        Rect.fromCenter(
            center: const Offset(140, 147.5), width: 132, height: 12),
        Paint()..color = const Color(0xFF8F5C3D));
  }

  static void drawShadow(Canvas c, {double lift = 0}) {
    final l = lift.abs();
    final scale = (1 - l * 5).clamp(0.4, 1.0);
    final opacity = (0.12 - l * 0.8).clamp(0.03, 0.12);
    c.drawOval(
      Rect.fromCenter(
          center: const Offset(140, 262),
          width: 164 * scale,
          height: 18 * scale),
      Paint()..color = Colors.black.withValues(alpha: opacity),
    );
  }

  // ── 식물 ────────────────────────────────────────────────────────────
  static void drawPlant(Canvas c, int stage) {
    switch (stage.clamp(1, 5)) {
      case 1:
        c.save();
        c.translate(140, 143.5);
        c.rotate(-14 * math.pi / 180);
        c.drawOval(Rect.fromCenter(center: Offset.zero, width: 12, height: 16),
            Paint()..color = const Color(0xFFC9A36A));
        c.restore();
      case 2:
        _stem(c, 128);
        _leafPair(c, 140, 130, -18, 0.52);
      case 3:
        _stem(c, 98);
        _leafPair(c, 140, 124, 8, 0.74);
        _leafPair(c, 140, 100, -24, 0.92);
      case 4:
        _stem(c, 94);
        _leafPair(c, 140, 122, 8, 0.78);
        final bud = Path()
          ..moveTo(140, 66)
          ..cubicTo(127, 82, 129, 96, 140, 99)
          ..cubicTo(151, 96, 153, 82, 140, 66)
          ..close();
        c.drawPath(bud, Paint()..color = const Color(0xFFF7A6B8));
        final sepal = Path()
          ..moveTo(130, 94)
          ..cubicTo(132, 99, 136, 101, 140, 101)
          ..cubicTo(144, 101, 148, 99, 150, 94)
          ..cubicTo(146, 97, 134, 97, 130, 94)
          ..close();
        c.drawPath(sepal, Paint()..color = const Color(0xFF46A23E));
      default:
        _stem(c, 92);
        _leafPair(c, 140, 122, 8, 0.78);
        c.save();
        c.translate(140, 80);
        for (var i = 0; i < 8; i++) {
          c.save();
          c.rotate(i * math.pi / 4);
          c.drawOval(
              Rect.fromCenter(
                  center: const Offset(0, -12), width: 15, height: 24),
              Paint()..color = const Color(0xFFFF9FB8));
          c.restore();
        }
        c.drawCircle(
            Offset.zero, 8.5, Paint()..color = const Color(0xFFFFCF4A));
        c.drawCircle(
            Offset.zero,
            8.5,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1.8
              ..color = const Color(0xFFF0A928));
        c.restore();
    }
  }

  static void _stem(Canvas c, double top) {
    final p = Path()
      ..moveTo(140, 149)
      ..cubicTo(140, 132, 141, 114, 140, top);
    c.drawPath(
      p,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5
        ..strokeCap = StrokeCap.round
        ..color = const Color(0xFF2E9A45),
    );
  }

  static void _leafPair(
      Canvas c, double x, double y, double rot, double scale) {
    _leaf(c, x, y, rot, scale, flip: false);
    _leaf(c, x, y, rot, scale, flip: true);
  }

  static void _leaf(Canvas c, double x, double y, double rot, double scale,
      {required bool flip}) {
    c.save();
    c.translate(x, y);
    c.rotate((flip ? -rot : rot) * math.pi / 180);
    c.scale(flip ? -scale : scale, scale);
    final leaf = Path()
      ..cubicTo(16, -6, 42, -4, 54, -28)
      ..cubicTo(28, -38, 6, -24, 0, 0)
      ..close();
    c.drawPath(
      leaf,
      Paint()
        ..shader = ui.Gradient.linear(const Offset(0, 0), const Offset(54, -28),
            [const Color(0xFF46A23E), const Color(0xFF7FD058)]),
    );
    final vein = Path()
      ..moveTo(3, -3)
      ..cubicTo(18, -10, 34, -16, 47, -26);
    c.drawPath(
      vein,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.4
        ..strokeCap = StrokeCap.round
        ..color = const Color(0xFF2F8A37),
    );
    c.restore();
  }

  // ── 얼굴 ────────────────────────────────────────────────────────────
  static const _eyeL = Offset(118, 196.4);
  static const _eyeR = Offset(162, 196.4);

  static const _cheekColors = {
    'cheek_1': Color(0xFFFF8C98),
    'cheek_2': Color(0xFFF7C873),
    'cheek_3': Color(0xFFB8A9E8),
    'cheek_4': Color(0xFFFF8C98),
  };

  static Color cheekColor(String id) =>
      _cheekColors[id] ?? _cheekColors['cheek_1']!;

  static void drawCheeks(Canvas c, String id) {
    final paint = Paint()..color = cheekColor(id).withValues(alpha: 0.62);
    for (final o in const [Offset(97, 218), Offset(183, 218)]) {
      if (id == 'cheek_4') {
        _heart(c, o, 9, paint);
      } else {
        c.drawOval(Rect.fromCenter(center: o, width: 23, height: 14), paint);
      }
    }
  }

  static void drawEyes(Canvas c, String id, {bool happy = false}) {
    final n = _num(id);
    final arcs = n == 2 || (happy && (n == 1 || n == 3 || n == 4));
    for (final o in const [_eyeL, _eyeR]) {
      if (arcs) {
        _arcEye(c, o);
      } else {
        switch (n) {
          case 3:
            _roundEye(c, o, 10.4, 12.6, sparkle: true);
          case 4:
            _sleepyEye(c, o);
          case 5:
            _star(c, o, 11.5);
          case 6:
            _heart(c, o, 10, Paint()..color = const Color(0xFFFF6F91));
          default:
            _roundEye(c, o, 8.6, 10.6);
        }
      }
    }
    _brows(c, lift: happy ? 3 : 0);
  }

  static void _roundEye(Canvas c, Offset o, double rx, double ry,
      {bool sparkle = false}) {
    c.drawOval(Rect.fromCenter(center: o, width: rx * 2, height: ry * 2),
        Paint()..color = _ink);
    final w = Paint()..color = Colors.white;
    c.drawCircle(o + Offset(3, sparkle ? -4.6 : -3.8), sparkle ? 4 : 3.3, w);
    c.drawCircle(o + Offset(-2.6, sparkle ? 4.6 : 4.2), sparkle ? 2 : 1.4, w);
    if (sparkle) c.drawCircle(o + const Offset(4.6, 3.4), 1.1, w);
  }

  static void _arcEye(Canvas c, Offset o) {
    final p = Path()
      ..moveTo(o.dx - 9.4, o.dy + 2.6)
      ..quadraticBezierTo(o.dx, o.dy - 9.4, o.dx + 9.4, o.dy + 2.6);
    c.drawPath(p, _line(_ink, 3.6));
  }

  static void _sleepyEye(Canvas c, Offset o) {
    final r = Rect.fromCenter(
        center: o + const Offset(0, 1), width: 17.2, height: 16);
    final p = Path()
      ..arcTo(r, 0, math.pi, false)
      ..close();
    c.drawPath(p, Paint()..color = _ink);
    c.drawLine(Offset(o.dx - 9.4, o.dy + 1), Offset(o.dx + 9.4, o.dy + 1),
        _line(_ink, 2.8));
  }

  static void _brows(Canvas c, {double lift = 0}) {
    c.save();
    c.translate(0, -lift);
    final l = Path()
      ..moveTo(108.5, 178.5)
      ..quadraticBezierTo(118, 172.5, 127.5, 177.5);
    final r = Path()
      ..moveTo(152.5, 177.5)
      ..quadraticBezierTo(162, 172.5, 171.5, 178.5);
    c.drawPath(l, _line(_brow, 3));
    c.drawPath(r, _line(_brow, 3));
    c.restore();
  }

  static void drawNose(Canvas c, String id) {
    const o = Offset(140, 213);
    switch (_num(id)) {
      case 2:
        final p = Path()
          ..moveTo(o.dx - 4.5, o.dy - 2.5)
          ..quadraticBezierTo(o.dx, o.dy - 4, o.dx + 4.5, o.dy - 2.5)
          ..quadraticBezierTo(o.dx + 4.5, o.dy, o.dx, o.dy + 4)
          ..quadraticBezierTo(o.dx - 4.5, o.dy, o.dx - 4.5, o.dy - 2.5)
          ..close();
        c.drawPath(p, Paint()..color = _brow);
      case 3:
        _heart(c, o, 5, Paint()..color = const Color(0xFFFF6F91));
      case 4:
        c.drawCircle(o, 4.6, Paint()..color = const Color(0xFFFF8FA3));
        c.drawCircle(o + const Offset(-1.4, -1.4), 1.3,
            Paint()..color = Colors.white.withValues(alpha: 0.8));
      default:
        c.drawOval(Rect.fromCenter(center: o, width: 6, height: 5),
            Paint()..color = _brow);
    }
  }

  static void drawMouth(Canvas c, String id, {bool happy = false}) {
    final n = _num(id);
    if (happy && (n == 1 || n == 2 || n == 4 || n == 6)) {
      _openSmile(c);
      return;
    }
    switch (n) {
      case 2:
        final p = Path()
          ..moveTo(128, 228)
          ..quadraticBezierTo(134, 236, 140, 228.5)
          ..quadraticBezierTo(146, 236, 152, 228);
        c.drawPath(p, _line(_ink, 3));
      case 3:
        _openSmile(c);
      case 4:
        c.drawOval(
            Rect.fromCenter(
                center: const Offset(140, 232), width: 9, height: 11),
            Paint()..color = _mouthRed);
        c.drawOval(
            Rect.fromCenter(
                center: const Offset(140, 232), width: 9, height: 11),
            _line(_ink, 2.2));
      case 5:
        final p = Path()
          ..moveTo(125, 226)
          ..quadraticBezierTo(140, 249, 155, 226)
          ..close();
        c.drawPath(p, Paint()..color = _mouthRed);
        c.save();
        c.clipPath(p);
        c.drawRect(const Rect.fromLTWH(120, 224, 40, 6.5),
            Paint()..color = Colors.white);
        c.restore();
        c.drawPath(p, _line(_ink, 2.4)..strokeJoin = StrokeJoin.round);
      case 6:
        final tongue = RRect.fromRectAndRadius(
            const Rect.fromLTWH(141, 229, 9, 11), const Radius.circular(4.5));
        c.drawRRect(tongue, Paint()..color = const Color(0xFFFF8F8F));
        c.drawPath(_smile(), _line(_ink, 3.2));
      default:
        c.drawPath(_smile(), _line(_ink, 3.2));
    }
  }

  static Path _smile() => Path()
    ..moveTo(129.5, 229)
    ..quadraticBezierTo(140, 238.5, 150.5, 229);

  static void _openSmile(Canvas c) {
    final p = Path()
      ..moveTo(127, 227.5)
      ..quadraticBezierTo(140, 249, 153, 227.5)
      ..close();
    c.drawPath(p, Paint()..color = _mouthRed);
    c.save();
    c.clipPath(p);
    c.drawOval(
        Rect.fromCenter(
            center: const Offset(140, 238.8), width: 12.4, height: 6.8),
        Paint()..color = const Color(0xFFFF8F8F));
    c.restore();
    c.drawPath(p, _line(_ink, 2.4)..strokeJoin = StrokeJoin.round);
  }

  // ── 도형 헬퍼 ───────────────────────────────────────────────────────
  static int _num(String id) => int.tryParse(id.split('_').last) ?? 1;

  static Paint _line(Color color, double w) => Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = w
    ..strokeCap = StrokeCap.round
    ..color = color;

  static void _heart(Canvas c, Offset o, double r, Paint paint) {
    final p = Path()
      ..moveTo(o.dx, o.dy + r * 0.9)
      ..cubicTo(o.dx - r * 1.5, o.dy - r * 0.1, o.dx - r * 0.6, o.dy - r * 1.1,
          o.dx, o.dy - r * 0.3)
      ..cubicTo(o.dx + r * 0.6, o.dy - r * 1.1, o.dx + r * 1.5, o.dy - r * 0.1,
          o.dx, o.dy + r * 0.9);
    c.drawPath(p, paint);
  }

  static void _star(Canvas c, Offset o, double r) {
    final p = Path();
    for (var i = 0; i < 10; i++) {
      final rad = i.isEven ? r : r * 0.45;
      final a = -math.pi / 2 + i * math.pi / 5;
      final pt = Offset(o.dx + rad * math.cos(a), o.dy + rad * math.sin(a));
      i == 0 ? p.moveTo(pt.dx, pt.dy) : p.lineTo(pt.dx, pt.dy);
    }
    p.close();
    c.drawPath(p, Paint()..color = const Color(0xFFFFCF4A));
    c.drawPath(
        p, _line(const Color(0xFFF0A928), 1.6)..strokeJoin = StrokeJoin.round);
  }
}

class _PotPalette {
  const _PotPalette(this.top, this.bottom, this.rim, this.rimLine);
  final Color top, bottom, rim, rimLine;
}

/// 화분 + 식물 + 얼굴을 한 번에 그린다. null인 부위는 그리지 않는다.
class PotArtPainter extends CustomPainter {
  const PotArtPainter({
    required this.stage,
    required this.potId,
    this.eyesId,
    this.noseId,
    this.mouthId,
    this.cheekId,
    this.happy = false,
  });

  final int stage;
  final String potId;
  final String? eyesId, noseId, mouthId, cheekId;
  final bool happy;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / PotArt.base);
    PotArt.drawPot(canvas, potId);
    PotArt.drawPlant(canvas, stage);
    if (cheekId != null) PotArt.drawCheeks(canvas, cheekId!);
    if (mouthId != null) PotArt.drawMouth(canvas, mouthId!, happy: happy);
    if (noseId != null) PotArt.drawNose(canvas, noseId!);
    if (eyesId != null) PotArt.drawEyes(canvas, eyesId!, happy: happy);
    canvas.restore();
  }

  @override
  bool shouldRepaint(PotArtPainter o) =>
      stage != o.stage ||
      potId != o.potId ||
      eyesId != o.eyesId ||
      noseId != o.noseId ||
      mouthId != o.mouthId ||
      cheekId != o.cheekId ||
      happy != o.happy;
}

/// 바닥 그림자. [lift]는 점프로 뜬 높이(캔버스 비율).
class PotShadowPainter extends CustomPainter {
  const PotShadowPainter({this.lift = 0});
  final double lift;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / PotArt.base);
    PotArt.drawShadow(canvas, lift: lift);
    canvas.restore();
  }

  @override
  bool shouldRepaint(PotShadowPainter o) => lift != o.lift;
}

/// 꾸미기 그리드용 부품 썸네일. 카테고리별 영역만 잘라 정사각 칸에 맞춰 그린다.
class PotPartThumbPainter extends CustomPainter {
  const PotPartThumbPainter({required this.category, required this.id});

  final DecorationCategory category;
  final String id;

  static const _regions = {
    DecorationCategory.pot: Rect.fromLTWH(65, 130, 150, 150),
    DecorationCategory.eyes: Rect.fromLTWH(90, 148, 100, 100),
    DecorationCategory.nose: Rect.fromLTWH(120, 196, 40, 40),
    DecorationCategory.mouth: Rect.fromLTWH(112, 205, 56, 56),
    DecorationCategory.cheek: Rect.fromLTWH(80, 158, 120, 120),
  };

  @override
  void paint(Canvas canvas, Size size) {
    final r = _regions[category];
    if (r == null) return;
    canvas.save();
    canvas.scale(size.width / r.width);
    canvas.translate(-r.left, -r.top);
    switch (category) {
      case DecorationCategory.pot:
        PotArt.drawPot(canvas, id);
      case DecorationCategory.eyes:
        PotArt.drawEyes(canvas, id);
      case DecorationCategory.nose:
        PotArt.drawNose(canvas, id);
      case DecorationCategory.mouth:
        PotArt.drawMouth(canvas, id);
      case DecorationCategory.cheek:
        PotArt.drawCheeks(canvas, id);
      default:
        break;
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(PotPartThumbPainter o) =>
      category != o.category || id != o.id;
}
