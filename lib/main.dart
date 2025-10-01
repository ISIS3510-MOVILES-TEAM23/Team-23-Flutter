import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'firebase_options.dart';
import 'router.dart';
import 'services/firestore_service.dart';
import 'theme/app_colors.dart';

// Tiempo de inicio para medir duración del lanzamiento
DateTime? _appStartTime;

void main() async {
  _appStartTime = DateTime.now();
  WidgetsFlutterBinding.ensureInitialized();

  if (Firebase.apps.isEmpty) {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  }
  runApp(
    ChangeNotifierProvider(
      create: (context) => ThemeProvider(),
      child: const MyApp(),
    ),
  );
}

class ThemeProvider with ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.light;

  ThemeMode get themeMode => _themeMode;

  void toggleTheme() {
    _themeMode = _themeMode == ThemeMode.light 
        ? ThemeMode.dark 
        : ThemeMode.light;
    notifyListeners();
  }
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();
    // Registrar el tiempo de inicio después de que el primer frame se renderice
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _logAppStartTime();
    });
  }

  Future<void> _logAppStartTime() async {
    try {
      if (_appStartTime != null) {
        final endTime = DateTime.now();
        final launchDuration = endTime.difference(_appStartTime!);
        
        // Registrar el tiempo de inicio con la duración del lanzamiento
        await FirestoreService.logAppStartTime(
          launchDurationMs: launchDuration.inMilliseconds,
        );
        
        // App launched in ${launchDuration.inMilliseconds}ms
      }
    } catch (e) {
      // Error logging app start time: $e
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        return MaterialApp.router(
          title: 'Campus Marketplace',
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: themeProvider.themeMode,
          routerConfig: router,
          debugShowCheckedModeBanner: false,
        );
      },
    );
  }
}