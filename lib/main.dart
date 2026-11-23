import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'data/database/progress_service.dart';
import 'data/services/level_storage_service.dart';
import 'presentation/managers/game_manager.dart';
import 'presentation/screens/main_menu_screen.dart';
import 'services/admob_service.dart';

import 'presentation/managers/theme_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);

  await ProgressService.init();
  await LevelStorageService.init();
  await AdMobService.init();

  runApp(const ArrowsPuzzleApp());
}

class ArrowsPuzzleApp extends StatelessWidget {
  const ArrowsPuzzleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => GameManager()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
      ], 
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, child) {
          return MaterialApp(
            title: 'Arrows Untangle Puzzle',
            debugShowCheckedModeBanner: false,
            theme: ThemeData(
              scaffoldBackgroundColor: themeProvider.backgroundColor,
              useMaterial3: true,
            ),
            home: const MainMenuScreen(),
          );
        },
      ),
    );
  }
}
