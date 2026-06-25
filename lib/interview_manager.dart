import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:http/http.dart' as http;
import 'dart:async';
import 'dart:convert';
import 'audio_speech_manager.dart';
import 'camera_face_manager.dart';
import 'app_config.dart';
import 'cloud_function_service.dart';

class InterviewManager {

  final List<CameraDescription>              cameras;
  final List<String>                         questions;
  final String                               company;
  final String                               apiKey;
  final String                               interviewStyle; // friendly|neutral|pressure
  final Function(Map<String, dynamic>)       onStateUpdate;
  final Function(List<Map<String, dynamic>>) onNavigateToCompletion;
  final Function(String)?                    onEarlyStopAttempt;

  bool _disposed = false;
  late final AudioSpeechManager _audio;
  late final CameraFaceManager  _camera;

  // Core state
  int    _qIdx          = 0;
  bool   _isRecording   = false;
  bool   _isAnalyzing   = false;
  String _transcript    = '';
  String _speechStatus  = 'notListening';
  bool   _showQuestion  = true;
  bool   _showCamera    = false;
  int    _countdown     = 5;
  bool   _countdownPaused = false;
  bool   _cameraReady   = false;
  bool   _timerPaused   = false;
  int    _recDuration   = 0;
  bool   _ttsCompleted  = false;
  bool   _canRecord     = false;
  bool   _showPreCountdown  = false;
  int    _preCountdown      = 3;
  bool   _preCountdownDone  = false;
  bool   _showFinalCountdown = false;
  int    _finalCountdown     = 3;
  bool   _showSpeakPrompt   = false;
  String _coachingTip       = '';
  int    _coachingTipIndex  = 0;
  int    _silenceSeconds    = 0;

  // Analysis state
  double _confidence    = 70.0;
  String _emotion       = 'Neutral';
  List<String> _fillers = [];
  double _sentiment     = 0.0;
  String _sentimentText = 'Neutral';
  double _cardOpacity   = 0.1;
  bool   _isSpeaking    = false;
  String _lastSnapshot  = '';

  // Feature 2 - mid-answer coaching
  String _midCoachingMsg   = '';
  int    _lowConfStreak    = 0;
  bool   _coachMsgShown    = false;
  String _currentAdaptedQ   = '';

  // Feature 3 - adaptive difficulty
  late List<String> _adaptedQuestions;

  // Feature 4 - post-question review
  bool   _showReview   = false;
  Map<String, dynamic> _reviewData = {};

  final List<Map<String, dynamic>> _results = [];

  static const _coachingTips = [
    'Sit up straight and face the camera directly',
    'Take a slow deep breath - you have got this',
    'Make eye contact with the camera lens, not the screen',
    'Relax your shoulders and speak at a steady pace',
    'Smile naturally - confidence starts with your expression',
  ];

  static const _fillerList = [
    'um','uh','like','you know','so','actually',
    'basically','well','okay','right',
  ];

  Timer? _masterTimer;
  Timer? _preTimer;
  Timer? _analysisTimer;
  Timer? _fillerTimer;
  Timer? _countdownTimer;

  InterviewManager({
    required this.cameras,
    required this.questions,
    required this.company,
    required this.apiKey,
    required this.onStateUpdate,
    required this.onNavigateToCompletion,
    this.interviewStyle = 'friendly',
    this.onEarlyStopAttempt,
  }) {
    _adaptedQuestions = List.from(questions);
    _audio = AudioSpeechManager(
      onTTSComplete:       _onTTSComplete,
      onSpeechResult:      _onSpeechResult,
      onSpeechError:       (_) {},
      onSpeechStatusChange:(s) => _push({'speechStatus': s}),
    );
    _camera = CameraFaceManager(
      cameras:               cameras,
      onCameraInitialized:   () => _push({'cameraInitialized': true}),
      onFaceDetectionChange: (f) => _push({'faceDetected': f}),
      onFaceWarning:         (w) => _push({'showingFaceWarning': w}),
    );
  }

  // - Public API -

  void startQuestionFlow() {
    _timerPaused = false;
    _resetCountdowns();
    _push({
      'showingQuestion':      true,
      'showingCamera':        false,
      'countdown':            5,
      'countdownPaused':      false,
      'analysisCardsOpacity': 0.05,
      'showingFaceWarning':   false,
      'faceDetected':         false,
      'showQuestionReview':   false,
      'currentAdaptedQuestion': _currentAdaptedQ,
    });
    _startQuestionCountdown();
  }

