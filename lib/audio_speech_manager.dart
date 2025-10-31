import 'package:speech_to_text/speech_to_text.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'dart:async';
import 'dart:typed_data';
import 'dart:io';

class AudioSpeechManager {
  // Callback functions
  final Function() onTTSComplete;
  final Function(String transcript, bool isFinal) onSpeechResult;
  final Function(String error) onSpeechError;
  final Function(String status) onSpeechStatusChange;

  // Azure TTS Configuration
  final String subscriptionKey = '935a507a40704fed86d4b57115f7ab59';
  final String region = 'eastus';
  late String ttsUrl;

  // Service objects
  late FlutterTts _flutterTts;
  late SpeechToText _speechToText;
  late AudioPlayer _audioPlayer;
  late http.Client _httpClient;
  bool _useAzureTTS = true;
  bool _azureTTSAvailable = false;
  bool _speechAvailable = false;

  // TTS state
  bool _faceWarningTtsPlaying = false;

  // Speech monitoring
  Timer? _speechMonitorTimer;
  String _lastTranscriptSnapshot = '';

  AudioSpeechManager({
    required this.onTTSComplete,
    required this.onSpeechResult,
    required this.onSpeechError,
    required this.onSpeechStatusChange,
  }) {
    ttsUrl = 'https://$region.tts.speech.microsoft.com/cognitiveservices/v1';
    _httpClient = http.Client();
    _audioPlayer = AudioPlayer();
    
    // Validate Azure configuration
    print('🔊 Azure TTS Configuration:');
    print('🔊 Region: $region');
    print('🔊 TTS URL: $ttsUrl');
    print('🔊 Subscription Key Length: ${subscriptionKey.length}');
    print('🔊 Key Preview: ${subscriptionKey.substring(0, 8)}***');
    
    if (subscriptionKey.length != 32) {
      print('🔊 ⚠️ WARNING: Subscription key length is ${subscriptionKey.length}, expected 32 characters');
    }
  }

  // Public interface methods
  Future<void> initializeServices() async {
    await _initializeAzureTTS();
    await _configureFallbackTTS();
    await _initializeSpeechRecognition();
  }

  Future<void> speakQuestion(String question) async {
    print('🔊 Speaking question: ${question.substring(0, question.length > 50 ? 50 : question.length)}...');
    
    bool ttsSuccessful = false;
    
    // Try Azure TTS first
    if (_useAzureTTS && _azureTTSAvailable) {
      try {
        print('🔊 Attempting Azure TTS with JennyNeural voice');
        await _speakWithAzure(question);
        ttsSuccessful = true;
        print('🔊 ✅ Azure TTS completed successfully');
      } catch (e) {
        print('🔊 ❌ Azure TTS failed: $e');
        _azureTTSAvailable = false; // Disable for this session
      }
    }
    
    // Fallback to system TTS if Azure failed
    if (!ttsSuccessful) {
      try {
        print('🔊 Using fallback system TTS');
        await _speakWithFallback(question);
        ttsSuccessful = true;
        print('🔊 ✅ Fallback TTS completed successfully');
      } catch (fallbackError) {
        print('🔊 ❌ Fallback TTS also failed: $fallbackError');
      }
    }
    
    // If both TTS methods fail, still continue the interview
    if (!ttsSuccessful) {
      print('🔊 ⚠️ All TTS methods failed - continuing without audio');
      onTTSComplete();
    }
  }

  Future<void> speakFaceWarning(String message) async {
    try {
      print('👤 🔊 Playing face warning TTS: $message');
      
      _faceWarningTtsPlaying = true;
      bool ttsSuccessful = false;
      
      if (_useAzureTTS && _azureTTSAvailable) {
        // Use Azure TTS for face warning
        try {
          await _speakWithAzure(message, isWarning: true);
          ttsSuccessful = true;
        } catch (e) {
          print('❌ Azure TTS failed for face warning: $e');
          _azureTTSAvailable = false; // Disable for this session
        }
      }
      
      if (!ttsSuccessful) {
        // Use fallback TTS
        await _speakWithFallback(message, isWarning: true);
      }
      
      // Reset flag after warning
      Timer(const Duration(seconds: 3), () {
        _faceWarningTtsPlaying = false;
      });
      
    } catch (e) {
      print('❌ Face warning TTS error: $e');
      _faceWarningTtsPlaying = false;
    }
  }

