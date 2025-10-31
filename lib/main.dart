import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';

import 'firebase_options.dart';
import 'router.dart';
import 'services/firestore_service.dart';
import 'services/hive_service.dart';
import 'theme/app_colors.dart';
import 'view_models/notification_view_model.dart';
import 'widgets/notification_banner.dart';

// Tiempo de inicio para medir duración del lanzamiento
DateTime? _appStartTime;

void main() async {
  _appStartTime = DateTime.now();
  WidgetsFlutterBinding.ensureInitialized();

  // Cargar variables de entorno
  try {
    await dotenv.load(fileName: ".env");
    debugPrint('✅ Variables de entorno cargadas correctamente');
  } catch (e) {
    debugPrint('⚠️ No se pudo cargar .env: $e');
    // Continuar sin .env (las features de IA no funcionarán)
  }

  // Initialize Hive for local database
  try {
    await HiveService.initialize();
    debugPrint('✅ Hive initialized successfully');
  } catch (e) {
    debugPrint('❌ Error initializing Hive: $e');
    // App can continue without Hive, but offline features won't work
  }

  if (Firebase.apps.isEmpty) {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  }
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (context) => ThemeProvider()),
        ChangeNotifierProvider(create: (context) => NotificationViewModel()),
      ],
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
      _checkNotifications();
    });
  }

  Future<void> _checkNotifications() async {
    try {
      final viewModel =
          Provider.of<NotificationViewModel>(context, listen: false);
      await viewModel.loadNotifications();
    } catch (e) {
      debugPrint('❌ Error checking notifications: $e');
    }
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
    return Consumer2<ThemeProvider, NotificationViewModel>(
      builder: (context, themeProvider, notificationViewModel, child) {
        return MaterialApp.router(
          title: 'Campus Marketplace',
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: themeProvider.themeMode,
          routerConfig: router,
          debugShowCheckedModeBanner: false,
          builder: (context, child) {
            return NotificationBannerContainer(
              viewModel: notificationViewModel,
              child: child ?? const SizedBox.shrink(),
            );
          },
        );
      },
    );
  }
}