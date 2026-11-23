import 'package:hive_flutter/hive_flutter.dart';

/// Service class for managing user progress persistence in the Arrows puzzle game.
///
/// This service handles:
/// - Saving/loading current level progress
/// - Managing player hearts/lives system
/// - Initializing Hive database for simple key-value storage
/// - Providing a centralized box for game state storage
///
/// All methods are static, making it a utility class that doesn't require instantiation.
/// Uses Hive as a lightweight NoSQL database for local storage (no backend required).
class ProgressService {
  // CONSTANTS

  /// Name of the Hive box (like a table in SQL) that stores all user progress data.
  /// This creates a file named 'user_progress_box.hive' in app's documents directory.
  static const String _boxName = 'user_progress_box';

  /// Key for storing the highest level the user has unlocked.
  /// Value type: int (level numbers start from 1)
  static const String _currentLevelKey = 'current_level_id';

  /// Key for storing the player's remaining hearts/lives.
  /// Value type: int (typically ranges 0-5)
  static const String _heartsKey = 'player_hearts';

  /// Key for storing the milliseconds since epoch when the last heart regeneration occurred.
  /// Value type: int
  static const String _lastRegenTimeKey = 'last_regen_time';

  /// Key for storing mid-level progress (which arrows are extracted in the current level).
  /// Value type: Map<dynamic, dynamic> (e.g. {'levelId': 5, 'extractedIds': [1, 3, 5]})
  static const String _midLevelProgressKey = 'mid_level_progress';

  // INITIALIZATION

  /// Initializes the Hive database.
  ///
  /// This method MUST be called before using any other ProgressService methods,
  /// typically in your main() function before runApp().
  ///
  /// Setup flow:
  /// 1. Initializes Hive for Flutter (sets up storage directory)
  /// 2. Opens the box (creates/loads the database file)
  ///
  /// Example usage:
  /// ```dart
  /// void main() async {
  ///   WidgetsFlutterBinding.ensureInitialized();
  ///   await ProgressService.init();
  ///   runApp(MyApp());
  /// }
  /// ```
  ///
  /// Throws: HiveError if box cannot be opened
  static Future<void> init() async {
    // Initialize Hive for Flutter platform (sets proper storage paths)
    await Hive.initFlutter();

    // Open the box (creates if doesn't exist, loads if exists)
    // Box acts as a persistent Map<String, dynamic> for primitive tracking values
    await Hive.openBox(_boxName);
    await Hive.openBox('settingsBox');
  }

  // BOX ACCESSOR

  /// Private getter for accessing the Hive box.
  ///
  /// Returns the already-opened box instance. Assumes init() has been called.
  /// All database operations go through this getter to ensure consistent access.
  ///
  /// Note: Throws if accessed before init() completes.
  static Box get _box => Hive.box(_boxName);

  // LEVEL PROGRESS METHODS

  /// Retrieves the current unlocked level index.
  ///
  /// Returns the highest level the player has unlocked (1-based index).
  /// New players start at level 1.
  ///
  /// Returns:
  ///    int - Current level number (minimum 1)
  static int getCurrentLevel() {
    // Get from box with default value of 1 (first level)
    final int lvl = _box.get(_currentLevelKey, defaultValue: 1);
    return lvl;
  }

  /// Saves progress when a level is completed.
  ///
  /// Updates the saved level ID ONLY if the completed level is higher than
  /// the previously saved progress (prevents backwards progression).
  ///
  /// Parameters:
  ///    [levelId] - The level number that was just completed (1-based)
  static Future<void> saveLevelReached(int levelId) async {
    int currentSaved = getCurrentLevel();

    // Only update if new level is further than previous best
    if (levelId > currentSaved) {
      await _box.put(_currentLevelKey, levelId);
    }
  }

  /// Resets level progression back to level 1.
  static Future<void> forceResetProgression() async {
    await _box.put(_currentLevelKey, 1);
  }

  // MID-LEVEL PROGRESS

  /// Saves mid-level progress: which arrows have been extracted for a specific level.
  static Future<void> saveMidLevelProgress(int levelId, List<int> extractedIds) async {
    await _box.put(_midLevelProgressKey, {
      'levelId': levelId,
      'extractedIds': extractedIds,
    });
  }

  /// Retrieves the mid-level progress if it exists for the given levelId.
  /// Returns a list of extracted arrow IDs, or an empty list if none exists or mismatch.
  static List<int> getMidLevelProgress(int levelId) {
    final data = _box.get(_midLevelProgressKey);
    if (data != null && data is Map) {
      final savedLevelId = data['levelId'] as int?;
      if (savedLevelId == levelId) {
        final extractedList = data['extractedIds'] as List<dynamic>?;
        if (extractedList != null) {
          return extractedList.cast<int>();
        }
      }
    }
    return [];
  }

  /// Clears the mid-level progress (e.g. when a level is completed).
  static Future<void> clearMidLevelProgress() async {
    await _box.delete(_midLevelProgressKey);
  }

  // HEART/LIFE SYSTEM METHODS

  /// Retrieves the player's remaining hearts/lives.
  ///
  /// Returns:
  ///    int - Current heart count (default: 5 for new players)
  static int getHearts() {
    return _box.get(_heartsKey, defaultValue: 5);
  }

  /// Saves the updated heart count to persistent storage.
  ///
  /// Parameters:
  ///    [count] - New heart count to save
  static Future<void> saveHearts(int count) async {
    await _box.put(_heartsKey, count);
  }

  /// Retrieves the last recorded heart regeneration time (milliseconds since epoch).
  static int? getLastRegenTime() {
    return _box.get(_lastRegenTimeKey);
  }

  /// Saves the last heart regeneration time to persistent storage.
  static Future<void> saveLastRegenTime(int ms) async {
    await _box.put(_lastRegenTimeKey, ms);
  }

  // HINT SYSTEM METHODS

  static const String _hintsKey = 'player_hints';
  static const String _lastHintRegenTimeKey = 'last_hint_regen_time';

  /// Retrieves the player's remaining hints.
  static int getHints() {
    return _box.get(_hintsKey, defaultValue: 3);
  }

  /// Saves the updated hint count.
  static Future<void> saveHints(int count) async {
    await _box.put(_hintsKey, count);
  }

  /// Retrieves the last recorded hint regeneration time (milliseconds since epoch).
  static int? getLastHintRegenTime() {
    return _box.get(_lastHintRegenTimeKey);
  }

  /// Saves the last hint regeneration time.
  static Future<void> saveLastHintRegenTime(int ms) async {
    await _box.put(_lastHintRegenTimeKey, ms);
  }
}
