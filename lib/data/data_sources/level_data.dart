import '../models/game_models.dart';

class LevelData {
  static List<LevelConfig> loadSourceLevels() {
    return [
      // LEVEL 1: Intro Setup
      LevelConfig(
        id: 1,
        matrixWidth: 5,
        matrixHeight: 5,
        lines: [
          SnakeLine(
            id: 1,
            exitDirection: MoveDirection.right,
            hexColor: "0xFF3B82F6", // Premium Blue
            bodyPoints: [
              const Point2D(1, 2),
              const Point2D(2, 2),
              const Point2D(3, 2),
            ],
          ),
          SnakeLine(
            id: 2,
            exitDirection: MoveDirection.down,
            hexColor: "0xFF10B981", // Premium Emerald Green
            bodyPoints: [
              const Point2D(2, 0),
              const Point2D(2, 1),
            ],
          ),
        ],
      ),

      // LEVEL 2: Spiral Interlock Configuration
      LevelConfig(
        id: 2,
        matrixWidth: 6,
        matrixHeight: 6,
        lines: [
          SnakeLine(
            id: 1,
            exitDirection: MoveDirection.up,
            hexColor: "0xFFF59E0B", // Premium Amber Orange
            bodyPoints: [
              const Point2D(3, 5),
              const Point2D(3, 4),
              const Point2D(3, 3),
            ],
          ),
          SnakeLine(
            id: 2,
            exitDirection: MoveDirection.left,
            hexColor: "0xFFEC4899", // Premium Vivid Pink
            bodyPoints: [
              const Point2D(5, 2),
              const Point2D(4, 2),
              const Point2D(3, 2),
            ],
          ),
        ],
      ),

      // LEVEL 3: Cross Intersection (Three Arrows Interlocked)
      LevelConfig(
        id: 3,
        matrixWidth: 6,
        matrixHeight: 6,
        lines: [
          SnakeLine(
            id: 1,
            exitDirection: MoveDirection.right,
            hexColor: "0xFF3B82F6", // Blue
            bodyPoints: [
              const Point2D(1, 3),
              const Point2D(2, 3),
              const Point2D(3, 3),
            ],
          ),
          SnakeLine(
            id: 2,
            exitDirection: MoveDirection.down,
            hexColor: "0xFF10B981", // Green
            bodyPoints: [
              const Point2D(2, 1),
              const Point2D(2, 2),
              const Point2D(2, 3),
            ],
          ),
          SnakeLine(
            id: 3,
            exitDirection: MoveDirection.up,
            hexColor: "0xFF8B5CF6", // Purple
            bodyPoints: [
              const Point2D(3, 4),
              const Point2D(3, 3),
              const Point2D(3, 2),
            ],
          ),
        ],
      ),

      // LEVEL 4: Corner Blockade
      LevelConfig(
        id: 4,
        matrixWidth: 6,
        matrixHeight: 6,
        lines: [
          SnakeLine(
            id: 1,
            exitDirection: MoveDirection.left,
            hexColor: "0xFFEC4899", // Pink
            bodyPoints: [
              const Point2D(4, 1),
              const Point2D(3, 1),
              const Point2D(2, 1),
            ],
          ),
          SnakeLine(
            id: 2,
            exitDirection: MoveDirection.up,
            hexColor: "0xFFF59E0B", // Orange
            bodyPoints: [
              const Point2D(2, 4),
              const Point2D(2, 3),
              const Point2D(2, 2),
            ],
          ),
          SnakeLine(
            id: 3,
            exitDirection: MoveDirection.right,
            hexColor: "0xFF06B6D4", // Cyan
            bodyPoints: [
              const Point2D(1, 2),
              const Point2D(2, 2),
              const Point2D(3, 2),
            ],
          ),
        ],
      ),

      // LEVEL 5: The Grid Cage (Complex Interlocking)
      LevelConfig(
        id: 5,
        matrixWidth: 7,
        matrixHeight: 7,
        lines: [
          SnakeLine(
            id: 1,
            exitDirection: MoveDirection.up,
            hexColor: "0xFF3B82F6", // Blue
            bodyPoints: [
              const Point2D(2, 5),
              const Point2D(2, 4),
              const Point2D(2, 3),
            ],
          ),
          SnakeLine(
            id: 2,
            exitDirection: MoveDirection.right,
            hexColor: "0xFF10B981", // Green
            bodyPoints: [
              const Point2D(1, 3),
              const Point2D(2, 3),
              const Point2D(3, 3),
            ],
          ),
          SnakeLine(
            id: 3,
            exitDirection: MoveDirection.down,
            hexColor: "0xFFEC4899", // Pink
            bodyPoints: [
              const Point2D(4, 1),
              const Point2D(4, 2),
              const Point2D(4, 3),
            ],
          ),
          SnakeLine(
            id: 4,
            exitDirection: MoveDirection.left,
            hexColor: "0xFFF59E0B", // Orange
            bodyPoints: [
              const Point2D(5, 4),
              const Point2D(4, 4),
              const Point2D(3, 4),
            ],
          ),
        ],
      ),
    ];
  }
}
