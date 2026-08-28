import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import 'projector_calculator_screen.dart' show InstallationType;

/// Side-profile schematic of the projector-to-screen setup — the same kind of diagram
/// BenQ's own projector calculator (projectorcalculator.benq.com) shows next to its throw
/// distance numbers, so a user can see what "2.66 m throw distance" actually looks like in
/// their room instead of just reading a number.
class ThrowDistanceDiagram extends StatelessWidget {
  const ThrowDistanceDiagram({
    super.key,
    required this.installationType,
    required this.throwDistanceMeters,
    required this.screenHeightMeters,
    this.roomLengthMeters,
    this.roomHeightMeters,
  });

  final InstallationType installationType;
  final double throwDistanceMeters;
  final double screenHeightMeters;
  final double? roomLengthMeters;
  final double? roomHeightMeters;

  static const _minHeight = 140.0;
  static const _maxHeight = 240.0;
  static const _pad = 24.0; // combined left+right / top+bottom padding budget below

  @override
  Widget build(BuildContext context) {
    final totalLengthM = [roomLengthMeters ?? 0, throwDistanceMeters * 1.15].reduce((a, b) => a > b ? a : b);
    final totalHeightM = [
      roomHeightMeters ?? 0,
      screenHeightMeters + 0.6,
      2.4,
    ].reduce((a, b) => a > b ? a : b);

    return LayoutBuilder(
      builder: (context, constraints) {
        // Size the card to the room's actual length:height proportions (fit the full
        // available width) instead of a fixed height — a fixed height forces whichever
        // dimension is smaller to dominate the scale, leaving the diagram stranded in a
        // fraction of the card with a large dead gap, which is what happened before this.
        final drawWidth = constraints.maxWidth - _pad;
        final naturalHeight = (totalHeightM / totalLengthM) * drawWidth + _pad;
        final height = naturalHeight.clamp(_minHeight, _maxHeight);

        return Container(
          height: height,
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          child: CustomPaint(
            painter: _ThrowDistancePainter(
              installationType: installationType,
              throwDistanceMeters: throwDistanceMeters,
              screenHeightMeters: screenHeightMeters,
              roomLengthMeters: roomLengthMeters,
              roomHeightMeters: roomHeightMeters,
              textColor: AppColors.textSecondary,
              lineColor: AppColors.border,
              accentColor: AppColors.gold,
            ),
            size: Size.infinite,
          ),
        );
      },
    );
  }
}

class _ThrowDistancePainter extends CustomPainter {
  _ThrowDistancePainter({
    required this.installationType,
    required this.throwDistanceMeters,
    required this.screenHeightMeters,
    required this.roomLengthMeters,
    required this.roomHeightMeters,
    required this.textColor,
    required this.lineColor,
    required this.accentColor,
  });

  final InstallationType installationType;
  final double throwDistanceMeters;
  final double screenHeightMeters;
  final double? roomLengthMeters;
  final double? roomHeightMeters;
  final Color textColor;
  final Color lineColor;
  final Color accentColor;

  static const _screenFloorGapMeters = 0.3;
  static const _deskProjectorHeightMeters = 0.75;
  static const _ceilingDropMeters = 0.15;