  void startListening() {
    if (!_speechToText.isAvailable || !_speechAvailable) {
      print('Speech recognition not available');
      return;
    }
    
    print('🎤 Starting speech recognition...');
    
    try {
      _speechToText.listen(
        onResult: (result) {
          if (result.recognizedWords.isNotEmpty || result.hasConfidenceRating) {
            print('✅ Valid speech result: ${result.recognizedWords} (confidence: ${result.confidence})');
            onSpeechResult(result.recognizedWords, result.finalResult);
          }
        },
        onSoundLevelChange: (level) {
          if (level > 0.2) {
            print('🔊 Sound detected: $level');
          }
        },
        listenFor: const Duration(seconds: 35),
        pauseFor: const Duration(seconds: 60),
        partialResults: true,
        cancelOnError: false,
        listenMode: ListenMode.search,
        sampleRate: 16000,
        onDevice: false,
        localeId: 'en_US',
      );
      
      _startSpeechMonitoring();
      
    } catch (e) {
      print('❌ Speech recognition setup error: $e');
      onSpeechError(e.toString());
    }
  }

  void stopListening() {
    try {
      if (_speechToText.isListening) {
        _speechToText.stop();
      }
    } catch (e) {
      print('Error stopping speech recognition: $e');
    }
    
    _speechMonitorTimer?.cancel();
  }

  void stopAll() {
    stopListening();
    
    try {
      _audioPlayer.stop();
    } catch (e) {
      print('Error stopping audio player: $e');
    }
    
    _speechMonitorTimer?.cancel();
  }

  void dispose() {
    print('🧹 Disposing AudioSpeechManager');
    
    stopAll();
    _audioPlayer.dispose();
    _httpClient.close();
    
    print('🧹 AudioSpeechManager disposed successfully');
  }

  // Getters for state
  bool get faceWarningTtsPlaying => _faceWarningTtsPlaying;

  // Private implementation methods

  // Azure TTS Methods
  Future<void> _initializeAzureTTS() async {
    try {
      print('🔊 Initializing Azure TTS...');
      print('🔊 Region: $region');
      print('🔊 TTS URL: $ttsUrl');
      print('🔊 Subscription Key: ${subscriptionKey.substring(0, 8)}...');
      
      // Test with a simple TTS request instead of HEAD
      await _testAzureWithSimpleTTS();
      
      _azureTTSAvailable = true;
      print('🔊 ✅ Azure TTS initialized successfully');
    } catch (e) {
      print('🔊 ❌ Azure TTS initialization failed: $e');
      _azureTTSAvailable = false;
      _useAzureTTS = false;
      print('🔊 Falling back to system TTS');
    }
  }

