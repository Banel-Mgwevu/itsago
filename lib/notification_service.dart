import 'dart:convert';
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

  static const String _permissionKey     = 'notification_permission_requested';
  static const String _enabledKey        = 'notifications_enabled';
  static const String _lastMotivationKey = 'last_motivation_date';

  final FlutterLocalNotificationsPlugin _notif = FlutterLocalNotificationsPlugin();
  final GoogleCalendarService _calendar = GoogleCalendarService();

  bool _isInitialized = false;
  List<CalendarEvent> _scheduledInterviews = [];
  final Set<int> _activeCalendarIds = {};

  final List<String> _motivational = [
    'Your next interview could be your breakthrough moment. Practise now.',
    'Top candidates in SA practise daily. Are you ready?',
    'Confidence is built one session at a time. Let us go.',
    'From Etwatwa to Sandton — every great hire prepared first.',
    'Your dream job at a top SA company starts with preparation.',
    'Recruiters notice candidates who are prepared. Be that person.',
    'Five minutes of practice today beats regret after the interview.',
    'Nervous about your next interview? Practise until you are not.',
    'South African employers want confident communicators. Become one.',
    'Every session builds the version of you that lands the job.',
    'The candidate who prepares most gets the offer. That is you.',
    'Filler words cost you offers. Practise eliminating them today.',
    'Great answers do not happen by accident — they are practised.',
    'Hustle smart. Practise with ITSAGO and walk into that interview ready.',
    'Mzansi is full of talent. Show them yours — practise today.',
    'That job is waiting for someone prepared enough to take it.',
  ];
  final List<String> _lowScore = [
    'Your last session scored below 50%. A quick practice now will make a real difference.',
    'Great candidates bounce back fast. Your next practice session is waiting.',
    'Low score? That\'s just feedback. Come back and nail it.',
    'Every top performer had sessions like that. What matters is coming back.',
    'Your score tells you where to improve — not where you\'ll stay.',
  ];

  final List<String> _highScore = [
    'You scored above 75% last session. Keep that momentum going!',
    'Strong performance! One more session and you\'re interview-ready.',
    'You\'re building real interview confidence. Don\'t stop now.',
    'Top score! Consistency separates good from great.',
    'You\'re on a roll. Book that interview — you\'re getting ready.',
  ];

  final List<String> _comeback = [
    'Your interview skills need regular practice to stay sharp. Come back.',
    'A quick 5-minute session keeps your confidence high. Ready?',
    'Don\'t let your preparation slip. Your next interview could be soon.',
    'Your future employer is interviewing candidates today. Are you ready?',
    'Consistency wins interviews. Come back and keep your streak going.',
    'You were making great progress. One session gets you back on track.',
    'Your competition hasn\'t stopped practising. Neither should you.',
    'It\'s been a while. A quick session is all it takes to stay sharp.',
  ];

  final List<String> _titles = [
    'ITSAGO — Practice Time',
    'ITSAGO — Stay Sharp',
    'ITSAGO — Keep Going',
    'ITSAGO — You\'ve Got This',
    'ITSAGO — Interview Ready?',
    'ITSAGO — Build Confidence',
    'ITSAGO — Daily Prep',
    'ITSAGO — One More Session',
  ];

  // ── Init ─────────────────────────────────────────────────────

  Future<void> initialize() async {
    if (_isInitialized) return;
    tz.initializeTimeZones();
    const settings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true));
    await _notif.initialize(settings,
        onDidReceiveNotificationResponse: _onTapped);
    await _createChannels();
    _isInitialized = true;
  }

  Future<void> _createChannels() async {
    if (!Platform.isAndroid) return;
    final plugin = _notif.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    const channels = [
      AndroidNotificationChannel('interview_reminders', 'Interview Reminders',
          description: 'Notifications for upcoming interviews',
          importance: Importance.max, enableVibration: true, playSound: true),
      AndroidNotificationChannel('comeback_channel', 'Practice Reminders',
          description: 'Reminders to continue interview preparation',
          importance: Importance.high, playSound: true, enableVibration: true),
      AndroidNotificationChannel('daily_motivation', 'Daily Coaching',
          description: 'Daily motivation for interview skills',
          importance: Importance.defaultImportance,
          playSound: false, enableVibration: false, showBadge: false),
      AndroidNotificationChannel('achievements', 'Achievements',
          description: 'Celebrate your preparation milestones',
          importance: Importance.high, playSound: true, enableVibration: true),
      AndroidNotificationChannel('score_feedback', 'Score Feedback',
          description: 'Personalised feedback based on your scores',
          importance: Importance.high, playSound: true, enableVibration: true),
    ];
    for (final ch in channels) {
      await plugin?.createNotificationChannel(ch);
    }
  }

  // ── Permissions ──────────────────────────────────────────────

  Future<bool> requestPermissions() => checkAndRequestPermissions();

  Future<bool> checkAndRequestPermissions() async {
    final prefs = await SharedPreferences.getInstance();
    if (!(prefs.getBool(_permissionKey) ?? false)) return _requestPerms();
    return _enabled();
  }

  Future<bool> _requestPerms() async {
    final prefs = await SharedPreferences.getInstance();
    try {
      bool granted = false;
      if (Platform.isAndroid) {
        final n = await Permission.notification.request();
        bool exact = true;
        try { exact = await Permission.scheduleExactAlarm.request() == PermissionStatus.granted; } catch (_) {}
        granted = n == PermissionStatus.granted && exact;
      } else {
        final plugin = _notif.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
        granted = await plugin?.requestPermissions(alert: true, badge: true, sound: true) ?? false;
      }
      await prefs.setBool(_permissionKey, true);
      await prefs.setBool(_enabledKey, granted);
      if (granted) await _scheduleDaily();
      return granted;
    } catch (_) {
      await prefs.setBool(_permissionKey, true);
      await prefs.setBool(_enabledKey, false);
      return false;
    }
  }

  Future<bool> _enabled() async {
    try {
      if (Platform.isAndroid) {
        final n = await Permission.notification.status;
        bool exact = true;
        try { exact = await Permission.scheduleExactAlarm.status == PermissionStatus.granted; } catch (_) {}
        return n == PermissionStatus.granted && exact;
      }
      return true;
    } catch (_) { return false; }
  }

  // ── Score-based notifications ─────────────────────────────────

  Future<void> onInterviewCompleted({
    required double avgScore,
    required String company,
    required int questionCount,
  }) async {
    if (!_isInitialized) await initialize();
    if (!await _enabled()) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('last_score', avgScore);
    final rng = Random();
    if (avgScore >= 75) {
      await _now(id: 500, ch: 'achievements', chName: 'Achievements',
        title: 'Strong Session — ${avgScore.round()}%',
        body: _highScore[rng.nextInt(_highScore.length)]);
    } else if (avgScore >= 50) {
      await _now(id: 501, ch: 'achievements', chName: 'Achievements',
        title: 'Good Effort — ${avgScore.round()}%',
        body: 'You\'re building momentum. Come back tomorrow to push that score higher.');
    } else {
      await _now(id: 502, ch: 'score_feedback', chName: 'Score Feedback',
        title: 'Keep Practising — ${avgScore.round()}%',
        body: _lowScore[rng.nextInt(_lowScore.length)]);
      await _schedule(id: 503, ch: 'comeback_channel', chName: 'Practice Reminders',
        title: 'Time to Improve That Score',
        body: 'Your last session at $company scored ${avgScore.round()}%. A focused practice now will help.',
        scheduledTime: DateTime.now().add(const Duration(hours: 23)));
    }
  }

  // ── Calendar interview notifications ─────────────────────────

  Future<void> scheduleInterviewNotifications() async {
    if (!_isInitialized) await initialize();
    try {
      final interviews = await _calendar.getInterviewEvents();
      await _clearInterviewNotifications();
      for (final i in interviews) {
        if (i.isUpcoming) await _scheduleForInterview(i);
      }
      _scheduledInterviews = interviews;
    } catch (e) { print('Error scheduling: $e'); }
  }

  Future<void> _scheduleForInterview(CalendarEvent interview) async {
    final now  = DateTime.now();
    final time = interview.startTime;
    final base = interview.id.hashCode;
    final slots = [
      (time.subtract(const Duration(days: 3)),    base + 1, 'Interview in 3 Days',  '📅'),
      (time.subtract(const Duration(days: 2)),    base + 2, 'Interview in 2 Days',  '⏰'),
      (time.subtract(const Duration(days: 1)),    base + 3, 'Interview Tomorrow!',  '🚀'),
      (time.subtract(const Duration(hours: 6)),   base + 4, 'Interview in 6 Hours', '⚡'),
      (time.subtract(const Duration(hours: 2)),   base + 5, 'Interview Today',      '🎯'),
      (time.subtract(const Duration(minutes: 30)), base + 6,'Starting in 30 Min',   '🔥'),
    ];
    for (final slot in slots) {
      final schedTime = slot.$1;
      final nid       = slot.$2;
      final title     = slot.$3;
      final emoji     = slot.$4;
      if (schedTime.isAfter(now)) {
        await _schedule(
          id: nid, ch: 'interview_reminders', chName: 'Interview Reminders',
          title: '$emoji $title',
          body: '"${interview.title}" — tap to do a quick practice session.',
          scheduledTime: schedTime, persistent: true);
        _activeCalendarIds.add(nid);
      }
    }
  }

  // ── Daily motivation ─────────────────────────────────────────

  Future<void> _scheduleDaily() async {
    for (int i = 0; i < 14; i++) { await _notif.cancel(200 + i); }
    final rng = Random();
    final now = DateTime.now();
    final times = [{'h': 8, 'm': 30}, {'h': 18, 'm': 0}];
    int id = 200;
    for (int day = 0; day < 7; day++) {
      for (final t in times) {
        final schedTime = DateTime(now.year, now.month, now.day + day, t['h']!, t['m']!);
        if (schedTime.isBefore(now)) { id++; continue; }
        await _schedule(
          id: id++,
          ch: 'daily_motivation', chName: 'Daily Coaching',
          title: _titles[rng.nextInt(_titles.length)],
          body:  _motivational[rng.nextInt(_motivational.length)],
          scheduledTime: schedTime, sound: false);
      }
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lastMotivationKey, now.toIso8601String());
  }

  Future<void> checkMotivationSchedule() async {
    final prefs = await SharedPreferences.getInstance();
    final last  = prefs.getString(_lastMotivationKey);
    if (last == null || DateTime.now().difference(DateTime.parse(last)).inDays >= 3) {
      await _scheduleDaily();
    } else { print('Motivation schedule current.'); }
  }

  // ── App lifecycle ─────────────────────────────────────────────

  Future<void> onAppPaused() async {
    if (!await _enabled()) return;
    final prefs     = await SharedPreferences.getInstance();
    final lastScore = prefs.getDouble('last_score');
    final rng       = Random();
    final body = (lastScore != null && lastScore < 50)
        ? _lowScore[rng.nextInt(_lowScore.length)]
        : _comeback[rng.nextInt(_comeback.length)];
    await _schedule(
      id: 1, ch: 'comeback_channel', chName: 'Practice Reminders',
      title: 'ITSAGO — Stay Sharp',
      body: body,
      scheduledTime: DateTime.now().add(const Duration(hours: 24)));
  }

  Future<void> onAppResumed() async {
    await _notif.cancel(1);
    await checkMotivationSchedule();
  }

  // ── Helpers ───────────────────────────────────────────────────

  Future<void> _now({required int id, required String ch, required String chName,
      required String title, required String body}) async {
    await _notif.show(id, title, body,
      NotificationDetails(
        android: AndroidNotificationDetails(ch, chName,
          importance: Importance.high, priority: Priority.high,
          icon: '@mipmap/ic_launcher', playSound: true, enableVibration: true),
        iOS: const DarwinNotificationDetails(
          presentAlert: true, presentBadge: true, presentSound: true)));
  }

  Future<void> _schedule({required int id, required String ch, required String chName,
      required String title, required String body, required DateTime scheduledTime,
      bool persistent = false, bool sound = true}) async {
    try {
      await _notif.zonedSchedule(id, title, body,
        tz.TZDateTime.from(scheduledTime, tz.local),
        NotificationDetails(
          android: AndroidNotificationDetails(ch, chName,
            importance: persistent ? Importance.max : Importance.high,
            priority:   persistent ? Priority.max   : Priority.high,
            icon: '@mipmap/ic_launcher',
            ongoing: persistent, autoCancel: !persistent,
            playSound: sound, enableVibration: sound),
          iOS: const DarwinNotificationDetails(
            presentAlert: true, presentBadge: true, presentSound: true)),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle);
    } catch (e) { print('Schedule failed $id: $e'); }
  }

  void _onTapped(NotificationResponse r) {
    if (r.payload == null || r.id == null) return;
    try {
      final data = jsonDecode(r.payload!);
      if (data['action'] == 'interview_reminder') {
        _activeCalendarIds.remove(r.id);
        _notif.cancel(r.id!);
      }
    } catch (_) {}
  }

  Future<void> _clearInterviewNotifications() async {
    for (final i in _scheduledInterviews) {
      final base = i.id.hashCode;
      for (int j = 1; j <= 6; j++) {
        await _notif.cancel(base + j);
        _activeCalendarIds.remove(base + j);
      }
    }
  }

  Future<void> onCalendarSynced() async => scheduleInterviewNotifications();
  Future<void> cancelAllNotifications() async {
    await _notif.cancelAll();
    _scheduledInterviews.clear();
    _activeCalendarIds.clear();
  }

  Map<String, dynamic> getNotificationStats() => {
    'isInitialized': _isInitialized,
    'scheduledInterviews': _scheduledInterviews.length,
    'activeCalendarNotifications': _activeCalendarIds.length,
  };
}
