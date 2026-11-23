import 'dart:math';
import 'dart:isolate';
import '../../data/models/game_models.dart';
import 'shape_level_generator.dart';
import 'shape_templates.dart';
import 'difficulty_config.dart';

// Colour palette for generated lines — mirrors AppColors.lineColors
// Keep in sync if you add more colours to AppColors.
const List<String> _kLineColors = ['0xFFF5EAE0'];

class ProceduralLevelGenerator {
  static int _backtrackSteps = 0;
  static const int _maxBacktrackSteps = 300;

  /// Generates a LevelConfig procedurally based on levelId and seed.
  /// Runs inside Isolate.run to avoid blocking UI thread.
  static Future<LevelConfig> generateAsync(int levelId, int seed, DifficultyConfig config) async {
    return await Isolate.run(() => generate(levelId, seed, config));
  }

  /// Generates a LevelConfig procedurally based on levelId and seed.
  static LevelConfig generate(int levelId, int seed, DifficultyConfig config) {
    Random currentRand = Random(seed);
    
    for (int attempt = 0; attempt < 5; attempt++) {
      if (attempt > 0) {
        currentRand = Random(currentRand.nextInt(1000000) + attempt);
      }
      
      int targetArrows = config.targetArrowMin + 
          currentRand.nextInt(config.targetArrowMax - config.targetArrowMin + 1);
      
      int minLen = config.minSnakeLen;
      int maxLen = config.maxSnakeLen;
      double avgLen = (minLen + maxLen) / 2.0;
      
      int totalCells = (targetArrows * avgLen).round();
      
      // Calculate width and height for approx 3:5 aspect ratio
      int width = sqrt(totalCells * 0.6).round();
      int height = (totalCells / width).round();
      
      if (width < 4) width = 4;
      if (height < 5) height = 5;

      Set<Point2D> activeCells = {};
      for (int y = 0; y < height; y++) {
        for (int x = 0; x < width; x++) {
          activeCells.add(Point2D(x, y));
        }
      }

      ShapeTemplate proceduralTemplate = ShapeTemplate(
        name: 'Procedural',
        emoji: '🧩',
        gridWidth: width,
        gridHeight: height,
        activeCells: activeCells,
      );

      List<SnakeLine> finalLines = ShapeLevelGenerator.generateShapeReverse(
        proceduralTemplate, 
        currentRand, 
        minLen, 
        maxLen
      ) ?? [];

      if (finalLines.isNotEmpty) {
        // Assign final IDs and colors
        for (int i = 0; i < finalLines.length; i++) {
          finalLines[i] = SnakeLine(
            id: i + 1,
            exitDirection: finalLines[i].exitDirection,
            hexColor: _kLineColors[i % _kLineColors.length],
            bodyPoints: finalLines[i].bodyPoints,
          );
        }
        return LevelConfig(
          id: levelId,
          matrixWidth: width,
          matrixHeight: height,
          lines: finalLines,
        );
      }
    }

    // Fallback if absolutely stuck (should theoretically never happen)
    List<SnakeLine> fallbackLines = [
      SnakeLine(
        id: 1,
        exitDirection: MoveDirection.right,
        hexColor: _kLineColors[0],
        bodyPoints: [const Point2D(0, 0), const Point2D(1, 0)],
      )
    ];
    return LevelConfig(
      id: levelId,
      matrixWidth: 2,
      matrixHeight: 1,
      lines: fallbackLines,
    );
  }

