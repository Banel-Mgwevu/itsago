import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'dart:async';
import 'dart:math';
import 'audio_speech_manager.dart';
import 'camera_face_manager.dart';

class InterviewManager {
  // Constructor dependencies
  final List<CameraDescription> cameras;
  final List<String> questions;
  final String company;
  final String apiKey;
  final Function(Map<String, dynamic>) onStateUpdate;
  final Function(List<Map<String, dynamic>>) onNavigateToCompletion;

  // Sub-managers
  late AudioSpeechManager _audioSpeechManager;
  late CameraFaceManager _cameraFaceManager;

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
  int _recordingDuration = 0;

  bool _showingQuestion = true;
  bool _showingCamera = false;
  int _countdown = 5;
  bool _countdownPaused = false;
  bool _cameraInitialized = false;

  // Enhanced countdown variables - FIXED LOGIC
  bool _showingFinalCountdown = false;
  int _finalCountdown = 3;
  Timer? _finalCountdownTimer;
  bool _ttsCompleted = false;
  bool _recordingCanStart = false;

  // Pre-recording countdown variables - FIXED LOGIC
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

  // Enhanced confidence analysis variables
  double _handGestureScore = 70.0;
  double _toneQualityScore = 70.0;
  double _bodyLanguageScore = 65.0;
  double _speechFlowScore = 60.0;
  bool _handGesturesDetected = false;
  String _currentToneAnalysis = 'Neutral';
  String _bodyPosture = 'Neutral';
  int _gestureCount = 0;
  Timer? _gestureResetTimer;

  final List<Map<String, dynamic>> _allQuestionResults = [];

  // Smart card visibility variables
  double _analysisCardsOpacity = 0.1;
  bool _isSpeaking = false;
  String _lastTranscriptSnapshot = '';
  int _lastFillerCount = 0;
  Timer? _speechInactivityTimer;
  Timer? _fillerVisibilityTimer;
  Timer? _speechMonitorTimer;
  Timer? _silenceWarningTimer;

  final List<String> _fillerWordsList = [
    'um', 'uh', 'like', 'you know', 'so', 'actually', 'basically', 'well', 'okay', 'right'
  ];

  // Timer pause functionality
  bool _timerPaused = false;

  InterviewManager({
    required this.cameras,
    required this.questions,
    required this.company,
    required this.apiKey,
    required this.onStateUpdate,
    required this.onNavigateToCompletion,
  }) {
    // Initialize sub-managers
    _audioSpeechManager = AudioSpeechManager(
      onTTSComplete: _onTTSComplete,
      onSpeechResult: _onSpeechResult,
      onSpeechError: _onSpeechError,
      onSpeechStatusChange: _onSpeechStatusChange,
    );

    _cameraFaceManager = CameraFaceManager(
      cameras: cameras,
      onCameraInitialized: _onCameraInitialized,
      onFaceDetectionChange: _onFaceDetectionChange,
      onFaceWarning: _onFaceWarning,
    );
  }

