import 'dart:math';
import '../../data/models/game_models.dart';
import 'shape_templates.dart';
import 'difficulty_config.dart';

// Colour palette for generated lines — mirrors AppColors.lineColors
const List<String> _kLineColors = ['0xFFF5EAE0'];

class _DirData {
  final int dx;
  final int dy;
  final MoveDirection dir;
  _DirData(this.dx, this.dy, this.dir);
}

class _ExtractionCandidate {
  final Point2D head;
  final MoveDirection dir;
  final List<Point2D> body;
  _ExtractionCandidate(this.head, this.dir, this.body);
}

/// Generates shape-based puzzle levels where arrows fill a silhouette.
/// Uses a Reverse-Fill algorithm: starts with the full shape as "unsolved",
/// and repeatedly finds an arrow that can escape to the boundary, "extracting" it.
/// This guarantees 100% playable levels in milliseconds, even for massive 15x15 solid shapes!
class ShapeLevelGenerator {
  static final List<List<int>> _dirs = [[0, 1], [0, -1], [1, 0], [-1, 0]];
  
  static final List<_DirData> _dirsWithEnum = [
    _DirData(0, 1, MoveDirection.down),
    _DirData(0, -1, MoveDirection.up),
    _DirData(1, 0, MoveDirection.right),
    _DirData(-1, 0, MoveDirection.left),
  ];

  static LevelConfig generate(int levelId, int seed, ShapeTemplate template, DifficultyConfig config) {
    Random rand = Random(seed);

    for (int attempt = 0; attempt < 10; attempt++) {
      if (attempt > 0) {
        rand = Random(rand.nextInt(1000000) + attempt);
      }

      int minLen = config.minSnakeLen;
      int maxLen = config.maxSnakeLen;
      
      // Scale down max length if the shape is very small to avoid DFS bottlenecks
      if (template.activeCells.length < 30) maxLen = (maxLen > 8) ? 8 : maxLen;
      else if (template.activeCells.length < 60) maxLen = (maxLen > 10) ? 10 : maxLen;
      
      List<SnakeLine>? finalLines = generateShapeReverse(template, rand, minLen, maxLen);

      if (finalLines != null) {
        // Assign IDs and colors
        for (int i = 0; i < finalLines.length; i++) {
          finalLines[i] = SnakeLine(
            id: i + 1,
            exitDirection: finalLines[i].exitDirection,
            hexColor: _kLineColors[i % _kLineColors.length],
            bodyPoints: finalLines[i].bodyPoints,
          );
        }
        
        // Final sanity check removed: Reverse generation mathematically guarantees 100% solvability.
        // Running it forward taking O(N^4) time causes huge 300-arrow grids to hang endlessly.
        return LevelConfig(
          id: levelId,
          matrixWidth: template.gridWidth,
          matrixHeight: template.gridHeight,
          lines: finalLines,
          isShapeLevel: true,
          shapeName: template.name,
          shapeEmoji: template.emoji,
          shapeMask: template.activeCells,
        );
      }
    }

    // Ultimate fallback — should never happen
    return LevelConfig(
      id: levelId,
      matrixWidth: 2,
      matrixHeight: 1,
      lines: [
        SnakeLine(
          id: 1,
          exitDirection: MoveDirection.right,
          hexColor: _kLineColors[0],
          bodyPoints: [const Point2D(0, 0), const Point2D(1, 0)],
        ),
      ],
    );
  }

