import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:arrows/domain/engine/shape_level_generator.dart';
import 'package:arrows/domain/engine/shape_templates.dart';
import 'package:arrows/domain/engine/difficulty_config.dart';
void main() {
  test('Benchmark Shape Level Generation', () {
    print('Starting benchmark for Shape Levels...');
    final start = DateTime.now();
    int failCount = 0;
    
    // Test all 8 shapes, 10 seeds each (80 levels total)
    for (var shape in ShapeTemplates.all) {
      for (int i = 0; i < 10; i++) {
        int seed = Random().nextInt(1000000);
        // Using a high level ID (50) ensures maximum arrow lengths
        final level = ShapeLevelGenerator.generate(50, seed, shape, DifficultyConfig.forLevel(50));
        
        // If it falls back to the 1-arrow emergency grid, it's a failure
        if (level.lines.length <= 1) {
          failCount++;
          print('Failed on shape ${shape.name} with seed $seed');
        }
      }
    }
    
    final end = DateTime.now();
    final elapsedMs = end.difference(start).inMilliseconds;
    
    print('80 iterations took $elapsedMs ms');
    print('Average per shape: ${elapsedMs / 80} ms');
    print('Fail (1-arrow) count: $failCount');
    
    expect(failCount, 0);
  });
}
