import 'package:firebase_remote_config/firebase_remote_config.dart';

class RemoteConfigService {
  static final _rc = FirebaseRemoteConfig.instance;

  static Future<void> init() async {
    await _rc.setConfigSettings(RemoteConfigSettings(
      fetchTimeout: const Duration(seconds: 10),
      minimumFetchInterval: const Duration(hours: 12),
    ));
    await _rc.setDefaults({
      'cv_weekly_limit': 2,
      'ai_coach_daily_limit': 20,
      'cv_builder_enabled': true,
      'ai_coach_enabled': true,
      'maintenance_mode': false,
      'maintenance_message': 'App is under maintenance. Back soon!',
      'claude_api_key': '',
      'gemini_api_key': '',
    });
    try {
      await _rc.fetchAndActivate();
    } catch (_) {
      // Remote config failed — app continues with defaults
    }
  }

  static int get cvWeeklyLimit => _rc.getInt('cv_weekly_limit');
  static int get aiCoachDailyLimit => _rc.getInt('ai_coach_daily_limit');
  static bool get cvBuilderEnabled => _rc.getBool('cv_builder_enabled');
  static bool get aiCoachEnabled => _rc.getBool('ai_coach_enabled');
  static bool get maintenanceMode => _rc.getBool('maintenance_mode');
  static String get maintenanceMessage => _rc.getString('maintenance_message');
  static String get claudeApiKey => _rc.getString('claude_api_key');
  static String get geminiApiKey => _rc.getString('gemini_api_key');
  static bool get showAnnouncement => _rc.getBool('show_announcement');
  static String get announcementMessage => _rc.getString('announcement_message');
}
