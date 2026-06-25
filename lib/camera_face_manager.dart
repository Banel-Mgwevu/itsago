import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:async';
import 'dart:io';
import 'audio_speech_manager.dart';

class CameraFaceManager {
  final List<CameraDescription> cameras;
  final Function()              onCameraInitialized;
  final Function(bool)          onFaceDetectionChange;
  final Function(bool)          onFaceWarning;

  late CameraController _cameraController;
  bool _cameraInitialized = false;
  bool _disposed          = false;

  late FaceDetector _faceDetector;
  bool      _faceDetectionInitialized = false;
  bool      _isProcessingImage        = false;
  bool      _faceDetected             = false;
  DateTime? _lastFaceDetectedTime;
  Timer?    _faceDetectionTimer;
  Timer?    _processingTimer;
  Timer?    _noFaceWarningTimer;
  bool      _showingFaceWarning       = false;
  bool      _faceWarningTtsPlaying    = false;
  int       _noFaceWarningCount       = 0;
  int       _eyeContactFrames         = 0; // frames where eyes are open/on camera
  int       _totalDetectionFrames     = 0; // total frames with face detected
  double    _eyeContactScore          = 100.0; // 0-100

  AudioSpeechManager? _audio;

  CameraFaceManager({
    required this.cameras,
    required this.onCameraInitialized,
    required this.onFaceDetectionChange,
    required this.onFaceWarning,
  });

  // ── Public API ───────────────────────────────────────────────

  Future<void> initializeCamera() async {
    if (_cameraInitialized || _disposed) return;
    await Permission.camera.request();
    await Permission.microphone.request();

    CameraDescription front = cameras.firstWhere(
      (c) => c.lensDirection == CameraLensDirection.front,
      orElse: () => cameras.first);

    _cameraController = CameraController(
      front, ResolutionPreset.high,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.jpeg);

    try {
      await _cameraController.initialize();
      await _cameraController.setFlashMode(FlashMode.off);
      await _cameraController.setFocusMode(FocusMode.auto);
      await _cameraController.setExposureMode(ExposureMode.auto);
    } catch (_) {
      _cameraController = CameraController(
          front, ResolutionPreset.medium, enableAudio: false);
      await _cameraController.initialize();
    }
    _cameraInitialized = true;
    onCameraInitialized();
  }

  Future<void> initializeFaceDetection() async {
    try {
      _faceDetector = FaceDetector(options: FaceDetectorOptions(
        enableContours: false, enableClassification: true,
        enableLandmarks: false, enableTracking: false,
        minFaceSize: 0.1,
        performanceMode: FaceDetectorMode.fast));
      _faceDetectionInitialized = true;
      _lastFaceDetectedTime = DateTime.now();
    } catch (e) {
      if (kDebugMode) print('Face detection init failed: $e');
      _faceDetectionInitialized = false;
    }
  }

  void setAudioSpeechManager(AudioSpeechManager audio) => _audio = audio;

  void startFaceDetection() {
    if (_disposed) return;
    if (!_faceDetectionInitialized) {
      initializeFaceDetection().then((_) {
        if (_faceDetectionInitialized && !_disposed) _startInternal();
      });
    } else {
      _startInternal();
    }
  }

  void stopFaceDetection() {
    _faceDetectionTimer?.cancel();
    _processingTimer?.cancel();
    _noFaceWarningTimer?.cancel();
    _showingFaceWarning = false;
    _faceDetected       = false;
    onFaceDetectionChange(false);
    onFaceWarning(false);
  }

  void stopAll() {
    _disposed = true;
    stopFaceDetection();
  }

  void resetForNewQuestion() {
    _noFaceWarningCount    = 0;
    _eyeContactFrames      = 0;
    _totalDetectionFrames  = 0;
    _eyeContactScore       = 100.0;
    _showingFaceWarning    = false;
    _faceWarningTtsPlaying = false;
    onFaceWarning(false);
  }