  void pauseCountdown() {
    _countdownPaused = !_countdownPaused;
    _push({'countdownPaused': _countdownPaused});
  }

  void startNow() {
    _countdownTimer?.cancel();
    _transitionToCamera();
  }

  void stopRecording() {
    if (!_isRecording) return;
    if (_recDuration < 3) {
      onEarlyStopAttempt?.call(
        'Keep going - try to answer for at least a few seconds.');
      return;
    }
    _doStopRecording();
  }

  void fillRemainingWithZero() {
    // Fill all unanswered questions with zero scores
    for (int i = _results.length; i < questions.length; i++) {
      _results.add({
        'questionNumber':    i + 1,
        'question':          questions[i],
        'transcript':        '[NO RESPONSE - EXITED]',
        'emotion':           'Neutral',
        'confidence':        0.0,
        'fillerWords':       <String>[],
        'sentimentScore':    0.0,
        'sentiment':         'Neutral',
        'recordingDuration': 0,
        'wordCount':         0,
        'wordsPerSecond':    0.0,
        'fillerRatio':       0.0,
        'faceDetectionWarnings': 0,
        'eyeContactScore':       0.0,
        'eyeContactFrames':      0,
        'totalDetectionFrames':  0,
      });
    }
    _audio.stopAll();
    _camera.stopAll();
    _cancelAll();
    onNavigateToCompletion(_results);
  }

  void skipQuestion() {
    _transcript = '[SKIPPED - NO RESPONSE]';
    _confidence = 3.0; // Hard cap skip at 3%
    _saveResult();
  }

  void pauseInterviewTimer(bool pause) => _timerPaused = pause;

  void forceExitInterview() {
    _isRecording = false;
    _cancelAll();
    _audio.stopAll();
    _camera.stopFaceDetection();
    _camera.stopAll();
    _resetCountdowns();
    _push({
      'isRecording':        false,
      'isAnalyzing':        false,
      'speechStatus':       'notListening',
      'showingFaceWarning': false,
    });
  }

  Widget getCameraPreview() => _camera.getCameraPreview();

  void dispose() {
    _disposed = true;
    _cancelAll();
    _audio.dispose();
    _camera.dispose();
  }

  // - Question countdown -

