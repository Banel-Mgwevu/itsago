import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;
import 'package:flutter/material.dart';
import 'dart:math';
import 'dart:io';
import 'main.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();
  
  static const String _permissionKey = 'notification_permission_requested';
  static const String _enabledKey = 'notifications_enabled';

  // Interview coaching motivation messages
  final List<String> _motivationalMessages = [
    "Ready to ace your next interview? Let's practice! 🎯",
    "Your dream job is waiting. Time for a quick practice session! ✨",
    "Confidence comes with practice. Let's build yours today! 💪",
    "Turn nervousness into confidence with ITAGO practice! 🌟",
    "Every expert was once a beginner. Keep practicing! 📈",
    "Your future self will thank you for practicing today! 🙏",
    "Small daily improvements lead to stunning results! 🎊",
    "The best time to practice was yesterday. The second best is now! ⏰",
    "Success is where preparation meets opportunity! 🎪",
    "You're closer to your goal than you think. Keep going! 🎯",
    "Practice makes progress, not perfection! 📚",
  ];

  Future<void> initialize() async {
    print('🔧 [NOTIF] Initializing Local NotificationService...');
    
    // Initialize timezone data - CRITICAL for scheduled notifications
    tz.initializeTimeZones();
    print('🌍 [NOTIF] Timezone initialized');
    
    // Initialize local notifications
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    
    const DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const InitializationSettings initializationSettings =
        InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );

    await _localNotifications.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        print('📱 [NOTIF] Notification tapped: ${response.payload}');
      },
    );

    // Create notification channels for Android
    await _createNotificationChannels();

    print('✅ [NOTIF] Local NotificationService initialized successfully');
  }

  Future<void> _createNotificationChannels() async {
    if (Platform.isAndroid) {
      print('📺 [NOTIF] Creating notification channels...');
      
      // Test channel
      const AndroidNotificationChannel testChannel = AndroidNotificationChannel(
        'test_channel',
        'Test Notifications',
        description: 'Test notifications to verify system works',
        importance: Importance.high,
        playSound: true,
        enableVibration: true,
      );

      // Comeback channel
      const AndroidNotificationChannel comebackChannel = AndroidNotificationChannel(
        'comeback_channel',
        'Come Back Notifications',
        description: 'Notifications to encourage users to return',
        importance: Importance.high,
        playSound: true,
        enableVibration: true,
      );

      // Daily motivation channel
      const AndroidNotificationChannel dailyChannel = AndroidNotificationChannel(
        'daily_motivation',
        'Daily Motivation',
        description: 'Daily motivational messages for interview practice',
        importance: Importance.defaultImportance,
        playSound: true,
        enableVibration: true,
      );

      await _localNotifications
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(testChannel);
          
      await _localNotifications
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(comebackChannel);
          
      await _localNotifications
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(dailyChannel);

      print('✅ [NOTIF] Notification channels created');
    }
  }

  Future<bool> checkAndRequestPermissions() async {
    print('🔐 [NOTIF] Checking notification permissions...');
    final prefs = await SharedPreferences.getInstance();
    final hasRequestedBefore = prefs.getBool(_permissionKey) ?? false;

    print('📝 [NOTIF] Has requested before: $hasRequestedBefore');

    if (!hasRequestedBefore) {
      print('🆕 [NOTIF] First time - requesting permissions');
      return await _requestPermissions();
    } else {
      // Check current status
      final isEnabled = await _areNotificationsEnabled();
      print('🔍 [NOTIF] Current permission status: $isEnabled');
      if (!isEnabled) {
        print('❌ [NOTIF] Permissions denied - asking user');
        return await _showEnableDialog();
      }
      print('✅ [NOTIF] Permissions already granted');
      // Test with immediate notification
      // await showTestNotification();
      return true;
    }
  }

  Future<bool> _requestPermissions() async {
    final prefs = await SharedPreferences.getInstance();
    
    try {
      print('🙏 [NOTIF] Requesting notification permissions...');
      
      bool granted = false;
      
      if (Platform.isAndroid) {
        print('🤖 [NOTIF] Requesting Android permissions...');
        
        // Request basic notification permission
        final notificationPermission = await Permission.notification.request();
        print('📱 [NOTIF] Notification permission result: $notificationPermission');
        
        // Request exact alarm permission for Android 12+ (API level 31+)
        bool exactAlarmGranted = true;
        try {
          final exactAlarmPermission = await Permission.scheduleExactAlarm.request();
          print('⏰ [NOTIF] Exact alarm permission result: $exactAlarmPermission');
          exactAlarmGranted = exactAlarmPermission == PermissionStatus.granted;
        } catch (e) {
          print('⚠️ [NOTIF] Exact alarm permission not available on this device: $e');
          exactAlarmGranted = true; // Assume granted on older Android versions
        }

        granted = notificationPermission == PermissionStatus.granted && exactAlarmGranted;
      } else {
        // For iOS, request permissions through the local notifications plugin
        final iosSettings = await _localNotifications
            .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()
            ?.requestPermissions(
              alert: true,
              badge: true,
              sound: true,
            );
        granted = iosSettings ?? false;
      }

      await prefs.setBool(_permissionKey, true);
      await prefs.setBool(_enabledKey, granted);

      print('💾 [NOTIF] Saved permission state: $granted');

      if (granted) {
        print('🔄 [NOTIF] Scheduling initial notifications...');
        await _scheduleNotifications();
        // Show immediate test notification
        await showTestNotification();
      }

      return granted;
    } catch (e) {
      print('❌ [NOTIF] Error requesting permissions: $e');
      await prefs.setBool(_permissionKey, true);
      await prefs.setBool(_enabledKey, false);
      return false;
    }
  }

  Future<bool> _areNotificationsEnabled() async {
    try {
      if (Platform.isAndroid) {
        final notificationStatus = await Permission.notification.status;
        
        // Check exact alarm permission for Android 12+
        bool exactAlarmEnabled = true;
        try {
          final exactAlarmStatus = await Permission.scheduleExactAlarm.status;
          exactAlarmEnabled = exactAlarmStatus == PermissionStatus.granted;
        } catch (e) {
          print('⚠️ [NOTIF] Exact alarm permission check failed (likely older Android): $e');
          exactAlarmEnabled = true; // Assume granted on older versions
        }
        
        bool enabled = notificationStatus == PermissionStatus.granted && exactAlarmEnabled;
        print('🔍 [NOTIF] Android notification status: $enabled (notif: $notificationStatus, exact: $exactAlarmEnabled)');
        return enabled;
      } else {
        // For iOS, assume enabled if we've made it this far
        return true;
      }
    } catch (e) {
      print('❌ [NOTIF] Error checking notification status: $e');
      return false;
    }
  }

  Future<bool> _showEnableDialog() async {
    print('💬 [NOTIF] Should show enable dialog (returning false for now)');
    return false;
  }

  Future<void> _scheduleNotifications() async {
    print('⏰ [NOTIF] Scheduling daily notifications...');
    await _scheduleRandomDailyNotifications();
    print('✅ [NOTIF] Daily notifications scheduled');
  }

  Future<void> showTestNotification() async {
    print('🧪 [NOTIF] Showing immediate test notification...');
    
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'test_channel',
      'Test Notifications',
      channelDescription: 'Test notifications to verify system works',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
      playSound: true,
      enableVibration: true,
    );

    const DarwinNotificationDetails iOSPlatformChannelSpecifics =
        DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
      iOS: iOSPlatformChannelSpecifics,
    );

    try {
      await _localNotifications.show(
        888,
        'ITSAGO - System Test! 🧪',
        'Notifications are working! You should see this immediately.',
        platformChannelSpecifics,
        payload: 'test_notification',
      );
      print('✅ [NOTIF] Test notification shown successfully');
    } catch (e) {
      print('❌ [NOTIF] Error showing test notification: $e');
    }
  }

  Future<void> _scheduleComebackNotification() async {
    print('⏰ [NOTIF] Scheduling comeback notification for 1 minute (testing)...');
    
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'comeback_channel',
      'Come Back Notifications',
      channelDescription: 'Notifications to encourage users to return',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
      showWhen: true,
      playSound: true,
      enableVibration: true,
    );

    const DarwinNotificationDetails iOSPlatformChannelSpecifics =
        DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
      iOS: iOSPlatformChannelSpecifics,
    );

    // Schedule for 1 minute from now for testing
    final scheduledDate = DateTime.now().add(const Duration(minutes: 1));
    final tzScheduledDate = tz.TZDateTime.from(scheduledDate, tz.local);
    
    print('📅 [NOTIF] Comeback notification scheduled for: $tzScheduledDate');
    print('🕒 [NOTIF] Current time: ${tz.TZDateTime.now(tz.local)}');
    
    try {
      await _localNotifications.zonedSchedule(
        1,
        'ITSAGO - Come Back!',
        'Your interview skills are waiting! Come back and practice. 🎯',
        tzScheduledDate,
        platformChannelSpecifics,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        payload: 'comeback_notification',
      );
      print('✅ [NOTIF] Comeback notification scheduled successfully');
      
      // Debug: Check if it was actually scheduled
      await debugPendingNotifications();
      
    } catch (e) {
      print('❌ [NOTIF] Error scheduling comeback notification: $e');
    }
  }

  Future<void> _scheduleRandomDailyNotifications() async {
    print('📅 [NOTIF] Scheduling daily motivational notifications...');
    
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'daily_motivation',
      'Daily Motivation',
      channelDescription: 'Daily motivational messages for interview practice',
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
      icon: '@mipmap/ic_launcher',
      playSound: true,
      enableVibration: true,
    );

    const DarwinNotificationDetails iOSPlatformChannelSpecifics =
        DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
      iOS: iOSPlatformChannelSpecifics,
    );

    final Random random = Random();
    
    // First, cancel any existing daily notifications
    for (int i = 0; i < 3; i++) {
      await _localNotifications.cancel(100 + i);
    }
    
    // Schedule 3 random notifications throughout the day
    for (int i = 0; i < 3; i++) {
      // Random hour between 9 AM and 8 PM
      int randomHour = 9 + random.nextInt(12); // 9-20 (8 PM)
      int randomMinute = random.nextInt(60);
      
      String randomMessage = _motivationalMessages[random.nextInt(_motivationalMessages.length)];
      
      final scheduleTime = _getScheduledDateTimeForHour(randomHour, randomMinute);
      print('📱 [NOTIF] Daily notification $i scheduled for: $scheduleTime');
      
      try {
        await _localNotifications.zonedSchedule(
          100 + i, // Unique ID for each notification
          'ITSAGO - Time to Practice!',
          randomMessage,
          scheduleTime,
          platformChannelSpecifics,
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          matchDateTimeComponents: DateTimeComponents.time, // Repeat daily
          payload: 'daily_motivation_$i',
        );
        print('✅ [NOTIF] Daily notification $i scheduled successfully');
      } catch (e) {
        print('❌ [NOTIF] Error scheduling daily notification $i: $e');
      }
    }
    
    // Debug: Show all pending notifications
    await debugPendingNotifications();
    print('✅ [NOTIF] All daily notifications scheduled');
  }

  tz.TZDateTime _getScheduledDateTimeForHour(int hour, int minute) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduledDate = tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    
    // If the time has already passed today, schedule for tomorrow
    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }
    
    print('🕐 [NOTIF] Scheduled time: $scheduledDate (current: $now)');
    return scheduledDate;
  }

  Future<void> onAppPaused() async {
    print('⏸️ [NOTIF] App paused - scheduling comeback notification');
    final isEnabled = await _areNotificationsEnabled();
    print('📋 [NOTIF] Notifications enabled: $isEnabled');
    
    if (isEnabled) {
      await _scheduleComebackNotification();
    } else {
      print('❌ [NOTIF] Notifications not enabled, skipping comeback notification');
    }
  }

  Future<void> onAppResumed() async {
    print('▶️ [NOTIF] App resumed - canceling comeback notification');
    try {
      await _localNotifications.cancel(1);
      print('✅ [NOTIF] Comeback notification cancelled');
    } catch (e) {
      print('❌ [NOTIF] Error cancelling comeback notification: $e');
    }
  }

  Future<void> cancelAllNotifications() async {
    print('🗑️ [NOTIF] Cancelling all notifications');
    try {
      await _localNotifications.cancelAll();
      print('✅ [NOTIF] All notifications cancelled');
    } catch (e) {
      print('❌ [NOTIF] Error cancelling notifications: $e');
    }
  }

  // Debug method to show all pending notifications
  Future<void> debugPendingNotifications() async {
    try {
      final pendingNotifications = await _localNotifications.pendingNotificationRequests();
      print('📋 [NOTIF] Pending notifications: ${pendingNotifications.length}');
      for (var notification in pendingNotifications) {
        print('   - ID: ${notification.id}, Title: ${notification.title}, Body: ${notification.body}');
      }
      
      if (pendingNotifications.isEmpty) {
        print('⚠️ [NOTIF] No pending notifications found - this might indicate a scheduling issue');
      }
    } catch (e) {
      print('❌ [NOTIF] Error getting pending notifications: $e');
    }
  }

  // Add this method to test scheduled notifications with a short delay
  Future<void> testScheduledNotification() async {
    print('🧪 [NOTIF] Testing scheduled notification in 30 seconds...');
    
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'test_channel',
      'Test Notifications',
      channelDescription: 'Test notifications to verify system works',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
      playSound: true,
      enableVibration: true,
    );

    const DarwinNotificationDetails iOSPlatformChannelSpecifics =
        DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
      iOS: iOSPlatformChannelSpecifics,
    );

    final scheduledDate = DateTime.now().add(const Duration(seconds: 30));
    final tzScheduledDate = tz.TZDateTime.from(scheduledDate, tz.local);
    
    print('📅 [NOTIF] Test scheduled notification for: $tzScheduledDate');
    
    try {
      await _localNotifications.zonedSchedule(
        999,
        'ITSAGO - Scheduled Test! ⏰',
        'This scheduled notification should appear in 30 seconds!',
        tzScheduledDate,
        platformChannelSpecifics,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        payload: 'test_scheduled',
      );
      print('✅ [NOTIF] Scheduled test notification created');
      await debugPendingNotifications();
    } catch (e) {
      print('❌ [NOTIF] Error scheduling test notification: $e');
    }
  }
}