  void dispose() {
    _disposed = true;
    stopFaceDetection();
    if (_cameraInitialized) {
      try { _cameraController.dispose(); } catch (_) {}
    }
    if (_faceDetectionInitialized) {
      try { _faceDetector.close(); } catch (_) {}
    }
  }

  Widget getCameraPreview() {
    if (_cameraInitialized && _cameraController.value.isInitialized) {
      return CameraPreview(_cameraController);
    }
    return Container(color: Colors.black);
  }

  bool get faceDetected        => _faceDetected;
  bool get showingFaceWarning  => _showingFaceWarning;
  bool get faceWarningTtsPlaying => _faceWarningTtsPlaying;
  int    get noFaceWarningCount  => _noFaceWarningCount;
  double get eyeContactScore      => _eyeContactScore;
  int    get eyeContactFrames     => _eyeContactFrames;
  int    get totalDetectionFrames => _totalDetectionFrames;
  bool get cameraInitialized   => _cameraInitialized;

  // ── Internal ─────────────────────────────────────────────────

  void _startInternal() {
    if (_disposed) return;
    _lastFaceDetectedTime = DateTime.now();
    _noFaceWarningCount   = 0;

    _faceDetectionTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      if (_disposed) { _faceDetectionTimer?.cancel(); return; }
      _checkFaceDetection();
    });

    _processingTimer = Timer.periodic(const Duration(milliseconds: 500), (_) {
      if (_disposed) { _processingTimer?.cancel(); return; }
      if (!_isProcessingImage) _processFrame();
    });
  }

  Future<void> _processFrame() async {
    if (_disposed || !_cameraInitialized) return;
    if (_isProcessingImage) return;
    if (!_cameraController.value.isInitialized) return;

    _isProcessingImage = true;
    try {
      final xfile     = await _cameraController.takePicture();
      final inputImg  = InputImage.fromFilePath(xfile.path);
      final faces     = await _faceDetector.processImage(inputImg);
      final detected  = faces.isNotEmpty;

      if (detected != _faceDetected) {
        _faceDetected = detected;
        onFaceDetectionChange(_faceDetected);
      }
      if (detected && faces.isNotEmpty) {
        _lastFaceDetectedTime = DateTime.now();
        if (_showingFaceWarning) {
          _showingFaceWarning = false;
          onFaceWarning(false);
        }
        // Eye contact tracking
        final face = faces.first;
        final leftEye  = face.leftEyeOpenProbability  ?? 1.0;
        final rightEye = face.rightEyeOpenProbability ?? 1.0;
        final eyesOpen = leftEye > 0.4 && rightEye > 0.4;
        _totalDetectionFrames++;
        if (eyesOpen) _eyeContactFrames++;
        // Update rolling eye contact score
        if (_totalDetectionFrames > 0) {
          _eyeContactScore = (_eyeContactFrames / _totalDetectionFrames) * 100.0;
        }
      }
      try { await File(xfile.path).delete(); } catch (_) {}
    } on CameraException catch (_) {
      _disposed = true;
      _faceDetectionTimer?.cancel();
      _processingTimer?.cancel();
    } catch (e) {
      if (kDebugMode) print('Face detection error: $e');
    } finally {
      _isProcessingImage = false;
    }
  }

  void _checkFaceDetection() {
    if (_disposed || _lastFaceDetectedTime == null) return;
    final secs = DateTime.now().difference(_lastFaceDetectedTime!).inSeconds;
    if (kDebugMode && secs > 0 && secs % 30 == 0) {
      print('No face detected for $secs seconds');
    }
    if (!_faceDetected && secs > 10 && !_showingFaceWarning) {
      _showingFaceWarning = true;
      _noFaceWarningCount++;
      onFaceWarning(true);
    } else if (_faceDetected && _showingFaceWarning) {
      _showingFaceWarning = false;
      onFaceWarning(false);
    }
  }
}

