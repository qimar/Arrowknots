import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

import 'package:arrows/data/models/game_models.dart';
import 'package:arrows/domain/engine/level_generator.dart';
import 'package:arrows/domain/engine/shape_level_generator.dart';
import 'package:arrows/domain/engine/shape_templates.dart';
import 'package:arrows/domain/engine/difficulty_config.dart';

int getSeedForLevel(int levelId) {
  return levelId * 1000003;
}

void main() {
  test('Generate Levels', () {
    // CHANGE THIS VARIABLE to generate more or fewer levels!
    int numLevels = 50;

    final dir = Directory('assets/levels');

    // Clear out any old levels if the folder exists, so we always start with a fresh batch of newly generated levels.
    if (dir.existsSync()) {
      dir.deleteSync(recursive: true);
    }
    dir.createSync(recursive: true);

    print('Generating $numLevels levels...');
    int batchSize = 10;

    for (int id = 1; id <= numLevels; id++) {
      final seed = getSeedForLevel(id);
      final config = DifficultyConfig.forLevel(id);

      LevelConfig generatedConfig;
      if (config.isShapeLevel) {
        final template = ShapeTemplates.all.first.scale(
          config.shapeScaleFactor,
        );
        generatedConfig = ShapeLevelGenerator.generate(
          id,
          seed,
          template,
          config,
        );
      } else {
        generatedConfig = ProceduralLevelGenerator.generate(id, seed, config);
      }

      final file = File('assets/levels/level_$id.json');
      final jsonStr = jsonEncode(generatedConfig.toJson());
      file.writeAsStringSync(jsonStr);

      if (id % batchSize == 0) {
        print('Generated level $id');
      }
    }

    print('Finished generating test levels.');
  }, timeout: Timeout.none);
}
