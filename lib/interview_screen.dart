import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'main.dart';
import 'completion_screen.dart';
import 'interview_manager.dart';

class InterviewScreen extends StatefulWidget {
  final List<CameraDescription> cameras;
  final List<String> questions;
  final String company;
  final String apiKey;

  const InterviewScreen({
    Key? key,
    required this.cameras,
    required this.questions,
    required this.company,
    required this.apiKey,
  }) : super(key: key);

  @override
  State<InterviewScreen> createState() => _InterviewScreenState();
}

class _InterviewScreenState extends State<InterviewScreen> {
  late InterviewManager _manager;
  
  // UI State Variables
  int _currentQuestionIndex = 0;
  bool _isRecording = false;
  bool _isAnalyzing = false;
  String _currentTranscript = '';
  String _speechStatus = 'notListening';
  int _recordingDuration = 0;
  
  bool _showingQuestion = true;
  bool _showingCamera = false;
  int _countdown = 5;
  bool _countdownPaused = false;
  bool _cameraInitialized = false;
  
  bool _showingFinalCountdown = false;
  int _finalCountdown = 3;
  bool _ttsCompleted = false;
  bool _recordingCanStart = false;
  bool _countdownFinished = false;
  
  bool _showingPreRecordingCountdown = false;
  int _preRecordingCountdown = 3;
  bool _preRecordingCountdownFinished = false;
  
  double _confidenceScore = 70.0;
  String _emotion = 'Neutral';
  List<String> _fillerWords = [];
  double _sentimentScore = 0.0;
  String _sentiment = 'Neutral';
  
  double _analysisCardsOpacity = 1.0;
  bool _isSpeaking = false;

  @override
  void initState() {
    super.initState();
    _manager = InterviewManager(
      cameras: widget.cameras,
      questions: widget.questions,
      company: widget.company,
      apiKey: widget.apiKey,
      onStateUpdate: _updateState,
      onNavigateToCompletion: _navigateToCompletion,
    );
    _manager.startQuestionFlow();
  }

  @override
  void dispose() {
    _manager.dispose();
    super.dispose();
  }

  // Handle back button press with confirmation
  Future<bool> _onWillPop() async {
    // Pause the interview timer when dialog shows
    _manager.pauseInterviewTimer(true);
    
    final result = await _showExitConfirmationDialog() ?? false;
    
    // Resume the interview timer when dialog closes
    _manager.pauseInterviewTimer(false);
    
    return result;
  }

