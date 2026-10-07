import 'package:cloud_functions/cloud_functions.dart';

class CloudFunctionService {
  static final _functions = FirebaseFunctions.instance;

  /// Redeems an ITSAGO promo code on the server. Returns {ok, days, until}.
  /// Throws FirebaseFunctionsException (e.g. code 'not-found') on failure.
  static Future<Map<String, dynamic>> redeemPromoCode(String code) async {
    final result = await _functions
        .httpsCallable('redeemPromoCode')
        .call({'code': code});
    return Map<String, dynamic>.from(result.data as Map);
  }

  // AI text generation - now routed to Google Gemini. The method keeps
  // its original name and signature so the 12 existing call sites across
  // the app don't need to change: the Cloud Function accepts this exact
  // payload shape and returns Claude-shaped responses ({content:[{text}]}),
  // and any Claude model name in `model` is mapped server-side to
  // gemini-2.5-flash.
  /// Asks the server to confirm a subscription with Google Play or the
  /// App Store. Pass the token/transaction ID after a purchase, or nothing
  /// to re-check the one already on file. Returns {active, expiry, ...}.
  static Future<Map<String, dynamic>> verifySubscription({
    required String platform,
    String? purchaseToken,
    String? transactionId,
  }) async {
    final name = platform == 'ios' ? 'verifyAppStoreSubscription' : 'verifyPlaySubscription';
    final result = await _functions.httpsCallable(name).call({
      if (purchaseToken != null) 'purchaseToken': purchaseToken,
      if (transactionId != null) 'transactionId': transactionId,
    });
    return Map<String, dynamic>.from(result.data as Map);
  }

  static Future<Map<String, dynamic>> callClaude({
    required String model,
    required int maxTokens,
    required List<Map<String, dynamic>> messages,
    String? system,
    String? feature, // e.g. 'coach' - used by the server's daily limits
  }) async {
    final payload = {
      'model': model,
      'max_tokens': maxTokens,
      'messages': messages,
      if (system != null) 'system': system,
    };

    final result = await _functions
        .httpsCallable('callGemini')
        .call({'payload': payload, if (feature != null) 'feature': feature});

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
