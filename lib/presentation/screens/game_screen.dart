import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:confetti/confetti.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/theme/app_colors.dart';
import '../../data/models/game_models.dart';
import '../../services/admob_service.dart';
import '../managers/game_manager.dart';
import '../managers/theme_provider.dart';
import '../widgets/puzzle_painter.dart';

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> with TickerProviderStateMixin {
  late ConfettiController _confettiController;
  late AnimationController _animationController;
  late AnimationController _collisionAnimationController;
  late AnimationController _pulseController;
  late AnimationController _introController;
  late Animation<double> _extractAnimation;
  late Animation<double> _uiFadeAnimation;
  late Animation<double> _introProgressAnimation;
  bool _confettiTriggered = false;
  int? _currentAnimatingId;
  int? _currentCollidingId;

  final TweenSequence<double> _bumpSequence = TweenSequence<double>([
    TweenSequenceItem(tween: Tween(begin: 0.0, end: 0.15).chain(CurveTween(curve: Curves.easeOut)), weight: 30),
    TweenSequenceItem(tween: Tween(begin: 0.15, end: -0.05).chain(CurveTween(curve: Curves.easeInOut)), weight: 40),
    TweenSequenceItem(tween: Tween(begin: -0.05, end: 0.0).chain(CurveTween(curve: Curves.easeIn)), weight: 30),
  ]);

  int _lastSeenLevelId = -1;
  GameManager? _gameManager;

  void _onManagerUpdate() {
    final newLevelId = _gameManager?.currentLevelId ?? -1;
    if (newLevelId != _lastSeenLevelId && newLevelId != -1) {
      _lastSeenLevelId = newLevelId;
      _introController.reset();
      _introController.forward();
    }
  }

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(duration: const Duration(seconds: 2));
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _extractAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOutQuad, // Smoother, elegant acceleration without the violent whip
    );
    _collisionAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
    
    _introController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    );
    _uiFadeAnimation = CurvedAnimation(
      parent: _introController,
      curve: const Interval(0.0, 0.35, curve: Curves.easeIn),
    );
    _introProgressAnimation = CurvedAnimation(
      parent: _introController,
      curve: const Interval(0.2, 1.0, curve: Curves.easeInOutCubic),
    );
    _introController.forward();
    _lastSeenLevelId = -1;
    // Attach listener after first frame so context is fully ready
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _gameManager = context.read<GameManager>();
      _lastSeenLevelId = _gameManager!.currentLevelId;
      _gameManager!.addListener(_onManagerUpdate);
    });
  }

  @override
  void dispose() {
    _gameManager?.removeListener(_onManagerUpdate);
    _confettiController.dispose();
    _animationController.dispose();
    _collisionAnimationController.dispose();
    _pulseController.dispose();
    _introController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final GameManager manager = Provider.of<GameManager>(context, listen: false);
    final themeProvider = context.watch<ThemeProvider>();

    return Scaffold(
      backgroundColor: themeProvider.backgroundColor,
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                // Premium App Header - Centered Layout
                FadeTransition(
                  opacity: _uiFadeAnimation,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    child: Stack(
                    alignment: Alignment.topCenter,
                    children: [
                      // LEFT: Back Button
                      Align(
                        alignment: Alignment.topLeft,
                        child: IconButton(
                          icon: Icon(Icons.arrow_back_ios_new_rounded, color: themeProvider.textColor, size: 24),
                          onPressed: () => Navigator.pop(context),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ),

                      // CENTER: Level & Hearts
                      Selector<GameManager, (int, int)>(
                        selector: (_, m) => (m.currentLevelId, m.hearts),
                        builder: (context, data, _) {
                          final (currentLevelId, hearts) = data;
                          return Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Level $currentLevelId',
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.5,
                                  color: themeProvider.textColor,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: List.generate(3, (index) {
                                  return Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 4.0),
                                    child: Icon(
                                      Icons.favorite_rounded,
                                      color: index < hearts ? AppColors.heartActive : themeProvider.surfaceBorderColor,
                                      size: 20,
                                    ),
                                  );
                                }),
                              ),
                            ],
                          );
                        },
                      ),

                      // RIGHT: Hint, Reset, & Difficulty Text
                      Align(
                        alignment: Alignment.topRight,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // Hint Button
                                Selector<GameManager, (int, String)>(
                                  selector: (_, m) => (m.hintsLeft, m.nextHintCooldownStr),
                                  builder: (context, hintState, _) {
                                    final hints = hintState.$1;
                                    final cooldown = hintState.$2;
                                    final hasHints = hints > 0;
                                    return GestureDetector(
                                      onTap: () {
                                        if (hasHints) {
                                          manager.useHint();
                                        } else {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(
                                              content: Text('No hints left. Next hint in $cooldown'),
                                              backgroundColor: AppColors.errorFlash,
                                            ),
                                          );
                                        }
                                      },
                                      child: Container(
                                        color: Colors.transparent, // expand hit area
                                        padding: const EdgeInsets.all(4.0),
                                        child: Stack(
                                          alignment: Alignment.center,
                                          children: [
                                            Icon(
                                              Icons.lightbulb_outline_rounded,
                                              color: themeProvider.textColor,
                                              size: 32,
                                            ),
                                            Positioned(
                                              top: 5,
                                              child: Text(
                                                hasHints ? '$hints' : '0',
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w900,
                                                  color: themeProvider.textColor,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                ),
                                 const SizedBox(width: 8),
                                 // Reset Button
                                 IconButton(
                                   padding: EdgeInsets.zero,
                                   constraints: const BoxConstraints(),
                                   icon: Icon(Icons.refresh_rounded, size: 28, color: themeProvider.textColor),
                                   onPressed: () {
                                     if (manager.hearts > 0) {
                                       manager.resetLevel();
                                     }
                                   },
                                 ),
                                 // DEBUG-ONLY: Skip Level button — never visible in release builds
                                 if (kDebugMode) ...([
                                   const SizedBox(width: 4),
                                   IconButton(
                                     padding: EdgeInsets.zero,
                                     constraints: const BoxConstraints(),
                                     tooltip: '[DEBUG] Skip Level',
                                     icon: Icon(Icons.skip_next_rounded, size: 28, color: Colors.amber),
                                     onPressed: () => manager.skipLevel(),
                                   ),
                                 ]),
                              ],
                            ),
                            const SizedBox(height: 8),
                            // Difficulty Text
                            Selector<GameManager, int>(
                              selector: (_, m) => m.currentLevelId,
                              builder: (context, currentLevelId, _) {
                                return Text(
                                  _difficultyLabel(currentLevelId),
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                    color: themeProvider.primaryColor, // Uses the bright Periwinkle Blue / Purple
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                ),

                // Sleek Level Progress Bar
                Selector<GameManager, (int, int)>(
                  selector: (_, m) {
                    final level = m.currentLevel;
                    if (level == null) return (0, 0);
                    final total = level.lines.length;
                    final cleared = level.lines.where((l) => l.isExtracted).length;
                    return (cleared, total);
                  },
                  builder: (context, progress, _) {
                    final cleared = progress.$1;
                    final total = progress.$2;
                    if (total == 0) return const SizedBox.shrink();

                    final double percent = cleared / total;

                    return FadeTransition(
                      opacity: _uiFadeAnimation,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'PROGRESS',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 1.5,
                                  color: themeProvider.textSecondaryColor,
                                ),
                              ),
                              Text(
                                '$cleared / $total CLEARED',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 1.0,
                                  color: themeProvider.textColor,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Container(
                            height: 6,
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: themeProvider.surfaceColor,
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: themeProvider.surfaceBorderColor, width: 1),
                            ),
                            child: TweenAnimationBuilder<double>(
                              tween: Tween<double>(begin: 0.0, end: percent),
                              duration: const Duration(milliseconds: 350),
                              curve: Curves.easeOutCubic,
                              builder: (context, value, child) {
                                return FractionallySizedBox(
                                  alignment: Alignment.centerLeft,
                                  widthFactor: value,
                                  child: Container(
                                      decoration: BoxDecoration(
                                        color: themeProvider.lineColor,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                    );
                  },
                ),

                // Canvas Container - Rebuilds ONLY when currentLevel changes
                Expanded(
                  child: Selector<GameManager, LevelConfig?>(
                    selector: (_, m) => m.currentLevel,
                    builder: (context, level, _) {
                      if (level == null) {
                        return const Center(child: CircularProgressIndicator(color: AppColors.textSecondary));
                      }

                      return LayoutBuilder(
                        builder: (context, constraints) {
                          // Use perfect matrix bounds since the level is a perfectly packed rectangle
                          final double gridW = (level.matrixWidth - 1).toDouble();
                          final double gridH = (level.matrixHeight - 1).toDouble();

                          final double containerWidth = constraints.maxWidth;
                          final double containerHeight = constraints.maxHeight;

                          // Apply 25% padding of the container's size to zoom out the puzzle comfortably
                          final double totalPaddingX = containerWidth * 0.25;
                          final double totalPaddingY = containerHeight * 0.25;

                          final double scale = min(
                            (containerWidth - totalPaddingX) / (gridW > 0 ? gridW : 1.0),
                            (containerHeight - totalPaddingY) / (gridH > 0 ? gridH : 1.0),
                          );

                          // Center based perfectly on the dot grid centers
                          final double translateX = (containerWidth - gridW * scale) / 2.0;
                          final double translateY = (containerHeight - gridH * scale) / 2.0;

                          return Selector<GameManager, bool>(
                            selector: (_, m) => m.isLevelCleared || m.hearts <= 0,
                            builder: (context, shouldBlockControls, _) {
                              return InteractiveViewer(
                                minScale: 0.5,
                                maxScale: 4.0,
                                boundaryMargin: EdgeInsets.all(containerWidth),
                                child: Stack(
                                  children: [
                                  Positioned.fill(
                                    child: GestureDetector(
                                      behavior: HitTestBehavior.opaque,
                                      onTapDown: (details) {
                                        if (manager.isLevelCleared || manager.hearts <= 0) return;

                                        // Convert touch event from local screen coordinates to matrix/grid coordinates
                                        final double localX = details.localPosition.dx;
                                        final double localY = details.localPosition.dy;

                                        final int targetGridX = ((localX - translateX) / scale).round();
                                        final int targetGridY = ((localY - translateY) / scale).round();

                                        if (targetGridX >= 0 &&
                                            targetGridX < level.matrixWidth &&
                                            targetGridY >= 0 &&
                                            targetGridY < level.matrixHeight) {
                                          manager.handleGridTap(targetGridX, targetGridY);
                                        }
                                      },
                                      child: SizedBox(
                                        width: constraints.maxWidth,
                                        height: constraints.maxHeight,
                                        child: Selector<GameManager, _CanvasRenderState>(
                                          selector: (_, m) => _CanvasRenderState(
                                            levelId: m.currentLevelId,
                                            collidingLineId: m.collidingLineId,
                                            obstacleLineId: m.obstacleLineId,
                                            animatingLineId: m.animatingLineId,
                                            hintedLineId: m.hintedLineId,
                                          ),
                                          builder: (context, renderState, _) {
                                            // Native animation sync trigger
                                            if (renderState.animatingLineId != null &&
                                                renderState.animatingLineId != _currentAnimatingId) {
                                              _currentAnimatingId = renderState.animatingLineId;

                                              // Option 1: Dynamic duration based on arrow length!
                                              final targetLine = level.lines.firstWhere((l) => l.id == _currentAnimatingId, orElse: () => level.lines.first);
                                              final length = targetLine.bodyPoints.length;
                                              
                                              // Relaxed base speed of 800ms + 40ms per block (capped at 2000ms)
                                              final ms = (800 + (length * 40)).clamp(800, 2000);
                                              _animationController.duration = Duration(milliseconds: ms);

                                              _animationController.forward().then((_) {
                                                if (_currentAnimatingId != null) {
                                                  manager.finalizeExtraction(_currentAnimatingId!);
                                                  _currentAnimatingId = null;
                                                }
                                                _animationController.reset();
                                              });
                                            }

                                            // Native collision bump animation trigger
                                            if (renderState.collidingLineId != null &&
                                                renderState.collidingLineId != _currentCollidingId) {
                                              _currentCollidingId = renderState.collidingLineId;
                                              _collisionAnimationController.forward().then((_) {
                                                _currentCollidingId = null;
                                                _collisionAnimationController.reset();
                                              });
                                            }

                                            return Stack(
                                              children: [
                                                // LAYER 1: STATIC (Only repaints during intro or when state radically changes)
                                                RepaintBoundary(
                                                  child: AnimatedBuilder(
                                                    animation: _introController,
                                                    builder: (context, _) {
                                                      final hiddenIds = {
                                                        renderState.animatingLineId,
                                                        renderState.collidingLineId,
                                                        renderState.obstacleLineId,
                                                        renderState.hintedLineId,
                                                      }.where((id) => id != null).cast<int>().toSet();

                                                      return CustomPaint(
                                                        size: Size.infinite,
                                                        painter: StaticPuzzlePainter(
                                                          level: level,
                                                          hiddenLineIds: hiddenIds,
                                                          scale: scale,
                                                          translateX: translateX,
                                                          translateY: translateY,
                                                          introProgress: _introProgressAnimation.value,
                                                          dotColor: themeProvider.gridDotColor,
                                                          baseLineColor: themeProvider.lineColor,
                                                        ),
                                                      );
                                                    },
                                                  ),
                                                ),
                                                // LAYER 2: ACTIVE (Repaints at 60fps but only draws 1-2 moving elements)
                                                RepaintBoundary(
                                                  child: AnimatedBuilder(
                                                    animation: Listenable.merge([
                                                      _animationController,
                                                      _collisionAnimationController,
                                                      _pulseController,
                                                    ]),
                                                    builder: (context, _) {
                                                      final activeIds = {
                                                        renderState.animatingLineId,
                                                        renderState.collidingLineId,
                                                        renderState.obstacleLineId,
                                                        renderState.hintedLineId,
                                                      }.where((id) => id != null).cast<int>().toSet();

                                                      final double bumpVal = _bumpSequence.evaluate(_collisionAnimationController);
                                                      return CustomPaint(
                                                        size: Size.infinite,
                                                        painter: ActivePuzzlePainter(
                                                          level: level,
                                                          activeLineIds: activeIds,
                                                          scale: scale,
                                                          translateX: translateX,
                                                          translateY: translateY,
                                                          collidingLineId: renderState.collidingLineId,
                                                          obstacleLineId: renderState.obstacleLineId,
                                                          animatingLineId: renderState.animatingLineId,
                                                          hintedLineId: renderState.hintedLineId,
                                                          animationProgress: _extractAnimation.value,
                                                          collisionProgress: bumpVal,
                                                          pulseProgress: _pulseController.value,
                                                          dotColor: themeProvider.gridDotColor,
                                                          baseLineColor: themeProvider.lineColor,
                                                        ),
                                                      );
                                                    },
                                                  ),
                                                ),
                                              ],
                                            );
                                          },
                                        ),
                                      ),
                                    ),
                                  ),
                                  ],
                                ),
                              );
                            },
                          );
                        },
                      );
                    },
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),

            // Confetti & Clear Trigger Layer - optimized via single selector
            Selector<GameManager, (bool, int)>(
              selector: (_, m) => (m.isLevelCleared, m.currentLevelId),
              builder: (context, data, _) {
                final isLevelCleared = data.$1;
                final currentLevelId = data.$2;
                if (isLevelCleared && !_confettiTriggered) {
                  _confettiTriggered = true;
                  if (currentLevelId % 10 == 0) {
                    _confettiController.play();
                  }
                } else if (!isLevelCleared && _confettiTriggered) {
                  _confettiTriggered = false;
                  _confettiController.stop();
                }

                return const SizedBox.shrink();
              },
            ),

            // Confetti Widget Emitter
            Align(
              alignment: Alignment.topCenter,
              child: ConfettiWidget(
                confettiController: _confettiController,
                blastDirection: pi / 2,
                maxBlastForce: 5,
                minBlastForce: 2,
                emissionFrequency: 0.05,
                numberOfParticles: 20,
                gravity: 0.2,
                colors: const [
                  Color(0xFF3B82F6),
                  Color(0xFF10B981),
                  Color(0xFFF59E0B),
                  Color(0xFFEC4899),
                  Color(0xFF8B5CF6)
                ],
              ),
            ),

            // Level Cleared Overlay - Rebuilds ONLY when level is cleared
            Selector<GameManager, _ClearOverlayState>(
              selector: (_, m) => _ClearOverlayState(
                isCleared: m.isLevelCleared,
                levelId: m.currentLevelId,
                hearts: m.hearts,
              ),
              builder: (context, state, _) {
                if (!state.isCleared) return const SizedBox.shrink();

                String titleText;
                Color borderColor = const Color(0xFFF5EAE0); // Warm Luxury Cream
                if (state.levelId >= 58) {
                  titleText = 'ALL LEVELS CLEARED!';
                } else if (state.hearts >= 3) {
                  titleText = 'PERFECT!';
                } else if (state.hearts == 2) {
                  titleText = 'GREAT JOB!';
                } else {
                  titleText = 'PHEW!';
                }

                Widget buildStar(int index) {
                  bool isLit = index < state.hearts;
                  return Icon(
                    Icons.star_rounded,
                    size: 64,
                    color: isLit ? const Color(0xFFF5EAE0) : AppColors.surfaceBorder,
                  ).animate(delay: Duration(milliseconds: 300 + index * 150))
                   .scale(begin: const Offset(0.0, 0.0), end: const Offset(1.0, 1.0), curve: Curves.easeOutBack, duration: const Duration(milliseconds: 500))
                   .fadeIn();
                }

                return Container(
                  color: Colors.black.withAlpha(200),
                  child: Center(
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 32),
                      padding: const EdgeInsets.all(28),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(32),
                        border: Border.all(color: borderColor.withAlpha(150), width: 2),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (state.levelId < 58)
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                buildStar(0),
                                buildStar(1),
                                buildStar(2),
                              ],
                            )
                          else
                            const Icon(
                              Icons.check_circle_outline_rounded,
                              color: Color(0xFFF5EAE0),
                              size: 72,
                            ).animate().scale(curve: Curves.easeOutBack).fadeIn(),
                          const SizedBox(height: 24),
                          Text(
                            titleText,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 2,
                              color: AppColors.textPrimary,
                            ),
                          ).animate(delay: const Duration(milliseconds: 800)).fadeIn().slideY(begin: 0.3, end: 0.0),
                          const SizedBox(height: 8),
                          Text(
                            state.levelId >= 58
                                ? 'Congratulations! You have completed all vector puzzles!'
                                : 'Untangled with ${state.hearts} heart${state.hearts == 1 ? '' : 's'} remaining.',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 14,
                              color: AppColors.textSecondary,
                            ),
                          ).animate(delay: const Duration(milliseconds: 900)).fadeIn(),
                          const SizedBox(height: 32),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: AppColors.textPrimary,
                                    side: const BorderSide(color: AppColors.surfaceBorder, width: 1.5),
                                    padding: const EdgeInsets.symmetric(vertical: 14),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                  ),
                                  onPressed: () {
                                    if (state.levelId >= 58) {
                                      manager.selectLevel(1);
                                    }
                                    Navigator.pop(context);
                                  },
                                  child: const Text('MENU'),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: borderColor,
                                    foregroundColor: const Color(0xFF1E1C1A),
                                    padding: const EdgeInsets.symmetric(vertical: 14),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                  ),
                                  onPressed: () {
                                    if (state.levelId >= 58) {
                                      manager.selectLevel(1);
                                      Navigator.pop(context);
                                    } else {
                                      manager.loadNextLevel();
                                    }
                                  },
                                  child: Text(
                                    state.levelId >= 58 ? 'PLAY AGAIN' : 'NEXT',
                                    style: const TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ),
                            ],
                          ).animate(delay: const Duration(milliseconds: 1000)).fadeIn().slideY(begin: 0.2, end: 0.0),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),

            // Game Over Overlay - Rebuilds ONLY when hearts are 0
            Selector<GameManager, int>(
              selector: (_, m) => m.hearts,
              builder: (context, hearts, _) {
                if (hearts > 0) return const SizedBox.shrink();

                return Container(
                  color: Colors.black.withAlpha(200),
                  child: Center(
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 32),
                      padding: const EdgeInsets.all(28),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(32),
                        border: Border.all(color: AppColors.errorFlash.withAlpha(100), width: 2),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.heart_broken_rounded,
                            color: AppColors.errorFlash,
                            size: 72,
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'LEVEL FAILED',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 2,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'You ran out of hearts.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 14,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 24),
                          Builder(builder: (context) {
                            final failCount = context.read<GameManager>().levelFailCount;
                            final showExtraHeart = true; // Always show extra heart on failure
                            final showSkipLevel = failCount >= 2; // 3rd failure and beyond

                            return Column(
                              children: [
                                // RETRY — always visible
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.errorFlash,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(vertical: 14),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                    ),
                                    onPressed: () => manager.resetLevel(),
                                    child: const Text(
                                      'RETRY',
                                      style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1),
                                    ),
                                  ),
                                ),

                                // EXTRA HEART — visible on fail 3, 4, 5
                                if (showExtraHeart) ...[
                                  const SizedBox(height: 12),
                                  SizedBox(
                                    width: double.infinity,
                                    child: OutlinedButton(
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: AppColors.textPrimary,
                                        side: const BorderSide(color: AppColors.surfaceBorder, width: 1.5),
                                        padding: const EdgeInsets.symmetric(vertical: 14),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(20),
                                        ),
                                      ),
                                      onPressed: () async {
                                        final success = await AdMobService.showRewardedAd(context: context);
                                        if (success) {
                                          manager.grantExtraHeart();
                                          if (context.mounted) {
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              const SnackBar(
                                                content: Text('+1 Heart granted!'),
                                                duration: Duration(seconds: 2),
                                              ),
                                            );
                                          }
                                        }
                                      },
                                      child: const Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(Icons.play_circle_outline_rounded, size: 18),
                                          SizedBox(width: 8),
                                          Text('EXTRA HEART', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1)),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],

                                // SKIP LEVEL — visible from fail 6 onward (replaces extra heart)
                                if (showSkipLevel) ...[
                                  const SizedBox(height: 12),
                                  SizedBox(
                                    width: double.infinity,
                                    child: OutlinedButton(
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: AppColors.primary,
                                        side: const BorderSide(color: AppColors.primary, width: 1.5),
                                        padding: const EdgeInsets.symmetric(vertical: 14),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(20),
                                        ),
                                      ),
                                      onPressed: () async {
                                        final success1 = await AdMobService.showRewardedAd(context: context);
                                        if (!success1) return;
                                        if (!context.mounted) return;

                                        final wantSecondAd = await showDialog<bool>(
                                          context: context,
                                          barrierDismissible: false,
                                          builder: (c) => AlertDialog(
                                            backgroundColor: AppColors.surface,
                                            title: const Text('Almost there!', style: TextStyle(color: AppColors.textPrimary)),
                                            content: const Text('You watched 1/2 ads. Watch one more ad to skip this level!', style: TextStyle(color: AppColors.textSecondary)),
                                            actions: [
                                              TextButton(
                                                onPressed: () => Navigator.pop(c, false),
                                                child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
                                              ),
                                              TextButton(
                                                onPressed: () => Navigator.pop(c, true),
                                                child: const Text('Watch Ad', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
                                              ),
                                            ],
                                          ),
                                        );

                                        if (wantSecondAd != true) return;
                                        if (!context.mounted) return;

                                        final success2 = await AdMobService.showRewardedAd(context: context);
                                        if (success2) {
                                          manager.skipLevel();
                                        }
                                      },
                                      child: const Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(Icons.skip_next_rounded, size: 20),
                                          SizedBox(width: 8),
                                          Text('SKIP LEVEL', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1)),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],

                                // QUIT TO MENU — always visible as a subtle text link
                                const SizedBox(height: 16),
                                GestureDetector(
                                  onTap: () => Navigator.pop(context),
                                  child: const Text(
                                    'Quit to Menu',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: AppColors.textSecondary,
                                      decoration: TextDecoration.underline,
                                      decorationColor: AppColors.textSecondary,
                                    ),
                                  ),
                                ),
                              ],
                            );
                          }),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

// Helpers for optimization
String _difficultyLabel(int levelId) {
  final int position = (levelId - 1) % 5;
  switch (position) {
    case 0: return 'Easy';
    case 1: return 'Normal';
    case 2: return 'Hard';
    case 3: return 'Super Hard';
    case 4: return 'Extreme';
    default: return 'Normal';
  }
}

class _CanvasRenderState {
  final int levelId;
  final int? collidingLineId;
  final int? obstacleLineId;
  final int? animatingLineId;
  final int? hintedLineId;

  _CanvasRenderState({
    required this.levelId,
    this.collidingLineId,
    this.obstacleLineId,
    this.animatingLineId,
    this.hintedLineId,
  });

  @override
  bool operator ==(Object other) =>
      other is _CanvasRenderState &&
      other.levelId == levelId &&
      other.collidingLineId == collidingLineId &&
      other.obstacleLineId == obstacleLineId &&
      other.animatingLineId == animatingLineId &&
      other.hintedLineId == hintedLineId;

  @override
  int get hashCode => Object.hash(levelId, collidingLineId, obstacleLineId, animatingLineId, hintedLineId);
}

class _ClearOverlayState {
  final bool isCleared;
  final int levelId;
  final int hearts;

  _ClearOverlayState({
    required this.isCleared,
    required this.levelId,
    required this.hearts,
  });

  @override
  bool operator ==(Object other) =>
      other is _ClearOverlayState && other.isCleared == isCleared && other.levelId == levelId && other.hearts == hearts;

  @override
  int get hashCode => Object.hash(isCleared, levelId, hearts);
}


