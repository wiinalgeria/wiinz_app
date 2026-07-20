import 'package:flutter/material.dart';

/// The WIINZ plastic-bottle mark, drawn in code (no asset) so it scales cleanly
/// and can be tinted anywhere — map pins, cards, empty states.
///
/// Shape: screw cap, short neck, sloping shoulders, straight body with a label
/// band, and a petaloid (ridged) base. Designed in a 100×200 box and scaled to
/// whatever rect it's painted into, so proportions never distort.
const double _kW = 100, _kH = 200;

/// Outer silhouette of the bottle, mapped into [r].
Path bottleOutline(Rect r) {
  final sx = r.width / _kW, sy = r.height / _kH;
  double x(double v) => r.left + v * sx;
  double y(double v) => r.top + v * sy;

  final p = Path();
  // ---- cap (rounded top) ----
  p.moveTo(x(36), y(26));
  p.lineTo(x(36), y(12));
  p.quadraticBezierTo(x(36), y(5), x(43), y(5));
  p.lineTo(x(57), y(5));
  p.quadraticBezierTo(x(64), y(5), x(64), y(12));
  p.lineTo(x(64), y(26));
  // ---- neck ----
  p.lineTo(x(62), y(26));
  p.lineTo(x(62), y(38));
  // ---- right shoulder → body ----
  p.cubicTo(x(62), y(48), x(80), y(52), x(80), y(70));
  p.lineTo(x(80), y(168));
  // ---- petaloid base (three shallow ridges) ----
  p.quadraticBezierTo(x(80), y(186), x(70), y(188));
  p.quadraticBezierTo(x(65), y(178), x(60), y(188));
  p.quadraticBezierTo(x(55), y(178), x(50), y(188));
  p.quadraticBezierTo(x(45), y(178), x(40), y(188));
  p.quadraticBezierTo(x(35), y(178), x(30), y(188));
  p.quadraticBezierTo(x(20), y(186), x(20), y(168));
  // ---- left body → shoulder ----
  p.lineTo(x(20), y(70));
  p.cubicTo(x(20), y(52), x(38), y(48), x(38), y(38));
  p.lineTo(x(38), y(26));
  p.close();
  return p;
}

/// Interior detail strokes (label band + highlights) mapped into [r].
List<Path> bottleDetails(Rect r) {
  final sx = r.width / _kW, sy = r.height / _kH;
  double x(double v) => r.left + v * sx;
  double y(double v) => r.top + v * sy;

  final label = Path()
    ..moveTo(x(20), y(88))..lineTo(x(80), y(88))
    ..moveTo(x(20), y(146))..lineTo(x(80), y(146));
  // shoulder highlight — the little curved stroke on the reference
  final shine = Path()
    ..moveTo(x(33), y(44))
    ..cubicTo(x(29), y(52), x(28), y(58), x(28), y(66));
  // short vertical ticks in the body and base
  final ticks = Path()
    ..moveTo(x(29), y(98))..lineTo(x(29), y(136))
    ..moveTo(x(29), y(158))..lineTo(x(29), y(176));
  return [label, shine, ticks];
}

/// Paint the bottle into [canvas] inside [rect]. Used by the map-marker
/// renderer (which needs a raw canvas) as well as the widget below.
void paintBottle(Canvas canvas, Rect rect, Color color, {double strokeScale = 1}) {
  final stroke = Paint()
    ..color = color
    ..style = PaintingStyle.stroke
    ..strokeWidth = (rect.width / _kW) * 8 * strokeScale
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round
    ..isAntiAlias = true;
  canvas.drawPath(bottleOutline(rect), stroke);
  final thin = Paint()
    ..color = color
    ..style = PaintingStyle.stroke
    ..strokeWidth = (rect.width / _kW) * 6 * strokeScale
    ..strokeCap = StrokeCap.round
    ..isAntiAlias = true;
  for (final d in bottleDetails(rect)) {
    canvas.drawPath(d, thin);
  }
}

class _BottlePainter extends CustomPainter {
  final Color color;
  final double strokeScale;
  const _BottlePainter(this.color, this.strokeScale);

  @override
  void paint(Canvas canvas, Size size) {
    // keep the 1:2 aspect ratio centred inside whatever box we're given
    final h = size.height, w = h / 2;
    final rect = Rect.fromLTWH((size.width - w) / 2, 0, w, h);
    paintBottle(canvas, rect, color, strokeScale: strokeScale);
  }

  @override
  bool shouldRepaint(_BottlePainter old) => old.color != color || old.strokeScale != strokeScale;
}

/// Bottle mark as a widget. [size] is the HEIGHT; width is half of it.
class BottleIcon extends StatelessWidget {
  final double size;
  final Color color;
  final double strokeScale;
  const BottleIcon({super.key, this.size = 24, this.color = const Color(0xFF34801f), this.strokeScale = 1});

  @override
  Widget build(BuildContext context) => SizedBox(
        width: size / 2, height: size,
        child: CustomPaint(painter: _BottlePainter(color, strokeScale)),
      );
}