  static List<List<Point2D>> _generateTiling(int width, int height, Random rand, int minLen, int maxLen) {
    for (int attempt = 0; attempt < 100; attempt++) {
      List<List<Point2D>> paths = [];
      Set<Point2D> unvisited = {};
      for (int x = 0; x < width; x++) {
        for (int y = 0; y < height; y++) {
          unvisited.add(Point2D(x, y));
        }
      }

      while (unvisited.isNotEmpty) {
        // Find if there are any unvisited cells that have unvisited neighbors
        // If a cell has no unvisited neighbors, it is isolated. We will handle it in the merge phase.
        List<Point2D> candidates = [];
        for (var p in unvisited) {
          if (_getEmptyNeighbors(p, unvisited).isNotEmpty) {
            candidates.add(p);
          }
        }

        if (candidates.isEmpty) {
          // All remaining unvisited cells are isolated. Stop path growth and go to merge phase.
          break;
        }

        // Pick candidate with fewest unvisited neighbors
        Point2D start = candidates.first;
        int minNeighbors = 999;
        for (var p in candidates) {
          int count = _getEmptyNeighbors(p, unvisited).length;
          if (count < minNeighbors) {
            minNeighbors = count;
            start = p;
          }
        }

        List<Point2D> currentPath = [start];
        unvisited.remove(start);

        int targetLength = rand.nextInt(maxLen - minLen + 1) + minLen;
        Point2D current = start;

        while (currentPath.length < targetLength) {
          List<Point2D> neighbors = _getEmptyNeighbors(current, unvisited);
          if (neighbors.isEmpty) break;

          Point2D next = neighbors[rand.nextInt(neighbors.length)];
          currentPath.add(next);
          unvisited.remove(next);
          current = next;
        }

        paths.add(currentPath);
      }

      // Merge phase: try to merge remaining unvisited (isolated) cells into adjacent path endpoints
      bool mergeSuccess = true;
      if (unvisited.isNotEmpty) {
        List<Point2D> isolated = unvisited.toList();
        // Sort isolated cells by number of neighbors to merge constrained ones first
        isolated.sort((a, b) => _getNeighbors(a, width, height).length.compareTo(_getNeighbors(b, width, height).length));

        for (var x in isolated) {
          List<Point2D> neighbors = _getNeighbors(x, width, height);
          bool merged = false;
          for (var y in neighbors) {
            // Find the path that contains y
            int pathIdx = -1;
            for (int i = 0; i < paths.length; i++) {
              if (paths[i].contains(y)) {
                pathIdx = i;
                break;
              }
            }
            if (pathIdx != -1) {
              var path = paths[pathIdx];
              if (path.length < maxLen) {
                if (y == path.first) {
                  path.insert(0, x);
                  unvisited.remove(x);
                  merged = true;
                  break;
                } else if (y == path.last) {
                  path.add(x);
                  unvisited.remove(x);
                  merged = true;
                  break;
                }
              }
            }
          }
          if (!merged) {
            mergeSuccess = false;
            break;
          }
        }
      }

      if (mergeSuccess && unvisited.isEmpty) {
        // Verify all paths have length >= 2
        bool allValid = true;
        for (var path in paths) {
          if (path.length < 2) {
            allValid = false;
            break;
          }
        }
        if (allValid) {
          return paths;
        }
      }
    }

    // Ultimate fallback if tiling fails 100 times (extremely unlikely)
    // Just return a simple partition of the grid
    List<List<Point2D>> simplePaths = [];
    for (int y = 0; y < height; y++) {
      List<Point2D> row = [];
      for (int x = 0; x < width; x++) {
        row.add(Point2D(x, y));
      }
      // Split row into segments of length 2 or 3
      int idx = 0;
      while (idx < row.length) {
        int len = (row.length - idx == 4) ? 2 : (row.length - idx >= 3 ? 3 : 2);
        if (idx + len > row.length) len = row.length - idx;
        simplePaths.add(row.sublist(idx, idx + len));
        idx += len;
      }
    }
    return simplePaths;
  }

  static List<Point2D> _getNeighbors(Point2D p, int w, int h) {
    List<Point2D> neighbors = [];
    final dirs = [[0,1], [0,-1], [1,0], [-1,0]];
    for (var d in dirs) {
      int nx = p.x + d[0];
      int ny = p.y + d[1];
      if (nx >= 0 && nx < w && ny >= 0 && ny < h) {
        neighbors.add(Point2D(nx, ny));
      }
    }
    return neighbors;
  }



  static List<Point2D> _getEmptyNeighbors(Point2D p, Set<Point2D> unvisited) {
    List<Point2D> neighbors = [];
    final dirs = [[0,1], [0,-1], [1,0], [-1,0]];
    for (var d in dirs) {
      Point2D np = Point2D(p.x + d[0], p.y + d[1]);
      if (unvisited.contains(np)) {
        neighbors.add(np);
      }
    }
    return neighbors;
  }

