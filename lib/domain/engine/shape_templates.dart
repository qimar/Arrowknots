import '../../data/models/game_models.dart';
import 'shape_templates_generated.dart';

/// A shape template defines a set of active grid cells that form
/// a recognizable silhouette. The generator tiles only these cells.
class ShapeTemplate {
  final String name;
  final String emoji;
  final int gridWidth;
  final int gridHeight;
  final Set<Point2D> activeCells;

  const ShapeTemplate({
    required this.name,
    required this.emoji,
    required this.gridWidth,
    required this.gridHeight,
    required this.activeCells,
  });

  /// Scales the template by multiplying grid dimensions and filling 
  /// every active cell with a factor x factor block of active cells.
  ShapeTemplate scale(int factor) {
    if (factor <= 1) return this;
    
    Set<Point2D> newCells = {};
    for (var p in activeCells) {
      for (int dy = 0; dy < factor; dy++) {
        for (int dx = 0; dx < factor; dx++) {
          newCells.add(Point2D(p.x * factor + dx, p.y * factor + dy));
        }
      }
    }
    
    return ShapeTemplate(
      name: name,
      emoji: emoji,
      gridWidth: gridWidth * factor,
      gridHeight: gridHeight * factor,
      activeCells: newCells,
    );
  }

  /// Factory to parse visual ASCII strings into shapes.
  /// 'X' means active cell, any other character (usually '.') means empty.
  factory ShapeTemplate.fromString({
    required String name,
    required String emoji,
    required List<String> gridStr,
  }) {
    final height = gridStr.length;
    final width = gridStr.isNotEmpty ? gridStr[0].replaceAll(' ', '').length : 0;
    final Set<Point2D> cells = {};

    for (int y = 0; y < height; y++) {
      final row = gridStr[y].replaceAll(' ', '');
      for (int x = 0; x < width; x++) {
        if (row[x] == 'X') {
          cells.add(Point2D(x, y));
        }
      }
    }

    return ShapeTemplate(
      name: name,
      emoji: emoji,
      gridWidth: width,
      gridHeight: height,
      activeCells: cells,
    );
  }
}

/// Catalog of all available shape templates.
class ShapeTemplates {
  ShapeTemplates._();

  /// All available shapes (redirects to the 313 generated shapes)
  static final List<ShapeTemplate> all = GeneratedShapeTemplates.all;
}
