import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Boarding-pass [OutlinedBorder] for flight result cards — notches + dashed
/// tear. Independent of bus/car borders; do not import from those features.
class FlightTicketBorder extends OutlinedBorder {
  const FlightTicketBorder({
    this.radius = 20,
    this.notchRadius = 10,
    this.notchOffsetFromBottom = 64,
    this.dashColor = const Color(0xFFE3E9F2),
    super.side = BorderSide.none,
  });

  final double radius;
  final double notchRadius;
  final double notchOffsetFromBottom;
  final Color dashColor;

  @override
  EdgeInsetsGeometry get dimensions => EdgeInsets.zero;

  Path _buildPath(Rect rect) {
    final double r = radius;
    final double nr = notchRadius;
    final double ny = rect.bottom - notchOffsetFromBottom;
    final Radius corner = Radius.circular(r);

    return Path()
      ..moveTo(rect.left + r, rect.top)
      ..lineTo(rect.right - r, rect.top)
      ..arcToPoint(Offset(rect.right, rect.top + r), radius: corner)
      ..lineTo(rect.right, ny - nr)
      ..arcTo(
        Rect.fromCircle(center: Offset(rect.right, ny), radius: nr),
        -math.pi / 2,
        -math.pi,
        false,
      )
      ..lineTo(rect.right, rect.bottom - r)
      ..arcToPoint(Offset(rect.right - r, rect.bottom), radius: corner)
      ..lineTo(rect.left + r, rect.bottom)
      ..arcToPoint(Offset(rect.left, rect.bottom - r), radius: corner)
      ..lineTo(rect.left, ny + nr)
      ..arcTo(
        Rect.fromCircle(center: Offset(rect.left, ny), radius: nr),
        math.pi / 2,
        -math.pi,
        false,
      )
      ..lineTo(rect.left, rect.top + r)
      ..arcToPoint(Offset(rect.left + r, rect.top), radius: corner)
      ..close();
  }

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) =>
      _buildPath(rect);

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) =>
      _buildPath(rect);

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {
    final double ny = rect.bottom - notchOffsetFromBottom;
    final Paint dashPaint = Paint()
      ..color = dashColor
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;

    const double dash = 5;
    const double gap = 4;
    double x = rect.left + notchRadius + 4;
    final double endX = rect.right - notchRadius - 4;
    while (x < endX) {
      canvas.drawLine(
        Offset(x, ny),
        Offset(math.min(x + dash, endX), ny),
        dashPaint,
      );
      x += dash + gap;
    }

    if (side.style != BorderStyle.none) {
      canvas.drawPath(getOuterPath(rect), side.toPaint());
    }
  }

  @override
  FlightTicketBorder copyWith({
    BorderSide? side,
    double? radius,
    double? notchRadius,
    double? notchOffsetFromBottom,
    Color? dashColor,
  }) {
    return FlightTicketBorder(
      side: side ?? this.side,
      radius: radius ?? this.radius,
      notchRadius: notchRadius ?? this.notchRadius,
      notchOffsetFromBottom:
          notchOffsetFromBottom ?? this.notchOffsetFromBottom,
      dashColor: dashColor ?? this.dashColor,
    );
  }

  @override
  ShapeBorder scale(double t) => FlightTicketBorder(
        side: side.scale(t),
        radius: radius * t,
        notchRadius: notchRadius * t,
        notchOffsetFromBottom: notchOffsetFromBottom * t,
        dashColor: dashColor,
      );

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is FlightTicketBorder &&
        other.side == side &&
        other.radius == radius &&
        other.notchRadius == notchRadius &&
        other.notchOffsetFromBottom == notchOffsetFromBottom &&
        other.dashColor == dashColor;
  }

  @override
  int get hashCode =>
      Object.hash(side, radius, notchRadius, notchOffsetFromBottom, dashColor);
}