  static bool _assignDirections(
    List<List<Point2D>> unplaced, 
    List<bool> occupied, 
    List<SnakeLine> result, 
    int width, 
    int height,
    Random rand
  ) {
    if (unplaced.isEmpty) return true;
    
    _backtrackSteps++;
    if (_backtrackSteps > _maxBacktrackSteps) return false;

    // Minimum Remaining Values (MRV) heuristic:
    // Sort unplaced paths to pick the one that has the FEWEST valid placements first.
    List<_PathOption> options = [];
    for (var path in unplaced) {
      List<_ValidPlacement> validPlacements = _getValidPlacements(path, occupied, width, height);
      if (validPlacements.isEmpty) {
        return false; // Dead end immediately
      }
      options.add(_PathOption(path, validPlacements));
    }

    options.sort((a, b) => a.placements.length.compareTo(b.placements.length));
    var chosen = options.first;
    
    // Shuffle the valid placements for random visual layouts
    chosen.placements.shuffle(rand);

    for (var placement in chosen.placements) {
      // Place it
      result.add(placement.line);
      for (var p in chosen.path) occupied[p.y * width + p.x] = true;
      
      List<List<Point2D>> nextUnplaced = List.from(unplaced)..remove(chosen.path);
      
      if (_assignDirections(nextUnplaced, occupied, result, width, height, rand)) {
        return true;
      }
      
      // Backtrack
      result.removeLast();
      for (var p in chosen.path) occupied[p.y * width + p.x] = false;
    }
    
    return false;
  }

  static List<_ValidPlacement> _getValidPlacements(
    List<Point2D> path, 
    List<bool> occupied, 
    int w, 
    int h
  ) {
    List<_ValidPlacement> placements = [];
    List<Point2D> ends = [path.first, path.last];
    // If somehow a length-1 path slipped through, distinct the ends
    if (ends[0] == ends[1]) ends.removeLast();

    for (var head in ends) {
      List<Point2D> body = (head == path.first) ? path.reversed.toList() : List.from(path);
      if (body.length < 2) continue;
      Point2D secondToLast = body[body.length - 2];
      
      MoveDirection dir;
      int dx = head.x - secondToLast.x;
      int dy = head.y - secondToLast.y;
      if (dx == 1) {
        dir = MoveDirection.right;
      } else if (dx == -1) {
        dir = MoveDirection.left;
      } else if (dy == 1) {
        dir = MoveDirection.down;
      } else if (dy == -1) {
        dir = MoveDirection.up;
      } else {
        continue;
      }

      if (_isExitClear(head, dir, path, occupied, w, h)) {
        SnakeLine line = SnakeLine(
          id: 0,
          exitDirection: dir,
          hexColor: "",
          bodyPoints: body,
        );
        placements.add(_ValidPlacement(line));
      }
    }
    return placements;
  }

  static bool _isExitClear(Point2D head, MoveDirection dir, List<Point2D> path, List<bool> occupied, int w, int h) {
    int dx = 0, dy = 0;
    if (dir == MoveDirection.up) { dy = -1; }
    else if (dir == MoveDirection.down) { dy = 1; }
    else if (dir == MoveDirection.left) { dx = -1; }
    else if (dir == MoveDirection.right) { dx = 1; }
    
    int cx = head.x + dx;
    int cy = head.y + dy;
    
    while (cx >= 0 && cx < w && cy >= 0 && cy < h) {
      // Cannot cross already placed paths (in reverse assembly)
      if (occupied[cy * w + cx]) return false;
      // Cannot cross its own body (except the head where it starts)
      bool hitSelf = false;
      for (int i = 0; i < path.length; i++) {
        if (path[i].x == cx && path[i].y == cy) { hitSelf = true; break; }
      }
      if (hitSelf) return false;
      cx += dx;
      cy += dy;
    }
    return true;
  }
}

class _PathOption {
  final List<Point2D> path;
  final List<_ValidPlacement> placements;
  _PathOption(this.path, this.placements);
}

class _ValidPlacement {
  final SnakeLine line;
  _ValidPlacement(this.line);
}
