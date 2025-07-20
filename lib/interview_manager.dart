import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'dart:async';
import 'dart:math';
import 'dart:typed_data';
import 'package:permission_handler/permission_handler.dart';
import 'main.dart';

class InterviewManager {
  // Constructor dependencies
  final List<CameraDescription> cameras;
  final List<String> questions;
  final String company;
  final String apiKey;
  final Function(Map<String, dynamic>) onStateUpdate;
  final Function(List<Map<String, dynamic>>) onNavigateToCompletion;

  // Service objects
  late CameraController _cameraController;
  late FlutterTts _flutterTts;
  late SpeechToText _speechToText;
  late FaceDetector _faceDetector;

  // Face detection variables
  bool _faceDetectionInitialized = false;
  bool _isProcessingImage = false;
  bool _faceDetected = false;
  DateTime? _lastFaceDetectedTime;
  Timer? _faceDetectionTimer;
  Timer? _noFaceWarningTimer;
  bool _showingFaceWarning = false;
  bool _faceWarningTtsPlaying = false;
  int _noFaceWarningCount = 0;
  Timer? _faceDetectionProcessingTimer;

  // Timer pause functionality
  bool _timerPaused = false;

  // State variables
  int _currentQuestionIndex = 0;
  bool _isRecording = false;
  bool _isAnalyzing = false;
  String _currentTranscript = '';
  String _speechStatus = 'notListening';
  Timer? _recordingTimer;
  Timer? _analysisTimer;
  Timer? _durationTimer;
  Timer? _countdownTimer;
  Timer? _cardVisibilityTimer;
  bool _speechAvailable = false;
  int _recordingDuration = 0;

  bool _showingQuestion = true;
  bool _showingCamera = false;
  int _countdown = 5;
  bool _countdownPaused = false;
  bool _cameraInitialized = false;

  // Enhanced countdown variables
  bool _showingFinalCountdown = false;
  int _finalCountdown = 3;
  Timer? _finalCountdownTimer;
  bool _ttsCompleted = false;
  bool _recordingCanStart = false;

  // Precise countdown variables
  DateTime? _countdownStartTime;
  Timer? _preciseCountdownTimer;
  int _countdownTimeRemaining = 3;
  bool _countdownFinished = false;

  // Pre-recording countdown variables
  bool _showingPreRecordingCountdown = false;
  int _preRecordingCountdown = 3;
  Timer? _preRecordingCountdownTimer;
  DateTime? _preRecordingCountdownStartTime;
  bool _preRecordingCountdownFinished = false;
  
  // Speaking prompt message
  bool _showingSpeakPrompt = false;
  Timer? _speakPromptTimer;

  double _confidenceScore = 70.0;
  String _emotion = 'Neutral';
  List<String> _fillerWords = [];
  double _sentimentScore = 0.0;
  String _sentiment = 'Neutral';

  List<Map<String, dynamic>> _allQuestionResults = [];

  // Smart card visibility variables
  double _analysisCardsOpacity = 0.1; // START VERY TRANSPARENT
  bool _isSpeaking = false;
  String _lastTranscriptSnapshot = '';
  int _lastFillerCount = 0;
  Timer? _speechInactivityTimer;
  Timer? _fillerVisibilityTimer;
  Timer? _speechMonitorTimer;
  Timer? _silenceWarningTimer; // For 5+ second silence detection

  final List<String> _fillerWordsList = [
    'um', 'uh', 'like', 'you know', 'so', 'actually', 'basically', 'well', 'okay', 'right'
  ];

  // Face detection warning messages
  final List<String> _faceWarningMessages = [
    "Hi, are you there? I don't see you on camera.",
    "Please make sure you're visible in the camera frame.",
    "I can't see your face. Please position yourself in front of the camera.",
    "Hi, get back there, I do not see you.",
    "Please ensure your face is visible for the interview to continue.",
  ];

  InterviewManager({
    required this.cameras,
    required this.questions,
    required this.company,
    required this.apiKey,
    required this.onStateUpdate,
    required this.onNavigateToCompletion,
  });

  // Public interface methods
  void startQuestionFlow() {
    // Ensure timer is not paused when starting a new question
    _timerPaused = false;
    
    _updateUIState({
      'showingQuestion': true,
      'showingCamera': false,
      'countdown': 5,
      'countdownPaused': false,
      'showingFinalCountdown': false,
      'ttsCompleted': false,
      'recordingCanStart': false,
      'countdownFinished': false,
      'showingPreRecordingCountdown': false,
      'preRecordingCountdown': 3,
      'preRecordingCountdownFinished': false,
      'showingSpeakPrompt': false,
      'analysisCardsOpacity': 0.05,
      'showingFaceWarning': false,
      'faceDetected': false,
    });
    _startCountdown();
  }

  void pauseCountdown() {
    _countdownPaused = !_countdownPaused;
    _updateUIState({'countdownPaused': _countdownPaused});
  }

  void startNow() {
    _countdownTimer?.cancel();
    _transitionToCamera();
  }

  // NEW METHOD: Force exit interview (when user confirms exit)
  void forceExitInterview() {
    print('🚪 === FORCE EXITING INTERVIEW ===');
    print('🛑 Stopping all recording, timers, and cleanup');
    
    // Stop all recording immediately
    if (_isRecording) {
      _forceStopRecording();
    }
    
    // Cancel all timers and cleanup
    _recordingTimer?.cancel();
    _analysisTimer?.cancel();
    _durationTimer?.cancel();
    _countdownTimer?.cancel();
    _cardVisibilityTimer?.cancel();
    _speechInactivityTimer?.cancel();
    _finalCountdownTimer?.cancel();
    _speechMonitorTimer?.cancel();
    _fillerVisibilityTimer?.cancel();
    _preciseCountdownTimer?.cancel();
    _preRecordingCountdownTimer?.cancel();
    _silenceWarningTimer?.cancel();
    _speakPromptTimer?.cancel();
    _faceDetectionTimer?.cancel();
    _noFaceWarningTimer?.cancel();
    _faceDetectionProcessingTimer?.cancel();
    
    // Stop speech recognition
    try {
      if (_speechToText.isListening) {
        _speechToText.stop();
      }
    } catch (e) {
      print('Error stopping speech recognition during exit: $e');
    }
    
    // Stop face detection
    _stopFaceDetection();
    
    // Update final state
    _updateUIState({
      'isRecording': false,
      'isAnalyzing': false,
      'speechStatus': 'notListening',
      'showingFinalCountdown': false,
      'showingPreRecordingCountdown': false,
      'showingSpeakPrompt': false,
      'showingFaceWarning': false,
    });
    
    print('🚪 Interview force exited successfully');
  }