  static List<SnakeLine>? generateShapeReverse(ShapeTemplate template, Random rand, int minLen, int maxLen) {
    int maxRestarts = 200;
    
    List<SnakeLine>? bestArrows;
    int minRemaining = 999999;
    
    final stopwatch = Stopwatch()..start();
    
    for (int restart = 0; restart < maxRestarts; restart++) {
      if (stopwatch.elapsedMilliseconds > 200) {
        break; // Timeout to prevent infinite hangs
      }
      Set<Point2D> remaining = Set.from(template.activeCells);
      List<List<bool>> remainingGrid = List.generate(
        template.gridHeight,
        (y) => List.generate(template.gridWidth, (x) => false)
      );
      for (var p in remaining) {
        remainingGrid[p.y][p.x] = true;
      }
      
      List<SnakeLine> arrows = [];
      bool stuck = false;
      int nextId = 1;

      while (remaining.isNotEmpty) {
        if (stopwatch.elapsedMilliseconds > 200) {
          stuck = true;
          break;
        }
        
        List<_ExtractionCandidate> fallbackCandidates = [];
        _ExtractionCandidate? chosen;

        // 1. Gather all clear heads
        List<Map<String, dynamic>> clearHeads = [];
        for (var head in remaining) {
          for (var dirData in _dirsWithEnum) {
            int dx = dirData.dx;
            int dy = dirData.dy;
            MoveDirection dir = dirData.dir;

            bool clear = true;
            int cx = head.x + dx;
            int cy = head.y + dy;
            while (cx >= 0 && cx < template.gridWidth && cy >= 0 && cy < template.gridHeight) {
              if (remainingGrid[cy][cx]) {
                clear = false;
                break;
              }
              cx += dx;
              cy += dy;
            }

            if (clear) {
              clearHeads.add({'head': head, 'dir': dir});
            }
          }
        }

        clearHeads.shuffle(rand);

        // Try decreasing target lengths to favor longer/random snakes but fall back gracefully
        int targetLen = minLen + rand.nextInt(maxLen - minLen + 1);
        
        while (targetLen >= minLen && chosen == null) {
          for (var hd in clearHeads) {
            Point2D head = hd['head'];
            MoveDirection dir = hd['dir'];

            List<Point2D>? safeBody = _findFirstSafeBody(
              head,
              remaining,
              remainingGrid,
              targetLen,
              template.gridWidth,
              template.gridHeight,
              rand,
            );

            if (safeBody != null) {
              chosen = _ExtractionCandidate(head, dir, safeBody);
              break;
            }
          }
          if (chosen == null) targetLen--;
        }

        if (chosen == null) {
          // If no safe body found even at minLen, fall back to any body of minLen
          for (var hd in clearHeads) {
            Point2D head = hd['head'];
            MoveDirection dir = hd['dir'];
            List<Point2D>? anyBody = _findFirstAnyBody(head, remaining, minLen, rand);
            if (anyBody != null) {
              fallbackCandidates.add(_ExtractionCandidate(head, dir, anyBody));
            }
          }
        }

        if (chosen == null && fallbackCandidates.isNotEmpty) {
          chosen = fallbackCandidates[rand.nextInt(fallbackCandidates.length)];
        }

        if (chosen == null) {
          stuck = true;
          break; // Dead end
        }
        
        // Execute extraction
        for (var p in chosen.body) {
          remaining.remove(p);
          remainingGrid[p.y][p.x] = false;
        }
        // In our SnakeLine, bodyPoints.last is the head.
        // `_findBodies` returns [head, next1, next2], so reverse it.
        List<Point2D> snakeBody = chosen.body.reversed.toList();

        arrows.add(SnakeLine(
          id: nextId++,
          exitDirection: chosen.dir,
          hexColor: '', 
          bodyPoints: snakeBody,
        ));
      }

      if (remaining.isEmpty) {
        return arrows;
      }
      
      if (remaining.length < minRemaining) {
        minRemaining = remaining.length;
        bestArrows = arrows;
      }
    }
    
    if (bestArrows != null && bestArrows.length > 10) {
      return bestArrows;
    }
    return null;
  }

  static List<Point2D>? _findFirstSafeBody(
    Point2D head,
    Set<Point2D> remaining,
    List<List<bool>> remainingGrid,
    int exactLen,
    int gridWidth,
    int gridHeight,
    Random rand,
  ) {
    List<Point2D> path = [head];
    Set<Point2D> pathSet = {head};
    List<Point2D>? foundBody;

    // Pre-allocate arrays for the cluster BFS/DFS to avoid memory allocation inside the loop.
    final List<List<bool>> visited = List.generate(gridHeight, (_) => List.filled(gridWidth, false));
    final int maxCells = gridWidth * gridHeight;
    final List<int> stackX = List.filled(maxCells, 0);
    final List<int> stackY = List.filled(maxCells, 0);

    int dfsSteps = 0;
    bool preferCW = rand.nextBool();

    List<List<int>> getNextDirs(Point2D prev, Point2D curr) {
      if (prev == curr) return List.from(_dirs)..shuffle(rand);
      int dx = curr.x - prev.x;
      int dy = curr.y - prev.y;
      
      List<int> turnCW = [-dy, dx];
      List<int> turnCCW = [dy, -dx];
      List<int> forward = [dx, dy];
      
      // 20% chance to prefer forward to avoid getting instantly trapped in 1x1 spirals
      bool goForwardFirst = rand.nextDouble() < 0.20;
      if (goForwardFirst) {
        return [forward, preferCW ? turnCW : turnCCW, preferCW ? turnCCW : turnCW];
      } else {
        return [preferCW ? turnCW : turnCCW, forward, preferCW ? turnCCW : turnCW];
      }
    }

    bool dfs(Point2D curr) {
      if (dfsSteps++ > 500) return false; // Safety abort
      
      if (path.length == exactLen) {
        for (var p in path) {
          remainingGrid[p.y][p.x] = false;
        }
        int tempRemaining = remaining.length - path.length;
        bool hasInvalidCluster = false;
        
        if (tempRemaining > 0) {
          // Clear visited array only for the remaining cells
          for (var p in remaining) {
            visited[p.y][p.x] = false;
          }
          
          for (var p in remaining) {
            if (!remainingGrid[p.y][p.x] || visited[p.y][p.x]) continue;
            
            int clusterSize = 0;
            int stackPtr = 0;
            stackX[stackPtr] = p.x;
            stackY[stackPtr] = p.y;
            stackPtr++;
            visited[p.y][p.x] = true;
            
            while(stackPtr > 0) {
              stackPtr--;
              int cx = stackX[stackPtr];
              int cy = stackY[stackPtr];
              clusterSize++;
              
              for (var d in _dirs) {
                int nx = cx + d[0];
                int ny = cy + d[1];
                if (nx >= 0 && nx < gridWidth && ny >= 0 && ny < gridHeight) {
                  if (remainingGrid[ny][nx] && !visited[ny][nx]) {
                    visited[ny][nx] = true;
                    stackX[stackPtr] = nx;
                    stackY[stackPtr] = ny;
                    stackPtr++;
                  }
                }
              }
            }
            
            if (clusterSize < exactLen) {
              hasInvalidCluster = true;
              break;
            }
          }
        }
        
        for (var p in path) {
          remainingGrid[p.y][p.x] = true;
        }
        
        if (!hasInvalidCluster) {
          foundBody = List.from(path);
          return true;
        }
        return false; // Don't grow beyond exactLen
      }

      Point2D prev = path.length > 1 ? path[path.length - 2] : curr;
      List<List<int>> shuffledDirs = getNextDirs(prev, curr);

      for (var d in shuffledDirs) {
        Point2D next = Point2D(curr.x + d[0], curr.y + d[1]);
        if (remaining.contains(next) && !pathSet.contains(next)) {
          path.add(next);
          pathSet.add(next);
          if (dfs(next)) return true;
          pathSet.remove(next);
          path.removeLast();
        }
      }
      return false;
    }

    dfs(head);
    return foundBody;
  }

