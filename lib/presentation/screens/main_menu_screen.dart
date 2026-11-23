import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_colors.dart';
import '../managers/game_manager.dart';
import '../managers/theme_provider.dart';
import '../../services/admob_service.dart';
import 'game_screen.dart';

class MainMenuScreen extends StatelessWidget {
  const MainMenuScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final manager = context.watch<GameManager>();
    final themeProvider = context.watch<ThemeProvider>();
    final currentLvl = manager.currentUnlockedLevel;

    return Scaffold(
      backgroundColor: themeProvider.backgroundColor,
      body: SafeArea(
        child: Stack(
          children: [
            // Theme Switcher (Top Right)
            Positioned(
              top: 16,
              right: 16,
              child: Row(
                children: [
                  _ThemeButton(
                    mode: AppThemeMode.light,
                    currentMode: themeProvider.currentMode,
                    color: AppColors.bgLight,
                    onTap: () => themeProvider.setTheme(AppThemeMode.light),
                  ),
                  const SizedBox(width: 8),
                  _ThemeButton(
                    mode: AppThemeMode.dark,
                    currentMode: themeProvider.currentMode,
                    color: AppColors.bgDark,
                    onTap: () => themeProvider.setTheme(AppThemeMode.dark),
                  ),
                  const SizedBox(width: 8),
                  _ThemeButton(
                    mode: AppThemeMode.cream,
                    currentMode: themeProvider.currentMode,
                    color: AppColors.bgCream,
                    onTap: () => themeProvider.setTheme(AppThemeMode.cream),
                  ),
                ],
              ),
            ),
            
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const Spacer(),
                    
                    // Logo matching the screenshot
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.change_history_rounded, // Triangle for 'A'
                          size: 58,
                          color: AppColors.buttonBlue,
                        ),
                        Text(
                          'rrows',
                          style: GoogleFonts.poppins(
                            fontSize: 48,
                            fontWeight: FontWeight.w800,
                            color: AppColors.buttonBlue,
                            letterSpacing: -1,
                          ),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 8),
                    
                    // Level Indicator
                    Text(
                      'Level $currentLvl',
                      style: GoogleFonts.poppins(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: AppColors.buttonBlue.withAlpha(200),
                      ),
                    ),
                    
                    const Spacer(),

                    // Play Button matching the screenshot (Wide blue pill)
                    SizedBox(
                      width: double.infinity,
                      height: 65,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.buttonBlue,
                          foregroundColor: Colors.white,
                          shape: const StadiumBorder(),
                          elevation: 0, // Flat design
                        ),
                        onPressed: () {
                          final manager = context.read<GameManager>();
                          manager.selectLevel(currentLvl);
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const GameScreen()),
                          );
                        },
                        child: Text(
                          'Play',
                          style: GoogleFonts.poppins(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ThemeButton extends StatelessWidget {
  final AppThemeMode mode;
  final AppThemeMode currentMode;
  final Color color;
  final VoidCallback onTap;

  const _ThemeButton({
    required this.mode,
    required this.currentMode,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isSelected = mode == currentMode;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(
            color: isSelected ? AppColors.buttonBlue : Colors.grey.withAlpha(100),
            width: isSelected ? 3 : 1,
          ),
          boxShadow: [
            if (isSelected)
              BoxShadow(
                color: AppColors.buttonBlue.withAlpha(50),
                blurRadius: 8,
              )
          ],
        ),
      ),
    );
  }
}
