import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'review_service.dart';
import 'package:camera/camera.dart';
import 'app_theme.dart';
import 'completion_screen.dart';
import 'interview_manager.dart';

class InterviewScreen extends StatefulWidget {
  final List<CameraDescription> cameras;
  final List<String> questions;
  final String company;
  final String apiKey;
  final String interviewStyle;
  const InterviewScreen({super.key,
    required this.cameras, required this.questions,
    required this.company,  required this.apiKey,
    this.interviewStyle = 'friendly'});
  @override
  State<InterviewScreen> createState() => _InterviewScreenState();
}

class _InterviewScreenState extends State<InterviewScreen> {
  late InterviewManager _mgr;

  // UI state
  int    _qIdx = 0;
  bool   _isRecording = false, _isAnalyzing = false;
  String _transcript = '', _speechStatus = 'notListening';
  int    _recDuration = 0;
  bool   _showQuestion = true, _showCamera = false;
  bool   _isExiting = false;
  int    _countdown = 5;
  bool   _countdownPaused = false, _cameraReady = false;
  bool   _showFinalCountdown = false; int _finalCountdown = 3;
  bool   _ttsCompleted = false, _canRecord = false;
  bool   _showPreCountdown = false; int _preCountdown = 3;
  bool   _showSpeakPrompt = false;
  double _confidence = 70.0;
  String _emotion = 'Neutral';
  List<String> _fillers = [];
  double _cardOpacity = 1.0;
  bool   _isSpeaking = false;
  bool   _finishingUp = false;
  bool   _faceDetected = false, _showFaceWarning = false;
  String _coachingTip    = '';
  String _midCoachingMsg = '';
  String _currentAdaptedQ = '';
  String _lizzysReaction = '';
  bool   _showReview     = false;
  Map<String, dynamic> _reviewData = {};


