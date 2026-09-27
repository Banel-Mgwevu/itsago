import 'package:cloud_functions/cloud_functions.dart';

class CloudFunctionService {
  static final _functions = FirebaseFunctions.instance;

  // AI text generation - now routed to Google Gemini. The method keeps
  // its original name and signature so the 12 existing call sites across
  // the app don't need to change: the Cloud Function accepts this exact
  // payload shape and returns Claude-shaped responses ({content:[{text}]}),
  // and any Claude model name in `model` is mapped server-side to
  // gemini-2.5-flash.
  static Future<Map<String, dynamic>> callClaude({
    required String model,
    required int maxTokens,
    required List<Map<String, dynamic>> messages,
    String? system,
  }) async {
    final payload = {
      'model': model,
      'max_tokens': maxTokens,
      'messages': messages,
      if (system != null) 'system': system,
    };

    final result = await _functions
        .httpsCallable('callGemini')
        .call({'payload': payload});

    return Map<String, dynamic>.from(result.data);
  }

  static String extractText(Map<String, dynamic> response) {
    final content = response['content'] as List<dynamic>;
    return content[0]['text'] as String;
  }

  // Send a base64-encoded audio recording to the transcribeAudio Cloud
  // Function and return the recognized transcript. Returns empty string
  // on any failure so callers can fall back to on-device recognition.
  static Future<String> transcribeAudio({
    required String audioBase64,
    int sampleRate = 16000,
    String encoding = 'LINEAR16',
  }) async {
    try {
      // 2-minute answers are ~4 MB of audio - give slow mobile networks
      // time to upload it (the default callable timeout is too short).
      final result = await _functions
          .httpsCallable('transcribeAudio',
              options: HttpsCallableOptions(timeout: const Duration(seconds: 90)))
          .call({
        'audioBase64': audioBase64,
        'sampleRate': sampleRate,
        'encoding': encoding,
      });
      final data = Map<String, dynamic>.from(result.data);
      return (data['transcript'] as String?)?.trim() ?? '';
    } catch (e) {
      // Network error, timeout, etc. Caller falls back to on-device words.
      return '';
    }
  }
}
