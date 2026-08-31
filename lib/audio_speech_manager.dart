import 'package:speech_to_text/speech_to_text.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:io';

class AudioSpeechManager {
  // Callback functions
  final Function() onTTSComplete;
  final Function(String transcript, bool isFinal) onSpeechResult;
  final Function(String error) onSpeechError;
  final Function(String status) onSpeechStatusChange;

  // Google Cloud Text-to-Speech (Chirp 3: HD voices) - accessed via a
  // Cloud Function so no API key ships in the app.
  final FirebaseFunctions _functions = FirebaseFunctions.instance;
  final String _voiceName = 'en-US-Chirp3-HD-Aoede';

  // Service objects
  late FlutterTts _flutterTts;
  late SpeechToText _speechToText;
  late AudioPlayer _audioPlayer;
  bool _useGoogleTTS = true;
  bool _googleTTSAvailable = true;
  bool _speechAvailable   = false;
  bool _shouldBeListening = false;
  bool _isRestarting    = false;
  String _accumulatedTranscript = '';

  // TTS state
  bool _faceWarningTtsPlaying = false;
  bool _ttsPlaying = false;

  // Speech monitoring
  Timer? _speechMonitorTimer;
  Timer? _audioTimeoutTimer;
  bool _disposed = false;
  String _lastTranscriptSnapshot = '';

  AudioSpeechManager({
    required this.onTTSComplete,
    required this.onSpeechResult,
    required this.onSpeechError,
    required this.onSpeechStatusChange,
  }) {
    _audioPlayer = AudioPlayer();
    print('Google Cloud TTS configured (voice: $_voiceName)');
  }

  // Public interface methods
  Future<void> initializeServices() async {
    await _configureFallbackTTS();
    await _initializeSpeechRecognition();
  }

  Future<void> speakQuestion(String question) async {
    stopListening();
    _ttsPlaying = true;
    print('Speaking question: ${question.substring(0, question.length > 50 ? 50 : question.length)}...');

    bool ttsSuccessful = false;

    // Try Google Cloud TTS (Chirp 3 HD) first
    if (_useGoogleTTS && _googleTTSAvailable) {
      try {
        print('Attempting Google Cloud TTS ($_voiceName)');
        await _speakWithGoogle(question);
        ttsSuccessful = true;
        print('Google Cloud TTS completed successfully');
      } catch (e) {
        print('Google Cloud TTS failed: $e');
        _googleTTSAvailable = false; // Disable for this session
      }
    }

    // Fallback to on-device system TTS if Google Cloud TTS failed
    if (!ttsSuccessful) {
      try {
        print('Using fallback system TTS');
        await _speakWithFallback(question);
        ttsSuccessful = true;
        print('Fallback TTS completed successfully');
      } catch (fallbackError) {
        print('Fallback TTS also failed: $fallbackError');
      }
    }

    // If both TTS methods fail, still continue the interview
    if (!ttsSuccessful) {
      print('All TTS methods failed - continuing without audio');
      onTTSComplete();
    }
  }

