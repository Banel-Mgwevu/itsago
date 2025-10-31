import 'package:camera/camera.dart'; //AIzaSyBG9Ibtg3a0UTO5DZb4mfhmN7mtij_OMPU
import 'package:flutter/material.dart';
import 'main.dart';
import 'purpose_selection_screen.dart';

class WelcomeScreen extends StatefulWidget {
  final List<CameraDescription> cameras;
  
  const WelcomeScreen({Key? key, required this.cameras}) : super(key: key);

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen>
    with TickerProviderStateMixin {
  
  late AnimationController _slideController;
  late AnimationController _fadeController;
  late AnimationController _geometryController;
  
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;
  late Animation<double> _geometryAnimation;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _startAnimations();
  }

  void _initializeAnimations() {
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    
    _geometryController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.5),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOut,
    ));
    
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    ));
    
    _geometryAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _geometryController,
      curve: Curves.elasticOut,
    ));
  }

  void _startAnimations() async {
    _geometryController.forward();
    await Future.delayed(const Duration(milliseconds: 200));
    _slideController.forward();
    await Future.delayed(const Duration(milliseconds: 100));
    _fadeController.forward();
  }

  @override
  void dispose() {
    _slideController.dispose();
    _fadeController.dispose();
    _geometryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BauhausColors.lightGray,
      body: SafeArea(
        child: Stack(
          children: [
            // Geometric background elements
            AnimatedBuilder(
              animation: _geometryController,
              builder: (context, child) {
                return Stack(
                  children: [
                    // Large yellow circle - top left
                    Positioned(
                      top: -100 + (50 * _geometryAnimation.value),
                      left: -100 + (30 * _geometryAnimation.value),
                      child: Transform.scale(
                        scale: _geometryAnimation.value,
                        child: Container(
                          width: 200,
                          height: 200,
                          decoration: BoxDecoration(
                            color: BauhausColors.yellow.withOpacity(0.8),
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    ),
                    
                    // Blue rectangle - top right
                    Positioned(
                      top: 80,
                      right: -50 + (30 * _geometryAnimation.value),
                      child: Transform.scale(
                        scale: _geometryAnimation.value,
                        child: Container(
                          width: 120,
                          height: 60,
                          color: BauhausColors.blue,
                        ),
                      ),
                    ),
                    
                    // Red triangle - bottom right
                    Positioned(
                      bottom: 100,
                      right: 40,
                      child: Transform.scale(
                        scale: _geometryAnimation.value,
                        child: CustomPaint(
                          size: const Size(80, 80),
                          painter: TrianglePainter(BauhausColors.red),
                        ),
                      ),
                    ),
                    
                    // Small black squares
                    Positioned(
                      top: 300,
                      left: 50,
                      child: Transform.scale(
                        scale: _geometryAnimation.value,
                        child: Container(
                          width: 20,
                          height: 20,
                          color: BauhausColors.black,
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
            
            // Main content
            SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 40),
                    
                    // Header section
                    SlideTransition(
                      position: _slideAnimation,
                      child: FadeTransition(
                        opacity: _fadeAnimation,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // App logo and name
                            Row(
                              children: [
                                Container(
                                  width: 80,
                                  height: 80,
                                  decoration: BoxDecoration(
                                    color: BauhausColors.white,
                                    border: Border.all(
                                      color: BauhausColors.black,
                                      width: 3,
                                    ),
                                  ),
                                  child: Center(
                                    child: Text(
                                      'I',
                                      style: TextStyle(
                                        fontSize: 36,
                                        fontWeight: FontWeight.w900,
                                        color: BauhausColors.black,
                                        letterSpacing: 2,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 20),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'ITSAGO',
                                        style: TextStyle(
                                          fontSize: 32,
                                          fontWeight: FontWeight.w900,
                                          color: BauhausColors.black,
                                          letterSpacing: 4,
                                        ),
                                      ),
                                      Container(
                                        width: 80,
                                        height: 3,
                                        color: BauhausColors.red,
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'AI INTERVIEW PREP',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: BauhausColors.gray,
                                          letterSpacing: 1,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            
                            const SizedBox(height: 50),
                            
                            // Welcome title
                            Text(
                              'WELCOME TO THE',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: BauhausColors.gray,
                                letterSpacing: 2,
                              ),
                            ),
                            Text(
                              'FUTURE OF',
                              style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.w900,
                                color: BauhausColors.black,
                                letterSpacing: 3,
                                height: 1.1,
                              ),
                            ),
                            Text(
                              'INTERVIEW',
                              style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.w900,
                                color: BauhausColors.blue,
                                letterSpacing: 3,
                                height: 1.1,
                              ),
                            ),
                            Text(
                              'PREPARATION',
                              style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.w900,
                                color: BauhausColors.red,
                                letterSpacing: 3,
                                height: 1.1,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 40),
                    
                    // Features section
                    FadeTransition(
                      opacity: _fadeAnimation,
                      child: Column(
                        children: [
                          _buildFeatureCard(
                            'GENERATE SMART QUESTIONS',
                            'AI-powered questions tailored to your specific job role and company',
                            BauhausColors.yellow,
                            Icons.psychology,
                          ),
                          
                          const SizedBox(height: 20),
                          
                          _buildFeatureCard(
                            'IMPROVE COMMUNICATION',
                            'Enhance your speaking skills and build confidence for any interview',
                            BauhausColors.blue,
                            Icons.record_voice_over,
                          ),
                          
                          const SizedBox(height: 20),
                          
                          _buildFeatureCard(
                            'BODY LANGUAGE ANALYSIS',
                            'Real-time feedback on posture, gestures, and non-verbal communication',
                            BauhausColors.red,
                            Icons.accessibility_new,
                          ),
                          
                          const SizedBox(height: 20),
                          
                          _buildFeatureCard(
                            'PERSONALIZED FEEDBACK',
                            'Detailed analysis and actionable suggestions for improvement',
                            BauhausColors.black,
                            Icons.analytics,
                          ),
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 40),
                    
                    // Call to action
                    SlideTransition(
                      position: _slideAnimation,
                      child: FadeTransition(
                        opacity: _fadeAnimation,
                        child: Column(
                          children: [
                            Container(
                              width: double.infinity,
                              height: 80,
                              decoration: BoxDecoration(
                                color: BauhausColors.red,
                                border: Border.all(
                                  color: BauhausColors.black,
                                  width: 3,
                                ),
                              ),
                              child: MaterialButton(
                                onPressed: _continueToNext,
                                child: Text(
                                  'GET STARTED',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w900,
                                    color: BauhausColors.white,
                                    letterSpacing: 3,
                                  ),
                                ),
                              ),
                            ),
                            
                            const SizedBox(height: 20),
                            
                            Text(
                              'POWERED BY ARTIFICIAL INTELLIGENCE',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: BauhausColors.gray,
                                letterSpacing: 1,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureCard(String title, String description, Color color, IconData icon) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        border: Border.all(color: BauhausColors.black, width: 3),
      ),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            height: 80,
            color: color,
            child: Row(
              children: [
                Container(
                  width: 80,
                  height: 80,
                  color: color == BauhausColors.black 
                      ? BauhausColors.white 
                      : BauhausColors.white.withOpacity(0.2),
                  child: Icon(
                    icon,
                    size: 40,
                    color: color == BauhausColors.black 
                        ? BauhausColors.black 
                        : color == BauhausColors.yellow 
                            ? BauhausColors.black 
                            : BauhausColors.white,
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: color == BauhausColors.yellow 
                            ? BauhausColors.black 
                            : BauhausColors.white,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: double.infinity,
            color: BauhausColors.white,
            padding: const EdgeInsets.all(16),
            child: Text(
              description,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: BauhausColors.black,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _continueToNext() {
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            PurposeSelectionScreen(cameras: widget.cameras),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(1.0, 0.0),
              end: Offset.zero,
            ).animate(CurvedAnimation(
              parent: animation,
              curve: Curves.easeOut,
            )),
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 600),
      ),
    );
  }
}

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