// Permission dialog widget for use in UI
class NotificationPermissionDialog extends StatelessWidget {
  final VoidCallback onAccept;
  final VoidCallback onDecline;

  const NotificationPermissionDialog({
    Key? key,
    required this.onAccept,
    required this.onDecline,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: BauhausColors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: BauhausColors.black, width: 2),
      ),
      title: Row(
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: BauhausColors.yellow,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.notifications_outlined,
              size: 14,
              color: BauhausColors.black,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            'STAY MOTIVATED',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: BauhausColors.black,
              letterSpacing: 1,
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Enable notifications to:',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: BauhausColors.black,
            ),
          ),
          const SizedBox(height: 12),
          _buildFeatureItem('🎯', 'Get practice reminders'),
          _buildFeatureItem('💪', 'Stay motivated daily'),
          _buildFeatureItem('📈', 'Track your progress'),
          _buildFeatureItem('🚀', 'Achieve interview success'),
        ],
      ),
      actions: [
        TextButton(
          onPressed: onDecline,
          style: TextButton.styleFrom(
            backgroundColor: BauhausColors.lightGray,
            foregroundColor: BauhausColors.black,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(6),
            ),
          ),
          child: Text(
            'NOT NOW',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              letterSpacing: 1,
            ),
          ),
        ),
        const SizedBox(width: 8),
        ElevatedButton(
          onPressed: onAccept,
          style: ElevatedButton.styleFrom(
            backgroundColor: BauhausColors.blue,
            foregroundColor: BauhausColors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(6),
            ),
          ),
          child: Text(
            'ENABLE',
            style: TextStyle(
              fontWeight: FontWeight.w900,
              letterSpacing: 1,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFeatureItem(String emoji, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text(emoji, style: TextStyle(fontSize: 16)),
          const SizedBox(width: 8),
          Text(
            text,
            style: TextStyle(
              fontSize: 13,
              color: BauhausColors.gray,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}