  Future<void> speakFaceWarning(String message) async {
    stopListening();
    try {
      print('Playing face warning TTS: $message');

      _faceWarningTtsPlaying = true;
      bool ttsSuccessful = false;

      if (_useGoogleTTS && _googleTTSAvailable) {
        try {
          await _speakWithGoogle(message, isWarning: true);
          ttsSuccessful = true;
        } catch (e) {
          print('Google Cloud TTS failed for face warning: $e');
          _googleTTSAvailable = false; // Disable for this session
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
      print('Face warning TTS error: $e');
      _faceWarningTtsPlaying = false;
    }
  }

  void startListening() {
    print('ðŸŽ¤ startListening called (available=${_speechToText.isAvailable}, speechAvailable=$_speechAvailable)');
    if (!_speechToText.isAvailable || !_speechAvailable) {
      print('ðŸŽ¤ âŒ Cannot listen - speech recognition unavailable');
      return;
    }
    _shouldBeListening     = true;
    _accumulatedTranscript = '';
    _isRestarting          = false;
    _doListen();
  }

  /// Resume listening WITHOUT clearing the accumulated transcript.
  /// Use this when the mic needs to restart mid-answer (e.g. after a
  /// face-warning TTS) so the user's earlier words are kept.
  void resumeListening() {
    print('ðŸŽ¤ resumeListening called');
    if (!_speechToText.isAvailable || !_speechAvailable) return;
    _shouldBeListening = true;
    _isRestarting      = false;
    _doListen();
  }

  void _doListen() {
    if (_disposed || !_shouldBeListening || _ttsPlaying || _isRestarting) {
      print('ðŸŽ¤ _doListen blocked (disposed=$_disposed shouldListen=$_shouldBeListening ttsPlaying=$_ttsPlaying restarting=$_isRestarting)');
      return;
    }
    if (_speechToText.isListening) {
      print('ðŸŽ¤ _doListen skipped - already listening');
      return;
    }
    _isRestarting = true;
    // 100ms is too short for Android's SpeechRecognizer teardown and causes
    // error_busy; 350ms gives it time to release before we listen again.
    Future.delayed(const Duration(milliseconds: 350), () async {
      _isRestarting = false;
      if (_disposed || !_shouldBeListening || _ttsPlaying) return;
      if (_speechToText.isListening) return;
      try {
        print('ðŸŽ¤ Calling speech.listen() with locale en_ZA...');
        await _speechToText.listen(
          onResult: (result) {
            print('ðŸŽ¤ Result: "${result.recognizedWords}" (final=${result.finalResult}, conf=${result.confidence})');
            if (result.recognizedWords.isNotEmpty) {
              final words = result.recognizedWords.trim();
              if (result.finalResult) {
                _accumulatedTranscript = (_accumulatedTranscript + ' ' + words).trim();
                onSpeechResult(_accumulatedTranscript, true);
              } else {
                onSpeechResult((_accumulatedTranscript + ' ' + words).trim(), false);
              }
            }
          },
          onSoundLevelChange: (level) {
            // Log occasionally so we can confirm the mic is actually
            // receiving audio (level changes = mic is live).
            if (level > 0.5) print('ðŸŽ¤ Sound level: ${level.toStringAsFixed(1)}');
          },
          listenFor: const Duration(seconds: 20),
          pauseFor:  const Duration(seconds: 20),
          partialResults: true,
          cancelOnError: false,
          listenMode: ListenMode.dictation,
          localeId: 'en_ZA',
        );
        print('ðŸŽ¤ âœ… speech.listen() started (isListening=${_speechToText.isListening})');
      } catch (e) {
        // This exception was previously swallowed silently - if listen()
        // fails, this is the reason the mic never picks anything up.
        print('ðŸŽ¤ âŒ speech.listen() FAILED: $e');
      }
    });
  }

  void stopListening() {
    _shouldBeListening     = false;
    _accumulatedTranscript = '';
    _isRestarting          = false;
    _speechMonitorTimer?.cancel();
    try { if (_speechToText.isListening) _speechToText.stop(); } catch (_) {}
  }

  // Google Cloud TTS (Chirp 3: HD voices) - via Cloud Function
  //
  // Chirp 3 HD is Google's most natural, human-sounding voice tier
  // (natural intonation, pacing and pauses baked into the model).
  // Unlike the old Azure SSML approach, Chirp 3 HD does NOT accept
  // SSML markup - only plain text - so no emphasis/break tags are
  // built here; the voice's own prosody handles that naturally.
  Future<void> _speakWithGoogle(String text, {bool isWarning = false}) async {
    if (!_googleTTSAvailable) {
      throw Exception('Google Cloud TTS not available');
    }

    final cleanText = text
        .trim()
        .replaceAll(RegExp(r'\s+'), ' ');

    print('Speaking with Google Cloud TTS: ${cleanText.length} characters');

    try {
      final result = await _functions.httpsCallable('synthesizeSpeech').call({
        'text': cleanText,
        'voiceName': _voiceName,
      }).timeout(const Duration(seconds: 15));

      final data = Map<String, dynamic>.from(result.data);
      final audioBase64 = data['audioBase64'] as String?;
      if (audioBase64 == null || audioBase64.isEmpty) {
        throw Exception('No audio returned from Google Cloud TTS');
      }

      final audioBytes = base64Decode(audioBase64);
      print('Google Cloud TTS response received (${audioBytes.length} bytes)');
      await _playAudioFromBytes(audioBytes);
    } catch (e) {
      print('Google Cloud TTS error: $e');
      rethrow;
    }
  }

  
  Future<void> _playAudioFromBytes(Uint8List audioBytes) async {
    try {
      // Save audio to temporary file
      final tempDir = await getTemporaryDirectory();
      final tempFile = File('${tempDir.path}/tts_audio_${DateTime.now().millisecondsSinceEpoch}.mp3');
      await tempFile.writeAsBytes(audioBytes);
      
      print('ðŸ”Š Audio file saved: ${tempFile.path} (${audioBytes.length} bytes)');
      
      // Stop any currently playing audio
      await _audioPlayer.stop();
      
      // Set up completion callback BEFORE playing
      StreamSubscription? completionSubscription;
      StreamSubscription? stateSubscription;
      bool playbackCompleted = false; // Guard against double-completion

      completionSubscription = _audioPlayer.onPlayerComplete.listen((_) {
        if (playbackCompleted) return;
        playbackCompleted = true;
        print('TTS playback completed');
        _audioTimeoutTimer?.cancel(); // Real completion - kill the safety timeout
        _onTTSCompleteInternal();
        
        // Clean up subscriptions
        completionSubscription?.cancel();
        stateSubscription?.cancel();
        
        // Clean up temp file
        tempFile.delete().catchError((e) {
          print('Warning: Could not delete temp file: $e');
          return tempFile;
        });
      });

      // Set up state change callback for error handling
      stateSubscription = _audioPlayer.onPlayerStateChanged.listen((state) {
        print('ðŸ”Š Audio player state: $state');
        if (state == PlayerState.stopped && completionSubscription != null) {
          print('ðŸ”Š Audio player stopped unexpectedly');
        }
      });

      // Play the audio
      print('ðŸ”Š Starting audio playback...');
      await _audioPlayer.play(DeviceFileSource(tempFile.path));
      print('ðŸ”Š Audio play command sent');
      
      // Store timeout so dispose() can cancel it
      _audioTimeoutTimer?.cancel();
      _audioTimeoutTimer = Timer(const Duration(seconds: 30), () {
        if (!playbackCompleted) {
          playbackCompleted = true;
          print('ðŸ”Š âš ï¸ Audio playback timeout - forcing completion');
          completionSubscription?.cancel();
          stateSubscription?.cancel();
          _onTTSCompleteInternal();
          tempFile.delete().catchError((e) {
            print('Warning: Could not delete temp file: $e');
            return tempFile;
          });
        }
      });
      
    } catch (e) {
      print('ðŸ”Š âŒ Error playing audio: $e');
      // Still call completion to continue the flow
      _onTTSCompleteInternal();
      rethrow;
    }
  }

  void _onTTSCompleteInternal() {
    if (_disposed) return;
    _ttsPlaying = false;
    if (!_faceWarningTtsPlaying) { // Only trigger countdown if not a face warning
      print('ðŸ”Š TTS COMPLETION - CALLING CALLBACK');
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
        print('ðŸ”Š FALLBACK TTS COMPLETION HANDLER CALLED');
        onTTSComplete();
      }
    });
    
    _flutterTts.setErrorHandler((msg) {
      if (!_faceWarningTtsPlaying) { // Only trigger countdown if not a face warning
        print('ðŸ”Š FALLBACK TTS ERROR: $msg - STARTING COUNTDOWN ANYWAY');
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
      print('âŒ Fallback TTS error: $e');
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
                             errorMsg.contains('busy') || // covers error_busy + 'recognition service busy'
                             errorMsg.contains('server') ||
                             errorMsg.contains('timeout') ||
                             errorMsg.contains('cancelled') ||
                             errorMsg.contains('aborted');

        // error_busy means listen() was called before the recognizer finished
        // tearing down - cancel the stuck session and retry after a delay so
        // the mic actually comes back instead of staying dead.
        if (errorMsg.contains('busy')) {
          try { _speechToText.cancel(); } catch (_) {}
          if (_shouldBeListening && !_ttsPlaying && !_disposed) {
            Future.delayed(const Duration(milliseconds: 700), _doListen);
          }
        }

        if (!isSilenceError) {
          print('âš ï¸ Speech recognition technical error: ${val.errorMsg}');
          onSpeechError(val.errorMsg);
        } else {
          print('âœ… Filtered silence/network error: ${val.errorMsg}');
        }
        
        print('ðŸ›¡ï¸ Speech error handled - recording continues normally');
      },
      onStatus: (val) {
        print('ðŸŽ¤ Status: $val (shouldListen=$_shouldBeListening ttsPlaying=$_ttsPlaying)');
        onSpeechStatusChange(val);
        if ((val == 'done' || val == 'notListening') &&
            _shouldBeListening && !_ttsPlaying && !_disposed) {
          Future.delayed(const Duration(milliseconds: 300), _doListen);
        }
      },
      debugLogging: true,
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









  void stopAll() {
    _speechMonitorTimer?.cancel();
    _speechMonitorTimer = null;
    _audioTimeoutTimer?.cancel();
    _shouldBeListening = false;
    _isRestarting      = false;
    try { _flutterTts.stop(); } catch (_) {}
    try { if (_speechToText.isListening) _speechToText.stop(); } catch (_) {}
    try { _audioPlayer.stop(); } catch (_) {}
  }

  void dispose() {
    _disposed = true;
    stopAll();
    try { _audioPlayer.dispose(); } catch (_) {}
  }
}


