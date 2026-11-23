import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:isolate';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../data/database/progress_service.dart';
import '../../data/services/level_storage_service.dart';
import '../../data/models/game_models.dart';
import '../../domain/engine/puzzle_engine.dart';



class GameManager extends ChangeNotifier {
  LevelConfig? _currentLevel;
  
  int _currentLevelId = 1;
  int _hearts = 3;
  int _hintsLeft = 3;
  int? _currentSeed;
  Point2D? _pendingTap; // Stores the tap made during animation

  static const int maxHearts = 3;
  static const int maxHints = 3;
  static const Duration hintRegenInterval = Duration(minutes: 30);
  
  Timer? _regenTimer;
  Timer? _collisionTimer;
  int? _nextHintRegenTimestamp;

  int? _collidingLineId;
  int? _obstacleLineId;
  int? _animatingLineId;
  int? _hintedLineId;
  double _animationProgress = 0.0;
  int _levelFailCount = 0; // tracks consecutive fails on current level

  GameManager() {
    _currentLevelId = ProgressService.getCurrentLevel();
    _hintsLeft = ProgressService.getHints();
    _loadLevel(_currentLevelId);
    _initializeHintRegen();
  }

  // Deterministic seed for a level ID guarantees same layout every time
  int _getSeedForLevel(int levelId) {
    return levelId * 1000003;
  }

  LevelConfig? get currentLevel => _currentLevel;
  int get currentLevelId => _currentLevelId;
  int get hearts => _hearts;
  int get hintsLeft => _hintsLeft;
  int? get currentSeed => _currentSeed;
  int? get collidingLineId => _collidingLineId;
  int? get obstacleLineId => _obstacleLineId;
  int? get animatingLineId => _animatingLineId;
  int? get hintedLineId => _hintedLineId;
  double get animationProgress => _animationProgress;
  int get levelFailCount => _levelFailCount;

