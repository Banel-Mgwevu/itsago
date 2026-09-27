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
import 'answer_recorder.dart';

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
  final AnswerRecorder _answerRec = AnswerRecorder();

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
  int    _qStartMs      = 0;
  int    _firstSpeechMs = 0;
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
  // Tracks in-flight _runBackgroundReview() calls. Individual questions
  // never wait on these - only the exit and natural-completion paths do,
  // briefly and with a timeout, so the completion screen never shows a
  // "Processing..." placeholder for the last answered question.
  final List<Future<void>> _pendingReviews = [];

  /// Longest an answer can run before it stops automatically. People can
  /// always tap COMPLETE ANSWER earlier.
  static const int maxAnswerSeconds = 120;

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
      onCameraError:         (msg) {
        print('Interview: camera unavailable ($msg) - continuing audio-only');
        _push({'cameraInitialized': false, 'cameraUnavailable': true});
      },
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

  Future<void> fillRemainingWithZero() async {
    // If the person exits while actively mid-answer, capture and score
    // whatever they've said so far instead of throwing it away - stops
    // the recording and reserves/kicks off its review exactly like a
    // normal answer, just without advancing to a next question (there
    // isn't one to go to on exit).
    if (_isRecording) {
      _stopAndReserveResult();
      _push({
        'isRecording':          false,
        'speechStatus':         'notListening',
        'showingFaceWarning':   false,
        'showingFinalCountdown':false,
      });
    }

    // The most recently answered question's background review
    // (transcription + scoring) may still be running - wait briefly for
    // it so the completion screen shows its real transcript/score
    // instead of the "Processing..." placeholder. Bounded so a slow
    // network call can never hang the exit.
    await _awaitPendingReviews();

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
    _answerRec.cancel();
    _audio.stopAll();
    _camera.stopAll();
    _cancelAll();
    onNavigateToCompletion(_results);
  }

  void skipQuestion() {
    _answerRec.cancel();
    _transcript = '[SKIPPED - NO RESPONSE]';
    _confidence = 3.0; // Hard cap skip at 3%
    _saveResult();
  }

  void pauseInterviewTimer(bool pause) => _timerPaused = pause;

  void forceExitInterview() {
    _answerRec.cancel();
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
    _answerRec.cancel();
    _answerRec.dispose();
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
    // If recording is active, do nothing: the WAV recorder keeps
    // running through the TTS, and we must not start the on-device
    // recognizer - it would steal the mic from the WAV recorder.
    if (_isRecording) return;
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
    print('ðŸŽ¤ _startRecording - recording begins, starting mic now');
    _recDuration     = 0;
    _silenceSeconds  = 0;
    _lastSnapshot    = '';
    _isSpeaking      = false;
    _qStartMs        = DateTime.now().millisecondsSinceEpoch;
    _firstSpeechMs   = 0;
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
    // NOTE: we deliberately do NOT start the on-device recognizer here.
    // Two simultaneous mic clients on Android means one of them receives
    // silence - and on this device the privileged Google recognizer
    // grabs the mic (then returns nothing), leaving the WAV recorder
    // with silent audio. The WAV recorder must own the microphone.
    // Cloud transcription path: record the answer as WAV and
    // transcribe it server-side. On devices whose built-in recognizer
    // returns nothing (e.g. this Huawei's doneNoResult), this is the
    // ONLY source of the transcript. Amplitude drives the live
    // "speaking" visuals so the UI still reacts to the user's voice.
    _answerRec.start(onAmplitude: (db) {
      if (!_isRecording || _timerPaused) return;
      if (db > -35.0) {
        _isSpeaking     = true;
        _silenceSeconds = 0;
        if (_firstSpeechMs == 0) {
          _firstSpeechMs = DateTime.now().millisecondsSinceEpoch;
        }
        _push({'isSpeaking': true, 'analysisCardsOpacity': 0.05});
      }
    });
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
      // Only nudges on real silence (measured from the mic level) - no
      // guessing at confidence while the person is still talking.
      if (_isRecording && !_coachMsgShown) {
        if (_silenceSeconds >= 8 && _isSpeaking == false) {
          _coachMsgShown  = true;
          _midCoachingMsg = interviewStyle == 'pressure'
            ? 'I am waiting for your answer'
            : 'Say more - give a specific example';
          _push({'midCoachingMsg': _midCoachingMsg});
          Timer(const Duration(seconds: 4), () {
            _midCoachingMsg = '';
            _push({'midCoachingMsg': ''});
          });
        }
      }

      // Final countdown
      if (_recDuration == maxAnswerSeconds - 3 && !_showFinalCountdown) {
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
      if (_recDuration >= maxAnswerSeconds) {
        t.cancel();
        _push({'showingFinalCountdown': false});
        // Direct call - bypasses guard so timer always moves to next question
        if (_isRecording) {
          _doStopRecording();
        }
        // else: recording was already stopped by a user tap, and
        // _doStopRecording() already reserved the result and advanced -
        // nothing left to do here.
      }
    });
  }

  void _doStopRecording() {
    if (!_stopAndReserveResult()) return;

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

    // Move on the instant recording ends. Transcription, content
    // scoring, Lizzy's reaction, and question adaptation all now run
    // fully in the background and never hold up the interview.
    _nextQuestion();
  }

  /// Stops the current recording (if any), captures everything its
  /// review will need, reserves its slot in _results immediately, and
  /// kicks off the background review. Does NOT advance to the next
  /// question or touch any UI state - callers decide what happens next.
  /// Used both by the normal end-of-answer flow (_doStopRecording, which
  /// advances afterward) and by exiting mid-answer (fillRemainingWithZero,
  /// which does not - there's no next question to go to). Returns false
  /// if nothing was recording, so callers can skip their own follow-up.
  bool _stopAndReserveResult() {
    if (!_isRecording) return false;
    _isRecording = false;
    _audio.stopAll(); // stop mic + TTS immediately
    _masterTimer?.cancel();
    _analysisTimer?.cancel();
    _camera.stopFaceDetection();

    // Capture everything this answer's review will need BEFORE anything
    // else resets it (advancing to the next question resets _qIdx, the
    // camera's per-question counters, _confidence, etc. immediately -
    // anything read after that point would silently describe the wrong
    // question).
    final snapQIdx         = _qIdx;
    final snapQuestion     = questions[_qIdx];
    final snapRecDuration  = _recDuration;
    final snapFaceWarnings = _camera.noFaceWarningCount;
    final snapEyeScore     = _camera.eyeContactScore;
    final snapEyeFrames    = _camera.eyeContactFrames;
    final snapTotalFrames  = _camera.totalDetectionFrames;
    final snapFaceDetected = _camera.faceDetected;
    final snapSpoke        = _firstSpeechMs > 0; // mic heard speech
    final snapHesitation   = (_firstSpeechMs > 0 && _qStartMs > 0)
        ? ((_firstSpeechMs - _qStartMs) / 1000.0).clamp(0.0, 60.0) : 0.0;
    // The live estimate tracked continuously during recording - used as
    // an immediate placeholder so the reserved slot is never blank while
    // the real transcript and content score are still being fetched.
    final liveConfidence   = _confidence;
    final liveEmotion      = _emotion;

    // Reserve this question's slot in _results right now, synchronously.
    // This is what makes exiting mid-review safe: _results.length must
    // reflect "answered" the instant recording stops, not once the
    // background review finishes - otherwise fillRemainingWithZero()
    // could mistake an in-progress answer for an unanswered one and
    // overwrite it with a zero score.
    final resultIndex = _results.length;
    _results.add({
      'questionNumber':    snapQIdx + 1,
      'question':          snapQuestion,
      'transcript':        'Processing...',
      'emotion':           liveEmotion,
      'confidence':        liveConfidence,
      'fillerWords':       <String>[],
      'sentimentScore':    0.0,
      'sentiment':         'Neutral',
      'recordingDuration': snapRecDuration,
      'wordCount':         0,
      'wordsPerSecond':    0.0,
      'fillerRatio':       0.0,
      'faceDetectionWarnings': snapFaceWarnings,
      'eyeContactScore':       snapEyeScore,
      'eyeContactFrames':      snapEyeFrames,
      'totalDetectionFrames':  snapTotalFrames,
      'hesitationSeconds':     snapHesitation,
      'scored':                true,
    });

    final reviewFuture = _runBackgroundReview(
      spoke:          snapSpoke,
      resultIndex:    resultIndex,
      qIdx:           snapQIdx,
      question:       snapQuestion,
      recDuration:    snapRecDuration,
      faceWarnings:   snapFaceWarnings,
      faceDetected:   snapFaceDetected,
      eyeScore:       snapEyeScore,
    );
    _pendingReviews.add(reviewFuture);
    return true;
  }

  /// The entire post-answer pipeline for one question: cloud
  /// transcription, filler/sentiment detection, content scoring,
  /// delivery scoring, saving the finished result, Lizzy's reaction, and
  /// next-question adaptation. Runs fully detached from the interview
  /// flow (kicked off from _doStopRecording right after _nextQuestion()
  /// already advanced), so none of it can ever block or delay moving on.
  Future<void> _runBackgroundReview({
    required bool   spoke,
    required int    resultIndex,
    required int    qIdx,
    required String question,
    required int    recDuration,
    required int    faceWarnings,
    required bool   faceDetected,
    required double eyeScore,
  }) async {
    final tag = 'Review Q${qIdx + 1}';
    print('$tag: started');
    try {
      String transcript = '';
      try {
        transcript = await _answerRec.stopAndTranscribe()
            .timeout(const Duration(seconds: 60), onTimeout: () {
          print('$tag: transcription timed out after 60s');
          return '';
        });
      } catch (e) {
        print('$tag: transcription threw: $e');
      }
      if (transcript.trim().isEmpty) {
        if (spoke) {
          // The mic heard them talking but we got no words back (network
          // or transcription failure). Don't pretend they were silent.
          _markUnscored(resultIndex, tag, 'transcription returned nothing');
          return;
        }
        transcript = '[NO RESPONSE - SILENT]';
      }
      print('$tag: transcript ready (${transcript.length} chars)');
      if (_disposed) {
        print('$tag: aborted - manager disposed before scoring');
        return;
      }

      final fillers        = _computeFillers(transcript);
      final sentimentData  = _computeSentiment(transcript);
      final sentimentScore = sentimentData['sentimentScore'] as double;

      double? scored;
      try {
        scored = await _scoreContentFor(
            question: question, transcript: transcript)
            .timeout(const Duration(seconds: 20), onTimeout: () {
          print('$tag: content scoring timed out after 20s');
          return null;
        });
      } catch (e) {
        print('$tag: content scoring threw: $e');
      }
      if (scored == null) {
        // No fake 60 - say honestly that this answer couldn't be scored.
        _markUnscored(resultIndex, tag, 'content scoring failed',
            transcript: transcript);
        return;
      }
      final double contentScore = scored;
      print('$tag: content score = $contentScore');
      if (_disposed) {
        print('$tag: aborted - manager disposed after scoring');
        return;
      }

      final words = transcript.split(RegExp(r'\s+'))
          .where((w) => w.isNotEmpty).length;
      final voiceScore   = _scoreVoiceFor(
          words: words, fillers: fillers.length, recDuration: recDuration);
      final postureScore = _scorePostureFor(
          faceDetected: faceDetected, faceWarnings: faceWarnings);
      final toneScore    = _scoreToneFor(sentimentScore: sentimentScore);

      final isNoResponse = transcript.startsWith('[') ||
          transcript.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length < 3;
      // What they SAID counts most. Delivery and camera signals only
      // nudge the score - front-camera eye contact in particular is noisy.
      final blended = ((contentScore * 0.75) +
                       (voiceScore   * 0.10) +
                       (postureScore * 0.05) +
                       (eyeScore     * 0.05) +
                       (toneScore    * 0.05)).clamp(0.0, 100.0);
      final confidence = isNoResponse
          ? blended.clamp(2.0, 8.0)
          : contentScore < 15
          ? blended.clamp(3.0, 15.0)
          : contentScore < 30
          ? blended.clamp(10.0, 32.0)
          : blended.clamp(20.0, 96.0);
      final emotion = confidence >= 83 ? 'Very Confident'
                    : confidence >= 73 ? 'Confident'
                    : confidence >= 63 ? 'Composed'
                    : confidence >= 50 ? 'Neutral'
                    : confidence >= 38 ? 'Nervous'
                    : 'Very Nervous';

      if (resultIndex < _results.length) {
        _results[resultIndex] = {
          ..._results[resultIndex],
          'transcript':     transcript,
          'confidence':     confidence,
          'emotion':        emotion,
          'fillerWords':    fillers,
          'sentimentScore': sentimentScore,
          'sentiment':      sentimentData['sentiment'],
          'wordCount':      words,
          'wordsPerSecond': recDuration > 0 ? words / recDuration : 0.0,
          'fillerRatio':    words > 0 ? fillers.length / words : 0.0,
          'scored':         true,
        };
        print('$tag: done - confidence=$confidence');
      } else {
        print('$tag: FAILED TO SAVE - resultIndex $resultIndex out of range '
            '(results has ${_results.length} entries)');
      }

      // Cosmetic only - never affects saved results, safe to finish last.
      unawaited(_lizzysReaction(transcript, confidence));
      unawaited(_adaptNextQuestion(qIdx + 1, confidence));
    } catch (e, st) {
      // This review must never get permanently stuck on "Processing..."
      // - if anything above threw unexpectedly, write a clear failure
      // marker now instead of leaving the placeholder forever.
      print('$tag: CRASHED: $e\n$st');
      if (resultIndex < _results.length &&
          _results[resultIndex]['transcript'] == 'Processing...') {
        _markUnscored(resultIndex, tag, 'review crashed: $e');
      }
    }
  }

  /// Marks an answer as "couldn't score this answer" instead of inventing
  /// a number. Unscored answers are left out of every average.
  void _markUnscored(int resultIndex, String tag, String reason,
      {String transcript = ''}) {
    print('$tag: UNSCORED - $reason');
    if (resultIndex >= _results.length) return;
    _results[resultIndex] = {
      ..._results[resultIndex],
      'transcript': transcript,
      'confidence': 0.0,
      'scored':     false,
    };
  }

  /// Waits for background reviews (transcription + scoring) before the
  /// results screen opens. Two-minute answers take longer to transcribe,
  /// so this shows a "scoring your answers" screen instead of racing
  /// ahead with half-finished results.
  Future<void> _awaitPendingReviews() async {
    if (_pendingReviews.isNotEmpty) {
      _push({'finishingUp': true});
      try {
        await Future.wait(_pendingReviews)
            .timeout(const Duration(seconds: 85), onTimeout: () => []);
      } catch (_) {}
    }
    for (int i = 0; i < _results.length; i++) {
      if (_results[i]['transcript'] == 'Processing...') {
        _markUnscored(i, 'Review Q${i + 1}', 'still processing at results time');
      }
    }
  }




  // - NEW: Content-first scoring -

  Future<double?> _scoreContentFor({
    required String question,
    required String transcript,
  }) async {
    final isReal = !transcript.startsWith('[');
    if (!isReal) return 5.0;

    final words = transcript
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
            'You are scoring a spoken interview answer (up to 2 minutes). '
            'Question: "$question"\n'
            'Answer: "$transcript"\n\n'
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
    return null; // caller shows "couldn't score this answer"
  }

  /// VOICE: how the answer sounds - amount said for the time available,
  /// speaking pace, and filler usage. Calibrated for answers of up to
  /// 2 minutes (a comfortable ~2-2.5 words/sec).
  double _scoreVoiceFor({
    required int words,
    required int fillers,
    required int recDuration,
  }) {
    final double wordScore = words < 12   ? 20.0
                           : words < 30   ? 55.0
                           : words <= 320 ? 100.0
                           : 85.0; // very long - slightly penalise rambling

    double paceScore = 65.0;
    if (recDuration > 0 && words > 0) {
      final wps = words / recDuration;
      if      (wps >= 1.5 && wps <= 3.0) paceScore = 95.0;
      else if (wps >= 1.0 && wps <= 3.8) paceScore = 78.0;
      else if (wps  < 0.5 || wps  > 4.5) paceScore = 40.0;
    }

    final ratio = words > 0 ? fillers / words : 0.0;
    final double fillerScore = ratio <= 0.03 ? 100.0
                             : ratio <= 0.08 ? 75.0
                             : ratio <= 0.15 ? 45.0
                             : 20.0;

    return (wordScore * 0.40) + (paceScore * 0.30) + (fillerScore * 0.30);
  }

  /// POSTURE / PRESENCE: staying framed and facing the camera throughout
  /// the answer. Uses face presence and how often the "face lost" warning
  /// fired. (True body-posture and hand-gesture tracking needs pose
  /// detection - see note in chat - so camera framing is the proxy here.)
  double _scorePostureFor({
    required bool faceDetected,
    required int  faceWarnings,
  }) {
    double score = faceDetected ? 88.0 : 35.0;
    score -= faceWarnings * 10.0;
    return score.clamp(0.0, 100.0);
  }

  /// TONE: positivity of the language used in the answer.
  /// sentimentScore runs -1..1 -> map to 30-95 so neutral answers sit at
  /// a reasonable baseline instead of being punished.
  double _scoreToneFor({required double sentimentScore}) {
    return (62.0 + sentimentScore * 55.0).clamp(30.0, 95.0);
  }

  /// Pure, side-effect-free filler detection for the background review
  /// pipeline - unlike _detectFillers(), this never pushes UI state, so
  /// it's safe to call after the interview has already moved on to a
  /// later question without corrupting that question's live display.
  List<String> _computeFillers(String text) {
    final words = text.toLowerCase().split(RegExp(r'\s+'));
    return words
        .map((w) => w.replaceAll(RegExp(r'[^\w]'), ''))
        .where(_fillerList.contains)
        .toList();
  }

  /// Pure, side-effect-free sentiment detection - see _computeFillers.
  Map<String, dynamic> _computeSentiment(String text) {
    const pos = ['good','great','excellent','amazing','love','excited','passionate'];
    const neg = ['bad','terrible','hate','difficult','problem','issue','struggle'];
    final ws = text.toLowerCase().split(' ');
    final p  = ws.where((w) => pos.any(w.contains)).length;
    final n  = ws.where((w) => neg.any(w.contains)).length;
    return {
      'sentiment':      p > n ? 'Positive' : n > p ? 'Negative' : 'Neutral',
      'sentimentScore': p > n ? 0.3 + (p - n) * 0.1
                      : n > p ? -(0.3 + (n - p) * 0.1) : 0.0,
    };
  }
  // - Answer flow -

  Future<void> _lizzysReaction(String transcript, double confidence) async {
    final isReal = !transcript.startsWith('[');
    if (!isReal) return;
    final words = transcript.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;
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
            'The candidate just answered: "${transcript.length > 200 ? transcript.substring(0, 200) : transcript}"\n'
            'Their confidence score was ${confidence.round()}%.\n'
            'Return only the reaction sentence, nothing else.'}],
        );

        if (_disposed) return; // interview may have ended while this was in flight
        final reaction = (CloudFunctionService.extractText(res)).trim();
        if (reaction.isNotEmpty) _push({'lizzysReaction': reaction});
    } catch (e) {
      if (kDebugMode) print('Reaction failed: $e');
    }
  }


  String _buildCoachingTip(int words, int fillers, double confidence) {
    if (words < 10) return 'Too brief - give at least one clear sentence that directly answers the question, then an example.';
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

  Future<void> _adaptNextQuestion(int nextIdx, double confidence) async {
    if (nextIdx >= questions.length) return;
    if (interviewStyle == 'neutral') return; // no adaptation in neutral

    // Only adapt if candidate is struggling - never make questions harder
    if (confidence < 45 && interviewStyle == 'friendly') {
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

          if (_disposed) return; // interview may have ended while this was in flight
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
      if (_firstSpeechMs == 0) { _firstSpeechMs = DateTime.now().millisecondsSinceEpoch; }
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
      'hesitationSeconds':     (_firstSpeechMs > 0 && _qStartMs > 0) ? ((_firstSpeechMs - _qStartMs) / 1000.0).clamp(0.0, 60.0) : 0.0,
    });
  }

  Future<void> _nextQuestion() async {
    if (_qIdx < questions.length - 1) {
      _qIdx++;
      _resetForQuestion();
      Timer(const Duration(seconds: 1), startQuestionFlow);
    } else {
      _timerPaused = false;
      _audio.stopAll();
      _camera.stopAll();
      _cancelAll();
      await Future.delayed(const Duration(seconds: 1));
      // The very last question's background review (transcription +
      // scoring) may still be running at this point - wait briefly for
      // it so the completion screen never shows a "Processing..."
      // placeholder. Bounded so a slow network call can't hang the exit.
      await _awaitPendingReviews();
      onNavigateToCompletion(_results);
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


















