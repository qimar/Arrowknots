import '../../../data/models/game_models.dart';

class CollisionResult {
  final bool hasCollision;
  final int? collidedWithLineId;
  final List<Point2D> traveledPath; // Useful for drawing the animated exit path later

  CollisionResult({
    required this.hasCollision,
    this.collidedWithLineId,
    required this.traveledPath,
  });
}

class PuzzleEngine {
  /// Evaluates whether a selected [targetLine] has an unobstructed exit path.
  ///
  /// Returns a [CollisionResult] containing details about whether it hit anything,
  /// what it hit, and the path it attempted to travel.
  static CollisionResult checkExitCollision({
    required LevelConfig currentLevel,
    required SnakeLine targetLine,
  }) {
    // If the line is already cleared, skip processing
    if (targetLine.isExtracted) {
      return CollisionResult(hasCollision: false, traveledPath: []);
    }

    // 1. Build a fast-lookup map of all coordinate points currently blocked by OTHER lines
    final Map<Point2D, int> blockedCoordinatesMap = {};

    for (var line in currentLevel.lines) {
      // Ignore itself and any lines that have already successfully exited
      if (line.id == targetLine.id || line.isExtracted) continue;

      for (var point in line.bodyPoints) {
        blockedCoordinatesMap[point] = line.id;
      }
    }

    // 2. Determine our step vectors based on the direction the head is facing
    int stepX = 0;
    int stepY = 0;

    switch (targetLine.exitDirection) {
      case MoveDirection.up:
        stepY = -1;
        break;
      case MoveDirection.down:
        stepY = 1;
        break;
      case MoveDirection.left:
        stepX = -1;
        break;
      case MoveDirection.right:
        stepX = 1;
        break;
    }

    final List<Point2D> raycastTraveledPath = [];

    // Start tracking our ray from the node immediately in front of the head
    int checkX = targetLine.head.x + stepX;
    int checkY = targetLine.head.y + stepY;

    // 3. Project the ray step-by-step until it goes completely out of the level margins
    while (checkX >= 0 && checkX < currentLevel.matrixWidth && checkY >= 0 && checkY < currentLevel.matrixHeight) {
      final currentCheckPoint = Point2D(checkX, checkY);
      raycastTraveledPath.add(currentCheckPoint);

      // Check if this point overlaps with any remaining line parts
      if (blockedCoordinatesMap.containsKey(currentCheckPoint)) {
        return CollisionResult(
          hasCollision: true,
          collidedWithLineId: blockedCoordinatesMap[currentCheckPoint],
          traveledPath: raycastTraveledPath,
        );
      }

      // Step forward along our direction vector
      checkX += stepX;
      checkY += stepY;
    }

    // No collisions found! The ray safely reached the edge of the screen.
    return CollisionResult(
      hasCollision: false,
      traveledPath: raycastTraveledPath,
    );
  }
}
