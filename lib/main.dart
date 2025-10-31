import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'firebase_options.dart';
import 'router.dart';
import 'services/firestore_service.dart';
import 'services/connectivity_service.dart';
import 'services/connectivity_provider.dart';
import 'services/local_storage_service.dart';
import 'services/sync_queue_service.dart';
import 'services/prefetch_service.dart';
import 'services/draft_upload_service.dart';
import 'view_models/notification_view_model.dart';
import 'widgets/notification_banner.dart';
import 'widgets/offline_banner.dart';
import 'theme/app_colors.dart';

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

  // Initialize Firebase
  if (Firebase.apps.isEmpty) {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  }

  // DISABLE Firebase automatic cache - we use our own Hive implementation
  // Note: Firebase requires minimum 1MB cache size, so we set it to minimum
  // but keep persistenceEnabled=false to avoid automatic caching behavior
  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: false, // ❌ Disabled - using manual Hive cache
    cacheSizeBytes: 1048576, // 1MB minimum (Firebase requirement)
  );

  // Initialize connectivity and local storage services
  await ConnectivityService().initialize();
  await LocalStorageService().initialize();

  // Start auto-sync for queued operations (Scenario 6)
  SyncQueueService().startAutoSync();

  // Initialize draft upload service (Scenario 8)
  // This will automatically process pending drafts when connectivity is restored
  DraftUploadService();

  debugPrint('🚀 App initialized with manual caching (Firebase auto-cache DISABLED)');

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (context) => ThemeProvider()),
        ChangeNotifierProvider(create: (context) => NotificationViewModel()),
        ChangeNotifierProvider(create: (context) => ConnectivityProvider()),
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
      _startBackgroundPrefetch();
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

  /// Start background prefetch of all data for offline support
  Future<void> _startBackgroundPrefetch() async {
    try {
      debugPrint('🚀 [App] Starting background prefetch...');
      // Run prefetch in background without blocking UI
      PrefetchService().prefetchAll().then((_) {
        debugPrint('✅ [App] Background prefetch completed');
      }).catchError((e) {
        debugPrint('❌ [App] Background prefetch failed: $e');
      });
    } catch (e) {
      debugPrint('❌ [App] Error starting prefetch: $e');
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
    return Consumer3<ThemeProvider, NotificationViewModel, ConnectivityProvider>(
      builder: (context, themeProvider, notificationViewModel, connectivityProvider, child) {
        return MaterialApp.router(
          title: 'Campus Marketplace',
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: themeProvider.themeMode,
          routerConfig: router,
          debugShowCheckedModeBanner: false,
          builder: (context, child) {
            return Column(
              children: [
                // Global offline banner with cache age
                if (connectivityProvider.isOffline)
                  OfflineBanner(
                    cacheAge: connectivityProvider.cacheAge,
                    onRetry: () => connectivityProvider.refresh(),
                  ),
                // Notification banner and app content
                Expanded(
                  child: NotificationBannerContainer(
                    viewModel: notificationViewModel,
                    child: child ?? const SizedBox.shrink(),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}