  @override
  void initState() {
    super.initState();
    _mgr = InterviewManager(
      cameras: widget.cameras, questions: widget.questions,
      company: widget.company, apiKey: widget.apiKey,
      onStateUpdate: _onState,
      onNavigateToCompletion: _onComplete,
      interviewStyle: widget.interviewStyle,
      onEarlyStopAttempt: (msg) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(msg, style: const TextStyle(
              fontWeight: FontWeight.w700, color: Colors.white)),
            backgroundColor: const Color(0xFF1A1C2A),
            behavior: SnackBarBehavior.floating,
            shape: const RoundedRectangleBorder(),
            duration: const Duration(seconds: 2)));
      });
    _mgr.startQuestionFlow();
  }

  @override
  void dispose() { _mgr.dispose(); super.dispose(); }

  void _onState(Map<String, dynamic> s) {
    if (!mounted) return;
    setState(() {
      _qIdx           = s['currentQuestionIndex']      ?? _qIdx;
      _isRecording    = s['isRecording']               ?? _isRecording;
      _isAnalyzing    = s['isAnalyzing']               ?? _isAnalyzing;
      _transcript     = s['currentTranscript']         ?? _transcript;
      _speechStatus   = s['speechStatus']              ?? _speechStatus;
      _recDuration    = s['recordingDuration']         ?? _recDuration;
      _showQuestion   = s['showingQuestion']           ?? _showQuestion;
      _showCamera     = s['showingCamera']             ?? _showCamera;
      _countdown      = s['countdown']                 ?? _countdown;
      _countdownPaused= s['countdownPaused']           ?? _countdownPaused;
      _cameraReady    = s['cameraInitialized']         ?? _cameraReady;
      _showFinalCountdown = s['showingFinalCountdown'] ?? _showFinalCountdown;
      _finalCountdown = s['finalCountdown']            ?? _finalCountdown;
      _ttsCompleted   = s['ttsCompleted']              ?? _ttsCompleted;
      _canRecord      = s['recordingCanStart']         ?? _canRecord;
      _showPreCountdown = s['showingPreRecordingCountdown'] ?? _showPreCountdown;
      _preCountdown   = s['preRecordingCountdown']     ?? _preCountdown;
      _showSpeakPrompt= s['showingSpeakPrompt']        ?? _showSpeakPrompt;
      _confidence     = (s['confidenceScore'] as num?) ?.toDouble() ?? _confidence;
      _emotion        = s['emotion']                   ?? _emotion;
      _fillers        = (s['fillerWords'] as List?)?.cast<String>() ?? _fillers;
      _cardOpacity    = (s['analysisCardsOpacity'] as num?)?.toDouble() ?? _cardOpacity;
      _isSpeaking     = s['isSpeaking']                ?? _isSpeaking;
      _finishingUp    = s['finishingUp']               ?? _finishingUp;
      _faceDetected   = s['faceDetected']              ?? _faceDetected;
      _showFaceWarning  = s['showingFaceWarning']      ?? _showFaceWarning;
      _coachingTip    = s['coachingTip']  as String?  ?? _coachingTip;
      _midCoachingMsg = s['midCoachingMsg'] as String? ?? _midCoachingMsg;
      _showReview     = s['showQuestionReview']          ?? _showReview;
      if (s['reviewData'] != null) _reviewData = Map<String, dynamic>.from(s['reviewData']);
      _currentAdaptedQ = s['currentAdaptedQuestion'] as String? ?? _currentAdaptedQ;
      if (s.containsKey('lizzysReaction')) _lizzysReaction = s['lizzysReaction'] as String? ?? '';

    });
  }

  void _onComplete(List<Map<String, dynamic>> results) {
    Navigator.of(context).pushReplacement(MaterialPageRoute(
      builder: (_) => CompletionScreen(
        allResults: results, company: widget.company)));
  }

  Future<bool> _onWillPop() async {
    _mgr.pauseInterviewTimer(true);
    final result = await _exitDialog() ?? false;
    if (result) {
      setState(() => _isExiting = true);
      await _mgr.fillRemainingWithZero();
      return true;
    }
    _mgr.pauseInterviewTimer(false);
    return false;
  }
  @override
  Widget build(BuildContext context) => WillPopScope(
    onWillPop: _onWillPop,
    child: _isExiting
         ? _loadingScreen(label: 'FINISHING UP YOUR\nLAST ANSWER...')
         : _showQuestion ? _questionScreen()
         : _showCamera  ? _cameraScreen()
         : _loadingScreen());

  // ── QUESTION SCREEN ────────────────────────────────────
  Widget _questionScreen() => Scaffold(
    backgroundColor: AppColors.cream,
    body: SafeArea(child: Column(children: [
      // Header poster
      Container(width: double.infinity, color: AppColors.ink,
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Row(children: [
          Container(width: 44, height: 44,
            decoration: const BoxDecoration(
              color: AppColors.amber, border: AppBorders.ink2,
              boxShadow: [AppShadows.hard3]),
            child: Center(child: Text('${_qIdx + 1}',
              style: AppText.title.copyWith(color: AppColors.ink)))),
          const SizedBox(width: 12),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('QUESTION ${_qIdx + 1} OF ${widget.questions.length}',
              style: AppText.label.copyWith(color: Colors.white)),
            Text(widget.company.toUpperCase(),
              style: AppText.label.copyWith(
                color: AppColors.amber, letterSpacing: 1.5)),
          ])),
          AppWidgets.badge(
            '${((_qIdx + 1) / widget.questions.length * 100).round()}%',
            bg: AppColors.red, fg: Colors.white),
        ])),

      // Progress bar
      Container(height: 4, color: AppColors.mist,
        child: FractionallySizedBox(
          widthFactor: (_qIdx + 1) / widget.questions.length,
          alignment: Alignment.centerLeft,
          child: Container(color: AppColors.amber))),

      Expanded(child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(children: [

          // Question card
          Container(
            decoration: AppDecorations.card,
            child: Column(children: [
              Container(width: double.infinity,
                padding: const EdgeInsets.all(14),
                color: AppColors.amber,
                child: Row(children: [
                  Container(width: 36, height: 36,
                    color: AppColors.ink,
                    child: const Icon(Icons.quiz_rounded,
                      color: Colors.white, size: 18)),
                  const SizedBox(width: 12),
                  Text('YOUR QUESTION',
                    style: AppText.label.copyWith(
                      color: AppColors.ink, fontSize: 11)),
                ])),
              Padding(padding: const EdgeInsets.all(20),
                child: Text(_currentAdaptedQ.isNotEmpty ? _currentAdaptedQ : widget.questions[_qIdx],
                  style: AppText.body.copyWith(fontSize: 16, height: 1.5),
                  textAlign: TextAlign.center)),
            ])),

          const SizedBox(height: 20),

          // Countdown card
          Container(
            decoration: AppDecorations.card,
            child: Column(children: [
              Container(width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 10),
                color: _countdownPaused ? AppColors.amber : AppColors.red,
                child: Text(
                  _countdownPaused ? 'PAUSED' : 'STARTING IN',
                  style: AppText.label.copyWith(
                    color: _countdownPaused
                      ? AppColors.ink : Colors.white,
                    fontSize: 11),
                  textAlign: TextAlign.center)),
              Padding(padding: const EdgeInsets.all(24),
                child: Column(children: [
                  Container(width: 100, height: 100,
                    decoration: BoxDecoration(
                      color: AppColors.white,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: _countdownPaused
                          ? AppColors.amber : AppColors.red, width: 4),
                      boxShadow: [AppShadows.colored(
                        _countdownPaused ? AppColors.amber : AppColors.red)]),
                    child: Center(child: Text('$_countdown',
                      style: AppText.display.copyWith(
                        color: _countdownPaused
                          ? AppColors.amber : AppColors.red,
                        fontSize: 44)))),
                  const SizedBox(height: 16),
                  Text(
                    _countdownPaused
                      ? 'TAP RESUME TO CONTINUE'
                      : 'INTERVIEWER WILL ASK QUESTION',
                    style: AppText.caption.copyWith(letterSpacing: 1),
                    textAlign: TextAlign.center),
                  const SizedBox(height: 20),
                  Row(children: [
                    Expanded(child: GestureDetector(
                      onTap: () => _mgr.pauseCountdown(),
                      child: Container(height: 48,
                        decoration: BoxDecoration(
                          color: _countdownPaused
                            ? AppColors.blue : AppColors.amber,
                          border: AppBorders.ink2,
                          boxShadow: const [AppShadows.hard3]),
                        child: Center(child: Text(
                          _countdownPaused ? 'RESUME' : 'PAUSE',
                          style: AppText.button.copyWith(
                            color: _countdownPaused
                              ? Colors.white : AppColors.ink)))))),
                    const SizedBox(width: 10),
                    Expanded(child: GestureDetector(
                      onTap: () => _mgr.startNow(),
                      child: Container(height: 48,
                        decoration: const BoxDecoration(
                          color: AppColors.ink,
                          border: AppBorders.ink2,
                          boxShadow: [AppShadows.hard3]),
                        child: Center(child: Text('BEGIN NOW',
                          style: AppText.button))))),
                  ]),
                ])),
            ])),
        ]))),
    ])));

  // ── CAMERA SCREEN ──────────────────────────────────────
  Widget _cameraScreen() {
    if (!_cameraReady) return _loadingScreen();
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(children: [
        Positioned.fill(child: _mgr.getCameraPreview()),

        // Face warning
        if (_showFaceWarning)
          Positioned.fill(child: Container(
            color: AppColors.redAt(0.25),
            child: Center(child: Container(
              margin: const EdgeInsets.all(24),
              decoration: const BoxDecoration(
                color: Colors.black87,
                border: Border.fromBorderSide(
                  BorderSide(color: AppColors.red, width: 2))),
              padding: const EdgeInsets.all(20),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.face_retouching_off_rounded,
                  color: AppColors.red, size: 44),
                const SizedBox(height: 12),
                Text('FACE NOT DETECTED',
                  style: AppText.title.copyWith(
                    color: Colors.white, letterSpacing: 1.5)),
                const SizedBox(height: 8),
                Text('Position yourself in front of the camera',
                  style: AppText.caption.copyWith(color: AppColors.amber),
                  textAlign: TextAlign.center),
              ]))))),

        // Mid-answer coaching overlay
        if (_midCoachingMsg.isNotEmpty)
          Positioned(top: 0, left: 0, right: 0, bottom: 0,
            child: IgnorePointer(child: Center(child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 32),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.ink.withOpacity(0.88),
                border: Border.all(color: AppColors.amber, width: 2),
                boxShadow: const [AppShadows.hard4]),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.tips_and_updates_rounded,
                  color: AppColors.amber, size: 20),
                const SizedBox(width: 12),
                Expanded(child: Text(_midCoachingMsg,
                  style: AppText.title.copyWith(
                    color: Colors.white, fontSize: 14, height: 1.4))),
              ]))))),

        // Top question header
        Positioned(top: 0, left: 0, right: 0,
          child: Container(
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 12,
              left: 14, right: 14, bottom: 14),
            color: Colors.black.withOpacity(0.75),
            child: Column(children: [
              Row(children: [
                Container(width: 36, height: 36,
                  decoration: const BoxDecoration(
                    color: AppColors.amber, border: AppBorders.ink2),
                  child: Center(child: Text('${_qIdx + 1}',
                    style: AppText.label.copyWith(
                      color: AppColors.ink, fontSize: 14)))),
                const SizedBox(width: 10),
                Expanded(child: Text(
                  'Q${_qIdx + 1} / ${widget.questions.length}',
                  style: AppText.title.copyWith(color: Colors.white))),
                if (_isRecording)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.red,
                      border: Border.all(color: Colors.white, width: 1)),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Container(width: 6, height: 6,
                        decoration: const BoxDecoration(
                          color: Colors.white, shape: BoxShape.circle)),
                      const SizedBox(width: 6),
                      Text('${_fmt(_recDuration)} / ${_fmt(InterviewManager.maxAnswerSeconds)}',
                        style: AppText.label.copyWith(
                          color: Colors.white, fontSize: 10)),
                    ])),
              ]),
              const SizedBox(height: 10),
              Container(width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: Colors.white.withOpacity(0.3), width: 1)),
                child: Text(_currentAdaptedQ.isNotEmpty ? _currentAdaptedQ : widget.questions[_qIdx],
                  style: AppText.caption.copyWith(
                    color: Colors.white, height: 1.4, fontSize: 12),
                  textAlign: TextAlign.center)),
            ]))),

        // Speaking indicator - honest, mic-level only (no live scoring)
        if (_isRecording)
          Positioned(
            right: 12,
            top: MediaQuery.of(context).padding.top + 180,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: _isSpeaking ? AppColors.blue : Colors.black.withOpacity(0.6),
                border: Border.all(color: Colors.white, width: 1.5)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(_isSpeaking ? Icons.graphic_eq_rounded : Icons.mic_none_rounded,
                  color: Colors.white, size: 16),
                const SizedBox(width: 6),
                Text(_isSpeaking ? 'SPEAKING' : 'LISTENING',
                  style: AppText.label.copyWith(color: Colors.white, fontSize: 9)),
              ]))),

        if (_showSpeakPrompt && _isRecording)
          Positioned(
            left: 16, right: 16,
            top: MediaQuery.of(context).size.height * 0.48,
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.blue.withOpacity(0.92),
                border: Border.all(color: Colors.white, width: 1.5),
                boxShadow: const [AppShadows.hard4]),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                const Icon(Icons.mic_rounded,
                  color: Colors.white, size: 20),
                const SizedBox(width: 10),
                Text('START SPEAKING NOW',
                  style: AppText.button.copyWith(letterSpacing: 2)),
              ]))),

        // Coaching tip during pre-recording countdown
        if (_showPreCountdown && _coachingTip.isNotEmpty)
          Positioned(bottom: 140, left: 16, right: 16,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.ink.withOpacity(0.88),
                border: Border.all(color: AppColors.amber, width: 1.5)),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                const Icon(Icons.tips_and_updates_rounded,
                  color: AppColors.amber, size: 14),
                const SizedBox(width: 8),
                Expanded(child: Text(_coachingTip,
                  style: AppText.caption.copyWith(
                    color: Colors.white, height: 1.4))),
              ]))),


        // Pre-recording countdown
        if (_showPreCountdown && !_isRecording && _ttsCompleted)
          Positioned(left: 16, top: MediaQuery.of(context).size.height * 0.35,
            child: _countdownWidget(_preCountdown, AppColors.blue, 'READY')),

        // Final countdown
        if (_showFinalCountdown && _isRecording &&
            _recDuration >= InterviewManager.maxAnswerSeconds - 3)
          Positioned(left: 16, top: MediaQuery.of(context).size.height * 0.35,
            child: _countdownWidget(_finalCountdown, AppColors.red, 'TIME')),

        // Bottom controls
        Positioned(bottom: 0, left: 0, right: 0,
          child: Container(
            padding: EdgeInsets.fromLTRB(16, 14, 16, 24 + MediaQuery.of(context).padding.bottom),
            color: Colors.black.withOpacity(0.8),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              if (_isRecording) ...[
                GestureDetector(
                  onTap: () => _mgr.stopRecording(),
                  child: Container(
                    width: double.infinity, height: 56,
                    decoration: const BoxDecoration(
                      color: AppColors.red,
                      border: AppBorders.ink2,
                      boxShadow: [AppShadows.hard4]),
                    child: Center(child: Text('COMPLETE ANSWER',
                      style: AppText.button.copyWith(
                        letterSpacing: 2, fontSize: 15))))),
              ] else ...[
                if (!_ttsCompleted && !_canRecord)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: AppColors.blue.withOpacity(0.6), width: 1.5)),
                    child: Column(children: [
                      Row(mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                        Container(width: 8, height: 8,
                          decoration: const BoxDecoration(
                            color: AppColors.blue, shape: BoxShape.circle)),
                        const SizedBox(width: 10),
                        Text('INTERVIEWER IS ASKING...',
                          style: AppText.label.copyWith(
                            color: Colors.white, fontSize: 10)),
                      ]),
                      const SizedBox(height: 8),
                      Text('LISTEN CAREFULLY — YOUR TURN IS NEXT',
                        style: AppText.caption.copyWith(
                          color: AppColors.blue, letterSpacing: 1),
                        textAlign: TextAlign.center),
                    ])),
              ],
            ]))),

        // Waiting for the last answers to be transcribed and scored
        if (_finishingUp)
          Positioned.fill(child: Container(
            color: AppColors.ink,
            child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
              const SizedBox(width: 36, height: 36,
                child: CircularProgressIndicator(color: AppColors.amber, strokeWidth: 3)),
              const SizedBox(height: 20),
              Text('SCORING YOUR ANSWERS',
                style: AppText.title.copyWith(color: Colors.white, letterSpacing: 2)),
              const SizedBox(height: 8),
              Text('This can take up to a minute',
                style: AppText.caption.copyWith(color: AppColors.amber)),
            ])))),
      ]));
  }




  Widget _reviewScreen() {
    final conf    = (_reviewData['confidence'] as num?)?.toInt() ?? 0;
    final emotion = _reviewData['emotion']     as String? ?? '';
    final fillers = (_reviewData['fillers']    as num?)?.toInt() ?? 0;
    final words   = (_reviewData['words']      as num?)?.toInt() ?? 0;
    final qNum    = (_reviewData['qNum']       as num?)?.toInt() ?? 0;
    final total   = (_reviewData['total']      as num?)?.toInt() ?? 0;
    final tip     = _reviewData['coachingTip'] as String? ?? '';
    final confColor = conf >= 70 ? AppColors.blue
      : conf >= 50 ? AppColors.amber : AppColors.red;
    final grade = conf >= 80 ? 'STRONG' : conf >= 65 ? 'GOOD'
      : conf >= 50 ? 'FAIR' : 'NEEDS WORK';

    return Scaffold(
      backgroundColor: AppColors.ink,
      body: SafeArea(child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start,
          children: [

          // Header
          Row(children: [
            Container(width: 6, height: 48, color: AppColors.amber),
            const SizedBox(width: 14),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('QUESTION $qNum COMPLETE',
                style: AppText.title.copyWith(
                  color: Colors.white, letterSpacing: 2)),
              Text('$qNum of $total answered',
                style: AppText.caption.copyWith(color: AppColors.dim)),
            ])),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              color: confColor,
              child: Text(grade, style: AppText.label.copyWith(
                color: Colors.white, fontSize: 9))),
          ]),

          const SizedBox(height: 20),

          // Stats row
          Row(children: [
            _reviewStat('$conf%', 'CONFIDENCE', confColor),
            const SizedBox(width: 10),
            _reviewStat('$fillers', 'FILLERS',
              fillers <= 2 ? AppColors.blue : fillers <= 5 ? AppColors.amber : AppColors.red),
            const SizedBox(width: 10),
            _reviewStat('$words', 'WORDS',
              words >= 40 ? AppColors.blue : words >= 20 ? AppColors.amber : AppColors.red),
          ]),

          const SizedBox(height: 14),

          // Emotion strip
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              border: Border.all(color: confColor.withOpacity(0.3), width: 1)),
            child: Row(children: [
              Icon(Icons.psychology_rounded, color: confColor, size: 16),
              const SizedBox(width: 10),
              Text('Emotion detected: ',
                style: AppText.caption.copyWith(color: AppColors.dim)),
              Text(emotion, style: AppText.label.copyWith(
                color: confColor, fontSize: 11)),
            ])),

          const SizedBox(height: 14),

          // Lizzy reaction
          if (_lizzysReaction.isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.amber.withOpacity(0.08),
                border: Border.all(color: AppColors.amber, width: 1.5)),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                const Icon(Icons.record_voice_over_rounded,
                  color: AppColors.amber, size: 16),
                const SizedBox(width: 10),
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('LIZZY SAYS', style: AppText.label.copyWith(
                    color: AppColors.amber, fontSize: 8)),
                  const SizedBox(height: 4),
                  Text(_lizzysReaction, style: AppText.body.copyWith(
                    color: Colors.white, fontSize: 13, height: 1.4)),
                ])),
              ])),

          if (_lizzysReaction.isNotEmpty) const SizedBox(height: 14),

          // Coaching tip
          if (tip.isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.blue.withOpacity(0.08),
                border: Border.all(color: AppColors.blue, width: 1.5)),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                const Icon(Icons.tips_and_updates_rounded,
                  color: AppColors.blue, size: 16),
                const SizedBox(width: 10),
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('HOW TO IMPROVE', style: AppText.label.copyWith(
                    color: AppColors.blue, fontSize: 8)),
                  const SizedBox(height: 4),
                  Text(tip, style: AppText.body.copyWith(
                    color: Colors.white, fontSize: 13, height: 1.4)),
                ])),
              ])),

          const SizedBox(height: 20),

          // Progress bar countdown
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.0, end: 1.0),
            duration: const Duration(seconds: 7),
            builder: (_, v, __) => Column(children: [
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                Text(qNum < total ? 'Next question coming up...' : 'Calculating results...',
                  style: AppText.caption.copyWith(
                    color: AppColors.dim, fontStyle: FontStyle.italic)),
                Text('${((1 - v) * 7).ceil()}s',
                  style: AppText.caption.copyWith(color: AppColors.dim)),
              ]),
              const SizedBox(height: 6),
              Container(height: 3, color: AppColors.dim.withOpacity(0.3),
                child: FractionallySizedBox(
                  widthFactor: v, alignment: Alignment.centerLeft,
                  child: Container(color: AppColors.amber))),
            ])),

        ]))));
  }

  Widget _reviewStat(String val, String lbl, Color color) =>
    Expanded(child: Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        border: Border.all(color: color.withOpacity(0.4), width: 1.5)),
      child: Column(children: [
        Text(val, style: AppText.display.copyWith(color: color, fontSize: 22)),
        const SizedBox(height: 4),
        Text(lbl, style: AppText.label.copyWith(color: color, fontSize: 7.5)),
      ])));

  Widget _analysisCard(String val, String lbl, Color accent, IconData icon) =>
    Container(width: 72,
      decoration: BoxDecoration(
        border: Border.all(color: Colors.white.withOpacity(0.3), width: 1.5)),
      child: Column(children: [
        Container(width: double.infinity, height: 36,
          color: accent,
          child: Icon(icon, color: Colors.white, size: 16)),
        Container(width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 6),
          color: Colors.black.withOpacity(0.85),
          child: Column(children: [
            Text(val, style: AppText.label.copyWith(
              color: Colors.white, fontSize: 9),
              textAlign: TextAlign.center),
            Text(lbl, style: AppText.label.copyWith(
              color: accent, fontSize: 7),
              textAlign: TextAlign.center),
          ])),
      ]));

  Widget _countdownWidget(int count, Color accent, String label) =>
    Container(width: 90,
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.88),
        border: Border.all(color: accent, width: 2.5),
        boxShadow: [AppShadows.colored(accent, size: 3)]),
      child: Column(children: [
        Container(width: double.infinity, height: 34,
          color: accent,
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(label == 'TIME'
              ? Icons.timer_rounded : Icons.mic_rounded,
              color: Colors.white, size: 14),
            const SizedBox(width: 5),
            Text(label, style: AppText.label.copyWith(
              color: Colors.white, fontSize: 9)),
          ])),
        Padding(padding: const EdgeInsets.symmetric(vertical: 12),
          child: Text('$count',
            style: AppText.display.copyWith(
              color: accent, fontSize: 44),
            textAlign: TextAlign.center)),
        Text('SEC', style: AppText.label.copyWith(
          color: accent.withOpacity(0.7), fontSize: 8)),
        const SizedBox(height: 10),
      ]));

  // ── LOADING SCREEN ─────────────────────────────────────
  Widget _loadingScreen({String label = 'PREPARING CAMERA...'}) => Scaffold(
    backgroundColor: AppColors.ink,
    body: Center(child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
      Container(width: 72, height: 72,
        decoration: BoxDecoration(
          color: AppColors.cream,
          border: AppBorders.ink3,
          boxShadow: [AppShadows.colored(AppColors.amber)]),
        child: const CircularProgressIndicator(
          color: AppColors.amber, strokeWidth: 4)),
      const SizedBox(height: 24),
      Text(label,
        style: AppText.title.copyWith(
          color: Colors.white, letterSpacing: 2),
        textAlign: TextAlign.center),
    ])));

  // ── EXIT DIALOG ────────────────────────────────────────
  Future<bool?> _exitDialog() => showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (dlg) => Dialog(backgroundColor: Colors.transparent,
      child: Container(
        decoration: AppDecorations.dialog,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: double.infinity,
            padding: const EdgeInsets.all(16), color: AppColors.red,
            child: Row(children: [
              const Icon(Icons.warning_rounded,
                color: Colors.white, size: 20),
              const SizedBox(width: 10),
              Text('EXIT INTERVIEW?', style: AppText.title.copyWith(
                color: Colors.white, letterSpacing: 2)),
            ])),
          Padding(padding: const EdgeInsets.all(20),
            child: Column(children: [
              // Progress
              Row(children: [
                Container(width: 46, height: 46,
                  decoration: const BoxDecoration(
                    color: AppColors.amber, border: AppBorders.ink2),
                  child: Center(child: Text('${_qIdx + 1}',
                    style: AppText.headline.copyWith(color: AppColors.ink)))),
                const SizedBox(width: 14),
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Q ${_qIdx + 1} OF ${widget.questions.length}',
                    style: AppText.title),
                  const SizedBox(height: 6),
                  Container(height: 6,
                    decoration: const BoxDecoration(
                      color: AppColors.mist, border: AppBorders.ink2),
                    child: FractionallySizedBox(
                      widthFactor: (_qIdx + 1) / widget.questions.length,
                      alignment: Alignment.centerLeft,
                      child: Container(color: AppColors.amber))),
                ])),
              ]),
              const SizedBox(height: 20),
              Row(children: [
                Expanded(child: GestureDetector(
                  onTap: () => Navigator.pop(dlg, false),
                  child: Container(height: 52,
                    decoration: const BoxDecoration(
                      color: AppColors.blue, border: AppBorders.ink2,
                      boxShadow: [AppShadows.hard3]),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                      const Icon(Icons.play_arrow_rounded,
                        color: Colors.white, size: 20),
                      const SizedBox(width: 6),
                      Text('CONTINUE', style: AppText.button),
                    ])))),
                const SizedBox(width: 12),
                Expanded(child: GestureDetector(
                  onTap: () => Navigator.pop(dlg, true),
                  child: Container(height: 52,
                    decoration: const BoxDecoration(
                      color: AppColors.red, border: AppBorders.ink2,
                      boxShadow: [AppShadows.hard3]),
                    child: Center(child: Text('EXIT',
                      style: AppText.button.copyWith(letterSpacing: 2)))))),
              ]),
            ])),
        ]))));

  String _fmt(int s) =>
    '${(s ~/ 60).toString().padLeft(2, '0')}:${(s % 60).toString().padLeft(2, '0')}';
}



