  // NEW METHOD: Pause/resume interview timer
  void pauseInterviewTimer(bool pause) {
    _timerPaused = pause;
    if (pause) {
      print('⏸️ INTERVIEW TIMER PAUSED - Dialog showing');
    } else {
      print('▶️ INTERVIEW TIMER RESUMED - Dialog closed');
    }
  }

  void stopRecording() {
    print('🛑 MANUAL STOP REQUESTED');
    _forceStopRecording();
  }
  
  void _forceStopRecording() {
    print('🛑 === FORCE STOPPING RECORDING ===');
    print('🛑 Final duration: $_recordingDuration seconds');
    print('🛑 Reason: Manual force stop');
    
    _cleanupCountdown();
    _stopFaceDetection();
    
    try {
      if (_speechToText.isListening) {
        _speechToText.stop();
      }
    } catch (e) {
      print('Error stopping speech recognition: $e');
    }
    
    _recordingTimer?.cancel();
    _analysisTimer?.cancel();
    _durationTimer?.cancel();
    _speechInactivityTimer?.cancel();
    _finalCountdownTimer?.cancel();
    _speechMonitorTimer?.cancel();
    _silenceWarningTimer?.cancel();
    _speakPromptTimer?.cancel();
    
    _updateUIState({
      'isRecording': false,
      'isAnalyzing': false,
      'speechStatus': 'notListening',
      'analysisCardsOpacity': 0.1,
      'isSpeaking': false,
      'showingFinalCountdown': false,
      'finalCountdown': 3,
      'ttsCompleted': false,
      'recordingCanStart': false,
      'countdownFinished': false,
      'showingPreRecordingCountdown': false,
      'preRecordingCountdown': 3,
      'preRecordingCountdownFinished': false,
      'showingSpeakPrompt': false,
      'showingFaceWarning': false,
    });
    
    if (_currentTranscript.isEmpty) {
      _currentTranscript = '[NO RESPONSE - SILENT]';
      _updateUIState({'currentTranscript': _currentTranscript});
    }
    
    print('🛑 Recording force stopped. Final transcript: $_currentTranscript');
    _storeQuestionResults();
    
    Timer(const Duration(milliseconds: 500), () {
      _nextQuestion();
    });
  }

  void skipQuestion() {
    _currentTranscript = '[SKIPPED - NO RESPONSE PROVIDED]';
    _storeQuestionResults();
    _nextQuestion();
  }

  Widget getCameraPreview() {
    if (_cameraInitialized && _cameraController.value.isInitialized) {
      return CameraPreview(_cameraController);
    }
    return Container(color: Colors.black);
  }

  void dispose() {
    print('🧹 Disposing InterviewManager - cleaning up all resources');
    
    // Reset timer pause state
    _timerPaused = false;
    
    if (_cameraInitialized) {
      _cameraController.dispose();
    }
    _faceDetector.close();
    _recordingTimer?.cancel();
    _analysisTimer?.cancel();
    _durationTimer?.cancel();
    _countdownTimer?.cancel();
    _cardVisibilityTimer?.cancel();
    _speechInactivityTimer?.cancel();
    _finalCountdownTimer?.cancel();
    _speechMonitorTimer?.cancel();
    _fillerVisibilityTimer?.cancel();
    _preciseCountdownTimer?.cancel();
    _preRecordingCountdownTimer?.cancel();
    _silenceWarningTimer?.cancel();
    _speakPromptTimer?.cancel();
    _faceDetectionTimer?.cancel();
    _noFaceWarningTimer?.cancel();
    _faceDetectionProcessingTimer?.cancel();
    
    print('🧹 InterviewManager disposed successfully');
  }

  // Private implementation methods
  void _updateUIState(Map<String, dynamic> updates) {
    // Update internal state
    if (updates.containsKey('currentQuestionIndex')) _currentQuestionIndex = updates['currentQuestionIndex'];
    if (updates.containsKey('isRecording')) _isRecording = updates['isRecording'];
    if (updates.containsKey('isAnalyzing')) _isAnalyzing = updates['isAnalyzing'];
    if (updates.containsKey('currentTranscript')) _currentTranscript = updates['currentTranscript'];
    if (updates.containsKey('speechStatus')) _speechStatus = updates['speechStatus'];
    if (updates.containsKey('recordingDuration')) _recordingDuration = updates['recordingDuration'];
    if (updates.containsKey('showingQuestion')) _showingQuestion = updates['showingQuestion'];
    if (updates.containsKey('showingCamera')) _showingCamera = updates['showingCamera'];
    if (updates.containsKey('countdown')) _countdown = updates['countdown'];
    if (updates.containsKey('countdownPaused')) _countdownPaused = updates['countdownPaused'];
    if (updates.containsKey('cameraInitialized')) _cameraInitialized = updates['cameraInitialized'];
    if (updates.containsKey('showingFinalCountdown')) _showingFinalCountdown = updates['showingFinalCountdown'];
    if (updates.containsKey('finalCountdown')) _finalCountdown = updates['finalCountdown'];
    if (updates.containsKey('countdownTimeRemaining')) _countdownTimeRemaining = updates['countdownTimeRemaining'];
    if (updates.containsKey('countdownFinished')) _countdownFinished = updates['countdownFinished'];
    if (updates.containsKey('ttsCompleted')) _ttsCompleted = updates['ttsCompleted'];
    if (updates.containsKey('recordingCanStart')) _recordingCanStart = updates['recordingCanStart'];
    if (updates.containsKey('showingPreRecordingCountdown')) _showingPreRecordingCountdown = updates['showingPreRecordingCountdown'];
    if (updates.containsKey('preRecordingCountdown')) _preRecordingCountdown = updates['preRecordingCountdown'];
    if (updates.containsKey('preRecordingCountdownFinished')) _preRecordingCountdownFinished = updates['preRecordingCountdownFinished'];
    if (updates.containsKey('showingSpeakPrompt')) _showingSpeakPrompt = updates['showingSpeakPrompt'];
    if (updates.containsKey('confidenceScore')) _confidenceScore = updates['confidenceScore'];
    if (updates.containsKey('emotion')) _emotion = updates['emotion'];
    if (updates.containsKey('fillerWords')) _fillerWords = updates['fillerWords'];
    if (updates.containsKey('sentimentScore')) _sentimentScore = updates['sentimentScore'];
    if (updates.containsKey('sentiment')) _sentiment = updates['sentiment'];
    if (updates.containsKey('analysisCardsOpacity')) _analysisCardsOpacity = updates['analysisCardsOpacity'];
    if (updates.containsKey('isSpeaking')) _isSpeaking = updates['isSpeaking'];
    if (updates.containsKey('faceDetected')) _faceDetected = updates['faceDetected'];
    if (updates.containsKey('showingFaceWarning')) _showingFaceWarning = updates['showingFaceWarning'];

    // Create full state map for UI
    Map<String, dynamic> fullState = {
      'currentQuestionIndex': _currentQuestionIndex,
      'isRecording': _isRecording,
      'isAnalyzing': _isAnalyzing,
      'currentTranscript': _currentTranscript,
      'speechStatus': _speechStatus,
      'recordingDuration': _recordingDuration,
      'showingQuestion': _showingQuestion,
      'showingCamera': _showingCamera,
      'countdown': _countdown,
      'countdownPaused': _countdownPaused,
      'cameraInitialized': _cameraInitialized,
      'showingFinalCountdown': _showingFinalCountdown,
      'finalCountdown': _finalCountdown,
      'countdownTimeRemaining': _countdownTimeRemaining,
      'countdownFinished': _countdownFinished,
      'ttsCompleted': _ttsCompleted,
      'recordingCanStart': _recordingCanStart,
      'showingPreRecordingCountdown': _showingPreRecordingCountdown,
      'preRecordingCountdown': _preRecordingCountdown,
      'preRecordingCountdownFinished': _preRecordingCountdownFinished,
      'showingSpeakPrompt': _showingSpeakPrompt,
      'confidenceScore': _confidenceScore,
      'emotion': _emotion,
      'fillerWords': _fillerWords,
      'sentimentScore': _sentimentScore,
      'sentiment': _sentiment,
      'analysisCardsOpacity': _analysisCardsOpacity,
      'isSpeaking': _isSpeaking,
      'faceDetected': _faceDetected,
      'showingFaceWarning': _showingFaceWarning,
    };

    onStateUpdate(fullState);
  }

