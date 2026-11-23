
enum MoveDirection { up, down, left, right }

class Point2D {
  final int x;
  final int y;
  const Point2D(this.x, this.y);

  @override
  bool operator ==(Object other) => other is Point2D && other.x == x && other.y == y;
  @override
  int get hashCode => Object.hash(x, y);

  Map<String, dynamic> toJson() => {'x': x, 'y': y};
  factory Point2D.fromJson(Map<String, dynamic> json) => Point2D(json['x'], json['y']);
}

class SnakeLine {
  final int id;
  final MoveDirection exitDirection;
  final String hexColor;
  final List<Point2D> bodyPoints;
  bool isExtracted;

  // Tracks tail retraction distance during escape animations
  double animatedDistance;

  // FIX FLAG: Ensures an arrow only moves on cascade if it was explicitly tapped and blocked
  bool isWaitingToRetry;

  SnakeLine({
    required this.id,
    required this.exitDirection,
    required this.hexColor,
    required this.bodyPoints,
    this.isExtracted = false,
    this.animatedDistance = 0.0,
    this.isWaitingToRetry = false, // Defaults to false
  });

  Point2D get head => bodyPoints.last;
  Point2D get tail => bodyPoints.first;

  int get colorValue => int.parse(hexColor);

  SnakeLine clone() {
    return SnakeLine(
      id: id,
      exitDirection: exitDirection,
      hexColor: hexColor,
      bodyPoints: List.from(bodyPoints),
      isExtracted: isExtracted,
      animatedDistance: animatedDistance,
      isWaitingToRetry: isWaitingToRetry,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'exitDirection': exitDirection.index,
        'hexColor': hexColor,
        'bodyPoints': bodyPoints.map((p) => p.toJson()).toList(),
      };

  factory SnakeLine.fromJson(Map<String, dynamic> json) {
    return SnakeLine(
      id: json['id'],
      exitDirection: MoveDirection.values[json['exitDirection']],
      hexColor: json['hexColor'],
      bodyPoints: (json['bodyPoints'] as List).map((p) => Point2D.fromJson(p)).toList(),
    );
  }
}

class LevelConfig {
  final int id;
  final int matrixWidth;
  final int matrixHeight;
  final List<SnakeLine> lines;

  /// True when this level is a shape level (arrows arranged in a silhouette).
  final bool isShapeLevel;

  /// Human-readable name of the shape (e.g. 'Heart', 'Star').
  final String? shapeName;

  /// Emoji icon for the shape (e.g. '❤️', '⭐').
  final String? shapeEmoji;

  /// The active cells that make up the shape outline. Used to mask the background grid.
  final Set<Point2D>? shapeMask;

  LevelConfig({
    required this.id,
    required this.matrixWidth,
    required this.matrixHeight,
    required this.lines,
    this.isShapeLevel = false,
    this.shapeName,
    this.shapeEmoji,
    this.shapeMask,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'matrixWidth': matrixWidth,
        'matrixHeight': matrixHeight,
        'lines': lines.map((l) => l.toJson()).toList(),
        'isShapeLevel': isShapeLevel,
        'shapeName': shapeName,
        'shapeEmoji': shapeEmoji,
        'shapeMask': shapeMask?.map((p) => p.toJson()).toList(),
      };

  factory LevelConfig.fromJson(Map<String, dynamic> json) {
    return LevelConfig(
      id: json['id'],
      matrixWidth: json['matrixWidth'],
      matrixHeight: json['matrixHeight'],
      lines: (json['lines'] as List).map((l) => SnakeLine.fromJson(l)).toList(),
      isShapeLevel: json['isShapeLevel'] ?? false,
      shapeName: json['shapeName'],
      shapeEmoji: json['shapeEmoji'],
      shapeMask: json['shapeMask'] != null
          ? (json['shapeMask'] as List).map((p) => Point2D.fromJson(p)).toSet()
          : null,
    );
  }
}