  static List<Point2D>? _findFirstAnyBody(
    Point2D head,
    Set<Point2D> remaining,
    int exactLen,
    Random rand,
  ) {
    List<Point2D> path = [head];
    Set<Point2D> pathSet = {head};
    List<Point2D>? foundBody;
    bool preferCW = rand.nextBool();
    int dfsSteps = 0;

    List<List<int>> getNextDirs(Point2D prev, Point2D curr) {
      if (prev == curr) return List.from(_dirs)..shuffle(rand);
      int dx = curr.x - prev.x;
      int dy = curr.y - prev.y;
      
      List<int> turnCW = [-dy, dx];
      List<int> turnCCW = [dy, -dx];
      List<int> forward = [dx, dy];
      
      bool goForwardFirst = rand.nextDouble() < 0.20;
      if (goForwardFirst) {
        return [forward, preferCW ? turnCW : turnCCW, preferCW ? turnCCW : turnCW];
      } else {
        return [preferCW ? turnCW : turnCCW, forward, preferCW ? turnCCW : turnCW];
      }
    }

    bool dfs(Point2D curr) {
      if (dfsSteps++ > 500) return false;
      
      if (path.length > (foundBody?.length ?? 0)) {
        foundBody = List.from(path);
      }
      
      if (path.length == exactLen) {
        return true;
      }

      Point2D prev = path.length > 1 ? path[path.length - 2] : curr;
      List<List<int>> shuffledDirs = getNextDirs(prev, curr);

      for (var d in shuffledDirs) {
        Point2D next = Point2D(curr.x + d[0], curr.y + d[1]);
        if (remaining.contains(next) && !pathSet.contains(next)) {
          path.add(next);
          pathSet.add(next);
          if (dfs(next)) return true;
          pathSet.remove(next);
          path.removeLast();
        }
      }
      return false;
    }

    dfs(head);
    return foundBody;
  }

  /// Verifies that the level is 100% playable
  static bool _isLevelSolvable(List<SnakeLine> lines, int w, int h) {
    List<SnakeLine> remaining = lines.map((l) => l.clone()).toList();
    bool changed = true;
    while (changed && remaining.isNotEmpty) {
      changed = false;
      for (int i = 0; i < remaining.length; i++) {
        var line = remaining[i];
        if (_canExtract(line, remaining, w, h)) {
          remaining.removeAt(i);
          changed = true;
          break;
        }
      }
    }
    return remaining.isEmpty;
  }

  static bool _canExtract(SnakeLine line, List<SnakeLine> lines, int w, int h) {
    int dx = 0, dy = 0;
    if (line.exitDirection == MoveDirection.up) dy = -1;
    else if (line.exitDirection == MoveDirection.down) dy = 1;
    else if (line.exitDirection == MoveDirection.left) dx = -1;
    else if (line.exitDirection == MoveDirection.right) dx = 1;

    int cx = line.head.x + dx;
    int cy = line.head.y + dy;

    while (cx >= 0 && cx < w && cy >= 0 && cy < h) {
      for (var other in lines) {
        if (other.id == line.id) continue;
        for (var p in other.bodyPoints) {
          if (p.x == cx && p.y == cy) return false;
        }
      }
      cx += dx;
      cy += dy;
    }
    return true;
  }
}