  String get nextHintCooldownStr {
    if (_hintsLeft >= maxHints || _nextHintRegenTimestamp == null) return '';
    final remainingMs = _nextHintRegenTimestamp! - DateTime.now().millisecondsSinceEpoch;
    if (remainingMs <= 0) return '00:00';
    final remainingSeconds = remainingMs ~/ 1000;
    final minutes = remainingSeconds ~/ 60;
    final seconds = remainingSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  bool _isLevelCleared = false;
  bool get isLevelCleared => _isLevelCleared;
  int get currentUnlockedLevel => ProgressService.getCurrentLevel();

  Future<void> _loadLevel(int id, {int? seed}) async {
    _currentLevel = null;
    _collidingLineId = null;
    _obstacleLineId = null;
    _animatingLineId = null;
    _animationProgress = 0.0;
    _isLevelCleared = false;
    _hearts = maxHearts;
    _collisionTimer?.cancel();
    _pendingTap = null;
    notifyListeners();

    _currentSeed = seed ?? _getSeedForLevel(id);
    
    // 1. Instantly get from Hive database
    _currentLevel = LevelStorageService.getLevel(id);
    
    // 2. Fallback: If not in Hive, the user is playing faster than we could download,
    // or they jumped to a level pack they don't have. Force download.
    if (_currentLevel == null) {
      int packNum = ((id - 1) ~/ 100) + 1;
      bool success = await LevelStorageService.downloadPack(packNum);
      if (success) {
        _currentLevel = LevelStorageService.getLevel(id);
      }
    }

    // Apply mid-level progress
    if (_currentLevel != null) {
      final extractedIds = ProgressService.getMidLevelProgress(id);
      if (extractedIds.isNotEmpty) {
        for (var line in _currentLevel!.lines) {
          if (extractedIds.contains(line.id)) {
            line.isExtracted = true;
          }
        }
      }
    }
    
    notifyListeners();
    
    // 3. Preemptive download: If the player reaches level 80 of the current 100-level pack,
    // trigger a silent background download for the next pack.
    if (id % 100 == 80) {
      int nextPackNum = ((id - 1) ~/ 100) + 2;
      // Fire and forget (don't await)
      LevelStorageService.downloadPack(nextPackNum);
    }
  }

  void handleGridTap(int x, int y) {
    if (_currentLevel == null || _collidingLineId != null) return;

    if (_animatingLineId != null) {
      _pendingTap = Point2D(x, y);
      return;
    }
    
    _pendingTap = null;

    final tappedPoint = Point2D(x, y);
    for (var line in _currentLevel!.lines) {
      if (line.isExtracted) continue;
      if (line.bodyPoints.contains(tappedPoint)) {
        _processExtractionAttempt(line);
        break;
      }
    }
  }

  // void _processExtractionAttempt(SnakeLine line) {
  //   final result = PuzzleEngine.checkExitCollision(
  //     currentLevel: _currentLevel!,
  //     targetLine: line,
  //   );

  //   if (result.hasCollision) {
  //     _triggerCollision(line.id, result.collidedWithLineId);
  //   } else {
  //     _triggerExtractionAnimation(line.id);
  //   }
  // }

  void _processExtractionAttempt(SnakeLine line) {
    final result = PuzzleEngine.checkExitCollision(
      currentLevel: _currentLevel!,
      targetLine: line,
    );

    if (result.hasCollision) {
      // Mark it as waiting/stuck because the player explicitly tapped it
      line.isWaitingToRetry = true;
      _triggerCollision(line.id, result.collidedWithLineId);
    } else {
      // Clear flag just in case, then run animation
      line.isWaitingToRetry = false;
      _triggerExtractionAnimation(line.id);
    }
  }

  void _triggerCollision(int targetId, int? obstacleId) {
    HapticFeedback.vibrate(); // Use universally supported vibrate
    _collidingLineId = targetId;
    _obstacleLineId = obstacleId;
    if (_hearts > 0) {
      _hearts--;
      if (_hearts == 0) {
        ProgressService.clearMidLevelProgress();
      }
    }
    notifyListeners();

    _collisionTimer?.cancel();
    _collisionTimer = Timer(const Duration(milliseconds: 350), () {
      _collidingLineId = null;
      _obstacleLineId = null;
      notifyListeners();
    });
  }

  // void _triggerExtractionAnimation(int lineId) async {
  //   _animatingLineId = lineId;

  //   // Smooth frame steps for snake tail escape pathing
  //   int frameSteps = 24;
  //   for (int i = 0; i <= frameSteps; i++) {
  //     await Future.delayed(const Duration(milliseconds: 14));
  //     _animationProgress = i / frameSteps;

  //     // Pass the progress down directly to the targeted line model
  //     final targetLine = _currentLevel!.lines.firstWhere((l) => l.id == lineId);
  //     targetLine.animatedDistance = _animationProgress;
  //     notifyListeners();
  //   }

  //   _currentLevel!.lines.firstWhere((l) => l.id == lineId).isExtracted = true;
  //   _animatingLineId = null;
  //   _animationProgress = 0.0;
  //   notifyListeners();

  //   _evaluateAutomaticCascades();
  // }

  void _triggerExtractionAnimation(int lineId) {
    _animatingLineId = lineId;
    _animationProgress = 0.0;
    notifyListeners();
  }

  void finalizeExtraction(int lineId) {
    if (_currentLevel == null) return;
    final targetLine = _currentLevel!.lines.firstWhere((l) => l.id == lineId);
    targetLine.isExtracted = true;
    targetLine.isWaitingToRetry = false; // Reset waiting status completely
    targetLine.animatedDistance = 0.0;
    
    if (targetLine.id == _hintedLineId) {
      _hintedLineId = null;
    }

    _animatingLineId = null;
    _animationProgress = 0.0;
    
    // Save mid-level progress
    final extractedIds = _currentLevel!.lines.where((l) => l.isExtracted).map((l) => l.id).toList();
    ProgressService.saveMidLevelProgress(_currentLevelId, extractedIds);
    
    notifyListeners();

    _checkWinCondition();
    
    if (!_isLevelCleared && _pendingTap != null) {
      final tap = _pendingTap!;
      _pendingTap = null;
      handleGridTap(tap.x, tap.y);
    }
  }

  void _checkWinCondition() {
    bool allCleared = _currentLevel!.lines.every((line) => line.isExtracted);
    if (allCleared) {
      _isLevelCleared = true;
      ProgressService.clearMidLevelProgress(); // Clear since level is beaten
      if (_currentLevelId == ProgressService.getCurrentLevel()) {
        ProgressService.saveLevelReached(_currentLevelId + 1);
      }
      notifyListeners();
    }
  }

  void loadNextLevel() {
    _levelFailCount = 0;
    _currentLevelId++;
    _loadLevel(_currentLevelId);
  }

  void skipLevel() {
    ProgressService.clearMidLevelProgress();
    if (_currentLevelId == ProgressService.getCurrentLevel()) {
      ProgressService.saveLevelReached(_currentLevelId + 1);
    }
    loadNextLevel();
  }

  void selectLevel(int levelId) {
    _levelFailCount = 0;
    _currentLevelId = levelId;
    _loadLevel(levelId);
  }

  void resetLevel() {
    _levelFailCount++;
    ProgressService.clearMidLevelProgress();
    _loadLevel(_currentLevelId, seed: _currentSeed);
  }

  void grantExtraHeart() {
    _hearts++;
    notifyListeners();
  }

  void testWinCondition(int stars) {
    if (_currentLevel == null) return;
    _hearts = stars;
    _isLevelCleared = true;
    notifyListeners();
  }

  void refillHints() {
    _hintsLeft = maxHints;
    ProgressService.saveHints(_hintsLeft);
    _nextHintRegenTimestamp = null;
    ProgressService.saveLastHintRegenTime(0);
    notifyListeners();
  }

  void grantFreeHint() {
    if (_hintsLeft < maxHints) {
      _hintsLeft++;
      ProgressService.saveHints(_hintsLeft);
      // If we are now full, cancel timer
      if (_hintsLeft >= maxHints) {
        _nextHintRegenTimestamp = null;
        ProgressService.saveLastHintRegenTime(0);
      }
      notifyListeners();
    }
  }

  Future<void> resetProgression() async {
    _currentLevelId = 1;
    await ProgressService.forceResetProgression();
    _loadLevel(1);
  }

  Future<void> unlockAllLevels() async {
    await ProgressService.saveLevelReached(58);
    notifyListeners();
  }

  void _initializeHintRegen() {
    _updateHintRegenOffline();
    _startHintRegenTimer();
  }

  void _startHintRegenTimer() {
    _regenTimer?.cancel();
    _regenTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      bool needsNotify = false;
      final now = DateTime.now().millisecondsSinceEpoch;

      // Hint Regen Tick
      if (_hintsLeft < maxHints) {
        if (_nextHintRegenTimestamp != null) {
          // Cap buggy timestamps
          if (_nextHintRegenTimestamp! > now + hintRegenInterval.inMilliseconds) {
            _nextHintRegenTimestamp = now + hintRegenInterval.inMilliseconds;
            ProgressService.saveLastHintRegenTime(_nextHintRegenTimestamp!);
          }

          if (now >= _nextHintRegenTimestamp!) {
            _hintsLeft++;
            ProgressService.saveHints(_hintsLeft);
            
            if (_hintsLeft < maxHints) {
              // Restart timer for next hint
              _nextHintRegenTimestamp = now + hintRegenInterval.inMilliseconds;
              ProgressService.saveLastHintRegenTime(_nextHintRegenTimestamp!);
            } else {
              _nextHintRegenTimestamp = null;
              ProgressService.saveLastHintRegenTime(0);
            }
          }
        }
        needsNotify = true;
      } else {
        if (_nextHintRegenTimestamp != null) {
          _nextHintRegenTimestamp = null;
          ProgressService.saveLastHintRegenTime(0);
        }
      }

      // Update UI if timer is running
      if (needsNotify) {
        notifyListeners();
      }
    });
  }

  void _updateHintRegenOffline() {
    if (_hintsLeft >= maxHints) {
      _nextHintRegenTimestamp = null;
      ProgressService.saveLastHintRegenTime(0);
      return;
    }

    int targetTime = ProgressService.getLastHintRegenTime() ?? 0;
    final now = DateTime.now().millisecondsSinceEpoch;

    if (targetTime == 0) {
      _nextHintRegenTimestamp = now + hintRegenInterval.inMilliseconds;
      ProgressService.saveLastHintRegenTime(_nextHintRegenTimestamp!);
      return;
    }

    // Process all missed intervals while offline
    while (now >= targetTime && _hintsLeft < maxHints) {
      _hintsLeft++;
      ProgressService.saveHints(_hintsLeft);
      targetTime += hintRegenInterval.inMilliseconds;
    }

    if (_hintsLeft >= maxHints) {
      _nextHintRegenTimestamp = null;
      ProgressService.saveLastHintRegenTime(0);
    } else {
      _nextHintRegenTimestamp = targetTime;
      ProgressService.saveLastHintRegenTime(_nextHintRegenTimestamp!);
    }
  }

  void useHint() {
    if (_hintsLeft <= 0 || _currentLevel == null || _hintedLineId != null) return;
    
    for (var line in _currentLevel!.lines) {
      if (line.isExtracted) continue;
      
      final result = PuzzleEngine.checkExitCollision(
        currentLevel: _currentLevel!,
        targetLine: line,
      );
      
      if (!result.hasCollision) {
        _hintedLineId = line.id;
        _hintsLeft--;
        ProgressService.saveHints(_hintsLeft);
        
        if (_hintsLeft < maxHints && _nextHintRegenTimestamp == null) {
          final now = DateTime.now().millisecondsSinceEpoch;
          _nextHintRegenTimestamp = now + hintRegenInterval.inMilliseconds;
          ProgressService.saveLastHintRegenTime(_nextHintRegenTimestamp!);
        }
        
        notifyListeners();
        break;
      }
    }
  }

  @override
  void dispose() {
    _regenTimer?.cancel();
    _collisionTimer?.cancel();
    super.dispose();
  }
}