  // Face Detection Methods
  Future<void> _initializeFaceDetection() async {
    try {
      final options = FaceDetectorOptions(
        enableContours: false,
        enableClassification: false,
        enableLandmarks: false,
        enableTracking: false,
        minFaceSize: 0.1,
        performanceMode: FaceDetectorMode.fast,
      );
      
      _faceDetector = FaceDetector(options: options);
      _faceDetectionInitialized = true;
      _lastFaceDetectedTime = DateTime.now();
      print('👤 Face detection initialized successfully');
    } catch (e) {
      print('❌ Face detection initialization failed: $e');
      _faceDetectionInitialized = false;
    }
  }

  void _startFaceDetection() {
    if (!_faceDetectionInitialized) return;
    
    print('👤 Starting face detection monitoring');
    _lastFaceDetectedTime = DateTime.now();
    _noFaceWarningCount = 0;
    
    // Start face detection timer - checks every 2 seconds
    _faceDetectionTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
      if (!_showingCamera) {
        return; // Skip if not on camera screen
      }
      
      _checkFaceDetection();
    });
    
    // Start processing camera frames for face detection
    _faceDetectionProcessingTimer = Timer.periodic(const Duration(milliseconds: 500), (timer) {
      if (!_showingCamera || _isProcessingImage) {
        return;
      }
      
      _processCameraFrameForFaceDetection();
    });
  }

  void _stopFaceDetection() {
    print('👤 Stopping face detection');
    _faceDetectionTimer?.cancel();
    _noFaceWarningTimer?.cancel();
    _faceDetectionProcessingTimer?.cancel();
    
    _updateUIState({
      'showingFaceWarning': false,
      'faceDetected': false,
    });
  }

  Future<void> _processCameraFrameForFaceDetection() async {
    if (!_faceDetectionInitialized || 
        !_cameraInitialized || 
        !_cameraController.value.isInitialized ||
        _isProcessingImage) {
      return;
    }

    _isProcessingImage = true;
    
    try {
      final image = await _cameraController.takePicture();
      final inputImage = InputImage.fromFilePath(image.path);
      
      final faces = await _faceDetector.processImage(inputImage);
      
      if (faces.isNotEmpty) {
        // Face detected!
        _lastFaceDetectedTime = DateTime.now();
        if (!_faceDetected) {
          print('👤 ✅ Face detected!');
          _updateUIState({'faceDetected': true});
          
          // Hide face warning if it was showing
          if (_showingFaceWarning) {
            _updateUIState({'showingFaceWarning': false});
            _noFaceWarningTimer?.cancel();
          }
        }
      } else {
        // No face detected
        if (_faceDetected) {
          print('👤 ❌ Face lost');
          _updateUIState({'faceDetected': false});
        }
      }
    } catch (e) {
      print('❌ Face detection processing error: $e');
    } finally {
      _isProcessingImage = false;
    }
  }

  void _checkFaceDetection() {
    if (_lastFaceDetectedTime == null || _faceWarningTtsPlaying) return;
    
    final timeSinceLastFace = DateTime.now().difference(_lastFaceDetectedTime!);
    
    if (timeSinceLastFace.inSeconds >= 6) {
      print('👤 ⚠️ No face detected for ${timeSinceLastFace.inSeconds} seconds');
      _triggerFaceWarning();
    }
  }

  void _triggerFaceWarning() {
    if (_showingFaceWarning || _faceWarningTtsPlaying) {
      return; // Already showing warning or TTS is playing
    }
    
    print('👤 🚨 Triggering face detection warning');
    
    _updateUIState({'showingFaceWarning': true});
    _faceWarningTtsPlaying = true;
    
    // Select a random warning message
    final randomMessage = _faceWarningMessages[_noFaceWarningCount % _faceWarningMessages.length];
    _noFaceWarningCount++;
    
    // Play TTS warning
    _playFaceWarningTTS(randomMessage);
    
    // Auto-hide warning after 4 seconds
    _noFaceWarningTimer = Timer(const Duration(seconds: 4), () {
      if (_showingFaceWarning) {
        _updateUIState({'showingFaceWarning': false});
      }
    });
  }

  Future<void> _playFaceWarningTTS(String message) async {
    try {
      print('👤 🔊 Playing face warning TTS: $message');
      
      // Configure TTS for warning (slightly different settings)
      await _flutterTts.setSpeechRate(0.5);
      await _flutterTts.setPitch(1.0);
      await _flutterTts.setVolume(0.9);
      
      await _flutterTts.speak(message);
      
      // Reset TTS settings back to normal after warning
      Timer(const Duration(seconds: 3), () async {
        _faceWarningTtsPlaying = false;
        await _flutterTts.setSpeechRate(0.4);
        await _flutterTts.setPitch(0.9);
        await _flutterTts.setVolume(0.8);
      });
      
    } catch (e) {
      print('❌ Face warning TTS error: $e');
      _faceWarningTtsPlaying = false;
    }
  }

  void _startCountdown() {
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      // PAUSE LOGIC: Skip countdown if paused (dialog showing) or manually paused
      if (_timerPaused) {
        print('⏸️ Question countdown paused - not progressing (dialog showing)');
        return;
      }
      
      if (_countdownPaused) return;
      
      if (_countdown > 0) {
        _countdown--;
        _updateUIState({'countdown': _countdown});
      } else {
        timer.cancel();
        _transitionToCamera();
      }
    });
  }

  void _transitionToCamera() async {
    _updateUIState({
      'showingQuestion': false,
      'showingCamera': true,
      'analysisCardsOpacity': 0.05,
    });
    
    if (!_cameraInitialized) {
      await _initializeServices();
    }
    
    // Start face detection when camera becomes active
    await _initializeFaceDetection();
    _startFaceDetection();
    
    await Future.delayed(const Duration(milliseconds: 500));
    _startQuestion();
  }

  Future<void> _initializeServices() async {
    var cameraStatus = await Permission.camera.request();
    var micStatus = await Permission.microphone.request();
    
    print('Camera permission: $cameraStatus');
    print('Microphone permission: $micStatus');
    
    CameraDescription? frontCamera;
    for (CameraDescription camera in cameras) {
      if (camera.lensDirection == CameraLensDirection.front) {
        frontCamera = camera;
        break;
      }
    }
    
    frontCamera ??= cameras.first;
    
    _cameraController = CameraController(
      frontCamera,
      ResolutionPreset.high,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );
    
    try {
      await _cameraController.initialize();
      
      await _cameraController.setFlashMode(FlashMode.off);
      await _cameraController.setFocusMode(FocusMode.auto);
      await _cameraController.setExposureMode(ExposureMode.auto);
      
      print('Selfie camera initialized successfully with high quality');
      _cameraInitialized = true;
      _updateUIState({'cameraInitialized': true});
    } catch (e) {
      print('Camera initialization error: $e');
      _cameraController = CameraController(
        frontCamera,
        ResolutionPreset.medium,
        enableAudio: false,
      );
      await _cameraController.initialize();
      _cameraInitialized = true;
      _updateUIState({'cameraInitialized': true});
      print('Fallback: Camera initialized with medium quality');
    }
    
    await _configureTTS();
    
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
        } else {
          print('✅ Filtered silence/network error: ${val.errorMsg}');
        }
        
        print('🛡️ Speech error handled - recording continues normally');
      },
      onStatus: (val) {
        print('Speech recognition status: $val');
        _updateUIState({'speechStatus': val});
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

  Future<void> _configureTTS() async {
    _flutterTts = FlutterTts();
    
    await _flutterTts.setLanguage('en-US');
    await _flutterTts.setSpeechRate(0.4);
    await _flutterTts.setPitch(0.9);
    await _flutterTts.setVolume(0.8);
    await _flutterTts.awaitSpeakCompletion(true);
    
    _flutterTts.setCompletionHandler(() {
      if (!_faceWarningTtsPlaying) { // Only trigger countdown if not a face warning
        print('🔊 TTS COMPLETION HANDLER CALLED - STARTING COUNTDOWN IMMEDIATELY');
        _updateUIState({
          'ttsCompleted': true,
          'recordingCanStart': true,
        });
        
        print('🎯 IMMEDIATELY STARTING PRE-RECORDING COUNTDOWN');
        _startPreRecordingCountdown();
      }
    });
    
    _flutterTts.setErrorHandler((msg) {
      if (!_faceWarningTtsPlaying) { // Only trigger countdown if not a face warning
        print('🔊 TTS ERROR: $msg - STARTING COUNTDOWN ANYWAY');
        _updateUIState({
          'ttsCompleted': true,
          'recordingCanStart': true,
        });
        
        _startPreRecordingCountdown();
      }
    });
    
    try {
      var voices = await _flutterTts.getVoices;
      if (voices != null && voices.isNotEmpty) {
        print('Available voices: ${voices.map((v) => v['name']).toList()}');
        
        var preferredVoices = [
          'neural', 'enhanced', 'premium', 'natural', 'high-quality',
          'google', 'wavenet', 'journey', 'studio', 'nova'
        ];
        
        Map<String, dynamic>? bestVoice;
        
        for (String preferred in preferredVoices) {
          try {
            bestVoice = voices.cast<Map<String, dynamic>>().firstWhere(
              (voice) => voice['name'].toString().toLowerCase().contains(preferred),
              orElse: () => <String, dynamic>{},
            );
            if (bestVoice != null && bestVoice.isNotEmpty) break;
          } catch (e) {
            print('Error finding $preferred voice: $e');
          }
        }
        
        if (bestVoice == null || bestVoice.isEmpty) {
          try {
            bestVoice = voices.cast<Map<String, dynamic>>().firstWhere(
              (voice) => voice['name'].toString().toLowerCase().contains('female') ||
                        voice['name'].toString().toLowerCase().contains('woman') ||
                        voice['name'].toString().toLowerCase().contains('samantha') ||
                        voice['name'].toString().toLowerCase().contains('siri'),
              orElse: () => voices.first as Map<String, dynamic>,
            );
          } catch (e) {
            print('Error finding female voice: $e');
            bestVoice = voices.first as Map<String, dynamic>;
          }
        }
        
        if (bestVoice != null && bestVoice.isNotEmpty) {
          try {
            Map<String, String> voiceMap = {
              'name': bestVoice['name']?.toString() ?? '',
              'locale': bestVoice['locale']?.toString() ?? 'en-US',
            };
            await _flutterTts.setVoice(voiceMap);
            print('Using voice: ${bestVoice['name']} (${bestVoice['locale']})');
          } catch (e) {
            print('Error setting voice: $e');
          }
        }
      }
    } catch (e) {
      print('Error configuring voice: $e');
    }
    
    print('TTS configured successfully');
  }

  void _startQuestion() async {
    final question = questions[_currentQuestionIndex];
    
    print('🎤 === STARTING QUESTION FLOW ===');
    print('🔊 TTS starting to speak question...');
    
    _updateUIState({
      'ttsCompleted': false,
      'recordingCanStart': false,
      'isRecording': false,
      'currentTranscript': '',
      'showingFinalCountdown': false,
      'finalCountdown': 3,
      'countdownFinished': false,
      'showingPreRecordingCountdown': false,
      'preRecordingCountdown': 3,
      'preRecordingCountdownFinished': false,
      'analysisCardsOpacity': 0.05,
      'isSpeaking': false,
    });
    
    try {
      await _flutterTts.speak(question);
      print('🔊 TTS speak() method completed');
    } catch (e) {
      print('🔊 TTS speak() error: $e');
      _updateUIState({
        'ttsCompleted': true,
        'recordingCanStart': true,
      });
      _startPreRecordingCountdown();
    }
  }

  void _startPreRecordingCountdown() {
    if (_showingPreRecordingCountdown || _preRecordingCountdownFinished) {
      print('🎯 PRE-RECORDING COUNTDOWN ALREADY ACTIVE - SKIPPING');
      return;
    }
    
    print('🎯 === PRE-RECORDING COUNTDOWN STARTED IMMEDIATELY ===');
    
    _preRecordingCountdownStartTime = DateTime.now();
    _preRecordingCountdownFinished = false;
    
    _updateUIState({
      'showingPreRecordingCountdown': true,
      'preRecordingCountdown': 3,
      'analysisCardsOpacity': 0.05,
    });
    
    _preRecordingCountdownTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      if (_preRecordingCountdownFinished) {
        print('🎯 PRE-RECORDING COUNTDOWN CANCELLED - cleanup');
        timer.cancel();
        return;
      }
      
      if (_preRecordingCountdownStartTime == null) {
        timer.cancel();
        return;
      }
      
      final elapsed = DateTime.now().difference(_preRecordingCountdownStartTime!);
      final elapsedSeconds = elapsed.inMilliseconds / 1000.0;
      
      final remainingTime = 3.0 - elapsedSeconds;
      final displayCountdown = remainingTime > 0 ? remainingTime.ceil() : 0;
      
      if (displayCountdown != _preRecordingCountdown && displayCountdown >= 0) {
        _updateUIState({'preRecordingCountdown': displayCountdown});
        print('🎯 COUNTDOWN: $displayCountdown seconds (elapsed: ${elapsedSeconds.toStringAsFixed(2)}s)');
      }
      
      if (elapsedSeconds >= 3.0 && !_preRecordingCountdownFinished) {
        print('🎯 COUNTDOWN FINISHED - STARTING RECORDING NOW');
        _preRecordingCountdownFinished = true;
        timer.cancel();
        
        _updateUIState({
          'showingPreRecordingCountdown': false,
          'preRecordingCountdown': 0,
          'recordingCanStart': true,
        });
        
        _startRecording();
      }
    });
  }

  void _startRecording() {
    if (!_speechToText.isAvailable || !_speechAvailable) {
      print('Speech recognition not available');
      return;
    }
    
    print('🎤 === STARTING RECORDING ===');
    print('📊 NOW ACTIVATING SMART ANALYSIS CARD VISIBILITY');
    
    _updateUIState({
      'isRecording': true,
      'isAnalyzing': true,
      'currentTranscript': '',
      'speechStatus': 'listening',
      'recordingDuration': 0,
      'analysisCardsOpacity': 0.1,
      'isSpeaking': false,
      'showingFinalCountdown': false,
      'finalCountdown': 3,
      'countdownFinished': false,
      'showingPreRecordingCountdown': false,
      'preRecordingCountdown': 3,
      'preRecordingCountdownFinished': false,
      'showingSpeakPrompt': true,
    });
    
    _speakPromptTimer = Timer(const Duration(seconds: 3), () {
      _updateUIState({'showingSpeakPrompt': false});
    });
    
    _fillerWords.clear();
    _lastTranscriptSnapshot = '';
    _lastFillerCount = 0;
    
    _speechMonitorTimer?.cancel();
    _fillerVisibilityTimer?.cancel();
    _finalCountdownTimer?.cancel();
    _silenceWarningTimer?.cancel();
    _cleanupCountdown();
    
    // UPDATED: Duration timer now respects pause state
    _durationTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!_isRecording) {
        print('🛑 Duration timer stopped - recording ended at $_recordingDuration seconds');
        timer.cancel();
        return;
      }
      
      // PAUSE LOGIC: Skip incrementing if timer is paused
      if (_timerPaused) {
        print('⏸️ Duration timer paused - not incrementing (dialog showing)');
        return;
      }
      
      _recordingDuration++;
      _updateUIState({'recordingDuration': _recordingDuration});
      
      print('🎤 === RECORDING PROGRESS: $_recordingDuration seconds ===');
      
      if (_recordingDuration == 5) {
        print('✅ 5 seconds recorded - interview progressing normally');
      }
      if (_recordingDuration == 10) {
        print('✅ 10 seconds recorded - 1/3 complete');
      }
      if (_recordingDuration == 15) {
        print('✅ 15 seconds recorded - halfway point');
      }
      if (_recordingDuration == 20) {
        print('⚠️ 20 seconds recorded - 10 seconds remaining');
      }
      if (_recordingDuration == 25) {
        print('⚠️ 25 seconds recorded - final countdown in 2 seconds');
      }
      
      if (_recordingDuration == 27) {
        print('⏰ === 27 SECONDS REACHED - TRIGGERING FINAL COUNTDOWN ===');
        print('⏰ Current state - showingFinalCountdown: $_showingFinalCountdown, countdownFinished: $_countdownFinished');
        
        if (!_showingFinalCountdown && !_countdownFinished) {
          print('⏰ ✅ STARTING FINAL COUNTDOWN NOW...');
          _startFinalCountdown();
        } else {
          print('⏰ ❌ Final countdown already active or finished - skipping');
          print('⏰ showingFinalCountdown: $_showingFinalCountdown');
          print('⏰ countdownFinished: $_countdownFinished');
        }
      }
      
      if (_recordingDuration >= 30) {
        print('🛑 === 30 SECONDS REACHED - AUTO-STOPPING (BACKUP SAFETY) ===');
        timer.cancel();
        _stopRecording();
        return;
      }
    });
    
    print('🎤 Starting speech recognition...');
    
    try {
      _speechToText.listen(
        onResult: (result) {
          if (result.recognizedWords.isNotEmpty || result.hasConfidenceRating) {
            print('✅ Valid speech result: ${result.recognizedWords} (confidence: ${result.confidence})');
            
            bool transcriptChanged = result.recognizedWords != _lastTranscriptSnapshot;
            
            if (transcriptChanged && result.recognizedWords.isNotEmpty) {
              if (!_isSpeaking) {
                print('🗣️ PERSON STARTED SPEAKING - Making cards transparent');
                _updateUIState({'isSpeaking': true});
                _updateCardVisibility();
                
                if (_showingSpeakPrompt) {
                  _speakPromptTimer?.cancel();
                  _updateUIState({'showingSpeakPrompt': false});
                  print('💬 User started speaking - hiding speak prompt');
                }
              } else {
                _updateCardVisibility();
              }
            }
            
            _updateUIState({'currentTranscript': result.recognizedWords});
            _detectFillers(result.recognizedWords);
            _analyzeSentiment(result.recognizedWords);
            
            _handleFillerWordDetection();
            _lastTranscriptSnapshot = result.recognizedWords;
            
            if (result.finalResult && _currentTranscript.split(' ').length > 10) {
              _checkForCompletedResponse();
            }
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
    }
    
    _startVideoAnalysis();
  }

  void _startFinalCountdown() {
    if (_showingFinalCountdown || _countdownFinished) {
      print('⏰ FINAL COUNTDOWN ALREADY ACTIVE - SKIPPING');
      return;
    }
    
    _speechInactivityTimer?.cancel();
    _silenceWarningTimer?.cancel();
    _fillerVisibilityTimer?.cancel();
    
    print('🚨 === FINAL COUNTDOWN STARTED ===');
    print('🚨 Recording duration: $_recordingDuration seconds');
    print('🚨 Making final countdown HIGHLY VISIBLE');
    
    _countdownStartTime = DateTime.now();
    _countdownFinished = false;
    _showingFinalCountdown = true;
    _finalCountdown = 3;
    _countdownTimeRemaining = 3;
    
    _updateUIState({
      'showingFinalCountdown': true,
      'finalCountdown': 3,
      'countdownTimeRemaining': 3,
      'analysisCardsOpacity': 0.3,
    });
    
    _preciseCountdownTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      if (_countdownFinished) {
        print('⏰ FINAL COUNTDOWN COMPLETED - stopping timer');
        timer.cancel();
        return;
      }
      
      if (!_isRecording && _countdownStartTime != null) {
        final elapsed = DateTime.now().difference(_countdownStartTime!);
        if (elapsed.inSeconds < 5) {
          print('⏰ Recording stopped but continuing final countdown');
        } else {
          print('⏰ Recording stopped too long ago - cancelling countdown');
          timer.cancel();
          return;
        }
      }
      
      if (_countdownStartTime == null) {
        timer.cancel();
        return;
      }
      
      // UPDATED: Final countdown also respects pause state
      if (_timerPaused) {
        print('⏸️ Final countdown paused - not progressing (dialog showing)');
        return;
      }
      
      final elapsed = DateTime.now().difference(_countdownStartTime!);
      final elapsedSeconds = elapsed.inMilliseconds / 1000.0;
      
      final remainingTime = 3.0 - elapsedSeconds;
      final displayCountdown = remainingTime > 0 ? remainingTime.ceil() : 0;
      
      if (displayCountdown != _finalCountdown && displayCountdown >= 0) {
        _finalCountdown = displayCountdown;
        _countdownTimeRemaining = displayCountdown;
        _updateUIState({
          'finalCountdown': displayCountdown,
          'countdownTimeRemaining': displayCountdown,
        });
        print('⏰ FINAL COUNTDOWN: $displayCountdown seconds (elapsed: ${elapsedSeconds.toStringAsFixed(2)}s)');
      }
      
      if (elapsedSeconds >= 3.0 && !_countdownFinished) {
        print('⏰ FINAL COUNTDOWN COMPLETED - EXACTLY 3.0 seconds elapsed');
        _countdownFinished = true;
        _showingFinalCountdown = false;
        timer.cancel();
        
        _updateUIState({
          'showingFinalCountdown': false,
          'finalCountdown': 0,
          'countdownFinished': true,
        });
        
        if (_isRecording) {
          print('🛑 Auto-stopping recording due to final countdown completion');
          _stopRecording();
        }
      }
    });
  }

  void _cleanupCountdown() {
    _preRecordingCountdownTimer?.cancel();
    _preRecordingCountdownTimer = null;
    _preRecordingCountdownStartTime = null;
    _preRecordingCountdownFinished = false;
    
    bool finalCountdownActive = _showingFinalCountdown || (_isRecording && _recordingDuration >= 27);
    
    if (!finalCountdownActive && !_isRecording) {
      print('🧹 Cleaning up final countdown timers (safe to do so)');
      _preciseCountdownTimer?.cancel();
      _preciseCountdownTimer = null;
      _countdownStartTime = null;
      _countdownFinished = false;
      _showingFinalCountdown = false;
      _finalCountdown = 3;
      _countdownTimeRemaining = 3;
    } else {
      print('🛡️ PROTECTING final countdown - NOT cleaning up (active: $finalCountdownActive, recording: $_isRecording, duration: $_recordingDuration)');
    }
    
    _updateUIState({
      'showingPreRecordingCountdown': false,
      'preRecordingCountdown': 3,
      'preRecordingCountdownFinished': false,
      'showingFinalCountdown': finalCountdownActive ? _showingFinalCountdown : false,
      'finalCountdown': finalCountdownActive ? _finalCountdown : 3,
      'countdownTimeRemaining': finalCountdownActive ? _countdownTimeRemaining : 3,
      'countdownFinished': finalCountdownActive ? _countdownFinished : false,
    });
  }

  void _updateCardVisibility() {
    if (_showingFinalCountdown) {
      print('📊 Card visibility skipped - final countdown active');
      return;
    }
    
    _speechInactivityTimer?.cancel();
    _silenceWarningTimer?.cancel();
    
    if (!_isRecording) {
      print('📊 Card visibility skipped - not recording yet');
      return;
    }
    
    if (_isSpeaking) {
      _updateUIState({'analysisCardsOpacity': 0.05});
      
      _speechInactivityTimer = Timer(const Duration(milliseconds: 800), () {
        _updateUIState({
          'isSpeaking': false,
          'analysisCardsOpacity': 0.15,
        });
        
        _startSilenceDetection();
      });
    } else {
      _startSilenceDetection();
    }
  }
  
  void _startSilenceDetection() {
    if (_showingFinalCountdown) {
      print('📊 Silence detection skipped - final countdown active');
      return;
    }
    
    _silenceWarningTimer?.cancel();
    
    if (!_isRecording) {
      return;
    }
    
    _silenceWarningTimer = Timer(const Duration(seconds: 5), () {
      if (!_isSpeaking && _isRecording && !_showingFinalCountdown) {
        print('💬 5+ SECONDS OF SILENCE - SHOWING ANALYSIS CARDS');
        _updateUIState({'analysisCardsOpacity': 0.85});
        
        Timer(const Duration(seconds: 3), () {
          if (!_isSpeaking && _isRecording && !_showingFinalCountdown) {
            _updateUIState({'analysisCardsOpacity': 0.15});
          }
        });
      }
    });
  }

  void _handleFillerWordDetection() {
    if (_showingFinalCountdown) {
      print('📊 Filler detection skipped - final countdown active');
      return;
    }
    
    if (!_isRecording) {
      return;
    }
    
    if (_fillerWords.length > _lastFillerCount) {
      _fillerVisibilityTimer?.cancel();
      _silenceWarningTimer?.cancel();
      
      print('🚨 FILLER WORD DETECTED! Showing analysis cards prominently');
      _updateUIState({'analysisCardsOpacity': 1.0});
      
      _fillerVisibilityTimer = Timer(const Duration(milliseconds: 2500), () {
        if (!_showingFinalCountdown) {
          double targetOpacity = _isSpeaking ? 0.05 : 0.15;
          _updateUIState({'analysisCardsOpacity': targetOpacity});
          
          if (!_isSpeaking && _isRecording) {
            _startSilenceDetection();
          }
        }
      });
    }
    _lastFillerCount = _fillerWords.length;
  }

  void _startSpeechMonitoring() {
    _speechMonitorTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (!_isRecording) {
        print('🔍 Speech monitoring stopped - recording ended');
        timer.cancel();
        return;
      }
      
      print('🔍 Monitoring speech recognition - Status: $_speechStatus, IsListening: ${_speechToText.isListening}');
      print('🔍 Recording duration: $_recordingDuration seconds');
      
      if (_isRecording && !_speechToText.isListening && _speechStatus != 'listening') {
        print('🔄 Speech recognition stopped unexpectedly - RESTARTING...');
        print('🔄 BUT NOT STOPPING RECORDING - just restarting speech recognition');
        _restartSpeechRecognition();
      }
    });
  }

  void _restartSpeechRecognition() {
    if (!_isRecording) return;
    
    print('🔄 Restarting speech recognition...');
    
    try {
      _speechToText.listen(
        onResult: (result) {
          if (result.recognizedWords.isNotEmpty || result.hasConfidenceRating) {
            print('✅ Restarted speech result: ${result.recognizedWords}');
            
            bool transcriptChanged = result.recognizedWords != _lastTranscriptSnapshot;
            
            if (transcriptChanged && result.recognizedWords.isNotEmpty) {
              if (!_isSpeaking) {
                print('🗣️ PERSON STARTED SPEAKING (RESTARTED) - Making cards transparent');
                _updateUIState({'isSpeaking': true});
                _updateCardVisibility();
                
                if (_showingSpeakPrompt) {
                  _speakPromptTimer?.cancel();
                  _updateUIState({'showingSpeakPrompt': false});
                  print('💬 User started speaking (restarted) - hiding speak prompt');
                }
              } else {
                _updateCardVisibility();
              }
            }
            
            String newTranscript = _currentTranscript.isEmpty 
                ? result.recognizedWords 
                : _currentTranscript.contains(result.recognizedWords) 
                  ? _currentTranscript 
                  : '$_currentTranscript ${result.recognizedWords}';
            
            _updateUIState({'currentTranscript': newTranscript});
            _detectFillers(newTranscript);
            _analyzeSentiment(newTranscript);
            
            _handleFillerWordDetection();
            _lastTranscriptSnapshot = result.recognizedWords;
          }
        },
        onSoundLevelChange: (level) {
          if (level > 0.2) {
            print('🔊 Restarted sound: $level');
          }
        },
        listenFor: Duration(seconds: 35 - _recordingDuration),
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
    }
  }

  void _checkForCompletedResponse() {
    print('📝 Response completion check - DISABLED to prevent early termination');
  }

  void _stopRecording() {
    if (_recordingDuration < 25 && _isRecording) {
      print('🛡️ BLOCKING PREMATURE STOP: Only ${_recordingDuration}s recorded, minimum 25s required');
      print('🛡️ Recording will continue until 27s + final countdown');
      return;
    }
    
    print('🛑 === STOPPING RECORDING ===');
    print('🛑 Final duration: $_recordingDuration seconds');
    print('🛑 Reason: ${_recordingDuration >= 30 ? "30s limit reached" : _countdownFinished ? "Final countdown completed" : "Manual stop"}');
    
    _cleanupCountdown();
    _stopFaceDetection();
    
    try {
      if (_speechToText.isListening) {
        _speechToText.stop();
      }
    } catch (e) {
      print('Error stopping speech recognition: $e');
    }
    
    _recordingTimer?.cancel();
    _analysisTimer?.cancel();
    _durationTimer?.cancel();
    _speechInactivityTimer?.cancel();
    _finalCountdownTimer?.cancel();
    _speechMonitorTimer?.cancel();
    _silenceWarningTimer?.cancel();
    _speakPromptTimer?.cancel();
    
    _updateUIState({
      'isRecording': false,
      'isAnalyzing': false,
      'speechStatus': 'notListening',
      'analysisCardsOpacity': 0.1,
      'isSpeaking': false,
      'showingFinalCountdown': false,
      'finalCountdown': 3,
      'ttsCompleted': false,
      'recordingCanStart': false,
      'countdownFinished': false,
      'showingPreRecordingCountdown': false,
      'preRecordingCountdown': 3,
      'preRecordingCountdownFinished': false,
      'showingSpeakPrompt': false,
      'showingFaceWarning': false,
    });
    
    if (_currentTranscript.isEmpty) {
      _currentTranscript = '[NO RESPONSE - SILENT]';
      _updateUIState({'currentTranscript': _currentTranscript});
    }
    
    print('🛑 Recording stopped. Final transcript: $_currentTranscript');
    _storeQuestionResults();
    
    Timer(const Duration(milliseconds: 500), () {
      _nextQuestion();
    });
  }

  void _storeQuestionResults() {
    Map<String, dynamic> questionResult = {
      'questionNumber': _currentQuestionIndex + 1,
      'question': questions[_currentQuestionIndex],
      'transcript': _currentTranscript,
      'emotion': _emotion,
      'confidence': _confidenceScore,
      'fillerWords': List<String>.from(_fillerWords),
      'sentimentScore': _sentimentScore,
      'sentiment': _sentiment,
      'recordingDuration': _recordingDuration,
      'wordCount': _currentTranscript.split(' ').length,
      'faceDetectionWarnings': _noFaceWarningCount,
    };
    
    _allQuestionResults.add(questionResult);
    print('Stored results for question ${_currentQuestionIndex + 1}');
  }

  void _startVideoAnalysis() {
    _analysisTimer = Timer.periodic(const Duration(milliseconds: 500), (timer) {
      if (!_isAnalyzing) {
        timer.cancel();
        return;
      }
      
      _analyzePosture();
    });
  }

  void _analyzePosture() {
    final random = Random();
    
    double newConfidenceScore = 60 + random.nextDouble() * 30;
    String newEmotion;
    
    if (newConfidenceScore > 85) {
      newEmotion = 'Confident';
    } else if (newConfidenceScore < 60) {
      newEmotion = 'Nervous';
    } else {
      newEmotion = 'Neutral';
    }
    
    _updateUIState({
      'confidenceScore': newConfidenceScore,
      'emotion': newEmotion,
    });
  }

  void _detectFillers(String transcript) {
    final words = transcript.toLowerCase().split(' ');
    final detectedFillers = <String>[];
    
    for (final word in words) {
      final cleanWord = word.replaceAll(RegExp(r'[^\w]'), '');
      if (_fillerWordsList.contains(cleanWord)) {
        detectedFillers.add(cleanWord);
      }
    }
    
    _fillerWords = detectedFillers;
    _updateUIState({'fillerWords': _fillerWords});
  }

  void _analyzeSentiment(String transcript) {
    final positiveWords = ['good', 'great', 'excellent', 'amazing', 'love', 'excited', 'passionate'];
    final negativeWords = ['bad', 'terrible', 'hate', 'difficult', 'problem', 'issue', 'struggle'];
    
    final words = transcript.toLowerCase().split(' ');
    int positiveCount = 0;
    int negativeCount = 0;
    
    for (final word in words) {
      if (positiveWords.any((pw) => word.contains(pw))) positiveCount++;
      if (negativeWords.any((nw) => word.contains(nw))) negativeCount++;
    }
    
    String newSentiment;
    double newSentimentScore;
    
    if (positiveCount > negativeCount) {
      newSentiment = 'Positive';
      newSentimentScore = 0.3 + (positiveCount - negativeCount) * 0.1;
    } else if (negativeCount > positiveCount) {
      newSentiment = 'Negative';
      newSentimentScore = -0.3 - (negativeCount - positiveCount) * 0.1;
    } else {
      newSentiment = 'Neutral';
      newSentimentScore = 0.0;
    }
    
    _updateUIState({
      'sentiment': newSentiment,
      'sentimentScore': newSentimentScore,
    });
  }

  void _nextQuestion() {
    if (_currentQuestionIndex < questions.length - 1) {
      _currentQuestionIndex++;
      _currentTranscript = '';
      _fillerWords.clear();
      _recordingDuration = 0;
      _confidenceScore = 70.0;
      _emotion = 'Neutral';
      _sentimentScore = 0.0;
      _sentiment = 'Neutral';
      _analysisCardsOpacity = 0.1;
      _isSpeaking = false;
      _lastTranscriptSnapshot = '';
      _lastFillerCount = 0;
      _showingFinalCountdown = false;
      _ttsCompleted = false;
      _recordingCanStart = false;
      _countdownFinished = false;
      _showingPreRecordingCountdown = false;
      _preRecordingCountdown = 3;
      _preRecordingCountdownFinished = false;
      _showingSpeakPrompt = false;
      _noFaceWarningCount = 0; // Reset face warning count for new question
      _timerPaused = false; // Reset timer pause state for new question
      
      _updateUIState({
        'currentQuestionIndex': _currentQuestionIndex,
        'currentTranscript': _currentTranscript,
        'fillerWords': _fillerWords,
        'recordingDuration': _recordingDuration,
        'confidenceScore': _confidenceScore,
        'emotion': _emotion,
        'sentimentScore': _sentimentScore,
        'sentiment': _sentiment,
        'analysisCardsOpacity': 0.1,
        'isSpeaking': _isSpeaking,
        'showingFinalCountdown': _showingFinalCountdown,
        'ttsCompleted': _ttsCompleted,
        'recordingCanStart': _recordingCanStart,
        'countdownFinished': _countdownFinished,
        'showingPreRecordingCountdown': _showingPreRecordingCountdown,
        'preRecordingCountdown': _preRecordingCountdown,
        'preRecordingCountdownFinished': _preRecordingCountdownFinished,
        'showingSpeakPrompt': _showingSpeakPrompt,
        'showingFaceWarning': false,
        'faceDetected': false,
      });
      
      Timer(const Duration(seconds: 1), () {
        startQuestionFlow();
      });
    } else {
      _timerPaused = false; // Reset timer pause state at interview completion
      Timer(const Duration(seconds: 1), () {
        onNavigateToCompletion(_allQuestionResults);
      });
    }
  }
}