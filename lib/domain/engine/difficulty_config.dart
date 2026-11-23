class DifficultyConfig {
  final int targetArrowMin;
  final int targetArrowMax;
  final int minSnakeLen;
  final int maxSnakeLen;
  final bool isShapeLevel;
  final int shapeScaleFactor;

  const DifficultyConfig({
    required this.targetArrowMin,
    required this.targetArrowMax,
    required this.minSnakeLen,
    required this.maxSnakeLen,
    required this.isShapeLevel,
    required this.shapeScaleFactor,
  });

  static DifficultyConfig forLevel(int levelId) {
    int position = (levelId - 1) % 5;
    int cycle = (levelId - 1) ~/ 5;
    
    // Global scale increases by 3% per cycle, capped at 50% max increase.
    double globalScale = (1.0 + (cycle * 0.03)).clamp(1.0, 1.5);
    
    int applyScale(int baseValue) {
      return (baseValue * globalScale).round();
    }

    int arrowMin = 20;
    int arrowMax = 40;
    int minLen = 2;
    int maxLen = 3;
    bool isShape = false;
    int shapeScale = 2;

    switch (position) {
      case 0: // Easy Procedural
        arrowMin = 15; arrowMax = 25;
        minLen = 2; maxLen = 8; // Bumped from 6 to 8
        break;
      case 1: // Medium Procedural
        arrowMin = 25; arrowMax = 40;
        minLen = 3; maxLen = 11; // Bumped from 8 to 11
        break;
      case 2: // Shape Level 1
        isShape = true;
        shapeScale = cycle > 10 ? 3 : 2;
        minLen = 3; maxLen = 10; // Bumped from 8 to 10
        break;
      case 3: // Hard Procedural (capped at ~65 base to avoid lag)
        arrowMin = 40; arrowMax = 65;
        minLen = 4; maxLen = 16;
        break;
      case 4: // Shape Level 2
        isShape = true;
        shapeScale = cycle > 5 ? 4 : 3;
        minLen = 4; maxLen = 12; // Bumped from 10 to 12
        break;
    }

    return DifficultyConfig(
      targetArrowMin: applyScale(arrowMin),
      targetArrowMax: applyScale(arrowMax),
      minSnakeLen: minLen,
      maxSnakeLen: maxLen,
      isShapeLevel: isShape,
      shapeScaleFactor: shapeScale,
    );
  }
}
