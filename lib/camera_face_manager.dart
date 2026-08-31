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
  /// Optional: called if the camera can't be initialized at all (no
  /// camera hardware available, or the device's camera service failed
  /// to enumerate any camera). Defaults to a no-op so existing callers
  /// don't need to change. The interview can still continue audio-only
  /// when this fires.
  final Function(String message) onCameraError;

  late CameraController _cameraController;
  bool _cameraInitialized = false;
  bool _disposed          = false;

  late FaceDetector _faceDetector;
  bool      _faceDetectionInitialized = false;
  bool      _isProcessingImage        = false;
  bool      _streamingImages          = false;
  DateTime  _lastFrameProcessedAt     = DateTime.fromMillisecondsSinceEpoch(0);
  bool      _faceDetected             = false;
  DateTime? _lastFaceDetectedTime;
  Timer?    _faceDetectionTimer;
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
    Function(String message)? onCameraError,
  }) : onCameraError = onCameraError ?? ((_) {});

  // ── Public API ───────────────────────────────────────────────

  Future<void> initializeCamera() async {
    if (_cameraInitialized || _disposed) return;
    try {
      await Permission.camera.request();
      await Permission.microphone.request();

      // `cameras` is captured once at app startup (splash screen). On some
      // devices - this Huawei included, per its "Connecting to camera
      // service" logs - camera enumeration can be slow or transiently
      // empty. cameras.first on an empty list throws "Bad state: No
      // element" with no useful message, so re-scan once before giving up
      // rather than crashing.
      List<CameraDescription> available = cameras;
      if (available.isEmpty) {
        print('CameraFaceManager: camera list was empty, re-scanning...');
        try {
          available = await availableCameras();
        } catch (e) {
          print('CameraFaceManager: availableCameras() re-scan failed: $e');
        }
      }

      if (available.isEmpty) {
        print('CameraFaceManager: no camera hardware available');
        onCameraError('No camera available on this device');
        return;
      }

      final front = available.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => available.first);

      _cameraController = CameraController(
        front, ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: Platform.isAndroid
            ? ImageFormatGroup.nv21
            : ImageFormatGroup.bgra8888);

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
    } catch (e) {
      // Last-resort guard: never let camera setup crash the interview -
      // report it and let the caller continue audio-only instead.
      print('CameraFaceManager: initializeCamera failed: $e');
      onCameraError('Camera initialization failed: $e');
    }
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
    _noFaceWarningTimer?.cancel();
    _stopImageStream();
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

    // Read frames straight off the camera's live video stream instead of
    // calling takePicture() repeatedly. takePicture() does a full JPEG
    // still capture each time (autofocus/AE convergence, disk write,
    // decode) and was previously called every 500ms - that saturated the
    // camera hardware and platform channel badly enough to starve other
    // platform-channel work (including the speech recognizer) of a chance
    // to run, which is why nothing was being transcribed.
    if (!_streamingImages && _cameraInitialized && _cameraController.value.isInitialized) {
      _streamingImages = true;
      _cameraController.startImageStream(_onCameraImage);
    }
  }

  void _stopImageStream() {
    if (_streamingImages) {
      _streamingImages = false;
      try { _cameraController.stopImageStream(); } catch (_) {}
    }
  }

  void _onCameraImage(CameraImage image) {
    if (_disposed || _isProcessingImage) return;
    // The stream delivers frames at full camera FPS (often 30/s); face
    // detection doesn't need that many, so only process one roughly every
    // 500ms to keep CPU usage low.
    final now = DateTime.now();
    if (now.difference(_lastFrameProcessedAt) < const Duration(milliseconds: 500)) return;
    _lastFrameProcessedAt = now;
    _isProcessingImage = true;
    _processCameraImage(image).whenComplete(() => _isProcessingImage = false);
  }

  Future<void> _processCameraImage(CameraImage image) async {
    if (_disposed || !_cameraInitialized) return;
    try {
      final inputImg = _inputImageFromCameraImage(image);
      if (inputImg == null) return;
      final faces    = await _faceDetector.processImage(inputImg);
      final detected = faces.isNotEmpty;

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
    } on CameraException catch (_) {
      _disposed = true;
      _faceDetectionTimer?.cancel();
      _stopImageStream();
    } catch (e) {
      if (kDebugMode) print('Face detection error: $e');
    }
  }

  /// Converts a raw camera stream frame into the format ML Kit expects.
  /// Returns null for formats/layouts we can't handle so the caller just
  /// skips that frame rather than crashing.
  InputImage? _inputImageFromCameraImage(CameraImage image) {
    final sensorOrientation = _cameraController.description.sensorOrientation;
    final rotation = InputImageRotationValue.fromRawValue(sensorOrientation);
    if (rotation == null) return null;

    final format = InputImageFormatValue.fromRawValue(image.format.raw);
    if (format == null) return null;
    if (Platform.isAndroid && format != InputImageFormat.nv21) return null;
    if (Platform.isIOS && format != InputImageFormat.bgra8888) return null;

    if (image.planes.length != 1) return null;
    final plane = image.planes.first;

    return InputImage.fromBytes(
      bytes: plane.bytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: format,
        bytesPerRow: plane.bytesPerRow,
      ),
    );
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

