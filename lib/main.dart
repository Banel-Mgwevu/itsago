import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:camera/camera.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'dart:ui' show PlatformDispatcher;
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'cv_storage_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'firebase_options.dart';
import 'remote_config_service.dart';
import 'subscription_service.dart';
import 'app_theme.dart';
import 'splash_screen.dart';
import 'main_menu_screen.dart';
import 'notification_service.dart';

// ── Bauhaus Color Palette ────────────────────────────────
class BauhausColors {
  static const Color red      = Color(0xFFE51E2E);
  static const Color blue     = Color(0xFF1F4C96);
  static const Color yellow   = Color(0xFFFDCC0D);
  static const Color black    = Color(0xFF000000);
  static const Color white    = Color(0xFFFFFFFF);
  static const Color gray     = Color(0xFF808080);
  static const Color lightGray = Color(0xFFF5F5F5);
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    // Enforce POPIA 30-day retention on startup
  CVStorageService.purgeExpired().catchError((_) {});
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

    // Crash reporting: every uncaught Flutter and Dart error goes to
    // Firebase Console > Crashlytics. Off in debug so testing stays quiet.
    await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(!kDebugMode);
    FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;
    PlatformDispatcher.instance.onError = (error, stack) {
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
      return true;
    };

    // Initialize in-app purchase / subscription handling. Wrapped so a
    // store-connection issue (e.g. no network, store unavailable) never
    // blocks the app from starting - PremiumStatus.isPremium() already
    // falls back to Firestore/local cache if this hasn't finished yet.
    try {
      await SubscriptionService().initialize();
    } catch (e) {
      if (kDebugMode) print('SubscriptionService init failed (non-fatal): $e');
    }

    // App Check is DISABLED for now. Its debug provider needs the printed
    // debug token registered in Firebase Console > App Check > Apps >
    // (this app) > Manage debug tokens before it will validate - without
    // that step it fails with "Too many attempts" on every call and
    // appears to be interfering with Cloud Function requests (including
    // transcription). Re-enable only after registering the token and
    // confirming Cloud Function calls still succeed with it active.
    //
    // try {
    //   await FirebaseAppCheck.instance.activate(
    //     androidProvider: kDebugMode
    //         ? AndroidProvider.debug
    //         : AndroidProvider.playIntegrity,
    //   );
    // } catch (e) {
    //   print('App Check activation failed (non-fatal): $e');
    // }

    tz.initializeTimeZones();
    try { await RemoteConfigService.init(); } catch (_) {}
    await NotificationService().initialize();
    runApp(const ItagoApp());
  } catch (e) {
    runApp(ErrorApp(message: 'Failed to initialize app: ${e.toString()}'));
  }
}

class ItagoApp extends StatefulWidget {
  const ItagoApp({super.key});
  @override
  State<ItagoApp> createState() => _ItagoAppState();
}

class _ItagoAppState extends State<ItagoApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.paused) {
      NotificationService().onAppPaused();
    } else if (state == AppLifecycleState.resumed) {
      NotificationService().onAppResumed();
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ITSAGO - AI Interview Prep',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.theme,
      home: const SplashScreen(),
    );
  }
}

// ── Error Screen ─────────────────────────────────────────
class ErrorApp extends StatelessWidget {
  final String message;
  const ErrorApp({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: BauhausColors.white,
        body: Center(
          child: Container(
            width: 300, height: 300,
            decoration: const BoxDecoration(
              color: BauhausColors.red, shape: BoxShape.circle),
            child: Center(child: Padding(
              padding: const EdgeInsets.all(40),
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Container(width: 60, height: 60,
                  color: BauhausColors.white,
                  child: const Icon(Icons.error_outline,
                    size: 40, color: BauhausColors.red)),
                const SizedBox(height: 20),
                const Text('ERROR', style: TextStyle(
                  fontSize: 20, fontWeight: FontWeight.w900,
                  color: BauhausColors.white, letterSpacing: 2)),
                const SizedBox(height: 10),
                Text(message, textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 12,
                    fontWeight: FontWeight.bold, color: BauhausColors.white)),
              ]))),
          ),
        ),
      ),
    );
  }
}

// ── InterviewCoachApp — used by splash screen ─────────────
class InterviewCoachApp extends StatelessWidget {
  final List<CameraDescription> cameras;
  const InterviewCoachApp({super.key, required this.cameras});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ITSAGO - AI Interview Prep',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.theme,
      home: MainMenuScreen(cameras: cameras),
    );
  }
}

// ── Upgrade modal stub — keeps other screens compiling ───
extension SubscriptionHelpers on BuildContext {
  Future<void> showUpgradeModalIfNeeded(List<CameraDescription> cameras) async {}
}






