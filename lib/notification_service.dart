import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;
import 'package:permission_handler/permission_handler.dart';
import 'dart:math';
import 'dart:io';
import 'calendar_service.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  static const String channelId = 'interview_reminders';
  static const String channelName = 'Interview Reminders';
  static const String channelDescription = 'Notifications for upcoming interviews';
  
  static const String _permissionKey = 'notification_permission_requested';
  static const String _enabledKey = 'notifications_enabled';
  static const String _lastMotivationKey = 'last_motivation_date';

  final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();
  final GoogleCalendarService _calendarService = GoogleCalendarService();
  
  bool _isInitialized = false;
  List<CalendarEvent> _scheduledInterviews = [];
  Set<int> _activeCalendarNotificationIds = {};

  // Enhanced interview coaching motivation messages
  final List<String> _motivationalMessages = [
    "Ready to ace your next interview? Let's practice! 🎯",
    "Your dream job is just one great interview away! ✨",
    "Confidence comes from preparation. Let's build yours! 💪",
    "Turn interview anxiety into excitement with practice! 🌟",
    "Every 'no' brings you closer to your 'yes'. Keep practicing! 📈",
    "Your future self will thank you for practicing today! 🙏",
    "Small daily practice leads to interview mastery! 🎊",
    "The best time to practice was yesterday. The second best is now! ⏰",
    "Success happens when preparation meets opportunity! 🎪",
    "You're closer to landing your dream job than you think! 🎯",
    "Practice doesn't make perfect, it makes confident! 📚",
    "Today's practice is tomorrow's success story! 🚀",
    "Master the STAR method with just 5 minutes of practice! ⭐",
    "Great interviews start with great preparation! 💼",
    "Your skills deserve the spotlight. Let's practice! 🔦",
    "Interview like a pro with daily practice sessions! 🏆",
    "Nail behavioral questions with focused practice! 🎭",
    "Technical interviews? You've got this with practice! 👨‍💻",
    "Salary negotiation confidence starts with preparation! 💰",
    "Transform nerves into interview superpowers! ⚡",
    "Practice makes permanent. Make excellence permanent! 💎",
    "Every practice session is an investment in your career! 📊",
    "Level up your interview game with ITSAGO! 🎮",
    "From good to great - one practice session at a time! 📱",
    "Your competition is practicing. Are you? 🏃‍♂️",
  ];

  // Comeback message variations
  final List<String> _comebackMessages = [
    "Your interview skills are waiting! Come back and practice. 🎯",
    "Missing you! Let's continue building your confidence. 💪",
    "Your dream job won't wait. Time for a quick practice! ⏰",
    "Ready to turn anxiety into confidence? Let's practice! 🌟",
    "Your future employer is looking for someone like you! 🔍",
    "5 minutes of practice = tons of confidence! Come back! ⭐",
    "Great interviews don't happen by accident. Let's practice! 🎪",
    "Your success story starts with preparation. Continue practicing! 📖",
    "Missing our practice sessions? Your skills need you! 🎭",
    "Come back and master your next interview! 🏆",
  ];

  // Different notification titles
  final List<String> _notificationTitles = [
    "ITSAGO - Practice Time! 🎯",
    "ITSAGO - Let's Ace This! 💪",
    "ITSAGO - Your Success Awaits! ✨",
    "ITSAGO - Confidence Builder! 🌟",
    "ITSAGO - Interview Mastery! 🏆",
    "ITSAGO - Dream Job Prep! 💼",
    "ITSAGO - Skill Building Time! 📈",
    "ITSAGO - Success Starts Now! 🚀",
  ];

  // Initialize the notification service
  Future<void> initialize() async {
    if (_isInitialized) return;

    print('🔧 [NOTIF] Initializing Enhanced NotificationService...');

    // Initialize timezone data
    tz.initializeTimeZones();
    print('🌍 [NOTIF] Timezone initialized');

    // Android settings
    const AndroidInitializationSettings androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    
    // iOS settings
    const DarwinInitializationSettings iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const InitializationSettings settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notifications.initialize(
      settings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    // Create notification channels for Android
    await _createNotificationChannels();
    
    _isInitialized = true;
    print('✅ [NOTIF] Enhanced NotificationService initialized successfully');
  }

  // Create enhanced notification channels
  Future<void> _createNotificationChannels() async {
    if (Platform.isAndroid) {
      print('📺 [NOTIF] Creating enhanced notification channels...');
      
      // PERSISTENT Interview reminders channel - High priority, ongoing
      const AndroidNotificationChannel interviewChannel = AndroidNotificationChannel(
        channelId,
        channelName,
        description: '$channelDescription (Persistent until opened)',
        importance: Importance.max, // Maximum importance for persistent notifications
        enableVibration: true,
        playSound: true,
        showBadge: true,
      );

      // Test channel
      const AndroidNotificationChannel testChannel = AndroidNotificationChannel(
        'test_channel',
        'Test Notifications',
        description: 'Test notifications to verify ITSAGO system works perfectly',
        importance: Importance.high,
        playSound: true,
        enableVibration: true,
      );

      // Comeback channel
      const AndroidNotificationChannel comebackChannel = AndroidNotificationChannel(
        'comeback_channel',
        'Practice Reminders',
        description: 'Gentle reminders to continue your interview preparation journey',
        importance: Importance.high,
        playSound: true,
        enableVibration: true,
      );

      // Daily motivation channel - Lower importance, dismissible
      const AndroidNotificationChannel dailyChannel = AndroidNotificationChannel(
        'daily_motivation',
        'Daily Interview Coaching',
        description: 'Daily motivation and tips to master your interview skills',
        importance: Importance.defaultImportance, // Normal importance for motivation
        playSound: false, // Less intrusive
        enableVibration: false,
        showBadge: false,
      );

      // Achievement channel
      const AndroidNotificationChannel achievementChannel = AndroidNotificationChannel(
        'achievements',
        'Success Milestones',
        description: 'Celebrate your interview preparation achievements',
        importance: Importance.high,
        playSound: true,
        enableVibration: true,
      );

      final androidImplementation = _notifications.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      
      await androidImplementation?.createNotificationChannel(interviewChannel);
      await androidImplementation?.createNotificationChannel(testChannel);
      await androidImplementation?.createNotificationChannel(comebackChannel);
      await androidImplementation?.createNotificationChannel(dailyChannel);
      await androidImplementation?.createNotificationChannel(achievementChannel);

      print('✅ [NOTIF] Enhanced notification channels created');
    }
  }

  // Enhanced permission request
  Future<bool> requestPermissions() async {
    return await checkAndRequestPermissions();
  }

  // Enhanced permission request with detailed flow
  Future<bool> checkAndRequestPermissions() async {
    print('🔐 [NOTIF] Checking enhanced notification permissions...');
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
      return isEnabled;
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
        final iosSettings = await _notifications
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
        await _scheduleImprovedDailyMotivation();
        // Show immediate welcome notification
        await showWelcomeNotification();
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

  // Handle notification tap
  void _onNotificationTapped(NotificationResponse response) {
    print('📱 [NOTIF] Notification tapped: ${response.payload}');
    
    // If it's a calendar notification, remove it from active set and cancel it
    if (response.payload != null && response.id != null) {
      try {
        final data = jsonDecode(response.payload!);
        final action = data['action'] as String?;
        final notificationId = response.id!; // Safe to use ! since we checked above
        
        if (action == 'interview_reminder') {
          print('📅 [NOTIF] Calendar notification opened - removing persistent notification');
          _activeCalendarNotificationIds.remove(notificationId);
          _notifications.cancel(notificationId);
        }
        
        if (action == 'open_ai_coach') {
          // Navigate to AI Coach screen
          // This would need to be handled by the main app
          print('🎯 Opening AI Coach for interview prep');
        }
      } catch (e) {
        print('Error parsing notification payload: $e');
      }
    }
  }

  // Show welcome notification
  Future<void> showWelcomeNotification() async {
    print('🎉 [NOTIF] Showing welcome notification...');
    
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'test_channel',
      'Test Notifications',
      channelDescription: 'Welcome to your interview success journey',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
      playSound: true,
      enableVibration: true,
    );

    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    try {
      await _notifications.show(
        888,
        'ITSAGO - Welcome! 🎉',
        'Your interview success journey starts now. Notifications are active!',
        platformChannelSpecifics,
        payload: 'welcome_notification',
      );
      print('✅ [NOTIF] Welcome notification shown successfully');
    } catch (e) {
      print('❌ [NOTIF] Error showing welcome notification: $e');
    }
  }

  // Schedule notifications for all upcoming interviews
  Future<void> scheduleInterviewNotifications() async {
    if (!_isInitialized) {
      await initialize();
    }

    try {
      // Get upcoming interviews from calendar
      final interviews = await _calendarService.getInterviewEvents();
      
      // Clear old interview notifications
      await _clearInterviewNotifications();
      
      // Schedule new notifications
      for (final interview in interviews) {
        if (interview.isUpcoming) {
          await _scheduleNotificationsForInterview(interview);
        }
      }
      
      _scheduledInterviews = interviews;
      print('📅 Scheduled persistent notifications for ${interviews.length} interviews');
      
    } catch (e) {
      print('❌ Error scheduling notifications: $e');
    }
  }

  // Schedule all notifications for a single interview (PERSISTENT)
  Future<void> _scheduleNotificationsForInterview(CalendarEvent interview) async {
    final now = DateTime.now();
    final interviewTime = interview.startTime;
    
    // Generate unique IDs for each notification
    final baseId = interview.id.hashCode;
    
    // 3 days before
    final threeDaysBefore = interviewTime.subtract(const Duration(days: 3));
    if (threeDaysBefore.isAfter(now)) {
      final notificationId = baseId + 1;
      await _schedulePersistentNotification(
        id: notificationId,
        title: '📅 Interview in 3 Days!',
        body: 'You have "${interview.title}" coming up. Start preparing now!',
        scheduledTime: threeDaysBefore,
        payload: _createInterviewPayload(interview, '3_days', notificationId),
        priority: 'high',
      );
      _activeCalendarNotificationIds.add(notificationId);
    }

    // 2 days before
    final twoDaysBefore = interviewTime.subtract(const Duration(days: 2));
    if (twoDaysBefore.isAfter(now)) {
      final notificationId = baseId + 2;
      await _schedulePersistentNotification(
        id: notificationId,
        title: '⏰ Interview in 2 Days',
        body: 'Time to review: "${interview.title}". Practice your answers!',
        scheduledTime: twoDaysBefore,
        payload: _createInterviewPayload(interview, '2_days', notificationId),
        priority: 'high',
      );
      _activeCalendarNotificationIds.add(notificationId);
    }

    // 1 day before
    final oneDayBefore = interviewTime.subtract(const Duration(days: 1));
    if (oneDayBefore.isAfter(now)) {
      final notificationId = baseId + 3;
      await _schedulePersistentNotification(
        id: notificationId,
        title: '🚀 Interview Tomorrow!',
        body: 'Final prep for "${interview.title}". Get your questions ready!',
        scheduledTime: oneDayBefore,
        payload: _createInterviewPayload(interview, '1_day', notificationId),
        priority: 'max',
      );
      _activeCalendarNotificationIds.add(notificationId);
    }

    // 6 hours before
    final sixHoursBefore = interviewTime.subtract(const Duration(hours: 6));
    if (sixHoursBefore.isAfter(now)) {
      final notificationId = baseId + 4;
      await _schedulePersistentNotification(
        id: notificationId,
        title: '⚡ Interview in 6 Hours!',
        body: 'Last chance prep for "${interview.title}". Review key points!',
        scheduledTime: sixHoursBefore,
        payload: _createInterviewPayload(interview, '6_hours', notificationId),
        priority: 'max',
      );
      _activeCalendarNotificationIds.add(notificationId);
    }

    // On the day (2 hours before)
    final twoHoursBefore = interviewTime.subtract(const Duration(hours: 2));
    if (twoHoursBefore.isAfter(now)) {
      final notificationId = baseId + 5;
      await _schedulePersistentNotification(
        id: notificationId,
        title: '🎯 Interview Today!',
        body: 'Your interview "${interview.title}" is in 2 hours. You\'ve got this!',
        scheduledTime: twoHoursBefore,
        payload: _createInterviewPayload(interview, 'today', notificationId),
        priority: 'max',
      );
      _activeCalendarNotificationIds.add(notificationId);
    }

    // 30 minutes before
    final thirtyMinutesBefore = interviewTime.subtract(const Duration(minutes: 30));
    if (thirtyMinutesBefore.isAfter(now)) {
      final notificationId = baseId + 6;
      await _schedulePersistentNotification(
        id: notificationId,
        title: '🔥 Interview Starting Soon!',
        body: '"${interview.title}" starts in 30 minutes. Take a deep breath!',
        scheduledTime: thirtyMinutesBefore,
        payload: _createInterviewPayload(interview, '30_minutes', notificationId),
        priority: 'max',
      );
      _activeCalendarNotificationIds.add(notificationId);
    }

    print('📱 Scheduled 6 PERSISTENT notifications for: ${interview.title}');
  }

  // Schedule a PERSISTENT notification (can't be dismissed unless opened in app)
  Future<void> _schedulePersistentNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledTime,
    required String payload,
    required String priority,
  }) async {
    try {
      // Create PERSISTENT notification details
      AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
        channelId,
        channelName,
        channelDescription: channelDescription,
        importance: priority == 'max' ? Importance.max : Importance.high,
        priority: priority == 'max' ? Priority.max : Priority.high,
        icon: '@mipmap/ic_launcher',
        enableVibration: true,
        playSound: true,
        ongoing: true, // Makes notification persistent (can't be swiped away)
        autoCancel: false, // Prevents auto-dismissal
        showWhen: true,
        when: scheduledTime.millisecondsSinceEpoch,
        fullScreenIntent: priority == 'max', // Full screen for urgent notifications
        category: AndroidNotificationCategory.event,
        visibility: NotificationVisibility.public,
      );

      const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        interruptionLevel: InterruptionLevel.timeSensitive,
      );

      final notificationDetails = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      await _notifications.zonedSchedule(
        id,
        title,
        body,
        tz.TZDateTime.from(scheduledTime, tz.local),
        notificationDetails,
        payload: payload,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      );

      print('⏰ Scheduled PERSISTENT notification: $title at ${scheduledTime.toString()}');
    } catch (e) {
      print('❌ Failed to schedule persistent notification: $e');
    }
  }

  // Create payload for interview notification
  String _createInterviewPayload(CalendarEvent interview, String timing, int notificationId) {
    return jsonEncode({
      'action': 'interview_reminder',
      'interview_id': interview.id,
      'interview_title': interview.title,
      'timing': timing,
      'start_time': interview.startTime.toIso8601String(),
      'notification_id': notificationId,
    });
  }

  // IMPROVED Daily motivational notifications - consistent schedule
  Future<void> _scheduleImprovedDailyMotivation() async {
    print('📅 [NOTIF] Scheduling IMPROVED daily motivational notifications...');
    
    // Cancel existing motivation notifications
    for (int i = 0; i < 10; i++) {
      await _notifications.cancel(200 + i);
    }
    
    // Schedule consistent daily notifications at fixed times
    final motivationTimes = [
      {'hour': 9, 'minute': 0, 'type': 'morning'},   // 9:00 AM
      {'hour': 18, 'minute': 30, 'type': 'evening'}, // 6:30 PM
    ];

    final Random random = Random();
    
    for (int dayOffset = 0; dayOffset < 7; dayOffset++) { // Schedule for next 7 days
      for (int timeIndex = 0; timeIndex < motivationTimes.length; timeIndex++) {
        final timeSlot = motivationTimes[timeIndex];
        final hour = timeSlot['hour'] as int;
        final minute = timeSlot['minute'] as int;
        final type = timeSlot['type'] as String;
        
        // Create unique ID
        final notificationId = 200 + (dayOffset * 2) + timeIndex;
        
        // Get random message and title
        String randomMessage = _motivationalMessages[random.nextInt(_motivationalMessages.length)];
        String randomTitle = _notificationTitles[random.nextInt(_notificationTitles.length)];
        
        // Calculate schedule time
        final now = DateTime.now();
        var scheduleTime = DateTime(
          now.year,
          now.month,
          now.day + dayOffset,
          hour,
          minute,
        );
        
        // Skip if time has passed today
        if (dayOffset == 0 && scheduleTime.isBefore(now)) {
          continue;
        }
        
        await _scheduleDismissibleMotivation(
          id: notificationId,
          title: randomTitle,
          body: randomMessage,
          scheduledTime: scheduleTime,
          type: type,
        );
        
        print('📱 [NOTIF] Scheduled $type motivation for day $dayOffset at $hour:${minute.toString().padLeft(2, '0')}');
      }
    }
    
    // Save last scheduling date
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lastMotivationKey, DateTime.now().toIso8601String());
    
    print('✅ [NOTIF] All improved daily motivation notifications scheduled');
  }

  // Schedule dismissible motivation notification
  Future<void> _scheduleDismissibleMotivation({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledTime,
    required String type,
  }) async {
    try {
      const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
        'daily_motivation',
        'Daily Interview Coaching',
        channelDescription: 'Daily motivation and tips for interview success',
        importance: Importance.defaultImportance, // Normal importance
        priority: Priority.defaultPriority,
        icon: '@mipmap/ic_launcher',
        playSound: false, // Less intrusive
        enableVibration: false,
        ongoing: false, // Can be dismissed
        autoCancel: true, // Auto dismiss when tapped
        showWhen: false,
        category: AndroidNotificationCategory.recommendation,
      );

      const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: false,
        presentSound: false,
      );

      const NotificationDetails platformChannelSpecifics = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      await _notifications.zonedSchedule(
        id,
        title,
        body,
        tz.TZDateTime.from(scheduledTime, tz.local),
        platformChannelSpecifics,
        payload: 'daily_motivation_$type',
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      );

      print('✅ [NOTIF] Scheduled dismissible $type motivation at $scheduledTime');
    } catch (e) {
      print('❌ [NOTIF] Error scheduling motivation notification: $e');
    }
  }

  // Check and reschedule motivation if needed
  Future<void> checkMotivationSchedule() async {
    final prefs = await SharedPreferences.getInstance();
    final lastScheduled = prefs.getString(_lastMotivationKey);
    
    if (lastScheduled == null) {
      print('🔄 [NOTIF] No previous motivation schedule found - scheduling now');
      await _scheduleImprovedDailyMotivation();
      return;
    }
    
    final lastDate = DateTime.parse(lastScheduled);
    final daysDifference = DateTime.now().difference(lastDate).inDays;
    
    if (daysDifference >= 3) { // Reschedule every 3 days to ensure consistency
      print('🔄 [NOTIF] Motivation schedule is $daysDifference days old - rescheduling');
      await _scheduleImprovedDailyMotivation();
    } else {
      print('✅ [NOTIF] Motivation schedule is current ($daysDifference days old)');
    }
  }

  // Show achievement notification
  Future<void> showAchievementNotification(String achievement) async {
    print('🏆 [NOTIF] Showing achievement notification: $achievement');
    
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'achievements',
      'Success Milestones',
      channelDescription: 'Celebrate your interview preparation achievements',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
      playSound: true,
      enableVibration: true,
    );

    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    try {
      await _notifications.show(
        777,
        'ITSAGO - Achievement Unlocked! 🏆',
        achievement,
        platformChannelSpecifics,
        payload: 'achievement_notification',
      );
      print('✅ [NOTIF] Achievement notification shown successfully');
    } catch (e) {
      print('❌ [NOTIF] Error showing achievement notification: $e');
    }
  }

  // App lifecycle methods
  Future<void> onAppPaused() async {
    print('⏸️ [NOTIF] App paused - scheduling enhanced comeback notification');
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
      await _notifications.cancel(1);
      print('✅ [NOTIF] Comeback notification cancelled');
      
      // Check motivation schedule when app resumes
      await checkMotivationSchedule();
    } catch (e) {
      print('❌ [NOTIF] Error cancelling comeback notification: $e');
    }
  }

  Future<void> _scheduleComebackNotification() async {
    print('⏰ [NOTIF] Scheduling enhanced comeback notification...');
    
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'comeback_channel',
      'Practice Reminders',
      channelDescription: 'Gentle reminders to continue your interview journey',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
      showWhen: true,
      playSound: true,
      enableVibration: true,
    );

    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    // Get random comeback message
    final Random random = Random();
    final comebackMessage = _comebackMessages[random.nextInt(_comebackMessages.length)];

    // Schedule for different intervals based on user behavior
    final scheduledDate = DateTime.now().add(const Duration(hours: 2)); // 2 hours for testing
    final tzScheduledDate = tz.TZDateTime.from(scheduledDate, tz.local);
    
    print('📅 [NOTIF] Enhanced comeback notification scheduled for: $tzScheduledDate');
    print('🕒 [NOTIF] Current time: ${tz.TZDateTime.now(tz.local)}');
    
    try {
      await _notifications.zonedSchedule(
        1,
        'ITSAGO - We Miss You! 👋',
        comebackMessage,
        tzScheduledDate,
        platformChannelSpecifics,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        payload: 'comeback_notification',
      );
      print('✅ [NOTIF] Enhanced comeback notification scheduled successfully');
      
    } catch (e) {
      print('❌ [NOTIF] Error scheduling comeback notification: $e');
    }
  }

  // Clear old interview notifications
  Future<void> _clearInterviewNotifications() async {
    // Cancel previous interview notifications (using known ID ranges)
    for (final interview in _scheduledInterviews) {
      final baseId = interview.id.hashCode;
      for (int i = 1; i <= 6; i++) {
        final notificationId = baseId + i;
        await _notifications.cancel(notificationId);
        _activeCalendarNotificationIds.remove(notificationId);
      }
    }
    print('🧹 Cleared old interview notifications');
  }

  // Check for new interviews and update notifications
  Future<void> checkForNewInterviews() async {
    if (!_calendarService.isSignedIn) return;

    try {
      final currentInterviews = await _calendarService.getInterviewEvents();
      
      // Check if there are new interviews
      final newInterviews = currentInterviews.where((current) =>
        !_scheduledInterviews.any((scheduled) => scheduled.id == current.id)
      ).toList();

      if (newInterviews.isNotEmpty) {
        print('🆕 Found ${newInterviews.length} new interviews');
        
        // Schedule persistent notifications for new interviews
        for (final interview in newInterviews) {
          if (interview.isUpcoming) {
            await _scheduleNotificationsForInterview(interview);
          }
        }
        
        // Update scheduled list
        _scheduledInterviews = currentInterviews;
      }
    } catch (e) {
      print('❌ Error checking for new interviews: $e');
    }
  }

  // Test notifications
  Future<void> sendTestNotification() async {
    if (!_isInitialized) {
      await initialize();
    }

    print('🧪 [NOTIF] Showing enhanced test notification...');
    
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'test_channel',
      'Test Notifications',
      channelDescription: 'Test notifications to verify ITSAGO system works',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
      playSound: true,
      enableVibration: true,
    );

    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    try {
      await _notifications.show(
        999,
        'ITSAGO - System Check! 🧪',
        'Perfect! Notifications are working. Your interview coach is ready!',
        platformChannelSpecifics,
        payload: 'test_notification',
      );
      print('✅ [NOTIF] Enhanced test notification shown successfully');
    } catch (e) {
      print('❌ [NOTIF] Error showing test notification: $e');
    }
  }

  // Test persistent notification
  Future<void> sendTestPersistentNotification() async {
    if (!_isInitialized) {
      await initialize();
    }

    print('🧪 [NOTIF] Showing test PERSISTENT notification...');
    
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      channelId,
      channelName,
      channelDescription: 'Test persistent interview notification',
      importance: Importance.max,
      priority: Priority.max,
      icon: '@mipmap/ic_launcher',
      ongoing: true, // Makes it persistent
      autoCancel: false, // Can't be dismissed by swiping
      playSound: true,
      enableVibration: true,
      showWhen: true,
      category: AndroidNotificationCategory.event,
    );

    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      interruptionLevel: InterruptionLevel.timeSensitive,
    );

    const NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    final testPayload = jsonEncode({
      'action': 'interview_reminder',
      'interview_id': 'test_interview',
      'interview_title': 'Test Interview',
      'timing': 'test',
      'start_time': DateTime.now().add(const Duration(hours: 2)).toIso8601String(),
      'notification_id': 9999,
    });

    try {
      await _notifications.show(
        9999,
        'ITSAGO - Test Persistent! 🧪',
        'This is a persistent notification - only opening the app will dismiss it!',
        platformChannelSpecifics,
        payload: testPayload,
      );
      _activeCalendarNotificationIds.add(9999);
      print('✅ [NOTIF] Test persistent notification shown successfully');
    } catch (e) {
      print('❌ [NOTIF] Error showing test persistent notification: $e');
    }
  }

  // Get pending notifications (for debugging)
  Future<List<PendingNotificationRequest>> getPendingNotifications() async {
    return await _notifications.pendingNotificationRequests();
  }

  // Cancel all notifications
  Future<void> cancelAllNotifications() async {
    await _notifications.cancelAll();
    _scheduledInterviews.clear();
    _activeCalendarNotificationIds.clear();
    print('🚫 Cancelled all notifications');
  }

  // Cancel only persistent calendar notifications
  Future<void> cancelPersistentNotifications() async {
    for (final notificationId in _activeCalendarNotificationIds) {
      await _notifications.cancel(notificationId);
    }
    _activeCalendarNotificationIds.clear();
    print('🚫 Cancelled all persistent calendar notifications');
  }

  // Auto-schedule notifications when calendar is synced
  Future<void> onCalendarSynced() async {
    print('📅 Calendar synced, scheduling persistent notifications...');
    await scheduleInterviewNotifications();
  }

  // Background task to periodically check for updates
  Future<void> performBackgroundCheck() async {
    print('🔄 Performing background notification check...');
    await checkForNewInterviews();
    await checkMotivationSchedule();
  }

  // Debug method to show all pending notifications
  Future<void> debugPendingNotifications() async {
    try {
      final pendingNotifications = await _notifications.pendingNotificationRequests();
      print('📋 [NOTIF] Pending notifications: ${pendingNotifications.length}');
      
      int calendarCount = 0;
      int motivationCount = 0;
      int otherCount = 0;
      
      for (var notification in pendingNotifications) {
        print('   - ID: ${notification.id}, Title: ${notification.title}, Body: ${notification.body}');
        
        // Categorize notifications
        if (_activeCalendarNotificationIds.contains(notification.id)) {
          calendarCount++;
        } else if (notification.id >= 200 && notification.id < 300) {
          motivationCount++;
        } else {
          otherCount++;
        }
      }
      
      print('📊 [NOTIF] Breakdown: $calendarCount calendar, $motivationCount motivation, $otherCount other');
      print('🔒 [NOTIF] Active persistent calendar notifications: ${_activeCalendarNotificationIds.length}');
      
      if (pendingNotifications.isEmpty) {
        print('⚠️ [NOTIF] No pending notifications found - this might indicate a scheduling issue');
      }
    } catch (e) {
      print('❌ [NOTIF] Error getting pending notifications: $e');
    }
  }

  // Method to manually dismiss a persistent notification (for testing)
  Future<void> dismissPersistentNotification(int notificationId) async {
    if (_activeCalendarNotificationIds.contains(notificationId)) {
      await _notifications.cancel(notificationId);
      _activeCalendarNotificationIds.remove(notificationId);
      print('✅ [NOTIF] Manually dismissed persistent notification $notificationId');
    } else {
      print('❌ [NOTIF] Notification $notificationId is not in active persistent list');
    }
  }

  // Get statistics
  Map<String, dynamic> getNotificationStats() {
    return {
      'isInitialized': _isInitialized,
      'scheduledInterviews': _scheduledInterviews.length,
      'activePersistentNotifications': _activeCalendarNotificationIds.length,
      'persistentIds': _activeCalendarNotificationIds.toList(),
    };
  }
}