import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:async';
import 'audio_speech_manager.dart';

class CameraFaceManager {
  // Constructor dependencies
  final List<CameraDescription> cameras;
  final Function() onCameraInitialized;
  final Function(bool faceDetected) onFaceDetectionChange;
  final Function(bool showingWarning) onFaceWarning;

  // Camera controller
  late CameraController _cameraController;
  bool _cameraInitialized = false;

  // Face detection variables
  late FaceDetector _faceDetector;
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

  // Audio reference for face warnings
  AudioSpeechManager? _audioSpeechManager;

  // Face detection warning messages
  final List<String> _faceWarningMessages = [
    "Hi, are you there? I don't see you on camera.",
    "Please make sure you're visible in the camera frame.",
    "I can't see your face. Please position yourself in front of the camera.",
    "Hi, get back there, I do not see you.",
    "Please ensure your face is visible for the interview to continue.",
  ];

  CameraFaceManager({
    required this.cameras,
    required this.onCameraInitialized,
    required this.onFaceDetectionChange,
    required this.onFaceWarning,
  });

  // Public interface methods
  Future<void> initializeCamera() async {
    if (_cameraInitialized) return;

    var cameraStatus = await Permission.camera.request();
    var micStatus = await Permission.microphone.request();
    
    if (kDebugMode) {
      print('Camera permission: $cameraStatus');
    }
    if (kDebugMode) {
      print('Microphone permission: $micStatus');
    }
    
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
      
      if (kDebugMode) {
        print('Selfie camera initialized successfully with high quality');
      }
      _cameraInitialized = true;
      onCameraInitialized();
    } catch (e) {
      if (kDebugMode) {
        print('Camera initialization error: $e');
      }
      // Fallback to medium quality
      _cameraController = CameraController(
        frontCamera,
        ResolutionPreset.medium,
        enableAudio: false,
      );
      await _cameraController.initialize();
      _cameraInitialized = true;
      onCameraInitialized();
      if (kDebugMode) {
        print('Fallback: Camera initialized with medium quality');
      }
    }
  }

  Future<void> initializeFaceDetection() async {
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
      if (kDebugMode) {
        print('👤 Face detection initialized successfully');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Face detection initialization failed: $e');
      }
      _faceDetectionInitialized = false;
    }
  }

  void setAudioSpeechManager(AudioSpeechManager audioManager) {
    _audioSpeechManager = audioManager;
  }

  void startFaceDetection() {
    if (!_faceDetectionInitialized) {
      initializeFaceDetection().then((_) {
        if (_faceDetectionInitialized) {
          _startFaceDetectionInternal();
        }
      });
    } else {
      _startFaceDetectionInternal();
    }
  }

  void stopFaceDetection() {
    if (kDebugMode) {
      print('👤 Stopping face detection');
    }
    _faceDetectionTimer?.cancel();
    _noFaceWarningTimer?.cancel();
    _faceDetectionProcessingTimer?.cancel();
    
    _showingFaceWarning = false;
    _faceDetected = false;
    onFaceDetectionChange(false);
    onFaceWarning(false);
  }

  void stopAll() {
    stopFaceDetection();
  }

  Widget getCameraPreview() {
    if (_cameraInitialized && _cameraController.value.isInitialized) {
      return CameraPreview(_cameraController);
    }
    return Container(color: Colors.black);
  }

  void resetForNewQuestion() {
    _noFaceWarningCount = 0;
    _showingFaceWarning = false;
    _faceWarningTtsPlaying = false;
    onFaceWarning(false);
  }

  void dispose() {
    if (kDebugMode) {
      print('🧹 Disposing CameraFaceManager');
    }
    
    if (_cameraInitialized) {
      _cameraController.dispose();
    }
    
    if (_faceDetectionInitialized) {
      _faceDetector.close();
    }
    
    stopFaceDetection();
    
    if (kDebugMode) {
      print('🧹 CameraFaceManager disposed successfully');
    }
  }

  // Getters for state
  bool get faceDetected => _faceDetected;
  bool get showingFaceWarning => _showingFaceWarning;
  bool get faceWarningTtsPlaying => _faceWarningTtsPlaying;
  int get noFaceWarningCount => _noFaceWarningCount;
  bool get cameraInitialized => _cameraInitialized;

  // Private implementation methods
  void _startFaceDetectionInternal() {
    if (!_faceDetectionInitialized) return;
    
    if (kDebugMode) {
      print('👤 Starting face detection monitoring');
    }
    _lastFaceDetectedTime = DateTime.now();
    _noFaceWarningCount = 0;
    
    // Start face detection timer - checks every 2 seconds
    _faceDetectionTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
      _checkFaceDetection();
    });
    
    // Start processing camera frames for face detection
    _faceDetectionProcessingTimer = Timer.periodic(const Duration(milliseconds: 500), (timer) {
      if (_isProcessingImage) {
        return;
      }
      
      _processCameraFrameForFaceDetection();
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
          if (kDebugMode) {
            print('👤 ✅ Face detected!');
          }
          _faceDetected = true;
          onFaceDetectionChange(true);
          
          // Hide face warning if it was showing
          if (_showingFaceWarning) {
            _showingFaceWarning = false;
            onFaceWarning(false);
            _noFaceWarningTimer?.cancel();
          }
        }
      } else {
        // No face detected
        if (_faceDetected) {
          if (kDebugMode) {
            print('👤 ❌ Face lost');
          }
          _faceDetected = false;
          onFaceDetectionChange(false);
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Face detection processing error: $e');
      }
    } finally {
      _isProcessingImage = false;
    }
  }

  void _checkFaceDetection() {
    if (_lastFaceDetectedTime == null || _faceWarningTtsPlaying) return;
    
    final timeSinceLastFace = DateTime.now().difference(_lastFaceDetectedTime!);
    
    if (timeSinceLastFace.inSeconds >= 6) {
      if (kDebugMode) {
        print('👤 ⚠️ No face detected for ${timeSinceLastFace.inSeconds} seconds');
      }
      _triggerFaceWarning();
    }
  }

  void _triggerFaceWarning() {
    if (_showingFaceWarning || _faceWarningTtsPlaying) {
      return; // Already showing warning or TTS is playing
    }
    
    if (kDebugMode) {
      print('👤 🚨 Triggering face detection warning');
    }
    
    _showingFaceWarning = true;
    onFaceWarning(true);
    _faceWarningTtsPlaying = true;
    
    // Select a random warning message
    final randomMessage = _faceWarningMessages[_noFaceWarningCount % _faceWarningMessages.length];
    _noFaceWarningCount++;
    
    // Play TTS warning
    _playFaceWarningTTS(randomMessage);
    
    // Auto-hide warning after 4 seconds
    _noFaceWarningTimer = Timer(const Duration(seconds: 4), () {
      if (_showingFaceWarning) {
        _showingFaceWarning = false;
        onFaceWarning(false);
      }
    });
  }

  Future<void> _playFaceWarningTTS(String message) async {
    try {
      if (kDebugMode) {
        print('👤 🔊 Playing face warning TTS: $message');
      }
      
      if (_audioSpeechManager != null) {
        await _audioSpeechManager!.speakFaceWarning(message);
      } else {
        if (kDebugMode) {
          print('👤 ⚠️ No audio manager available for face warning TTS');
        }
      }
      
      // Reset flag after warning
      Timer(const Duration(seconds: 3), () {
        _faceWarningTtsPlaying = false;
      });
      
    } catch (e) {
      if (kDebugMode) {
        print('❌ Face warning TTS error: $e');
      }
      _faceWarningTtsPlaying = false;
    }
  }
}