  // Show attractive Bauhaus-styled exit confirmation dialog
  Future<bool?> _showExitConfirmationDialog() {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(30),
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(color: BauhausColors.black, width: 4),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 20,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: Stack(
              children: [
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Header with geometric elements
                    Container(
                      width: double.infinity,
                      height: 80,
                      color: BauhausColors.red,
                      child: Stack(
                        children: [
                          // Yellow triangle decoration
                          Positioned(
                            top: 10,
                            right: 15,
                            child: CustomPaint(
                              size: Size(30, 30),
                              painter: TrianglePainter(BauhausColors.yellow),
                            ),
                          ),
                          // White circle decoration
                          Positioned(
                            bottom: 5,
                            left: 15,
                            child: Container(
                              width: 20,
                              height: 20,
                              decoration: BoxDecoration(
                                color: BauhausColors.white,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                          // Main content
                          Center(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  width: 50,
                                  height: 50,
                                  color: BauhausColors.black,
                                  child: Icon(
                                    Icons.warning,
                                    color: BauhausColors.white,
                                    size: 28,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'EXIT INTERVIEW?',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w900,
                                        color: BauhausColors.white,
                                        letterSpacing: 2,
                                      ),
                                    ),
                                    Text(
                                      'CONFIRM YOUR CHOICE',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
                                        color: BauhausColors.yellow,
                                        letterSpacing: 1,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    // Content area with progress visual
                    Container(
                      width: double.infinity,
                      color: BauhausColors.white,
                      child: Column(
                        children: [
                          // Progress indicator section
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(20),
                            child: Row(
                              children: [
                                Container(
                                  width: 50,
                                  height: 50,
                                  color: BauhausColors.yellow,
                                  child: Center(
                                    child: Text(
                                      '${_currentQuestionIndex + 1}',
                                      style: TextStyle(
                                        fontSize: 24,
                                        fontWeight: FontWeight.w900,
                                        color: BauhausColors.black,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'QUESTION ${_currentQuestionIndex + 1} OF ${widget.questions.length}',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w900,
                                          color: BauhausColors.black,
                                          letterSpacing: 1,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Container(
                                        height: 8,
                                        decoration: BoxDecoration(
                                          border: Border.all(color: BauhausColors.black, width: 2),
                                        ),
                                        child: LinearProgressIndicator(
                                          value: (_currentQuestionIndex + 1) / widget.questions.length,
                                          backgroundColor: BauhausColors.lightGray,
                                          valueColor: AlwaysStoppedAnimation<Color>(BauhausColors.yellow),
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '${((_currentQuestionIndex + 1) / widget.questions.length * 100).round()}% COMPLETE',
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w600,
                                          color: BauhausColors.blue,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          
                          // Company reminder
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  width: 30,
                                  height: 30,
                                  color: BauhausColors.blue,
                                  child: Icon(
                                    Icons.business,
                                    color: BauhausColors.white,
                                    size: 16,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  widget.company.toUpperCase(),
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w900,
                                    color: BauhausColors.blue,
                                    letterSpacing: 1,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          
                          const SizedBox(height: 20),
                        ],
                      ),
                    ),
                    
                    // Action buttons with enhanced styling
                    Container(
                      width: double.infinity,
                      height: 70,
                      child: Row(
                        children: [
                          // Continue button
                          Expanded(
                            flex: 2,
                            child: Container(
                              height: double.infinity,
                              color: BauhausColors.blue,
                              child: MaterialButton(
                                onPressed: () => Navigator.of(context).pop(false),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.play_arrow,
                                      color: BauhausColors.white,
                                      size: 24,
                                    ),
                                    const SizedBox(width: 8),
                                    Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Text(
                                          'CONTINUE',
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w900,
                                            color: BauhausColors.white,
                                            letterSpacing: 1,
                                          ),
                                        ),
                                        Text(
                                          'INTERVIEW',
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w600,
                                            color: BauhausColors.yellow,
                                            letterSpacing: 0.5,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          
                          // Exit button
                          Expanded(
                            child: Container(
                              height: double.infinity,
                              color: BauhausColors.red,
                              child: MaterialButton(
                                onPressed: () => Navigator.of(context).pop(true),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.exit_to_app,
                                      color: BauhausColors.white,
                                      size: 24,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'EXIT',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w900,
                                        color: BauhausColors.white,
                                        letterSpacing: 1,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // Callback to update UI state from manager
  void _updateState(Map<String, dynamic> state) {
    if (mounted) {
      setState(() {
        _currentQuestionIndex = state['currentQuestionIndex'] ?? _currentQuestionIndex;
        _isRecording = state['isRecording'] ?? _isRecording;
        _isAnalyzing = state['isAnalyzing'] ?? _isAnalyzing;
        _currentTranscript = state['currentTranscript'] ?? _currentTranscript;
        _speechStatus = state['speechStatus'] ?? _speechStatus;
        _recordingDuration = state['recordingDuration'] ?? _recordingDuration;
        _showingQuestion = state['showingQuestion'] ?? _showingQuestion;
        _showingCamera = state['showingCamera'] ?? _showingCamera;
        _countdown = state['countdown'] ?? _countdown;
        _countdownPaused = state['countdownPaused'] ?? _countdownPaused;
        _cameraInitialized = state['cameraInitialized'] ?? _cameraInitialized;
        _showingFinalCountdown = state['showingFinalCountdown'] ?? _showingFinalCountdown;
        _finalCountdown = state['finalCountdown'] ?? _finalCountdown;
        _ttsCompleted = state['ttsCompleted'] ?? _ttsCompleted;
        _recordingCanStart = state['recordingCanStart'] ?? _recordingCanStart;
        _countdownFinished = state['countdownFinished'] ?? _countdownFinished;
        _showingPreRecordingCountdown = state['showingPreRecordingCountdown'] ?? _showingPreRecordingCountdown;
        _preRecordingCountdown = state['preRecordingCountdown'] ?? _preRecordingCountdown;
        _preRecordingCountdownFinished = state['preRecordingCountdownFinished'] ?? _preRecordingCountdownFinished;
        _confidenceScore = state['confidenceScore'] ?? _confidenceScore;
        _emotion = state['emotion'] ?? _emotion;
        _fillerWords = state['fillerWords'] ?? _fillerWords;
        _sentimentScore = state['sentimentScore'] ?? _sentimentScore;
        _sentiment = state['sentiment'] ?? _sentiment;
        _analysisCardsOpacity = state['analysisCardsOpacity'] ?? _analysisCardsOpacity;
        _isSpeaking = state['isSpeaking'] ?? _isSpeaking;
      });
    }
  }

  // Navigate to completion screen
  void _navigateToCompletion(List<Map<String, dynamic>> allResults) {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (context) => CompletionScreen(
          allResults: allResults,
          company: widget.company,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Wrap the entire widget with WillPopScope to handle back button
    return WillPopScope(
      onWillPop: _onWillPop,
      child: _buildMainContent(),
    );
  }

  Widget _buildMainContent() {
    if (_showingQuestion) {
      return _buildQuestionScreen();
    } else if (_showingCamera) {
      return _buildCameraScreen();
    } else {
      return _buildLoadingScreen();
    }
  }

  Widget _buildQuestionScreen() {
    return Scaffold(
      backgroundColor: BauhausColors.lightGray,
      body: SafeArea(
        child: Column(
          children: [
            // Bauhaus header with geometric elements
            Container(
              width: double.infinity,
              height: 160,
              color: BauhausColors.blue,
              child: Stack(
                children: [
                  // Yellow triangle
                  Positioned(
                    top: 20,
                    right: 20,
                    child: CustomPaint(
                      size: Size(60, 60),
                      painter: TrianglePainter(BauhausColors.yellow),
                    ),
                  ),
                  // Red circle
                  Positioned(
                    bottom: 10,
                    left: 20,
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: BauhausColors.red,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),

                  // Title and progress
                  Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'QUESTION ${_currentQuestionIndex + 1}/${widget.questions.length}',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                            color: BauhausColors.white,
                            letterSpacing: 3,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          widget.company.toUpperCase(),
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: BauhausColors.yellow,
                            letterSpacing: 2,
                          ),
                        ),
                        const SizedBox(height: 16),
                        // Bauhaus progress bar
                        Container(
                          width: 200,
                          height: 8,
                          decoration: BoxDecoration(
                            border: Border.all(color: BauhausColors.white, width: 2),
                          ),
                          child: LinearProgressIndicator(
                            value: (_currentQuestionIndex + 1) / widget.questions.length,
                            backgroundColor: Colors.transparent,
                            valueColor: AlwaysStoppedAnimation<Color>(BauhausColors.yellow),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${((_currentQuestionIndex + 1) / widget.questions.length * 100).round()}% COMPLETE',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: BauhausColors.white,
                            letterSpacing: 1,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    // Question display with Bauhaus styling
                    Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        border: Border.all(color: BauhausColors.black, width: 4),
                      ),
                      child: Column(
                        children: [
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            color: BauhausColors.yellow,
                            child: Row(
                              children: [
                                Container(
                                  width: 40,
                                  height: 40,
                                  color: BauhausColors.black,
                                  child: Icon(
                                    Icons.quiz,
                                    color: BauhausColors.white,
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Text(
                                  'QUESTION',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w900,
                                    color: BauhausColors.black,
                                    letterSpacing: 2,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(24),
                            color: BauhausColors.white,
                            child: Text(
                              widget.questions[_currentQuestionIndex],
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w600,
                                color: BauhausColors.black,
                                height: 1.4,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 30),
                    
                    // Countdown with Bauhaus geometric design
                    Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        border: Border.all(color: BauhausColors.black, width: 4),
                      ),
                      child: Column(
                        children: [
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            color: _countdownPaused ? BauhausColors.yellow : BauhausColors.red,
                            child: Text(
                              _countdownPaused ? 'PAUSED' : 'COUNTDOWN',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                                color: _countdownPaused ? BauhausColors.black : BauhausColors.white,
                                letterSpacing: 2,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(30),
                            color: BauhausColors.white,
                            child: Column(
                              children: [
                                // Countdown circle with Bauhaus styling
                                Container(
                                  width: 120,
                                  height: 120,
                                  decoration: BoxDecoration(
                                    border: Border.all(
                                      color: _countdownPaused ? BauhausColors.yellow : BauhausColors.red,
                                      width: 6,
                                    ),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Center(
                                    child: Text(
                                      '$_countdown',
                                      style: TextStyle(
                                        fontSize: 48,
                                        fontWeight: FontWeight.w900,
                                        color: _countdownPaused ? BauhausColors.yellow : BauhausColors.red,
                                      ),
                                    ),
                                  ),
                                ),
                                
                                const SizedBox(height: 20),
                                
                                Text(
                                  _countdownPaused 
                                      ? 'INTERVIEW PAUSED\nCLICK RESUME TO CONTINUE'
                                      : 'INTERVIEWER WILL ASK QUESTION\nWHEN COUNTDOWN REACHES 0',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: BauhausColors.black,
                                    letterSpacing: 1,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                
                                const SizedBox(height: 24),
                                
                                // Control buttons with Bauhaus styling
                                Row(
                                  children: [
                                    Expanded(
                                      child: Container(
                                        height: 50,
                                        color: _countdownPaused ? BauhausColors.blue : BauhausColors.yellow,
                                        child: MaterialButton(
                                          onPressed: () => _manager.pauseCountdown(),
                                          child: Text(
                                            _countdownPaused ? 'RESUME' : 'PAUSE',
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w900,
                                              color: _countdownPaused ? BauhausColors.white : BauhausColors.black,
                                              letterSpacing: 1,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Container(
                                        height: 50,
                                        color: BauhausColors.red,
                                        child: MaterialButton(
                                          onPressed: () => _manager.startNow(),
                                          child: Text(
                                            'BEGIN NOW',
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w900,
                                              color: BauhausColors.white,
                                              letterSpacing: 1,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingScreen() {
    return Scaffold(
      backgroundColor: BauhausColors.black,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                border: Border.all(color: BauhausColors.white, width: 4),
                shape: BoxShape.circle,
              ),
              child: CircularProgressIndicator(
                color: BauhausColors.yellow,
                strokeWidth: 6,
              ),
            ),
            const SizedBox(height: 30),
            Text(
              'PREPARING CAMERA...',
              style: TextStyle(
                color: BauhausColors.white,
                fontSize: 18,
                fontWeight: FontWeight.w900,
                letterSpacing: 2,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCameraScreen() {
    if (!_cameraInitialized) {
      return _buildLoadingScreen();
    }

    return Scaffold(
      backgroundColor: BauhausColors.black,
      body: Stack(
        children: [
          // Camera preview (NATURAL VIEW - no mirroring)
          Positioned.fill(
            child: _manager.getCameraPreview(),
          ),
          
          // Question header
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: EdgeInsets.only(
                top: MediaQuery.of(context).padding.top + 16,
                left: 16,
                right: 16,
                bottom: 16,
              ),
              decoration: BoxDecoration(
                color: BauhausColors.black.withOpacity(0.8),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        color: BauhausColors.yellow,
                        child: Center(
                          child: Text(
                            '${_currentQuestionIndex + 1}',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              color: BauhausColors.black,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Text(
                          'Q${_currentQuestionIndex + 1}/${widget.questions.length}',
                          style: TextStyle(
                            color: BauhausColors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 2,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      border: Border.all(color: BauhausColors.white, width: 2),
                    ),
                    child: Text(
                      widget.questions[_currentQuestionIndex],
                      style: TextStyle(
                        color: BauhausColors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          // Analysis indicators with smart opacity and smooth transitions
          Positioned(
            right: 16,
            top: MediaQuery.of(context).padding.top + 200,
            child: AnimatedOpacity(
              opacity: _analysisCardsOpacity,
              duration: const Duration(milliseconds: 400),
              curve: Curves.easeInOut,
              child: Column(
                children: [
                  _buildBauhausAnalysisCard(
                    'HD',
                    'CAMERA',
                    BauhausColors.yellow,
                    Icons.camera_front,
                  ),
                  const SizedBox(height: 12),
                  _buildBauhausAnalysisCard(
                    '${_confidenceScore.round()}%',
                    'CONFIDENCE',
                    _confidenceScore > 70 ? BauhausColors.blue : BauhausColors.red,
                    Icons.psychology,
                  ),
                  const SizedBox(height: 12),
                  _buildBauhausAnalysisCard(
                    _emotion.toUpperCase(),
                    'EMOTION',
                    _emotion == 'Confident' ? BauhausColors.blue : 
                    _emotion == 'Nervous' ? BauhausColors.red : BauhausColors.yellow,
                    Icons.sentiment_satisfied,
                  ),
                  const SizedBox(height: 12),
                  _buildBauhausAnalysisCard(
                    '${_fillerWords.length}',
                    'FILLERS',
                    _fillerWords.length <= 2 ? BauhausColors.blue : BauhausColors.red,
                    Icons.warning,
                  ),
                ],
              ),
            ),
          ),
          
          // Bottom controls with Bauhaus styling
          Positioned(
            bottom: 28,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: BauhausColors.black.withOpacity(0.8),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_isRecording) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        border: Border.all(color: BauhausColors.red, width: 3),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                width: 16,
                                height: 16,
                                decoration: BoxDecoration(
                                  color: _speechStatus == 'listening' ? BauhausColors.red : BauhausColors.yellow,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                _getSpeechStatusText().toUpperCase(),
                                style: TextStyle(
                                  color: BauhausColors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 2,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            _currentTranscript.isEmpty 
                                ? 'INTERVIEW IN PROGRESS... ${_formatDuration(_recordingDuration)} | SHARE YOUR THOUGHTS!' 
                                : 'GREAT RESPONSE! ${_formatDuration(_recordingDuration)} | WORDS: ${_currentTranscript.split(' ').where((w) => w.isNotEmpty).length}',
                            style: TextStyle(
                              color: _currentTranscript.isEmpty ? BauhausColors.yellow : BauhausColors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 1,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          if (_currentTranscript.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(12),
                              color: BauhausColors.white.withOpacity(0.1),
                              child: Text(
                                _currentTranscript,
                                style: TextStyle(
                                  color: BauhausColors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      width: double.infinity,
                      height: 60,
                      color: BauhausColors.red,
                      child: MaterialButton(
                        onPressed: () => _manager.stopRecording(),
                        child: Text(
                          'COMPLETE ANSWER',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            color: BauhausColors.white,
                            letterSpacing: 2,
                          ),
                        ),
                      ),
                    ),
                  ] else ...[
                    // Show TTS status when not recording AND TTS hasn't completed
                    if (!_ttsCompleted && !_recordingCanStart) ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          border: Border.all(color: BauhausColors.blue, width: 3),
                        ),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  width: 16,
                                  height: 16,
                                  decoration: BoxDecoration(
                                    color: BauhausColors.blue,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  'INTERVIEWER ASKING QUESTION...',
                                  style: TextStyle(
                                    color: BauhausColors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 2,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'PLEASE LISTEN - YOUR TURN TO RESPOND NEXT',
                              style: TextStyle(
                                color: BauhausColors.blue,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 1,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                    
                    // Only show skip button AFTER TTS has completed
                    if (_ttsCompleted || _recordingCanStart) ...[
                      Row(
                        children: [
                          const SizedBox(width: 10),
                          Expanded(
                            child: Container(
                              height: 50,
                              color: BauhausColors.gray,
                              child: MaterialButton(
                                onPressed: () => _manager.skipQuestion(),
                                child: Text(
                                  'SKIP',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w900,
                                    color: BauhausColors.white,
                                    letterSpacing: 1,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ],
              ),
            ),
          ),
          
          // Pre-recording countdown display (3, 2, 1)
          if (_showingPreRecordingCountdown)
            Positioned(
              left: 20,
              top: MediaQuery.of(context).size.height * 0.35,
              child: AnimatedScale(
                scale: 1.0,
                duration: const Duration(milliseconds: 150),
                child: Container(
                  width: 100,
                  decoration: BoxDecoration(
                    color: BauhausColors.black.withOpacity(0.85),
                    border: Border.all(color: BauhausColors.blue.withOpacity(0.9), width: 3),
                    boxShadow: [
                      BoxShadow(
                        color: BauhausColors.blue.withOpacity(0.4),
                        blurRadius: 15,
                        spreadRadius: 3,
                      ),
                      BoxShadow(
                        color: Colors.black.withOpacity(0.6),
                        blurRadius: 8,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Container(
                        width: double.infinity,
                        height: 40,
                        color: BauhausColors.blue.withOpacity(0.9),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.mic,
                              color: BauhausColors.white.withOpacity(0.95),
                              size: 18,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'START',
                              style: TextStyle(
                                color: BauhausColors.white.withOpacity(0.95),
                                fontSize: 11,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        color: BauhausColors.black.withOpacity(0.85),
                        child: Column(
                          children: [
                            Text(
                              _preRecordingCountdown >= 0 ? '$_preRecordingCountdown' : '0',
                              style: TextStyle(
                                color: BauhausColors.blue.withOpacity(0.95),
                                fontSize: 48,
                                fontWeight: FontWeight.w900,
                                shadows: [
                                  Shadow(
                                    color: Colors.black.withOpacity(0.6),
                                    blurRadius: 4,
                                    offset: Offset(2, 2),
                                  ),
                                  Shadow(
                                    color: BauhausColors.blue.withOpacity(0.3),
                                    blurRadius: 8,
                                    offset: Offset(0, 0),
                                  ),
                                ],
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              _preRecordingCountdown == 1 ? 'SEC' : 'SECS',
                              style: TextStyle(
                                color: BauhausColors.blue.withOpacity(0.8),
                                fontSize: 9,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.5,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          
          // Final countdown display
          if (_showingFinalCountdown)
            Positioned(
              left: 20,
              top: MediaQuery.of(context).size.height * 0.35,
              child: AnimatedScale(
                scale: 1.0,
                duration: const Duration(milliseconds: 150),
                child: Container(
                  width: 100,
                  decoration: BoxDecoration(
                    color: BauhausColors.black.withOpacity(0.85),
                    border: Border.all(color: BauhausColors.red.withOpacity(0.9), width: 3),
                    boxShadow: [
                      BoxShadow(
                        color: BauhausColors.red.withOpacity(0.4),
                        blurRadius: 15,
                        spreadRadius: 3,
                      ),
                      BoxShadow(
                        color: Colors.black.withOpacity(0.6),
                        blurRadius: 8,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Container(
                        width: double.infinity,
                        height: 40,
                        color: BauhausColors.red.withOpacity(0.9),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.timer,
                              color: BauhausColors.white.withOpacity(0.95),
                              size: 18,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'TIME',
                              style: TextStyle(
                                color: BauhausColors.white.withOpacity(0.95),
                                fontSize: 11,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        color: BauhausColors.black.withOpacity(0.85),
                        child: Column(
                          children: [
                            Text(
                              _finalCountdown >= 0 ? '$_finalCountdown' : '0',
                              style: TextStyle(
                                color: BauhausColors.red.withOpacity(0.95),
                                fontSize: 48,
                                fontWeight: FontWeight.w900,
                                shadows: [
                                  Shadow(
                                    color: Colors.black.withOpacity(0.6),
                                    blurRadius: 4,
                                    offset: Offset(2, 2),
                                  ),
                                  Shadow(
                                    color: BauhausColors.red.withOpacity(0.3),
                                    blurRadius: 8,
                                    offset: Offset(0, 0),
                                  ),
                                ],
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              _finalCountdown == 1 ? 'SEC' : 'SECS',
                              style: TextStyle(
                                color: BauhausColors.red.withOpacity(0.8),
                                fontSize: 9,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.5,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBauhausAnalysisCard(String value, String label, Color color, IconData icon) {
    return Container(
      width: 80,
      decoration: BoxDecoration(
        border: Border.all(color: BauhausColors.white, width: 2),
      ),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            height: 40,
            color: color,
            child: Icon(
              icon,
              color: BauhausColors.white,
              size: 20,
            ),
          ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(8),
            color: BauhausColors.black,
            child: Column(
              children: [
                Text(
                  value,
                  style: TextStyle(
                    color: BauhausColors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                  ),
                  textAlign: TextAlign.center,
                ),
                Text(
                  label,
                  style: TextStyle(
                    color: color,
                    fontSize: 8,
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatDuration(int seconds) {
    int minutes = seconds ~/ 60;
    int remainingSeconds = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  String _getSpeechStatusText() {
    switch (_speechStatus) {
      case 'listening':
        return _currentTranscript.isEmpty ? 'LISTENING FOR YOUR ANSWER' : 'CAPTURING YOUR RESPONSE';
      case 'notListening':
        return 'READY TO LISTEN';
      case 'unavailable':
        return 'MICROPHONE UNAVAILABLE';
      case 'done':
        return 'PROCESSING YOUR ANSWER...';
      default:
        return 'INTERVIEWER LISTENING';
    }
  }
}

// Custom painter for triangle
class TrianglePainter extends CustomPainter {
  final Color color;
  
  TrianglePainter(this.color);
  
  @override
  void paint(Canvas canvas, Size size) {
    Paint paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    
    Path path = Path();
    path.moveTo(size.width / 2, 0);
    path.lineTo(0, size.height);
    path.lineTo(size.width, size.height);
    path.close();
    
    canvas.drawPath(path, paint);
  }
  
  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}