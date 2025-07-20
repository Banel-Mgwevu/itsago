import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:purchases_flutter/purchases_flutter.dart';
import 'firebase_options.dart';

import 'setup_screen.dart';
import 'splash_screen.dart';
import 'notification_service.dart';

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

// RevenueCat Configuration
class RevenueCatConfig {
  // TODO: Replace these with your actual RevenueCat API keys
  static const String androidApiKey = 'goog_YOUR_GOOGLE_PLAY_API_KEY_HERE';
  static const String iosApiKey = 'appl_YOUR_APP_STORE_API_KEY_HERE';
  
  // Entitlement identifier - should match your RevenueCat dashboard
  static const String premiumEntitlementId = 'premium';
  
  // Product identifiers - should match your RevenueCat dashboard
  static const String monthlyProductId = 'itago_monthly_premium';
  static const String annualProductId = 'itago_annual_premium';
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

    // Initialize RevenueCat
    await _initializeRevenueCat();

    // Start with splash screen - authentication check happens there
    runApp(const ItagoApp());
  } catch (e) {
    // If initialization fails, show error screen
    runApp(ErrorApp(message: 'Failed to initialize app: ${e.toString()}'));
  }
}

Future<void> _initializeRevenueCat() async {
  try {
    // Configure RevenueCat logging (only in debug mode)
    if (kDebugMode) {
      await Purchases.setLogLevel(LogLevel.debug);
    } else {
      await Purchases.setLogLevel(LogLevel.info);
    }

    // Configure RevenueCat based on platform
    PurchasesConfiguration configuration;
    
    if (Platform.isAndroid) {
      configuration = PurchasesConfiguration(RevenueCatConfig.androidApiKey);
    } else if (Platform.isIOS) {
      configuration = PurchasesConfiguration(RevenueCatConfig.iosApiKey);
    } else {
      throw UnsupportedError('RevenueCat not supported on this platform');
    }

    // Set user ID if you have one (optional)
    // configuration = configuration.copyWith(userId: 'your_user_id');

    // Initialize RevenueCat
    await Purchases.configure(configuration);

    // Set up listener for customer info updates
    Purchases.addCustomerInfoUpdateListener((customerInfo) {
      // Handle customer info updates (subscription changes, etc.)
      final isPremium = customerInfo.entitlements.all[RevenueCatConfig.premiumEntitlementId]?.isActive ?? false;
      
      if (kDebugMode) {
        print('Customer info updated. Premium status: $isPremium');
      }
      
      // You can save premium status to shared preferences or state management here
      _savePremiumStatus(isPremium);
    });

    if (kDebugMode) {
      print('RevenueCat initialized successfully');
    }
  } catch (e) {
    if (kDebugMode) {
      print('Failed to initialize RevenueCat: $e');
    }
    // Don't throw error - app can still work without RevenueCat in emergency
    // Just log the error and continue
  }
}

void _savePremiumStatus(bool isPremium) {
  // TODO: Implement saving premium status to your preferred storage
  // This could be SharedPreferences, Hive, or your state management solution
  // Example:
  // SharedPreferences.getInstance().then((prefs) {
  //   prefs.setBool('is_premium', isPremium);
  // });
}

class ItagoApp extends StatefulWidget {
  const ItagoApp({Key? key}) : super(key: key);

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
    
    switch (state) {
      case AppLifecycleState.paused:
        // User left the app - schedule comeback notification
        NotificationService().onAppPaused();
        break;
      case AppLifecycleState.resumed:
        // User returned to app - cancel comeback notification
        NotificationService().onAppResumed();
        // Also sync RevenueCat data when app resumes
        _syncRevenueCatData();
        break;
      case AppLifecycleState.detached:
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
        break;
    }
  }

  Future<void> _syncRevenueCatData() async {
    try {
      // Sync the latest customer info when app resumes
      await Purchases.syncPurchases();
      final customerInfo = await Purchases.getCustomerInfo();
      final isPremium = customerInfo.entitlements.all[RevenueCatConfig.premiumEntitlementId]?.isActive ?? false;
      _savePremiumStatus(isPremium);
    } catch (e) {
      if (kDebugMode) {
        print('Failed to sync RevenueCat data: $e');
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
      home: SetupScreen(cameras: cameras),
      debugShowCheckedModeBanner: false,
    );
  }
}

// Utility class to check premium status throughout the app
class PremiumStatus {
  static Future<bool> isPremium() async {
    try {
      final customerInfo = await Purchases.getCustomerInfo();
      return customerInfo.entitlements.all[RevenueCatConfig.premiumEntitlementId]?.isActive ?? false;
    } catch (e) {
      if (kDebugMode) {
        print('Failed to check premium status: $e');
      }
      return false;
    }
  }

  static Future<CustomerInfo?> getCustomerInfo() async {
    try {
      return await Purchases.getCustomerInfo();
    } catch (e) {
      if (kDebugMode) {
        print('Failed to get customer info: $e');
      }
      return null;
    }
  }
}