  @override
  void paint(Canvas canvas, Size size) {
    final totalLengthM = [roomLengthMeters ?? 0, throwDistanceMeters * 1.15]
        .reduce((a, b) => a > b ? a : b);
    final totalHeightM = [
      roomHeightMeters ?? 0,
      screenHeightMeters + _screenFloorGapMeters + 0.3,
      2.4,
    ].reduce((a, b) => a > b ? a : b);

    const leftPad = 12.0, rightPad = 44.0, topPad = 20.0, bottomPad = 28.0;
    final drawWidth = size.width - leftPad - rightPad;
    final drawHeight = size.height - topPad - bottomPad;
    final scale = [drawWidth / totalLengthM, drawHeight / totalHeightM].reduce((a, b) => a < b ? a : b);

    final floorY = size.height - bottomPad;
    double x(double metersFromLeft) => leftPad + metersFromLeft * scale;
    double y(double metersFromFloor) => floorY - metersFromFloor * scale;

    final linePaint = Paint()
      ..color = lineColor
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    final dashedPaint = Paint()
      ..color = accentColor
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    // Floor.
    canvas.drawLine(Offset(x(0), floorY), Offset(x(totalLengthM), floorY), linePaint);

    // Screen wall + screen rectangle, flush to the right edge of the drawable area.
    final screenX = x(totalLengthM);
    final screenBottomY = y(_screenFloorGapMeters);
    final screenTopY = y(_screenFloorGapMeters + screenHeightMeters);
    canvas.drawLine(Offset(screenX, floorY), Offset(screenX, y(totalHeightM)), linePaint);
    final screenPaint = Paint()
      ..color = accentColor.withValues(alpha: 0.15)
      ..style = PaintingStyle.fill;
    final screenRect = Rect.fromPoints(Offset(screenX - 4, screenTopY), Offset(screenX, screenBottomY));
    canvas.drawRect(screenRect, screenPaint);
    canvas.drawRect(screenRect, linePaint..style = PaintingStyle.stroke);

    // Ceiling (dashed) if a room height is known.
    if (roomHeightMeters != null) {
      _drawDashedLine(canvas, Offset(x(0), y(roomHeightMeters!)), Offset(x(totalLengthM), y(roomHeightMeters!)), lineColor);
    }

    // Projector position + throw-distance line.
    final projectorHeightM = installationType == InstallationType.ceiling
        ? (roomHeightMeters ?? totalHeightM) - _ceilingDropMeters
        : _deskProjectorHeightMeters;
    final projectorX = totalLengthM - throwDistanceMeters;
    final projOffset = Offset(x(projectorX), y(projectorHeightM));
    final screenTargetOffset = Offset(screenX, y(projectorHeightM));

    _drawDashedLine(canvas, projOffset, screenTargetOffset, accentColor);

    // Projector glyph: small filled circle + a short mount stub.
    canvas.drawCircle(projOffset, 5, Paint()..color = accentColor);
    if (installationType == InstallationType.ceiling) {
      canvas.drawLine(projOffset, Offset(projOffset.dx, y(roomHeightMeters ?? totalHeightM)), dashedPaint);
    } else {
      canvas.drawLine(projOffset, Offset(projOffset.dx, floorY), linePaint);
    }

    // Labels.
    _drawLabel(canvas, '${throwDistanceMeters.toStringAsFixed(2)} m', Offset((projOffset.dx + screenTargetOffset.dx) / 2, projOffset.dy - 16), textColor, accentColor);
    _drawLabel(canvas, '${screenHeightMeters.toStringAsFixed(2)} m', Offset(screenX + 20, (screenTopY + screenBottomY) / 2), textColor, textColor, rotated: true);
  }

  void _drawDashedLine(Canvas canvas, Offset start, Offset end, Color color) {
    const dashLength = 5.0, gapLength = 4.0;
    final total = (end - start).distance;
    if (total == 0) return;
    final direction = (end - start) / total;
    var covered = 0.0;
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    while (covered < total) {
      final segStart = start + direction * covered;
      final segEnd = start + direction * (covered + dashLength).clamp(0, total);
      canvas.drawLine(segStart, segEnd, paint);
      covered += dashLength + gapLength;
    }
  }

  void _drawLabel(Canvas canvas, String text, Offset center, Color textColor, Color chipColor, {bool rotated = false}) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: TextStyle(color: textColor, fontSize: 11, fontWeight: FontWeight.w600)),
      textDirection: TextDirection.ltr,
    )..layout();
    canvas.save();
    canvas.translate(center.dx, center.dy);
    if (rotated) canvas.rotate(-1.5708);
    painter.paint(canvas, Offset(-painter.width / 2, -painter.height / 2));
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _ThrowDistancePainter oldDelegate) {
    return oldDelegate.installationType != installationType ||
        oldDelegate.throwDistanceMeters != throwDistanceMeters ||
        oldDelegate.screenHeightMeters != screenHeightMeters ||
        oldDelegate.roomLengthMeters != roomLengthMeters ||
        oldDelegate.roomHeightMeters != roomHeightMeters;
  }
}
