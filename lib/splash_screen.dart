import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:timezone/timezone.dart' as tz;
import 'dart:async';
import 'dart:math';
import 'main.dart';
import 'welcome_screen.dart';
import 'notification_service.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({Key? key}) : super(key: key);

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  
  late AnimationController _logoController;
  late AnimationController _textController;
  late AnimationController _geometryController;
  late AnimationController _pulseController;
  
  late Animation<double> _logoScale;
  late Animation<double> _logoOpacity;
  late Animation<double> _textOpacity;
  late Animation<double> _textSlide;
  late Animation<double> _redRectScale;
  late Animation<double> _blueCircleScale;
  late Animation<double> _yellowTriangleScale;
  late Animation<double> _pulseAnimation;
  late Animation<double> _lineAnimation;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _startAnimationSequence();
  }

  void _initializeAnimations() {
    // Logo animations
    _logoController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    
    _logoScale = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _logoController,
        curve: Curves.elasticOut,
      ),
    );
    
    _logoOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _logoController,
        curve: const Interval(0.0, 0.7, curve: Curves.easeOut),
      ),
    );

    // Text animations
    _textController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    
    _textOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _textController,
        curve: Curves.easeOut,
      ),
    );
    
    _textSlide = Tween<double>(begin: 30.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _textController,
        curve: Curves.easeOut,
      ),
    );

    // Geometry animations
    _geometryController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    
    _redRectScale = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _geometryController,
        curve: const Interval(0.0, 0.4, curve: Curves.bounceOut),
      ),
    );
    
    _blueCircleScale = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _geometryController,
        curve: const Interval(0.2, 0.6, curve: Curves.bounceOut),
      ),
    );
    
    _yellowTriangleScale = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _geometryController,
        curve: const Interval(0.4, 0.8, curve: Curves.bounceOut),
      ),
    );

    _lineAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _geometryController,
        curve: const Interval(0.6, 1.0, curve: Curves.easeOut),
      ),
    );

    // Pulse animation
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );
    
    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(
        parent: _pulseController,
        curve: Curves.easeInOut,
      ),
    );
  }

  void _startAnimationSequence() async {
    // Start geometry first
    _geometryController.forward();
    
    await Future.delayed(const Duration(milliseconds: 300));
    
    // Start logo
    _logoController.forward();
    
    await Future.delayed(const Duration(milliseconds: 600));
    
    // Start text
    _textController.forward();
    
    await Future.delayed(const Duration(milliseconds: 400));
    
    // Start subtle pulse
    _pulseController.repeat(reverse: true);
    
    // Wait for all animations to complete, then navigate
    await Future.delayed(const Duration(milliseconds: 2000));
    
    if (mounted) {
      _checkAuthAndNavigate();
    }
  }

  void _checkAuthAndNavigate() async {
    try {
      // Initialize cameras
      final cameras = await availableCameras();
      
      if (mounted) {
        // Check notification permissions first
        await _handleNotificationPermissions();
        
        // Check if user is already authenticated
        final user = FirebaseAuth.instance.currentUser;
        
        if (user != null) {
          // User is already signed in, go directly to setup
          Navigator.of(context).pushReplacement(
            PageRouteBuilder(
              pageBuilder: (context, animation, secondaryAnimation) =>
                  InterviewCoachApp(cameras: cameras),
              transitionsBuilder: (context, animation, secondaryAnimation, child) {
                return FadeTransition(opacity: animation, child: child);
              },
              transitionDuration: const Duration(milliseconds: 600),
            ),
          );
        } else {
          // User is not signed in, show welcome flow
          Navigator.of(context).pushReplacement(
            PageRouteBuilder(
              pageBuilder: (context, animation, secondaryAnimation) =>
                  WelcomeScreen(cameras: cameras),
              transitionsBuilder: (context, animation, secondaryAnimation, child) {
                return FadeTransition(opacity: animation, child: child);
              },
              transitionDuration: const Duration(milliseconds: 600),
            ),
          );
        }
      }
    } catch (e) {
      print('Error during initialization: $e');
      if (mounted) {
        Navigator.of(context).pushReplacement(
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) =>
                ErrorApp(message: 'INITIALIZATION FAILED: $e'),
            transitionsBuilder: (context, animation, secondaryAnimation, child) {
              return FadeTransition(opacity: animation, child: child);
            },
            transitionDuration: const Duration(milliseconds: 600),
          ),
        );
      }
    }
  }

  Future<void> _handleNotificationPermissions() async {
    final notificationService = NotificationService();
    final shouldRequest = await notificationService.checkAndRequestPermissions();
    
    if (!shouldRequest && mounted) {
      // Show dialog to ask user if they want to enable notifications
      final result = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return NotificationPermissionDialog(
            onAccept: () => Navigator.of(context).pop(true),
            onDecline: () => Navigator.of(context).pop(false),
          );
        },
      );
      
      if (result == true) {
        // User wants to enable, try requesting again
        await notificationService.checkAndRequestPermissions();
      }
    }
  }

  @override
  void dispose() {
    _logoController.dispose();
    _textController.dispose();
    _geometryController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BauhausColors.white,
      body: AnimatedBuilder(
        animation: Listenable.merge([
          _logoController,
          _textController,
          _geometryController,
          _pulseController,
        ]),
        builder: (context, child) {
          return Stack(
            children: [
              // Clean geometric elements
              
              // Red rectangle - top left
              Positioned(
                top: 80,
                left: 40,
                child: Transform.scale(
                  scale: _redRectScale.value,
                  child: Container(
                    width: 60,
                    height: 20,
                    decoration: BoxDecoration(
                      color: BauhausColors.red,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ),
              
              // Blue circle - top right
              Positioned(
                top: 100,
                right: 50,
                child: Transform.scale(
                  scale: _blueCircleScale.value,
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: BauhausColors.blue,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ),
              
              // Yellow triangle - bottom left
              Positioned(
                bottom: 120,
                left: 60,
                child: Transform.scale(
                  scale: _yellowTriangleScale.value,
                  child: CustomPaint(
                    size: const Size(30, 30),
                    painter: SimpleTrianglePainter(BauhausColors.yellow),
                  ),
                ),
              ),

              // Animated lines
              Positioned(
                bottom: 200,
                right: 40,
                child: Opacity(
                  opacity: _lineAnimation.value,
                  child: Container(
                    width: 80 * _lineAnimation.value,
                    height: 3,
                    color: BauhausColors.black,
                  ),
                ),
              ),

              Positioned(
                top: 180,
                left: 30,
                child: Opacity(
                  opacity: _lineAnimation.value,
                  child: Container(
                    width: 3,
                    height: 60 * _lineAnimation.value,
                    color: BauhausColors.black,
                  ),
                ),
              ),
              
              // Main logo and content
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Animated logo
                    Transform.scale(
                      scale: _logoScale.value * _pulseAnimation.value,
                      child: Opacity(
                        opacity: _logoOpacity.value,
                        child: Container(
                          width: 120,
                          height: 120,
                          decoration: BoxDecoration(
                            color: BauhausColors.white,
                            border: Border.all(
                              color: BauhausColors.black,
                              width: 4,
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Stack(
                            children: [
                              // Minimal geometric pattern
                              Positioned(
                                top: 15,
                                right: 15,
                                child: Container(
                                  width: 20,
                                  height: 20,
                                  decoration: BoxDecoration(
                                    color: BauhausColors.red,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              ),
                              Positioned(
                                bottom: 15,
                                left: 15,
                                child: Container(
                                  width: 15,
                                  height: 25,
                                  color: BauhausColors.yellow,
                                ),
                              ),
                              Positioned(
                                top: 15,
                                left: 15,
                                child: Container(
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    color: BauhausColors.blue,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              ),
                              // App initial
                              Center(
                                child: Text(
                                  'I',
                                  style: TextStyle(
                                    fontSize: 48,
                                    fontWeight: FontWeight.w900,
                                    color: BauhausColors.black,
                                    letterSpacing: 2,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 40),
                    
                    // App name with clean typography
                    Transform.translate(
                      offset: Offset(0, _textSlide.value),
                      child: Opacity(
                        opacity: _textOpacity.value,
                        child: Column(
                          children: [
                            Text(
                              'ITSAGO',
                              style: TextStyle(
                                fontSize: 42,
                                fontWeight: FontWeight.w900,
                                color: BauhausColors.black,
                                letterSpacing: 6,
                              ),
                            ),
                            const SizedBox(height: 8),
                            // Clean line separator
                            Container(
                              width: 120,
                              height: 3,
                              color: BauhausColors.red,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'AI INTERVIEW PREP',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: BauhausColors.gray,
                                letterSpacing: 2,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              
              // Minimal loading indicator
              Positioned(
                bottom: 60,
                left: 0,
                right: 0,
                child: Opacity(
                  opacity: _textOpacity.value,
                  child: Column(
                    children: [
                      // Simple progress dots
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(3, (index) {
                          return AnimatedBuilder(
                            animation: _pulseController,
                            builder: (context, child) {
                              double delay = index * 0.3;
                              double animValue = ((_pulseController.value - delay) % 1.0);
                              return Container(
                                margin: const EdgeInsets.symmetric(horizontal: 4),
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: BauhausColors.black.withOpacity(
                                    0.3 + (animValue * 0.7)
                                  ),
                                  shape: BoxShape.circle,
                                ),
                              );
                            },
                          );
                        }),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'INITIALIZING',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: BauhausColors.gray,
                          letterSpacing: 2,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// Simple triangle painter
class SimpleTrianglePainter extends CustomPainter {
  final Color color;
  
  SimpleTrianglePainter(this.color);
  
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