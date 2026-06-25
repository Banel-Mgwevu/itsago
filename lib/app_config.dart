import 'remote_config_service.dart';

class AppConfig {
  // No API keys stored here — all calls go through Firebase Cloud Function
  // Gemini key still used for voice features only
  static String get geminiApiKey => RemoteConfigService.geminiApiKey;
}