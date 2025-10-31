import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:camera/camera.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:interviewai/main_menu_screen.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'firebase_options.dart';

import 'splash_screen.dart';
import 'notification_service.dart';
import 'subscription_service.dart';

// Bauhaus Color Palette
class BauhausColors {
  static const Color red = Color(0xFFE51E2E);
  static const Color blue = Color(0xFF1F4C96);
  static const Color yellow = Color(0xFFFDCC0D);
  static const Color black = Color(0xFF000000);
  static const Color white = Color(0xFFFFFFFF);
  static const Color gray = Color(0xFF808080);
  static const Color lightGray = Color(0xFFF5F5F5);
}

// Subscription Configuration
class SubscriptionConfig {
  // Updated product identifiers to match your Play Console setup
  static const String monthlyProductId = 'itsago_prod'; // Your current subscription ID
  static const String annualProductId = 'itsago_annual_prod'; // Create this in Play Console
  
  // For testing purposes
  static const String testProductId = 'android.test.purchased';
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    // Initialize Firebase
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    // Initialize timezone data for local notifications
    tz.initializeTimeZones();

    // Initialize notification service
    await NotificationService().initialize();

    // Initialize Subscription Service
    await SubscriptionService().initialize();

    // Start with splash screen - authentication check happens there
    runApp(const ItagoApp());
  } catch (e) {
    // If initialization fails, show error screen
    runApp(ErrorApp(message: 'Failed to initialize app: ${e.toString()}'));
  }
}

class ItagoApp extends StatefulWidget {
  const ItagoApp({super.key});

  @override
  State<ItagoApp> createState() => _ItagoAppState();
}

