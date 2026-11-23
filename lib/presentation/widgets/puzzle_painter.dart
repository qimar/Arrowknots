import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../data/models/game_models.dart';

class StaticPuzzlePainter extends CustomPainter {
  final LevelConfig level;
  final Set<int> hiddenLineIds;
  final double introProgress;
  final double scale;
  final double translateX;
  final double translateY;
  
  final Color dotColor;
  final Color baseLineColor;

  StaticPuzzlePainter({
    required this.level,
    required this.hiddenLineIds,
    required this.scale,
    required this.translateX,
    required this.translateY,
    required this.dotColor,
    required this.baseLineColor,
    this.introProgress = 1.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.translate(translateX, translateY);
    canvas.scale(scale);

    final double referenceExtent = 1.0;

    // Subtle grid dots
    final dotPaint = Paint()
      ..color = dotColor
      ..style = PaintingStyle.fill;
    final double dotRadius = referenceExtent * 0.06;

    for (int x = 0; x < level.matrixWidth; x++) {
      for (int y = 0; y < level.matrixHeight; y++) {
        if (level.isShapeLevel && level.shapeMask != null) {
          if (!level.shapeMask!.contains(Point2D(x, y))) {
            continue;
          }
        }
        canvas.drawCircle(Offset(x.toDouble(), y.toDouble()), dotRadius, dotPaint);
      }
    }

    final double sleekStrokeWidth = referenceExtent * 0.12; // Thinner lines
    final double chevronSize = referenceExtent * 0.22; // Arrowhead width

    final linePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = sleekStrokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    for (var line in level.lines) {
      if (line.isExtracted || hiddenLineIds.contains(line.id)) continue;

      // Calculate staggered intro animation (from center outwards)
      double cx = (level.matrixWidth - 1) / 2.0;
      double cy = (level.matrixHeight - 1) / 2.0;
      double tailX = line.bodyPoints.first.x.toDouble();
      double tailY = line.bodyPoints.first.y.toDouble();
      double distFromCenter = math.sqrt(math.pow(tailX - cx, 2) + math.pow(tailY - cy, 2));
      double maxDist = math.sqrt(math.pow(cx, 2) + math.pow(cy, 2));
      
      // Delay fraction based on distance. Max delay is 0.45.
      double staggerDelay = maxDist > 0 ? (distFromCenter / maxDist) * 0.45 : 0.0;
      double lineProgress = (introProgress - staggerDelay) / (1.0 - staggerDelay);
      lineProgress = lineProgress.clamp(0.0, 1.0);
      
      linePaint.color = baseLineColor; // 100% opacity as requested

      // 2. Build out the path coordinates in grid space
      List<Offset> worldPoints = line.bodyPoints.map((pt) => Offset(pt.x.toDouble(), pt.y.toDouble())).toList();

      // Grow path logic
      if (lineProgress < 1.0) {
        worldPoints = _growSnakeSubPath(worldPoints, lineProgress);
      }
      if (worldPoints.length < 2) continue;

      List<Offset> calculatedSnakeBody = worldPoints;
      Offset workingHead = calculatedSnakeBody.last;

      // Always use the canonical exitDirection — this is the true mechanical direction.
      double exitDx = 0, exitDy = 0;
      switch (line.exitDirection) {
        case MoveDirection.up:    exitDy = -1; break;
        case MoveDirection.down:  exitDy =  1; break;
        case MoveDirection.left:  exitDx = -1; break;
        case MoveDirection.right: exitDx =  1; break;
      }

      final path = Path();
      path.moveTo(calculatedSnakeBody.first.dx, calculatedSnakeBody.first.dy);
      
      for (int i = 1; i < calculatedSnakeBody.length; i++) {
        path.lineTo(calculatedSnakeBody[i].dx, calculatedSnakeBody[i].dy);
      }

      canvas.drawPath(path, linePaint);

      // Draw arrowhead
      if (lineProgress < 1.0) {
        double stemLength = 0.0;
        for (int i = 0; i < calculatedSnakeBody.length - 1; i++) {
          stemLength += (calculatedSnakeBody[i + 1] - calculatedSnakeBody[i]).distance;
        }
        if (stemLength >= 0.3) {
          _drawSolidChevron(
              canvas, workingHead.dx, workingHead.dy, line.exitDirection, chevronSize, baseLineColor);
        }
      } else {
        // Fully grown: use the classic extension + gap so head floats just ahead of stem.
        double gapDistance = 0.25;
        double extensionAmount = 0.30;
        Offset arrowheadCenter = Offset(
          workingHead.dx + exitDx * extensionAmount,
          workingHead.dy + exitDy * extensionAmount,
        );
        double pushBack = 0.15;
        Offset stemEnd = Offset(
          workingHead.dx + exitDx * (extensionAmount - pushBack),
          workingHead.dy + exitDy * (extensionAmount - pushBack),
        );
        if (calculatedSnakeBody.length >= 2) {
          final secondToLast = calculatedSnakeBody[calculatedSnakeBody.length - 2];
          final dist = (stemEnd - secondToLast).distance;
          if (dist > gapDistance) {
            path.lineTo(stemEnd.dx, stemEnd.dy);
            canvas.drawPath(path, linePaint);
          }
        }
        _drawSolidChevron(
            canvas, arrowheadCenter.dx, arrowheadCenter.dy, line.exitDirection, chevronSize, baseLineColor);
      }
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant StaticPuzzlePainter oldDelegate) {
    return oldDelegate.introProgress != introProgress ||
           oldDelegate.scale != scale ||
           oldDelegate.translateX != translateX ||
           oldDelegate.translateY != translateY ||
           oldDelegate.level != level; // Re-evaluates when lines extract or active lines change
  }
}

class ActivePuzzlePainter extends CustomPainter {
  final LevelConfig level;
  final Set<int> activeLineIds;
  final int? collidingLineId;
  final int? obstacleLineId;
  final int? animatingLineId;
  final int? hintedLineId;
  final double animationProgress;
  final double collisionProgress;
  final double pulseProgress;
  final double scale;
  final double translateX;
  final double translateY;
  
  final Color dotColor;
  final Color baseLineColor;

  ActivePuzzlePainter({
    required this.level,
    required this.activeLineIds,
    required this.scale,
    required this.translateX,
    required this.translateY,
    required this.dotColor,
    required this.baseLineColor,
    this.collidingLineId,
    this.obstacleLineId,
    this.animatingLineId,
    this.hintedLineId,
    this.animationProgress = 0.0,
    this.collisionProgress = 0.0,
    this.pulseProgress = 0.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (activeLineIds.isEmpty) return; // Nothing to draw

    canvas.save();
    canvas.translate(translateX, translateY);
    canvas.scale(scale);

    final double referenceExtent = 1.0;
    final double sleekStrokeWidth = referenceExtent * 0.12; 
    final double chevronSize = referenceExtent * 0.22;

    final linePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = sleekStrokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    for (var line in level.lines) {
      if (!activeLineIds.contains(line.id)) continue;
      
      Color renderColor = baseLineColor;
      if (line.id == collidingLineId || line.id == obstacleLineId) {
        renderColor = AppColors.errorFlash;
      } else if (line.id == animatingLineId) {
        renderColor = AppColors.successHighlight;
      }
      
      linePaint.color = renderColor;

      List<Offset> worldPoints = [];
      for (var pt in line.bodyPoints) {
        double dx = pt.x.toDouble();
        double dy = pt.y.toDouble();

        if (line.id == collidingLineId) {
          double shift = collisionProgress * 0.5;
          switch (line.exitDirection) {
            case MoveDirection.up:    dy -= shift; break;
            case MoveDirection.down:  dy += shift; break;
            case MoveDirection.left:  dx -= shift; break;
            case MoveDirection.right: dx += shift; break;
          }
        }
        worldPoints.add(Offset(dx, dy));
      }

      double trimProgress = line.animatedDistance.clamp(0.0, 0.999);

      if (line.id == animatingLineId) {
        double naturalLength = 0.0;
        for (int i = 0; i < worldPoints.length - 1; i++) {
          naturalLength += (worldPoints[i + 1] - worldPoints[i]).distance;
        }

        double offscreenFlightDistance = math.max(level.matrixWidth, level.matrixHeight) * 2.0;
        double currentExtension = animationProgress * offscreenFlightDistance;
        
        Offset headPos = worldPoints.last;
        Offset extendedTarget = headPos;

        switch (line.exitDirection) {
          case MoveDirection.up:    extendedTarget = Offset(headPos.dx, headPos.dy - currentExtension); break;
          case MoveDirection.down:  extendedTarget = Offset(headPos.dx, headPos.dy + currentExtension); break;
          case MoveDirection.left:  extendedTarget = Offset(headPos.dx - currentExtension, headPos.dy); break;
          case MoveDirection.right: extendedTarget = Offset(headPos.dx + currentExtension, headPos.dy); break;
        }
        
        if (currentExtension > 0) {
          worldPoints.add(extendedTarget);
        }
        
        double totalNewLength = naturalLength + currentExtension;
        if (totalNewLength > 0) {
           trimProgress = currentExtension / totalNewLength;
        } else {
           trimProgress = 0.0;
        }
      }

      List<Offset> calculatedSnakeBody = _extractSnakeSubPath(worldPoints, trimProgress);
      if (calculatedSnakeBody.length < 2) continue;
      Offset workingHead = calculatedSnakeBody.last;

      double exitDx = 0, exitDy = 0;
      switch (line.exitDirection) {
        case MoveDirection.up:    exitDy = -1; break;
        case MoveDirection.down:  exitDy =  1; break;
        case MoveDirection.left:  exitDx = -1; break;
        case MoveDirection.right: exitDx =  1; break;
      }

      if (line.id == hintedLineId) {
        final int alpha = (150 + 105 * math.sin(pulseProgress * math.pi * 2)).toInt().clamp(0, 255);
        final hintPaint = Paint()
          ..color = AppColors.buttonBlue.withAlpha(alpha)
          ..style = PaintingStyle.fill;
          
        double step = 0.35;
        double currX = workingHead.dx + exitDx * step;
        double currY = workingHead.dy + exitDy * step;
        
        while (currX >= -10.0 && currX <= level.matrixWidth + 10.0 && currY >= -10.0 && currY <= level.matrixHeight + 10.0) {
          canvas.drawCircle(Offset(currX, currY), referenceExtent * 0.08, hintPaint);
          currX += exitDx * step;
          currY += exitDy * step;
        }
      }

      final path = Path();
      path.moveTo(calculatedSnakeBody.first.dx, calculatedSnakeBody.first.dy);
      
      for (int i = 1; i < calculatedSnakeBody.length; i++) {
        path.lineTo(calculatedSnakeBody[i].dx, calculatedSnakeBody[i].dy);
      }

      canvas.drawPath(path, linePaint);

      double gapDistance = (line.id == animatingLineId) ? 0.0 : 0.25;
      double extensionAmount = 0.30;
      Offset arrowheadCenter = Offset(
        workingHead.dx + exitDx * extensionAmount,
        workingHead.dy + exitDy * extensionAmount,
      );
      double pushBack = 0.15;
      Offset stemEnd = Offset(
        workingHead.dx + exitDx * (extensionAmount - pushBack),
        workingHead.dy + exitDy * (extensionAmount - pushBack),
      );
      if (calculatedSnakeBody.length >= 2) {
        final secondToLast = calculatedSnakeBody[calculatedSnakeBody.length - 2];
        final dist = (stemEnd - secondToLast).distance;
        if (dist > gapDistance) {
          path.lineTo(stemEnd.dx, stemEnd.dy);
          canvas.drawPath(path, linePaint);
        }
      }
      _drawSolidChevron(
          canvas, arrowheadCenter.dx, arrowheadCenter.dy, line.exitDirection, chevronSize, renderColor);
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant ActivePuzzlePainter oldDelegate) {
    return oldDelegate.animationProgress != animationProgress ||
           oldDelegate.collisionProgress != collisionProgress ||
           oldDelegate.pulseProgress != pulseProgress ||
           oldDelegate.animatingLineId != animatingLineId ||
           oldDelegate.collidingLineId != collidingLineId ||
           oldDelegate.obstacleLineId != obstacleLineId ||
           oldDelegate.hintedLineId != hintedLineId ||
           oldDelegate.scale != scale ||
           oldDelegate.translateX != translateX ||
           oldDelegate.translateY != translateY;
  }
}

List<Offset> _growSnakeSubPath(List<Offset> sourcePoints, double growthFraction) {
  if (growthFraction <= 0.0) return [];
  if (growthFraction >= 1.0) return sourcePoints;

    double totalLength = 0.0;
    for (int i = 0; i < sourcePoints.length - 1; i++) {
      totalLength += (sourcePoints[i + 1] - sourcePoints[i]).distance;
    }

    double lengthToGrow = totalLength * growthFraction;
    double accumulatedLength = 0.0;
    List<Offset> grownPoints = [sourcePoints.first];

    for (int i = 0; i < sourcePoints.length - 1; i++) {
      Offset pStart = sourcePoints[i];
      Offset pEnd = sourcePoints[i + 1];
      double segLength = (pEnd - pStart).distance;

      if (accumulatedLength + segLength >= lengthToGrow) {
        double segmentGrowthDistance = lengthToGrow - accumulatedLength;
        double ratio = segmentGrowthDistance / segLength;
        Offset partialEndOffset = Offset.lerp(pStart, pEnd, ratio)!;

        grownPoints.add(partialEndOffset);
        break;
      } else {
        grownPoints.add(pEnd);
        accumulatedLength += segLength;
      }
    }

    return grownPoints;
  }

List<Offset> _extractSnakeSubPath(List<Offset> sourcePoints, double fractionalDistanceToTrim) {
  if (fractionalDistanceToTrim <= 0.0) return sourcePoints;
  if (fractionalDistanceToTrim >= 1.0) return [];

    double totalLength = 0.0;
    for (int i = 0; i < sourcePoints.length - 1; i++) {
      totalLength += (sourcePoints[i + 1] - sourcePoints[i]).distance;
    }

    double lengthToTrim = totalLength * fractionalDistanceToTrim;
    double accumulatedLength = 0.0;
    List<Offset> remainingPoints = [];

    for (int i = 0; i < sourcePoints.length - 1; i++) {
      Offset pStart = sourcePoints[i];
      Offset pEnd = sourcePoints[i + 1];
      double segLength = (pEnd - pStart).distance;

      if (accumulatedLength + segLength > lengthToTrim) {
        // Find exactly where the tail currently cuts through this segment
        double segmentTrimDistance = lengthToTrim - accumulatedLength;
        double ratio = segmentTrimDistance / segLength;
        Offset partialStartOffset = Offset.lerp(pStart, pEnd, ratio)!;

        remainingPoints.add(partialStartOffset);
        for (int j = i + 1; j < sourcePoints.length; j++) {
          remainingPoints.add(sourcePoints[j]);
        }
        break;
      }
      accumulatedLength += segLength;
    }

    return remainingPoints;
  }

void _drawSolidChevron(
    Canvas canvas, double cx, double cy, MoveDirection direction, double size, Color color) {
  // Arrowhead size adjustments
    double width = size * 1.0;
    double height = size * 0.9;
    
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill
      ..strokeJoin = StrokeJoin.round // Makes the outer points of the filled shape slightly rounded if we use stroke, but since it's fill we should just draw a path. To get rounded points on a fill, we can combine fill and a small stroke.
      ..strokeWidth = size * 0.15;
      
    // Draw twice: once for fill, once for stroke to get rounded corners
    final strokePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round
      ..strokeWidth = size * 0.2;

    final path = Path();
    switch (direction) {
      case MoveDirection.up:
        path.moveTo(cx - width * 0.5, cy + height * 0.3);
        path.lineTo(cx, cy - height * 0.7);
        path.lineTo(cx + width * 0.5, cy + height * 0.3);
        path.lineTo(cx, cy + height * 0.1); // Inner cutout for arrowhead shape
        break;
      case MoveDirection.down:
        path.moveTo(cx - width * 0.5, cy - height * 0.3);
        path.lineTo(cx, cy + height * 0.7);
        path.lineTo(cx + width * 0.5, cy - height * 0.3);
        path.lineTo(cx, cy - height * 0.1);
        break;
      case MoveDirection.left:
        path.moveTo(cx + height * 0.3, cy - width * 0.5);
        path.lineTo(cx - height * 0.7, cy);
        path.lineTo(cx + height * 0.3, cy + width * 0.5);
        path.lineTo(cx + height * 0.1, cy);
        break;
      case MoveDirection.right:
        path.moveTo(cx - height * 0.3, cy - width * 0.5);
        path.lineTo(cx + height * 0.7, cy);
        path.lineTo(cx - height * 0.3, cy + width * 0.5);
        path.lineTo(cx - height * 0.1, cy);
        break;
    }
    path.close();
    
    canvas.drawPath(path, paint);
    canvas.drawPath(path, strokePaint);
  }