  // Public interface methods
  void startQuestionFlow() {
    _timerPaused = false;
    
    // RESET ALL COUNTDOWN STATES
    _resetAllCountdownStates();
    
    _updateUIState({
      'showingQuestion': true,
      'showingCamera': false,
      'countdown': 5,
      'countdownPaused': false,
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

  void forceExitInterview() {
    print('🚪 === FORCE EXITING INTERVIEW ===');
    
    if (_isRecording) {
      _forceStopRecording();
    }
    
    // FIXED: Stop all camera detection when force exiting
    _cancelAllTimers();
    _audioSpeechManager.stopAll();
    _cameraFaceManager.stopFaceDetection(); // Stop face detection
    _cameraFaceManager.stopAll(); // Stop all camera services
    
    _resetAllCountdownStates();
    
    print('📷 CAMERA DETECTION FORCE STOPPED');
    
    _updateUIState({
      'isRecording': false,
      'isAnalyzing': false,
      'speechStatus': 'notListening',
      'showingFaceWarning': false,
    });
    
    print('🚪 Interview force exited successfully');
  }

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

  void skipQuestion() {
    _currentTranscript = '[SKIPPED - NO RESPONSE PROVIDED]';
    _storeQuestionResults();
    _nextQuestion();
  }

  Widget getCameraPreview() {
    return _cameraFaceManager.getCameraPreview();
  }

  void dispose() {
    print('🧹 Disposing InterviewManager - cleaning up all resources');
    _timerPaused = false;
    _cancelAllTimers();
    _audioSpeechManager.dispose();
    _cameraFaceManager.dispose();
    print('🧹 InterviewManager disposed successfully');
  }

  // FIXED: Reset all countdown states properly
  void _resetAllCountdownStates() {
    print('🔄 RESETTING ALL COUNTDOWN STATES');
    
    // Cancel all countdown timers
    _finalCountdownTimer?.cancel();
    _preRecordingCountdownTimer?.cancel();
    
    // Reset all countdown flags and values
    _showingFinalCountdown = false;
    _finalCountdown = 3;
    _ttsCompleted = false;
    _recordingCanStart = false;
    _showingPreRecordingCountdown = false;
    _preRecordingCountdown = 3;
    _preRecordingCountdownFinished = false;
    _preRecordingCountdownStartTime = null;
    _showingSpeakPrompt = false;
    
    print('✅ ALL COUNTDOWN STATES RESET');
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
    
    // Enhanced confidence analysis state updates
    if (updates.containsKey('handGesturesDetected')) _handGesturesDetected = updates['handGesturesDetected'];
    if (updates.containsKey('currentToneAnalysis')) _currentToneAnalysis = updates['currentToneAnalysis'];
    if (updates.containsKey('bodyPosture')) _bodyPosture = updates['bodyPosture'];

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
      // Enhanced confidence analysis states
      'handGesturesDetected': _handGesturesDetected,
      'currentToneAnalysis': _currentToneAnalysis,
      'bodyPosture': _bodyPosture,
      // Include face detection state from sub-manager
      'faceDetected': _cameraFaceManager.faceDetected,
      'showingFaceWarning': _cameraFaceManager.showingFaceWarning,
    };

    onStateUpdate(fullState);
  }

  // Callback handlers from sub-managers
  void _onTTSComplete() {
    if (!_cameraFaceManager.faceWarningTtsPlaying) {
      print('🔊 TTS COMPLETION - STARTING PRE-RECORDING COUNTDOWN');
      _updateUIState({
        'ttsCompleted': true,
        'recordingCanStart': true,
      });
      
      // FIXED: Only start pre-recording countdown after TTS completes
      _startPreRecordingCountdown();
    }
  }

  void _onSpeechResult(String transcript, bool isFinal) {
    bool transcriptChanged = transcript != _lastTranscriptSnapshot;
    
    if (transcriptChanged && transcript.isNotEmpty) {
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
    
    _updateUIState({'currentTranscript': transcript});
    _detectFillers(transcript);
    _analyzeSentiment(transcript);
    
    _handleFillerWordDetection();
    _lastTranscriptSnapshot = transcript;
    
    if (isFinal && _currentTranscript.split(' ').length > 10) {
      _checkForCompletedResponse();
    }
  }

  void _onSpeechError(String error) {
    print('Speech recognition error: $error');
    // Handle speech errors gracefully
  }

  void _onSpeechStatusChange(String status) {
    _updateUIState({'speechStatus': status});
  }

  void _onCameraInitialized() {
    _cameraInitialized = true;
    _updateUIState({'cameraInitialized': true});
  }

  void _onFaceDetectionChange(bool faceDetected) {
    _updateUIState({'faceDetected': faceDetected});
  }

  void _onFaceWarning(bool showingWarning) {
    _updateUIState({'showingFaceWarning': showingWarning});
  }

  // Timer management
  void _cancelAllTimers() {
    _recordingTimer?.cancel();
    _analysisTimer?.cancel();
    _durationTimer?.cancel();
    _countdownTimer?.cancel();
    _cardVisibilityTimer?.cancel();
    _speechInactivityTimer?.cancel();
    _finalCountdownTimer?.cancel();
    _speechMonitorTimer?.cancel();
    _fillerVisibilityTimer?.cancel();
    _preRecordingCountdownTimer?.cancel();
    _silenceWarningTimer?.cancel();
    _speakPromptTimer?.cancel();
    _gestureResetTimer?.cancel();
  }

  void _startCountdown() {
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
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
      await _cameraFaceManager.initializeCamera();
      await _audioSpeechManager.initializeServices();
    }
    
    _cameraFaceManager.startFaceDetection();
    
    await Future.delayed(const Duration(milliseconds: 500));
    _startQuestion();
  }

  void _startQuestion() async {
    final question = questions[_currentQuestionIndex];
    
    print('🎤 === STARTING QUESTION FLOW ===');
    print('🔊 TTS starting to speak question...');
    
    // FIXED: Reset all countdown states before starting question
    _resetAllCountdownStates();
    
    _updateUIState({
      'isRecording': false,
      'currentTranscript': '',
      'analysisCardsOpacity': 0.05,
      'isSpeaking': false,
    });
    
    // Check if this is the first question
    if (_currentQuestionIndex == 0) {
      // First question: Introduction + Question
      final introductionAndQuestion = "Hi, my name is Lizzy. I am here to interview you. Here is your first question: $question";
      await _audioSpeechManager.speakQuestion(introductionAndQuestion);
    } else {
      // Subsequent questions: Just the question
      await _audioSpeechManager.speakQuestion(question);
    }
  }

  // FIXED: Pre-recording countdown logic
  void _startPreRecordingCountdown() {
    // FIXED: Ensure we're not already running any countdown
    if (_showingPreRecordingCountdown || _preRecordingCountdownFinished || _showingFinalCountdown) {
      print('🎯 PRE-RECORDING COUNTDOWN BLOCKED - Another countdown active');
      return;
    }
    
    print('🎯 === PRE-RECORDING COUNTDOWN STARTED ===');
    
    _preRecordingCountdownStartTime = DateTime.now();
    _preRecordingCountdownFinished = false;
    
    _updateUIState({
      'showingPreRecordingCountdown': true,
      'preRecordingCountdown': 3,
      'analysisCardsOpacity': 0.05,
    });
    
    _preRecordingCountdownTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      if (_preRecordingCountdownFinished || _isRecording) {
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
        print('🎯 PRE-RECORDING COUNTDOWN: $displayCountdown seconds');
      }
      
      if (elapsedSeconds >= 3.0 && !_preRecordingCountdownFinished) {
        print('🎯 PRE-RECORDING COUNTDOWN FINISHED - STARTING RECORDING');
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
    print('🎤 === STARTING RECORDING ===');
    
    // FIXED: Ensure pre-recording countdown is completely hidden
    _updateUIState({
      'isRecording': true,
      'isAnalyzing': true,
      'currentTranscript': '',
      'speechStatus': 'listening',
      'recordingDuration': 0,
      'analysisCardsOpacity': 0.1,
      'isSpeaking': false,
      'showingPreRecordingCountdown': false,
      'preRecordingCountdown': 0,
      'preRecordingCountdownFinished': true,
      'showingSpeakPrompt': true,
    });
    
    _speakPromptTimer = Timer(const Duration(seconds: 3), () {
      _updateUIState({'showingSpeakPrompt': false});
    });
    
    // FIXED: Don't clear filler words here - they should accumulate throughout the entire question
    // _fillerWords.clear(); // REMOVED - fillers should only reset at end of question
    
    _lastTranscriptSnapshot = '';
    _lastFillerCount = 0;
    
    _startRecordingTimers();
    _audioSpeechManager.startListening();
    _startVideoAnalysis();
  }

  void _startRecordingTimers() {
    _durationTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!_isRecording) {
        timer.cancel();
        return;
      }
      
      if (_timerPaused) {
        print('⏸️ Duration timer paused - not incrementing (dialog showing)');
        return;
      }
      
      _recordingDuration++;
      _updateUIState({'recordingDuration': _recordingDuration});
      
      print('🎤 === RECORDING PROGRESS: $_recordingDuration seconds ===');
      
      // FIXED: Only start final countdown at exactly 27 seconds
      if (_recordingDuration == 27 && !_showingFinalCountdown) {
        print('⏰ === 27 SECONDS REACHED - STARTING FINAL COUNTDOWN ===');
        _startFinalCountdown();
      }
      
      if (_recordingDuration >= 30) {
        print('🛑 === 30 SECONDS REACHED - AUTO-STOPPING ===');
        timer.cancel();
        _stopRecording();
        return;
      }
    });
  }