class _ItagoAppState extends State<ItagoApp> with WidgetsBindingObserver {
  late Stream<User?> _authStateChanges;
  final SubscriptionService _subscriptionService = SubscriptionService();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    
    // Listen to authentication state changes
    _authStateChanges = FirebaseAuth.instance.authStateChanges();
    _setupAuthListener();
  }

  void _setupAuthListener() {
    _authStateChanges.listen((User? user) async {
      if (kDebugMode) {
        print('Auth state changed: ${user?.uid ?? 'No user'}');
      }
      
      // Notify subscription service about auth changes
      await _subscriptionService.onUserAuthChanged(user);
      
      if (user != null) {
        // User signed in - sync subscription data
        await _syncUserData(user);
      } else {
        // User signed out
        if (kDebugMode) {
          print('User signed out');
        }
      }
    });
  }

  Future<void> _syncUserData(User user) async {
    try {
      if (kDebugMode) {
        print('Syncing user data for: ${user.email}');
      }
      
      // Sync subscription status
      await _subscriptionService.syncSubscriptionStatus();
      
      // You can add other data syncing here
      // e.g., user preferences, interview history, etc.
      
    } catch (e) {
      if (kDebugMode) {
        print('Error syncing user data: $e');
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    
    switch (state) {
      case AppLifecycleState.paused:
        // User left the app - schedule comeback notification
        NotificationService().onAppPaused();
        break;
      case AppLifecycleState.resumed:
        // User returned to app - cancel comeback notification
        NotificationService().onAppResumed();
        // Also sync subscription data when app resumes
        _syncSubscriptionData();
        break;
      case AppLifecycleState.detached:
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
        break;
    }
  }

  Future<void> _syncSubscriptionData() async {
    try {
      // Check latest subscription status when app resumes
      await _subscriptionService.checkSubscriptionStatus();
    } catch (e) {
      if (kDebugMode) {
        print('Failed to sync subscription data: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ITSAGO - AI Interview Prep',
      theme: ThemeData(
        fontFamily: 'Arial',
        primaryColor: BauhausColors.blue,
        colorScheme: ColorScheme.fromSeed(
          seedColor: BauhausColors.blue,
          primary: BauhausColors.blue,
          secondary: BauhausColors.red,
        ),
        textTheme: const TextTheme(
          displayLarge: TextStyle(
            fontWeight: FontWeight.w900,
            letterSpacing: 2,
            color: BauhausColors.black,
          ),
          headlineLarge: TextStyle(
            fontWeight: FontWeight.w900,
            letterSpacing: 1.5,
            color: BauhausColors.black,
          ),
          bodyLarge: TextStyle(
            fontWeight: FontWeight.w600,
            color: BauhausColors.black,
          ),
        ),
      ),
      home: SplashScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class ErrorApp extends StatelessWidget {
  final String message;

  const ErrorApp({Key? key, required this.message}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        backgroundColor: BauhausColors.white,
        body: Center(
          child: Container(
            width: 300,
            height: 300,
            decoration: const BoxDecoration(
              color: BauhausColors.red,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(40),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 60,
                      height: 60,
                      decoration: const BoxDecoration(
                        color: BauhausColors.white,
                        shape: BoxShape.rectangle,
                      ),
                      child: const Icon(
                        Icons.error_outline,
                        size: 40,
                        color: BauhausColors.red,
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'ERROR',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: BauhausColors.white,
                        letterSpacing: 2,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      message,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: BauhausColors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class InterviewCoachApp extends StatelessWidget {
  final List<CameraDescription> cameras;

  const InterviewCoachApp({Key? key, required this.cameras}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ITSAGO - AI Interview Coach',
      theme: ThemeData(
        fontFamily: 'Arial',
        primaryColor: BauhausColors.blue,
        colorScheme: ColorScheme.fromSeed(
          seedColor: BauhausColors.blue,
          primary: BauhausColors.blue,
          secondary: BauhausColors.red,
        ),
        textTheme: const TextTheme(
          displayLarge: TextStyle(
            fontWeight: FontWeight.w900,
            letterSpacing: 2,
            color: BauhausColors.black,
          ),
          headlineLarge: TextStyle(
            fontWeight: FontWeight.w900,
            letterSpacing: 1.5,
            color: BauhausColors.black,
          ),
          bodyLarge: TextStyle(
            fontWeight: FontWeight.w600,
            color: BauhausColors.black,
          ),
        ),
      ),
      home: MainMenuScreen(cameras: cameras),
      debugShowCheckedModeBanner: false,
    );
  }
}

// Utility class for subscription-related UI helpers
class SubscriptionUI {
  // Show subscription status in debug mode
  static Widget buildDebugSubscriptionInfo() {
    if (!kDebugMode) return const SizedBox.shrink();
    
    return FutureBuilder<bool>(
      future: PremiumStatus.isPremium(),
      builder: (context, snapshot) {
        return Container(
          padding: const EdgeInsets.all(8),
          color: snapshot.data == true ? Colors.green : Colors.red,
          child: Text(
            'Premium: ${snapshot.data ?? false}',
            style: const TextStyle(color: Colors.white, fontSize: 12),
          ),
        );
      },
    );
  }
  
  // Helper method to refresh subscription status across the app
  static Future<void> refreshSubscriptionStatus(BuildContext context) async {
    try {
      await SubscriptionService().syncSubscriptionStatus();
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Subscription status refreshed',
              style: TextStyle(
                color: BauhausColors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
            backgroundColor: BauhausColors.blue,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Error refreshing subscription',
              style: TextStyle(
                color: BauhausColors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
            backgroundColor: BauhausColors.red,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }
}

// Extension to add subscription helpers to BuildContext
extension SubscriptionHelpers on BuildContext {
  // Check if user has premium access
  Future<bool> checkPremiumAccess() async {
    return await PremiumStatus.isPremium();
  }
  
  // Show premium upgrade modal if user is not premium
  Future<bool> requiresPremiumUpgrade() async {
    final isPremium = await PremiumStatus.isPremium();
    return !isPremium;
  }
  
  // Get subscription info for display
  Future<Map<String, dynamic>> getSubscriptionDisplayInfo() async {
    return await SubscriptionService().getSubscriptionInfo();
  }
}