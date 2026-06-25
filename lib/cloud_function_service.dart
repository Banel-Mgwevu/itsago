import 'package:cloud_functions/cloud_functions.dart';

class CloudFunctionService {
  static final _functions = FirebaseFunctions.instance;

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
        .httpsCallable('callClaude')
        .call({'payload': payload});

    return Map<String, dynamic>.from(result.data);
  }

  static String extractText(Map<String, dynamic> response) {
    final content = response['content'] as List<dynamic>;
    return content[0]['text'] as String;
  }
}