  // FIXED: Final countdown logic
  void _startFinalCountdown() {
    // FIXED: Prevent multiple final countdowns
    if (_showingFinalCountdown) {
      print('⏰ FINAL COUNTDOWN ALREADY ACTIVE - SKIPPING');
      return;
    }
    
    // FIXED: Only allow final countdown during recording at 27+ seconds
    if (!_isRecording || _recordingDuration < 27) {
      print('⏰ FINAL COUNTDOWN BLOCKED - Not recording or too early');
      return;
    }
    
    _speechInactivityTimer?.cancel();
    _silenceWarningTimer?.cancel();
    _fillerVisibilityTimer?.cancel();
    
    print('🚨 === FINAL COUNTDOWN STARTED ===');
    
    _updateUIState({
      'showingFinalCountdown': true,
      'finalCountdown': 3,
      'analysisCardsOpacity': 0.3,
    });
    
    _finalCountdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_timerPaused) {
        print('⏸️ Final countdown paused - not progressing (dialog showing)');
        return;
      }
      
      if (_finalCountdown > 0) {
        _finalCountdown--;
        _updateUIState({'finalCountdown': _finalCountdown});
        print('⏰ FINAL COUNTDOWN: $_finalCountdown seconds remaining');
      } else {
        print('⏰ FINAL COUNTDOWN COMPLETED - STOPPING RECORDING');
        timer.cancel();
        
        _updateUIState({
          'showingFinalCountdown': false,
          'finalCountdown': 0,
        });
        
        if (_isRecording) {
          _stopRecording();
        }
      }
    });
  }

  void _forceStopRecording() {
    print('🛑 === FORCE STOPPING RECORDING ===');
    
    // FIXED: Clean up all countdowns properly
    _cleanupAllCountdowns();
    
    _cameraFaceManager.stopFaceDetection();
    _audioSpeechManager.stopListening();
    _cancelAllTimers();
    
    _updateUIState({
      'isRecording': false,
      'isAnalyzing': false,
      'speechStatus': 'notListening',
      'analysisCardsOpacity': 0.1,
      'isSpeaking': false,
      'showingSpeakPrompt': false,
      'showingFaceWarning': false,
    });
    
    if (_currentTranscript.isEmpty) {
      _currentTranscript = '[NO RESPONSE - SILENT]';
      _updateUIState({'currentTranscript': _currentTranscript});
    }
    
    _storeQuestionResults();
    
    Timer(const Duration(milliseconds: 500), () {
      _nextQuestion();
    });
  }

  void _stopRecording() {
    if (_recordingDuration < 25 && _isRecording) {
      print('🛡️ BLOCKING PREMATURE STOP: Only ${_recordingDuration}s recorded');
      return;
    }
    
    print('🛑 === STOPPING RECORDING ===');
    
    // FIXED: Clean up all countdowns properly
    _cleanupAllCountdowns();
    
    _cameraFaceManager.stopFaceDetection();
    _audioSpeechManager.stopListening();
    _cancelAllTimers();
    
    _updateUIState({
      'isRecording': false,
      'isAnalyzing': false,
      'speechStatus': 'notListening',
      'analysisCardsOpacity': 0.1,
      'isSpeaking': false,
      'showingSpeakPrompt': false,
      'showingFaceWarning': false,
    });
    
    if (_currentTranscript.isEmpty) {
      _currentTranscript = '[NO RESPONSE - SILENT]';
      _updateUIState({'currentTranscript': _currentTranscript});
    }
    
    _storeQuestionResults();
    
    Timer(const Duration(milliseconds: 500), () {
      _nextQuestion();
    });
  }

  // FIXED: Comprehensive countdown cleanup
  void _cleanupAllCountdowns() {
    print('🧹 CLEANING UP ALL COUNTDOWNS');
    
    // Cancel all countdown timers
    _preRecordingCountdownTimer?.cancel();
    _finalCountdownTimer?.cancel();
    
    // Reset all countdown states
    _preRecordingCountdownTimer = null;
    _preRecordingCountdownStartTime = null;
    _preRecordingCountdownFinished = false;
    _finalCountdownTimer = null;
    
    // Update UI to hide all countdowns
    _updateUIState({
      'showingPreRecordingCountdown': false,
      'preRecordingCountdown': 3,
      'preRecordingCountdownFinished': false,
      'showingFinalCountdown': false,
      'finalCountdown': 3,
    });
    
    print('✅ ALL COUNTDOWNS CLEANED UP');
  }

  // Analysis methods
  void _updateCardVisibility() {
    if (_showingFinalCountdown) return;
    
    _speechInactivityTimer?.cancel();
    _silenceWarningTimer?.cancel();
    
    if (!_isRecording) return;
    
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
    if (_showingFinalCountdown) return;
    
    _silenceWarningTimer?.cancel();
    
    if (!_isRecording) return;
    
    _silenceWarningTimer = Timer(const Duration(seconds: 5), () {
      if (!_isSpeaking && _isRecording && !_showingFinalCountdown) {
        print('💬 5+ SECONDS OF SILENCE - SHOWING ANALYSIS CARDS AND SPEAK PROMPT');
        _updateUIState({
          'analysisCardsOpacity': 0.85,
          'showingSpeakPrompt': true, // FIXED: Show speak prompt during silence
        });
        
        Timer(const Duration(seconds: 3), () {
          if (!_isSpeaking && _isRecording && !_showingFinalCountdown) {
            _updateUIState({'analysisCardsOpacity': 0.15});
            // Keep speak prompt visible until they start speaking
          }
        });
      }
    });
  }

  void _handleFillerWordDetection() {
    if (_showingFinalCountdown || !_isRecording) return;
    
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

  void _checkForCompletedResponse() {
    print('📝 Response completion check - DISABLED to prevent early termination');
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

  // ENHANCED CONFIDENCE ANALYSIS METHODS
  void _analyzePosture() {
    if (!_isAnalyzing || !_isRecording) return;
    
    // Analyze different components of confidence
    _analyzeHandGestures();
    _analyzeToneQuality();
    _analyzeBodyLanguage();
    _analyzeSpeechFlow();
    
    // Calculate composite confidence score
    _calculateOverallConfidence();
  }

  void _analyzeHandGestures() {
    final random = Random();
    
    // Simulate hand gesture detection when person is speaking
    if (_isSpeaking && _currentTranscript.isNotEmpty) {
      // Higher chance of detecting gestures during active speech
      double gestureDetectionChance = random.nextDouble();
      
      if (gestureDetectionChance > 0.3) { // 70% chance when speaking
        _handGesturesDetected = true;
        _gestureCount++;
        
        // Reset gesture detection after a brief period
        _gestureResetTimer?.cancel();
        _gestureResetTimer = Timer(const Duration(seconds: 2), () {
          _handGesturesDetected = false;
        });
        
        // Hand gestures boost confidence significantly
        _handGestureScore = min(100.0, 75.0 + (_gestureCount * 2.5));
        
        print('👋 HAND GESTURES DETECTED - Confidence boost! Score: $_handGestureScore');
      }
    } else {
      // Gradually decrease hand gesture score when not gesturing
      _handGestureScore = max(50.0, _handGestureScore - 1.0);
    }
  }

  void _analyzeToneQuality() {
    if (!_isSpeaking || _currentTranscript.isEmpty) {
      _toneQualityScore = max(60.0, _toneQualityScore - 0.5);
      _currentToneAnalysis = 'Neutral';
      return;
    }
    
    final random = Random();
    final words = _currentTranscript.split(' ');
    final recentWords = words.length > 10 ? words.sublist(words.length - 10) : words;
    
    // Analyze speech patterns for tone quality
    double toneScore = 70.0; // Base tone score
    
    // Check for speech fluency indicators
    bool hasFillers = _fillerWords.isNotEmpty;
    bool isLongResponse = recentWords.length > 5;
    bool hasVariedVocabulary = Set.from(recentWords).length > (recentWords.length * 0.7);
    
    // Boost for fluent speech
    if (isLongResponse && !hasFillers) {
      toneScore += 15.0;
      _currentToneAnalysis = 'Confident';
    } else if (hasFillers) {
      toneScore -= 10.0;
      _currentToneAnalysis = 'Hesitant';
    }
    
    // Boost for varied vocabulary
    if (hasVariedVocabulary) {
      toneScore += 10.0;
    }
    
    // Simulate voice clarity and pace analysis
    double clarityFactor = 0.8 + (random.nextDouble() * 0.4); // 0.8-1.2
    toneScore *= clarityFactor;
    
    _toneQualityScore = max(40.0, min(100.0, toneScore));
    
    print('🎵 TONE ANALYSIS: $_currentToneAnalysis - Score: $_toneQualityScore');
  }

  void _analyzeBodyLanguage() {
    final random = Random();
    
    // Simulate body language analysis based on face detection and posture
    double bodyScore = 65.0; // Base body language score
    
    // Face detection indicates good camera positioning and engagement
    if (_cameraFaceManager.faceDetected) {
      bodyScore += 20.0;
      _bodyPosture = 'Engaged';
      
      // Simulate posture analysis
      double postureQuality = random.nextDouble();
      if (postureQuality > 0.7) {
        bodyScore += 10.0;
        _bodyPosture = 'Confident';
      } else if (postureQuality < 0.3) {
        bodyScore -= 5.0;
        _bodyPosture = 'Slouched';
      }
    } else {
      // No face detected or poor positioning
      bodyScore -= 15.0;
      _bodyPosture = 'Disengaged';
    }
    
    // Speaking while maintaining good posture is a strong confidence indicator
    if (_isSpeaking && _cameraFaceManager.faceDetected) {
      bodyScore += 10.0;
    }
    
    _bodyLanguageScore = max(30.0, min(100.0, bodyScore));
    
    print('🧍 BODY LANGUAGE: $_bodyPosture - Score: $_bodyLanguageScore');
  }

  void _analyzeSpeechFlow() {
    if (!_isSpeaking || _currentTranscript.isEmpty) {
      _speechFlowScore = max(50.0, _speechFlowScore - 1.0);
      return;
    }
    
    final words = _currentTranscript.split(' ');
    double flowScore = 60.0; // Base flow score
    
    // Analyze speech flow factors
    int wordCount = words.length;
    int fillerCount = _fillerWords.length;
    double fillerRatio = wordCount > 0 ? fillerCount / wordCount : 0;
    
    // Penalize excessive filler words
    if (fillerRatio > 0.15) { // More than 15% fillers
      flowScore -= 20.0;
    } else if (fillerRatio < 0.05) { // Less than 5% fillers - very smooth
      flowScore += 15.0;
    }
    
    // Reward longer, coherent responses
    if (wordCount > 20) {
      flowScore += 10.0;
    } else if (wordCount > 50) {
      flowScore += 20.0;
    }
    
    // Simulate pace analysis
    if (_recordingDuration > 0) {
      double wordsPerSecond = wordCount / _recordingDuration;
      if (wordsPerSecond >= 1.5 && wordsPerSecond <= 3.0) { // Good pace
        flowScore += 10.0;
      } else if (wordsPerSecond < 0.8 || wordsPerSecond > 4.0) { // Too slow/fast
        flowScore -= 10.0;
      }
    }
    
    _speechFlowScore = max(30.0, min(100.0, flowScore));
    
    print('💬 SPEECH FLOW: $fillerRatio filler ratio - Score: $_speechFlowScore');
  }

  void _calculateOverallConfidence() {
    // Weight different factors for overall confidence
    const double handGestureWeight = 0.25;    // 25% - Hand gestures are strong indicators
    const double toneWeight = 0.30;           // 30% - Tone quality is crucial
    const double bodyLanguageWeight = 0.25;   // 25% - Body language is important
    const double speechFlowWeight = 0.20;     // 20% - Speech flow matters
    
    double newConfidenceScore = (
      (_handGestureScore * handGestureWeight) +
      (_toneQualityScore * toneWeight) +
      (_bodyLanguageScore * bodyLanguageWeight) +
      (_speechFlowScore * speechFlowWeight)
    );
    
    // Apply hand gesture boost when actively gesturing
    if (_handGesturesDetected && _isSpeaking) {
      newConfidenceScore = min(95.0, newConfidenceScore + 10.0);
      print('🚀 HAND GESTURE BOOST APPLIED! +10 confidence');
    }
    
    // Smooth the confidence changes to avoid jarring jumps
    double smoothedScore = (_confidenceScore * 0.7) + (newConfidenceScore * 0.3);
    
    // Determine emotion based on comprehensive confidence score
    String newEmotion;
    if (smoothedScore >= 85) {
      newEmotion = 'Very Confident';
    } else if (smoothedScore >= 75) {
      newEmotion = 'Confident';
    } else if (smoothedScore >= 65) {
      newEmotion = 'Composed';
    } else if (smoothedScore >= 50) {
      newEmotion = 'Neutral';
    } else if (smoothedScore >= 40) {
      newEmotion = 'Nervous';
    } else {
      newEmotion = 'Very Nervous';
    }
    
    _updateUIState({
      'confidenceScore': smoothedScore,
      'emotion': newEmotion,
      'handGesturesDetected': _handGesturesDetected,
      'currentToneAnalysis': _currentToneAnalysis,
      'bodyPosture': _bodyPosture,
    });
    
    print('🎯 OVERALL CONFIDENCE: $smoothedScore% ($newEmotion)');
    print('📊 Breakdown - Gestures: $_handGestureScore, Tone: $_toneQualityScore, Body: $_bodyLanguageScore, Flow: $_speechFlowScore');
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
      'faceDetectionWarnings': _cameraFaceManager.noFaceWarningCount,
      // Enhanced confidence analysis results
      'handGestureScore': _handGestureScore,
      'toneQualityScore': _toneQualityScore,
      'bodyLanguageScore': _bodyLanguageScore,
      'speechFlowScore': _speechFlowScore,
      'gestureCount': _gestureCount,
      'toneAnalysis': _currentToneAnalysis,
      'bodyPosture': _bodyPosture,
    };
    
    _allQuestionResults.add(questionResult);
    print('Stored enhanced results for question ${_currentQuestionIndex + 1}');
  }

  void _nextQuestion() {
    if (_currentQuestionIndex < questions.length - 1) {
      _currentQuestionIndex++;
      _resetQuestionState();
      
      Timer(const Duration(seconds: 1), () {
        startQuestionFlow();
      });
    } else {
      // FIXED: Ensure complete cleanup before navigating to completion
      print('🏁 INTERVIEW COMPLETED - FINAL CLEANUP');
      _timerPaused = false;
      
      // Force stop all services
      _audioSpeechManager.stopAll();
      _cameraFaceManager.stopAll();
      _cancelAllTimers();
      
      Timer(const Duration(seconds: 1), () {
        onNavigateToCompletion(_allQuestionResults);
      });
    }
  }

  // Enhanced confidence analysis reset
  void _resetConfidenceAnalysis() {
    _handGestureScore = 70.0;
    _toneQualityScore = 70.0;
    _bodyLanguageScore = 65.0;
    _speechFlowScore = 60.0;
    _handGesturesDetected = false;
    _currentToneAnalysis = 'Neutral';
    _bodyPosture = 'Neutral';
    _gestureCount = 0;
    _gestureResetTimer?.cancel();
    
    print('🔄 Confidence analysis reset for new question');
  }

  void _resetQuestionState() {
    print('🔄 RESETTING QUESTION STATE');
    
    _currentTranscript = '';
    
    // FIXED: This is the correct place to clear filler words - at the end of each question
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
    _timerPaused = false;
    
    // Reset confidence analysis
    _resetConfidenceAnalysis();
    
    // FIXED: Reset all countdown states for new question
    _resetAllCountdownStates();
    
    _cameraFaceManager.resetForNewQuestion();
    
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
      'showingFaceWarning': false,
      'faceDetected': false,
      'handGesturesDetected': false,
      'currentToneAnalysis': 'Neutral',
      'bodyPosture': 'Neutral',
    });
    
    print('✅ QUESTION STATE RESET COMPLETE');
  }
}