  Future<void> _testAzureWithSimpleTTS() async {
    try {
      print('🔊 Testing Azure TTS with JennyNeural voice...');
      
      final testSSML = '''
<speak version="1.0" xmlns="http://www.w3.org/2001/10/synthesis" xml:lang="en-US" xmlns:mstts="https://www.w3.org/2001/mstts">
  <voice name="en-US-JennyNeural">
    <mstts:express-as style="friendly" styledegree="1.1">
      <prosody rate="0.85" pitch="+1%" volume="medium">
        Test
      </prosody>
    </mstts:express-as>
  </voice>
</speak>''';
      
      final response = await _httpClient.post(
        Uri.parse(ttsUrl),
        headers: {
          'Ocp-Apim-Subscription-Key': subscriptionKey,
          'Content-Type': 'application/ssml+xml',
          'X-Microsoft-OutputFormat': 'audio-16khz-32kbitrate-mono-mp3',
          'User-Agent': 'FlutterApp/1.0',
        },
        body: testSSML,
      ).timeout(const Duration(seconds: 10));

      print('🔊 Test response status: ${response.statusCode}');
      if (response.statusCode == 200) {
        print('🔊 Azure TTS test successful (${response.bodyBytes.length} bytes received)');
      } else {
        print('🔊 Azure TTS test failed: ${response.statusCode}');
        print('🔊 Response body: ${response.body}');
        throw Exception('Azure TTS test failed: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      print('🔊 Azure TTS test exception: $e');
      throw Exception('Azure TTS test failed: $e');
    }
  }

  Future<void> _speakWithAzure(String text, {bool isWarning = false}) async {
    if (!_azureTTSAvailable) {
      throw Exception('Azure TTS not available');
    }

    try {
      print('🔊 Speaking with Azure TTS: ${text.length} characters');
      
      // Create SSML for JennyNeural voice with enhanced settings
      final ssml = _createSSMLForJenny(text, isWarning: isWarning);
      print('🔊 SSML created: ${ssml.substring(0, 100)}...');
      
      final response = await _httpClient.post(
        Uri.parse(ttsUrl),
        headers: {
          'Ocp-Apim-Subscription-Key': subscriptionKey,
          'Content-Type': 'application/ssml+xml',
          'X-Microsoft-OutputFormat': 'audio-16khz-32kbitrate-mono-mp3',
          'User-Agent': 'FlutterApp/1.0',
        },
        body: ssml,
      ).timeout(const Duration(seconds: 15));

      print('🔊 Azure TTS response: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        print('🔊 ✅ Azure TTS response received (${response.bodyBytes.length} bytes)');
        if (response.bodyBytes.length > 1000) { // Ensure we have a reasonable audio file
          await _playAudioFromBytes(response.bodyBytes);
        } else {
          throw Exception('Audio response too small: ${response.bodyBytes.length} bytes');
        }
      } else {
        print('🔊 ❌ Azure TTS error: ${response.statusCode}');
        print('🔊 Response headers: ${response.headers}');
        print('🔊 Response body: ${response.body}');
        throw Exception('Azure TTS request failed: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      print('🔊 ❌ Azure TTS error: $e');
      rethrow;
    }
  }

  String _createSSMLForJenny(String text, {bool isWarning = false}) {
    // Clean text for SSML - be more thorough
    final cleanText = text
        .trim()
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&apos;')
        .replaceAll('\n', ' ')
        .replaceAll('\r', ' ')
        .replaceAll(RegExp(r'\s+'), ' '); // Replace multiple spaces with single space

    print('🔊 Creating SSML for JennyNeural voice: ${cleanText.substring(0, cleanText.length > 100 ? 100 : cleanText.length)}...');

    // Enhance text for natural speech patterns
    String enhancedText = _enhanceTextForNaturalSpeech(cleanText, isWarning);

    // Different settings for warnings vs normal speech - FASTER SPEECH
    String style = isWarning ? 'empathetic' : 'friendly';
    String rate = isWarning ? '1.1' : '1.15'; // Increased from 0.9/0.85 to make her speak faster
    String pitch = isWarning ? '+3%' : '+1%';
    String volume = isWarning ? '+10%' : 'medium';

    return '''<speak version="1.0" xmlns="http://www.w3.org/2001/10/synthesis" xml:lang="en-US" xmlns:mstts="https://www.w3.org/2001/mstts">
  <voice name="en-US-JennyNeural">
    <mstts:express-as style="$style" styledegree="1.2">
      <prosody rate="$rate" pitch="$pitch" volume="$volume">
        $enhancedText
      </prosody>
    </mstts:express-as>
  </voice>
</speak>''';
  }

  String _enhanceTextForNaturalSpeech(String text, bool isWarning) {
    String enhanced = text;
    
    if (isWarning) {
      // More urgent tone for face detection warnings
      enhanced = enhanced.replaceAll('Please', '<emphasis level="strong">Please</emphasis>');
      enhanced = enhanced.replaceAll('camera', '<emphasis level="moderate">camera</emphasis>');
      enhanced = enhanced.replaceAll('position', '<emphasis level="moderate">position</emphasis>');
      return enhanced;
    }

    // Add natural pauses and emphasis for introductions
    if (enhanced.contains('Hi, my name is')) {
      enhanced = enhanced.replaceAll('Hi, my name is', 'Hi,<break time="300ms"/> my name is');
      enhanced = enhanced.replaceAll('I am here to interview you', 'I am here to interview you<break time="500ms"/>');
      enhanced = enhanced.replaceAll('Here is your first question:', 'Here is your first question:<break time="400ms"/>');
    }
    
    // Add emphasis on question words and natural pauses
    enhanced = enhanced.replaceAll('Tell me about', '<emphasis level="moderate">Tell me about</emphasis>');
    enhanced = enhanced.replaceAll('Describe', '<emphasis level="moderate">Describe</emphasis>');
    enhanced = enhanced.replaceAll('What', '<emphasis level="moderate">What</emphasis>');
    enhanced = enhanced.replaceAll('How', '<emphasis level="moderate">How</emphasis>');
    enhanced = enhanced.replaceAll('Why', '<emphasis level="moderate">Why</emphasis>');
    enhanced = enhanced.replaceAll('Can you', '<emphasis level="moderate">Can you</emphasis>');
    
    // Add natural pauses after question setup
    enhanced = enhanced.replaceAll('?', '?<break time="200ms"/>');
    
    // Add pauses after common phrases
    if (enhanced.contains('For example')) {
      enhanced = enhanced.replaceAll('For example,', 'For example,<break time="400ms"/>');
    }
    
    // Add slight emphasis on important words
    enhanced = enhanced.replaceAll('experience', '<emphasis level="moderate">experience</emphasis>');
    enhanced = enhanced.replaceAll('challenge', '<emphasis level="moderate">challenge</emphasis>');
    enhanced = enhanced.replaceAll('achievement', '<emphasis level="moderate">achievement</emphasis>');
    enhanced = enhanced.replaceAll('strength', '<emphasis level="moderate">strength</emphasis>');
    enhanced = enhanced.replaceAll('weakness', '<emphasis level="moderate">weakness</emphasis>');
    
    return enhanced;
  }
  
  Future<void> _playAudioFromBytes(Uint8List audioBytes) async {
    try {
      // Save audio to temporary file
      final tempDir = await getTemporaryDirectory();
      final tempFile = File('${tempDir.path}/tts_audio_${DateTime.now().millisecondsSinceEpoch}.mp3');
      await tempFile.writeAsBytes(audioBytes);
      
      print('🔊 Audio file saved: ${tempFile.path} (${audioBytes.length} bytes)');
      
      // Stop any currently playing audio
      await _audioPlayer.stop();
      
      // Set up completion callback BEFORE playing
      StreamSubscription? completionSubscription;
      StreamSubscription? stateSubscription;
      
      completionSubscription = _audioPlayer.onPlayerComplete.listen((_) {
        print('🔊 ✅ Azure TTS playback completed');
        _onTTSCompleteInternal();
        
        // Clean up subscriptions
        completionSubscription?.cancel();
        stateSubscription?.cancel();
        
        // Clean up temp file
        tempFile.delete().catchError((e) {
          print('Warning: Could not delete temp file: $e');
        });
      });

      // Set up state change callback for error handling
      stateSubscription = _audioPlayer.onPlayerStateChanged.listen((state) {
        print('🔊 Audio player state: $state');
        if (state == PlayerState.stopped && completionSubscription != null) {
          print('🔊 Audio player stopped unexpectedly');
        }
      });

      // Play the audio
      print('🔊 Starting audio playback...');
      await _audioPlayer.play(DeviceFileSource(tempFile.path));
      print('🔊 Audio play command sent');
      
      // Set a timeout in case completion handler never fires
      Timer(const Duration(seconds: 30), () {
        if (completionSubscription != null) {
          print('🔊 ⚠️ Audio playback timeout - forcing completion');
          completionSubscription?.cancel();
          stateSubscription?.cancel();
          _onTTSCompleteInternal();
          tempFile.delete().catchError((e) {
            print('Warning: Could not delete temp file: $e');
          });
        }
      });
      
    } catch (e) {
      print('🔊 ❌ Error playing audio: $e');
      // Still call completion to continue the flow
      _onTTSCompleteInternal();
      rethrow;
    }
  }

  void _onTTSCompleteInternal() {
    if (!_faceWarningTtsPlaying) { // Only trigger countdown if not a face warning
      print('🔊 TTS COMPLETION - CALLING CALLBACK');
      onTTSComplete();
    }
  }

  // Fallback TTS Methods
  Future<void> _configureFallbackTTS() async {
    _flutterTts = FlutterTts();
    
    await _flutterTts.setLanguage('en-US');
    await _flutterTts.setSpeechRate(0.4);
    await _flutterTts.setPitch(0.9);
    await _flutterTts.setVolume(0.8);
    await _flutterTts.awaitSpeakCompletion(true);
    
    _flutterTts.setCompletionHandler(() {
      if (!_faceWarningTtsPlaying) { // Only trigger countdown if not a face warning
        print('🔊 FALLBACK TTS COMPLETION HANDLER CALLED');
        onTTSComplete();
      }
    });
    
    _flutterTts.setErrorHandler((msg) {
      if (!_faceWarningTtsPlaying) { // Only trigger countdown if not a face warning
        print('🔊 FALLBACK TTS ERROR: $msg - STARTING COUNTDOWN ANYWAY');
        onTTSComplete();
      }
    });
    
    print('Fallback TTS configured successfully');
  }

  Future<void> _speakWithFallback(String text, {bool isWarning = false}) async {
    try {
      // Configure TTS for warning (slightly different settings)
      if (isWarning) {
        await _flutterTts.setSpeechRate(0.5);
        await _flutterTts.setPitch(1.0);
        await _flutterTts.setVolume(0.9);
      }
      
      await _flutterTts.speak(text);
      
      // Reset TTS settings back to normal after warning
      if (isWarning) {
        Timer(const Duration(seconds: 3), () async {
          await _flutterTts.setSpeechRate(0.4);
          await _flutterTts.setPitch(0.9);
          await _flutterTts.setVolume(0.8);
        });
      }
      
    } catch (e) {
      print('❌ Fallback TTS error: $e');
      throw e;
    }
  }

  // Speech Recognition Methods
  Future<void> _initializeSpeechRecognition() async {
    _speechToText = SpeechToText();
    bool available = await _speechToText.initialize(
      onError: (val) {
        print('Speech recognition error: ${val.errorMsg}');
        String errorMsg = val.errorMsg.toLowerCase();
        bool isSilenceError = errorMsg.contains('no match') ||
                             errorMsg.contains('no speech') ||
                             errorMsg.contains('speech timeout') ||
                             errorMsg.contains('network') ||
                             errorMsg.contains('audio recording error') ||
                             errorMsg.contains('insufficient permissions') ||
                             errorMsg.contains('recognition service busy') ||
                             errorMsg.contains('server') ||
                             errorMsg.contains('timeout') ||
                             errorMsg.contains('cancelled') ||
                             errorMsg.contains('aborted');
        
        if (!isSilenceError) {
          print('⚠️ Speech recognition technical error: ${val.errorMsg}');
          onSpeechError(val.errorMsg);
        } else {
          print('✅ Filtered silence/network error: ${val.errorMsg}');
        }
        
        print('🛡️ Speech error handled - recording continues normally');
      },
      onStatus: (val) {
        print('Speech recognition status: $val');
        onSpeechStatusChange(val);
      },
      debugLogging: false,
    );
    
    if (!available) {
      print('Speech recognition not available');
      _speechAvailable = false;
    } else {
      print('Speech recognition initialized successfully');
      _speechAvailable = true;
      
      var locales = await _speechToText.locales();
      print('Available locales: ${locales.map((l) => l.localeId).toList()}');
    }
  }

  void _startSpeechMonitoring() {
    _speechMonitorTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      print('🔍 Monitoring speech recognition - Status: ${_speechToText.isListening ? "listening" : "not listening"}');
      
      if (!_speechToText.isListening) {
        print('🔄 Speech recognition stopped unexpectedly - RESTARTING...');
        _restartSpeechRecognition();
      }
    });
  }

  void _restartSpeechRecognition() {
    print('🔄 Restarting speech recognition...');
    
    try {
      _speechToText.listen(
        onResult: (result) {
          if (result.recognizedWords.isNotEmpty || result.hasConfidenceRating) {
            print('✅ Restarted speech result: ${result.recognizedWords}');
            onSpeechResult(result.recognizedWords, result.finalResult);
          }
        },
        onSoundLevelChange: (level) {
          if (level > 0.2) {
            print('🔊 Restarted sound: $level');
          }
        },
        listenFor: const Duration(seconds: 35),
        pauseFor: const Duration(seconds: 60),
        partialResults: true,
        cancelOnError: false,
        listenMode: ListenMode.search,
        sampleRate: 16000,
        onDevice: false,
        localeId: 'en_US',
      );
    } catch (e) {
      print('❌ Error restarting speech recognition: $e');
      onSpeechError(e.toString());
    }
  }
}