import 'package:flutter_test/flutter_test.dart';
import 'package:arrows/domain/engine/shape_level_generator.dart';
import 'package:arrows/domain/engine/shape_templates.dart';
import 'package:arrows/domain/engine/difficulty_config.dart';
import 'dart:math';

void main() {
  test('Speed Test', () {
    print('Starting speed test...');
    final watch = Stopwatch()..start();
    for (int i = 1; i <= 20; i++) {
      final config = DifficultyConfig.forLevel(i);
      final template = ShapeTemplates.all.first.scale(config.shapeScaleFactor);
      ShapeLevelGenerator.generate(i, i * 1000003, template, config);
    }
    print('20 levels took ${watch.elapsedMilliseconds} ms');
  });
}