  void _startQuestionCountdown() {
    _countdown = 5;
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_timerPaused || _countdownPaused) return;
      _countdown--;
      _push({'countdown': _countdown});
      if (_countdown <= 0) { t.cancel(); _transitionToCamera(); }
    });
  }

  Future<void> _transitionToCamera() async {
    _push({'showingQuestion': false, 'showingCamera': true,
           'analysisCardsOpacity': 0.05});
    if (!_cameraReady) {
      await _camera.initializeCamera();
      await _audio.initializeServices();
    }
    _camera.startFaceDetection();
    await Future.delayed(const Duration(milliseconds: 500));
    _startQuestion();
  }

  Future<void> _startQuestion() async {
    _resetCountdowns();
    _coachMsgShown = false;
    _lowConfStreak = 0;
    _push({'isRecording': false, 'currentTranscript': '',
           'analysisCardsOpacity': 0.05, 'isSpeaking': false,
           'midCoachingMsg': '', 'lizzysReaction': ''});
    _currentAdaptedQ = _adaptedQuestions[_qIdx];
    _push({'currentAdaptedQuestion': _currentAdaptedQ});
    final q = _adaptedQuestions[_qIdx];

    // Feature 5 - style-specific intro
    String text;
    if (_qIdx == 0) {
      text = interviewStyle == 'pressure'
        ? 'Good morning. I am your interviewer today. '
          'I will be evaluating your responses critically. '
          'First question: $q'
        : interviewStyle == 'neutral'
        ? 'Hello. I am here to conduct your interview. '
          'First question: $q'
        : 'Hi, my name is Lizzy. I am here to interview you. '
          'Here is your first question: $q';
    } else {
      text = q;
    }
    await _audio.speakQuestion(text);
  }

  // - Pre-recording countdown -

  void _onTTSComplete() {
    if (_camera.faceWarningTtsPlaying) return;
    // If recording is active, restart mic immediately after TTS
    if (_isRecording) {
      _audio.startListening();
      return;
    }
    _push({'ttsCompleted': true, 'recordingCanStart': true});
    _startPreCountdown();
  }
  void _startPreCountdown() {
    if (_showPreCountdown || _preCountdownDone || _showFinalCountdown) return;
    _preCountdownDone = false;
    _preCountdown     = 3;
    _push({'showingPreRecordingCountdown': true,
           'preRecordingCountdown': 3,
           'analysisCardsOpacity': 0.05});
    _preTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_preCountdownDone || _isRecording) { t.cancel(); return; }
      _preCountdown--;
      final tip = _camera.faceDetected
        ? _coachingTips[_coachingTipIndex % _coachingTips.length]
        : 'Move closer - make sure your face is visible';
      _coachingTipIndex++;
      _coachingTip = tip;
      if (_preCountdown <= 0) {
        _preCountdownDone = true;
        t.cancel();
        _push({'showingPreRecordingCountdown': false,
               'preRecordingCountdown': 0,
               'recordingCanStart': true, 'coachingTip': ''});
        _startRecording();
      } else {
        _push({'preRecordingCountdown': _preCountdown, 'coachingTip': tip});
      }
    });
  }

  // - Recording -

  void _startRecording() {
    _recDuration     = 0;
    _silenceSeconds  = 0;
    _lastSnapshot    = '';
    _isSpeaking      = false;
    _showSpeakPrompt = true;
    _midCoachingMsg  = '';
    _lowConfStreak   = 0;
    _coachMsgShown   = false;
    _push({
      'isRecording':               true,
      'isAnalyzing':               true,
      'currentTranscript':         '',
      'speechStatus':              'listening',
      'recordingDuration':         0,
      'analysisCardsOpacity':      0.1,
      'isSpeaking':                false,
      'showingPreRecordingCountdown': false,
      'preRecordingCountdown':     0,
      'showingSpeakPrompt':        true,
      'coachingTip':               '',
      'midCoachingMsg':            '',
    });
    _audio.startListening();
    _startAnalysisLoop();

    _masterTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!_isRecording) { t.cancel(); return; }
      if (_timerPaused)  return;
      _recDuration++;
      _push({'recordingDuration': _recDuration});

      // Speak prompt hide
      if (_recDuration == 4 && _showSpeakPrompt) {
        _showSpeakPrompt = false;
        _push({'showingSpeakPrompt': false});
      }

      // Silence detection
      if (!_isSpeaking) {
        _silenceSeconds++;
        if (_silenceSeconds == 5) {
          _push({'analysisCardsOpacity': 0.85, 'showingSpeakPrompt': true});
        } else if (_silenceSeconds == 8) {
          _push({'analysisCardsOpacity': 0.15});
        }
      } else {
        _silenceSeconds = 0;
        if (_showSpeakPrompt) {
          _showSpeakPrompt = false;
          _push({'showingSpeakPrompt': false});
        }
      }

      // Feature 2 - mid-answer coaching visual
      if (_isRecording && !_coachMsgShown) {
        if (_confidence < 50) {
          _lowConfStreak++;
          if (_lowConfStreak >= 4) {
            _coachMsgShown  = true;
            _midCoachingMsg = interviewStyle == 'pressure'
              ? 'Be more specific - give concrete evidence'
              : 'Take your time - breathe and speak clearly';
            _push({'midCoachingMsg': _midCoachingMsg});
            Timer(const Duration(seconds: 4), () {
              _midCoachingMsg = '';
              _push({'midCoachingMsg': ''});
            });
          }
        } else if (_silenceSeconds >= 8 && _isSpeaking == false) {
          _coachMsgShown  = true;
          _midCoachingMsg = interviewStyle == 'pressure'
            ? 'I am waiting for your answer'
            : 'Say more - give a specific example';
          _push({'midCoachingMsg': _midCoachingMsg});
          Timer(const Duration(seconds: 4), () {
            _midCoachingMsg = '';
            _push({'midCoachingMsg': ''});
          });
        } else {
          _lowConfStreak = 0;
        }
      }

      // Final countdown
      if (_recDuration == 17 && !_showFinalCountdown) {
        _showFinalCountdown = true;
        _finalCountdown     = 3;
        _push({'showingFinalCountdown': true, 'finalCountdown': 3,
               'analysisCardsOpacity': 0.35});
        // Safety: force stop if still recording at 22s

      }
      if (_showFinalCountdown && _finalCountdown > 0) {
        _finalCountdown--;
        _push({'finalCountdown': _finalCountdown});
      }
      if (_recDuration >= 20) {
        t.cancel();
        _push({'showingFinalCountdown': false});
        // Direct call - bypasses guard so timer always moves to next question
        if (_isRecording) {
          _doStopRecording();
        } else {
          // Recording already stopped by user tap - ensure flow continues
          if (_transcript.isEmpty) _transcript = '[NO RESPONSE - SILENT]';
          _checkFollowUp();
        }
      }
    });
  }

  void _doStopRecording() {
    if (!_isRecording) return;
    _isRecording = false;
    _audio.stopAll(); // stop mic + TTS immediately
    _masterTimer?.cancel();
    _analysisTimer?.cancel();
    _camera.stopFaceDetection();
    _push({
      'isRecording':          false,
      'isAnalyzing':          false,
      'speechStatus':         'notListening',
      'analysisCardsOpacity': 0.1,
      'isSpeaking':           false,
      'showingSpeakPrompt':   false,
      'showingFaceWarning':   false,
      'showingFinalCountdown':false,
      'midCoachingMsg':       '',
    });
    if (_transcript.isEmpty) {
      _transcript = '[NO RESPONSE - SILENT]';
      _push({'currentTranscript': _transcript});
    }
    _checkFollowUp();
  }

  // - Follow-up -

  Future<void> _checkFollowUp() async {
    // One question per slot - no follow-ups
    await _afterAnswer();
  }




  // - NEW: Content-first scoring -

  Future<double> _scoreContent() async {
    final isReal = !_transcript.startsWith('[');
    if (!isReal) return 5.0;

    final words = _transcript
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .length;
    if (words < 3) return 5.0;
    if (words < 8) return 18.0;

    try {
      final res = await CloudFunctionService.callClaude(
          model: 'claude-haiku-4-5-20251001',
          maxTokens: 80,
          messages: [{'role': 'user', 'content':
            'You are scoring a 20-second interview answer. '
            'Question: "${questions[_qIdx]}"\n'
            'Answer: "$_transcript"\n\n'
            'Score 0-100 on CONTENT ONLY.\n'
            'SCORING GUIDE:\n'
            '90-100: Clear specific answer, directly addresses question\n'
            '70-89: Relevant with a supporting point\n'
            '50-69: Vague but on-topic\n'
            '20-49: Partially relevant or very brief\n'
            '5-19: Gibberish, random words, or off-topic\n'
            '1-4: No meaningful content\n\n'
            'If the answer is random words or makes no sense score 5-15 maximum.\n'
            'Return ONLY valid JSON with one field: {"score": number}',
          }],
        );


        final raw  = CloudFunctionService.extractText(res);
        final data = jsonDecode(
            raw.replaceAll(RegExp(r'```[a-z]*'), '').replaceAll('```', '').trim());
        return (data['score'] as num).toDouble().clamp(0.0, 100.0);
    } catch (_) {}
    return 60.0;
  }

  double _scoreDelivery(int words, int fillers) {
    // Word count - calibrated for 20 seconds
    final double wordScore = words < 10  ? 20.0
                           : words < 20  ? 55.0
                           : words <= 55 ? 100.0
                           : 80.0; // slightly penalise rushing

    // Filler ratio
    final ratio = words > 0 ? fillers / words : 0.0;
    final double fillerScore = ratio <= 0.03 ? 100.0
                             : ratio <= 0.08 ? 75.0
                             : ratio <= 0.15 ? 45.0
                             : 20.0;

    // Face detection bonus
    final double faceBonus = _camera.faceDetected ? 100.0 : 40.0;

    // Delivery = word count 50% + fillers 35% + face 15%
    return (wordScore * 0.50) + (fillerScore * 0.35) + (faceBonus * 0.15);
  }
  // - Answer flow -

  Future<void> _afterAnswer() async {
    // 1. Score content via Claude (60% weight)
    final contentScore  = await _scoreContent();
    if (_disposed) return;

    // 2. Score delivery locally (40% weight)
    final words = _transcript.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;
    final deliveryScore = _scoreDelivery(words, _fillers.length);

    // 3. Blend - content is primary
    // Eye contact bonus/penalty - up to 10 points
    final eyeScore     = _camera.eyeContactScore;
    final eyeBonus     = eyeScore >= 80 ? 8.0
                       : eyeScore >= 60 ? 4.0
                       : eyeScore >= 40 ? 0.0
                       : -6.0;

    // No response = hard cap at 8 regardless of delivery/face/confidence
    final isNoResponse = _transcript.startsWith('[') ||
        _transcript.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length < 3;
    final blended = ((contentScore * 0.60) + (deliveryScore * 0.40) + eyeBonus).clamp(0.0, 100.0);
    _confidence = isNoResponse
        ? blended.clamp(2.0, 8.0)
        : contentScore < 15
        ? blended.clamp(3.0, 15.0)
        : contentScore < 30
        ? blended.clamp(10.0, 32.0)
        : blended.clamp(20.0, 96.0);
    _push({'confidenceScore': _confidence});

    _saveResult();
    if (_disposed) return;
    await _lizzysReaction();
    if (_disposed) return;
    await _adaptNextQuestion();
    if (_disposed) return;
    _nextQuestion();
  }

  Future<void> _lizzysReaction() async {
    final isReal = !_transcript.startsWith('[');
    if (!isReal) return;
    final words = _transcript.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;
    if (words < 5) return; // Too short to react to

    final stylePrompt = interviewStyle == 'pressure'
      ? 'You are a tough interviewer. React critically in 1 sentence. '
        'Acknowledge what they said but push back or show skepticism. '
        'No longer than 15 words.'
      : interviewStyle == 'neutral'
      ? 'You are a professional interviewer. Give a brief neutral '
        'acknowledgment in 1 sentence. No emotion. Max 10 words.'
      : 'You are a warm interviewer named Lizzy. React encouragingly '
        'in 1 sentence. Be natural and human. Max 15 words.';

    try {
      final res = await CloudFunctionService.callClaude(
          model: 'claude-haiku-4-5-20251001',
          maxTokens: 50,
          messages: [{'role': 'user', 'content':
            '$stylePrompt\n\n'
            'The candidate just answered: "${_transcript.length > 200 ? _transcript.substring(0, 200) : _transcript}"\n'
            'Their confidence score was ${_confidence.round()}%.\n'
            'Return only the reaction sentence, nothing else.'}],
        );

        final reaction = (CloudFunctionService.extractText(res)).trim();
        if (reaction.isNotEmpty) _push({'lizzysReaction': reaction});
    } catch (e) {
      if (kDebugMode) print('Reaction failed: $e');
    }
  }


  String _buildCoachingTip(int words, int fillers, double confidence) {
    if (words < 10) return 'Too brief - even in 20 seconds, give at least one clear sentence that directly answers the question.';
    if (words < 20) return 'Add one specific example or detail to your next answer. A concrete point makes a short answer much stronger.';
    if (fillers > 5) return 'You used many filler words. Pause silently instead of saying um or like - a pause sounds more confident.';
    if (confidence < 45) return 'Focus on answering the question directly first, then add a supporting detail. Lead with your main point.';
    if (confidence >= 78) return 'Strong answer! Keep being specific - numbers, names, and outcomes make short answers memorable.';
    return 'Good effort. Next time, open with a direct answer to the question, then back it up with one specific example.';
  }
  Future<void> _postQuestionReview() async {
    final words = _transcript.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;
    final tip = _buildCoachingTip(words, _fillers.length, _confidence);
    final reviewData = {
      'qNum':       _qIdx + 1,
      'total':      questions.length,
      'confidence': _confidence.round(),
      'emotion':    _emotion,
      'fillers':    _fillers.length,
      'words':      words,
      'duration':   _recDuration,
      'coachingTip': tip,
      'question':   questions[_qIdx],
    };
    _push({'showQuestionReview': true, 'reviewData': reviewData});
    // Show for 4 seconds
    await Future.delayed(const Duration(seconds: 7));
    _push({'showQuestionReview': false});
  }

  Future<void> _adaptNextQuestion() async {
    final nextIdx = _qIdx + 1;
    if (nextIdx >= questions.length) return;
    if (interviewStyle == 'neutral') return; // no adaptation in neutral

    // Only adapt if candidate is struggling - never make questions harder
    if (_confidence < 45 && interviewStyle == 'friendly') {
      // Struggling - make next question more supportive
      try {
      final res = await CloudFunctionService.callClaude(
            model: 'claude-haiku-4-5-20251001',
            maxTokens: 80,
            messages: [{'role': 'user', 'content':
              'Make this interview question slightly more approachable '
              'and easier to answer:\n"${questions[nextIdx]}"\n'
              'Return only the new question. Keep it one sentence.'}],
          );

          _adaptedQuestions[nextIdx] =
            (CloudFunctionService.extractText(res)).trim();
      } catch (_) {}
    }
  }

  // - Analysis -

  void _startAnalysisLoop() {
    _analysisTimer = Timer.periodic(const Duration(milliseconds: 600), (t) {
      if (!_isAnalyzing || !_isRecording) { t.cancel(); return; }
      _recalculate();
    });
  }

  void _recalculate() {
    final words  = _transcript.split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty).toList();
    final wCount = words.length;
    double flow = 65.0;
    if (wCount > 0) {
      final ratio = _fillers.length / wCount;
      if      (ratio > 0.15) flow -= 25.0;
      else if (ratio > 0.08) flow -= 12.0;
      else if (ratio < 0.03) flow += 15.0;
    }
    if      (wCount >= 60) flow += 18.0;
    else if (wCount >= 30) flow += 8.0;
    else if (wCount  <  8) flow -= 12.0;
    double pace = 65.0;
    if (_recDuration > 0 && wCount > 0) {
      final wps = wCount / _recDuration;
      if      (wps >= 1.5 && wps <= 3.0) pace += 22.0;
      else if (wps >= 1.0 && wps <= 3.8) pace += 10.0;
      else if (wps  < 0.5 || wps  > 4.5) pace -= 20.0;
    }
    double body = 55.0;
    if (_camera.faceDetected) {
      body += 25.0;
      if (_isSpeaking) body += 12.0;
    }
    body -= (_camera.noFaceWarningCount * 4.0);
    final raw      = (flow * 0.40) + (pace * 0.32) + (body * 0.28);
    final smoothed = _confidence <= 8.0
        ? _confidence  // preserve skip/no-response low score
        : ((_confidence * 0.55) + (raw * 0.45)).clamp(15.0, 95.0);
    final emotion  = smoothed >= 83 ? 'Very Confident'
                   : smoothed >= 73 ? 'Confident'
                   : smoothed >= 63 ? 'Composed'
                   : smoothed >= 50 ? 'Neutral'
                   : smoothed >= 38 ? 'Nervous'
                   : 'Very Nervous';
    _confidence = smoothed;
    _push({
      'confidenceScore':      smoothed,
      'emotion':              emotion,
      'analysisCardsOpacity': _isSpeaking ? 0.05
                            : _showFinalCountdown ? 0.4 : 0.08,
    });
  }

  void _onSpeechResult(String transcript, bool isFinal) {
    if (transcript != _lastSnapshot && transcript.isNotEmpty) {
      _isSpeaking     = true;
      _silenceSeconds = 0;
      _push({'isSpeaking': true, 'analysisCardsOpacity': 0.05});
    }
    _transcript   = transcript;
    _lastSnapshot = transcript;
    _push({'currentTranscript': transcript});
    _detectFillers(transcript);
    _detectSentiment(transcript);
  }

  void _detectFillers(String text) {
    final words    = text.toLowerCase().split(RegExp(r'\s+'));
    final detected = words
        .map((w) => w.replaceAll(RegExp(r'[^\w]'), ''))
        .where(_fillerList.contains)
        .toList();
    final prev = _fillers.length;
    _fillers = detected;
    _push({'fillerWords': detected});
    if (detected.length > prev) {
      _push({'analysisCardsOpacity': 1.0});
      _fillerTimer?.cancel();
      _fillerTimer = Timer(const Duration(milliseconds: 2200), () {
        _push({'analysisCardsOpacity': _isSpeaking ? 0.05 : 0.18});
      });
    }
  }

  void _detectSentiment(String text) {
    const pos = ['good','great','excellent','amazing','love','excited','passionate'];
    const neg = ['bad','terrible','hate','difficult','problem','issue','struggle'];
    final ws = text.toLowerCase().split(' ');
    final p  = ws.where((w) => pos.any(w.contains)).length;
    final n  = ws.where((w) => neg.any(w.contains)).length;
    _push({
      'sentiment':      p > n ? 'Positive' : n > p ? 'Negative' : 'Neutral',
      'sentimentScore': p > n ? 0.3 + (p - n) * 0.1
                      : n > p ? -(0.3 + (n - p) * 0.1) : 0.0,
    });
  }

  // - Results -

  void _saveResult() {
    final words = _transcript.split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty).toList();
    _results.add({
      'questionNumber':    _qIdx + 1,
      'question':          questions[_qIdx],
      'transcript':        _transcript,
      'emotion':           _emotion,
      'confidence':        _confidence,
      'fillerWords':       List<String>.from(_fillers),
      'sentimentScore':    _sentiment,
      'sentiment':         _sentimentText,
      'recordingDuration': _recDuration,
      'wordCount':         words.length,
      'wordsPerSecond':    _recDuration > 0 ? words.length / _recDuration : 0.0,
      'fillerRatio':       words.isNotEmpty ? _fillers.length / words.length : 0.0,
      'faceDetectionWarnings': _camera.noFaceWarningCount,
      'eyeContactScore':       _camera.eyeContactScore,
      'eyeContactFrames':      _camera.eyeContactFrames,
      'totalDetectionFrames':  _camera.totalDetectionFrames,
    });
  }

  void _nextQuestion() {
    if (_qIdx < questions.length - 1) {
      _qIdx++;
      _resetForQuestion();
      Timer(const Duration(seconds: 1), startQuestionFlow);
    } else {
      _timerPaused = false;
      _audio.stopAll();
      _camera.stopAll();
      _cancelAll();
      Timer(const Duration(seconds: 1), () => onNavigateToCompletion(_results));
    }
  }

  void _resetForQuestion() {
    _transcript     = '';
    _fillers        = [];
    _recDuration    = 0;
    _confidence     = 70.0;
    _emotion        = 'Neutral';
    _sentiment      = 0.0;
    _sentimentText  = 'Neutral';
    _isSpeaking     = false;
    _lastSnapshot   = '';
    _timerPaused    = false;
    _midCoachingMsg = '';
    _lowConfStreak  = 0;
    _coachMsgShown  = false;
    _currentAdaptedQ = _qIdx < _adaptedQuestions.length ? _adaptedQuestions[_qIdx] : questions[_qIdx];
    _resetCountdowns();
    _camera.resetForNewQuestion();
    _push({
      'currentQuestionIndex': _qIdx,
      'currentTranscript':    '',
      'fillerWords':          [],
      'recordingDuration':    0,
      'confidenceScore':      70.0,
      'emotion':              'Neutral',
      'sentimentScore':       0.0,
      'sentiment':            'Neutral',
      'analysisCardsOpacity': 0.1,
      'isSpeaking':           false,
      'showingFaceWarning':   false,
      'faceDetected':         false,
      'midCoachingMsg':       '',
      'lizzysReaction':       '',
      'showQuestionReview':   false,
      'currentAdaptedQuestion': _currentAdaptedQ,
    });
  }

  // - Helpers -

  void _resetCountdowns() {
    _preTimer?.cancel();
    _masterTimer?.cancel();
    _showPreCountdown   = false;
    _preCountdown       = 3;
    _preCountdownDone   = false;
    _showFinalCountdown = false;
    _finalCountdown     = 3;
    _ttsCompleted       = false;
    _canRecord          = false;
    _showSpeakPrompt    = false;
  }

  void _cancelAll() {
    _masterTimer?.cancel();
    _preTimer?.cancel();
    _analysisTimer?.cancel();
    _fillerTimer?.cancel();
    _countdownTimer?.cancel();
  }

  void _push(Map<String, dynamic> updates) {
    if (_disposed) return; // widget already unmounted
    if (updates.containsKey('currentQuestionIndex'))         _qIdx             = updates['currentQuestionIndex'];
    if (updates.containsKey('isRecording'))                  _isRecording      = updates['isRecording'];
    if (updates.containsKey('isAnalyzing'))                  _isAnalyzing      = updates['isAnalyzing'];
    if (updates.containsKey('currentTranscript'))            _transcript       = updates['currentTranscript'];
    if (updates.containsKey('speechStatus'))                 _speechStatus     = updates['speechStatus'];
    if (updates.containsKey('recordingDuration'))            _recDuration      = updates['recordingDuration'];
    if (updates.containsKey('showingQuestion'))              _showQuestion     = updates['showingQuestion'];
    if (updates.containsKey('showingCamera'))                _showCamera       = updates['showingCamera'];
    if (updates.containsKey('countdown'))                    _countdown        = updates['countdown'];
    if (updates.containsKey('countdownPaused'))              _countdownPaused  = updates['countdownPaused'];
    if (updates.containsKey('cameraInitialized'))            _cameraReady      = updates['cameraInitialized'];
    if (updates.containsKey('ttsCompleted'))                 _ttsCompleted     = updates['ttsCompleted'];
    if (updates.containsKey('recordingCanStart'))            _canRecord        = updates['recordingCanStart'];
    if (updates.containsKey('confidenceScore'))              _confidence       = (updates['confidenceScore'] as num).toDouble();
    if (updates.containsKey('emotion'))                      _emotion          = updates['emotion'];
    if (updates.containsKey('fillerWords'))                  _fillers          = List<String>.from(updates['fillerWords']);
    if (updates.containsKey('sentimentScore'))               _sentiment        = (updates['sentimentScore'] as num).toDouble();
    if (updates.containsKey('sentiment'))                    _sentimentText    = updates['sentiment'];
    if (updates.containsKey('isSpeaking'))                   _isSpeaking       = updates['isSpeaking'];
    if (updates.containsKey('showingPreRecordingCountdown')) _showPreCountdown = updates['showingPreRecordingCountdown'];
    if (updates.containsKey('preRecordingCountdown'))        _preCountdown     = updates['preRecordingCountdown'];
    if (updates.containsKey('showingFinalCountdown'))        _showFinalCountdown = updates['showingFinalCountdown'];
    if (updates.containsKey('finalCountdown'))               _finalCountdown   = updates['finalCountdown'];
    if (updates.containsKey('showingSpeakPrompt'))           _showSpeakPrompt  = updates['showingSpeakPrompt'];
    if (updates.containsKey('coachingTip'))                  _coachingTip      = updates['coachingTip'] as String? ?? '';
    if (updates.containsKey('midCoachingMsg'))               _midCoachingMsg   = updates['midCoachingMsg'] as String? ?? '';
    if (updates.containsKey('currentAdaptedQuestion'))       _currentAdaptedQ = updates['currentAdaptedQuestion'] as String? ?? _currentAdaptedQ;
    if (updates.containsKey('showQuestionReview'))           _showReview       = updates['showQuestionReview'];
    if (updates.containsKey('reviewData') && updates['reviewData'] != null)
      _reviewData = Map<String, dynamic>.from(updates['reviewData']);

    onStateUpdate({
      'currentQuestionIndex':          _qIdx,
      'isRecording':                   _isRecording,
      'isAnalyzing':                   _isAnalyzing,
      'currentTranscript':             _transcript,
      'speechStatus':                  _speechStatus,
      'recordingDuration':             _recDuration,
      'showingQuestion':               _showQuestion,
      'showingCamera':                 _showCamera,
      'countdown':                     _countdown,
      'countdownPaused':               _countdownPaused,
      'cameraInitialized':             _cameraReady,
      'showingFinalCountdown':         _showFinalCountdown,
      'finalCountdown':                _finalCountdown,
      'ttsCompleted':                  _ttsCompleted,
      'recordingCanStart':             _canRecord,
      'showingPreRecordingCountdown':  _showPreCountdown,
      'preRecordingCountdown':         _preCountdown,
      'preRecordingCountdownFinished': _preCountdownDone,
      'showingSpeakPrompt':            _showSpeakPrompt,
      'coachingTip':                   _coachingTip,
      'midCoachingMsg':                _midCoachingMsg,
      'confidenceScore':               _confidence,
      'emotion':                       _emotion,
      'fillerWords':                   _fillers,
      'sentimentScore':                _sentiment,
      'sentiment':                     _sentimentText,
      'analysisCardsOpacity': updates['analysisCardsOpacity'] ?? _cardOpacity,
      'isSpeaking':                    _isSpeaking,
      'faceDetected':                  _camera.faceDetected,
      'showingFaceWarning':            _camera.showingFaceWarning,
      'showQuestionReview':            _showReview,
      'currentAdaptedQuestion':       _currentAdaptedQ,
      'reviewData':                    _reviewData,
      ...updates,
    });
  }
}


















