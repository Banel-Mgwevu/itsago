import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'main.dart';

class AboutScreen extends StatefulWidget {
  final List<CameraDescription> cameras;
  
  const AboutScreen({Key? key, required this.cameras}) : super(key: key);

  @override
  State<AboutScreen> createState() => _AboutScreenState();
}

class _AboutScreenState extends State<AboutScreen>
    with TickerProviderStateMixin {
  
  late AnimationController _animationController;
  late AnimationController _geometryController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _slideAnimation;
  late Animation<double> _geometryAnimation;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _startAnimations();
  }

  void _initializeAnimations() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    
    _geometryController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    ));
    
    _slideAnimation = Tween<double>(
      begin: 30.0,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
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

  void _startAnimations() {
    _geometryController.forward();
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
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
                    Positioned(
                      top: -100 + (50 * _geometryAnimation.value),
                      right: -100 + (30 * _geometryAnimation.value),
                      child: Transform.scale(
                        scale: _geometryAnimation.value,
                        child: Container(
                          width: 200,
                          height: 200,
                          decoration: BoxDecoration(
                            color: BauhausColors.yellow.withOpacity(0.6),
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: -80,
                      left: -80,
                      child: Transform.scale(
                        scale: _geometryAnimation.value,
                        child: Container(
                          width: 200,
                          height: 120,
                          color: BauhausColors.blue.withOpacity(0.6),
                        ),
                      ),
                    ),
                    Positioned(
                      top: 300,
                      left: 40,
                      child: Transform.scale(
                        scale: _geometryAnimation.value,
                        child: Container(
                          width: 30,
                          height: 30,
                          color: BauhausColors.red,
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
            
            // Main content
            Column(
              children: [
                // Header
                AnimatedBuilder(
                  animation: _animationController,
                  builder: (context, child) {
                    return Transform.translate(
                      offset: Offset(0, _slideAnimation.value),
                      child: FadeTransition(
                        opacity: _fadeAnimation,
                        child: Container(
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: BauhausColors.white,
                            border: Border(
                              bottom: BorderSide(
                                color: BauhausColors.black,
                                width: 3,
                              ),
                            ),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Row(
                              children: [
                                GestureDetector(
                                  onTap: () => Navigator.of(context).pop(),
                                  child: Container(
                                    width: 50,
                                    height: 50,
                                    decoration: BoxDecoration(
                                      color: BauhausColors.red,
                                      border: Border.all(
                                        color: BauhausColors.black,
                                        width: 3,
                                      ),
                                    ),
                                    child: Icon(
                                      Icons.arrow_back,
                                      color: BauhausColors.white,
                                      size: 24,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 20),
                                Expanded(
                                  child: Text(
                                    'ABOUT ITSAGO',
                                    style: TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.w900,
                                      color: BauhausColors.black,
                                      letterSpacing: 3,
                                    ),
                                  ),
                                ),
                                Container(
                                  width: 50,
                                  height: 50,
                                  decoration: BoxDecoration(
                                    color: BauhausColors.yellow,
                                    border: Border.all(
                                      color: BauhausColors.black,
                                      width: 3,
                                    ),
                                  ),
                                  child: Icon(
                                    Icons.info,
                                    color: BauhausColors.black,
                                    size: 24,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
                
                // Content
                Expanded(
                  child: FadeTransition(
                    opacity: _fadeAnimation,
                    child: SingleChildScrollView(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Logo and intro section
                            Center(
                              child: Column(
                                children: [
                                  Container(
                                    width: 100,
                                    height: 100,
                                    decoration: BoxDecoration(
                                      color: BauhausColors.white,
                                      border: Border.all(
                                        color: BauhausColors.black,
                                        width: 4,
                                      ),
                                    ),
                                    child: Stack(
                                      children: [
                                        Positioned(
                                          top: 10,
                                          right: 10,
                                          child: Container(
                                            width: 15,
                                            height: 15,
                                            decoration: BoxDecoration(
                                              color: BauhausColors.red,
                                              shape: BoxShape.circle,
                                            ),
                                          ),
                                        ),
                                        Positioned(
                                          bottom: 10,
                                          left: 10,
                                          child: Container(
                                            width: 12,
                                            height: 20,
                                            color: BauhausColors.yellow,
                                          ),
                                        ),
                                        Positioned(
                                          top: 10,
                                          left: 10,
                                          child: Container(
                                            width: 6,
                                            height: 6,
                                            decoration: BoxDecoration(
                                              color: BauhausColors.blue,
                                              shape: BoxShape.circle,
                                            ),
                                          ),
                                        ),
                                        Center(
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
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 20),
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
                                  const SizedBox(height: 8),
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
                            
                            const SizedBox(height: 40),
                            
                            // Mission section
                            _buildInfoSection(
                              'OUR MISSION',
                              'ITSAGO revolutionizes interview preparation through cutting-edge AI technology. We believe everyone deserves the confidence and skills to succeed in their career journey.',
                              BauhausColors.blue,
                              Icons.rocket_launch,
                            ),
                            
                            const SizedBox(height: 20),
                            
                            // Technology section
                            _buildInfoSection(
                              'AI TECHNOLOGY',
                              'Our advanced machine learning algorithms analyze speech patterns, body language, and communication effectiveness to provide personalized feedback and coaching.',
                              BauhausColors.yellow,
                              Icons.psychology,
                            ),
                            
                            const SizedBox(height: 20),
                            
                            // Features section
                            _buildInfoSection(
                              'KEY FEATURES',
                              '• Real-time speech analysis\n• Body language assessment\n• Personalized question generation\n• Progress tracking\n• Industry-specific coaching\n• Confidence building exercises',
                              BauhausColors.red,
                              Icons.star,
                            ),
                            
                            const SizedBox(height: 20),
                            
                            // Team section
                            _buildInfoSection(
                              'DEVELOPMENT TEAM',
                              'Built with passion by a team of AI researchers, interview experts, and career coaches dedicated to democratizing access to professional development.',
                              BauhausColors.black,
                              Icons.group,
                            ),
                            
                            const SizedBox(height: 30),
                            
                            // Contact section
                            Container(
                              width: double.infinity,
                              decoration: BoxDecoration(
                                color: BauhausColors.white,
                                border: Border.all(
                                  color: BauhausColors.black,
                                  width: 3,
                                ),
                              ),
                              child: Column(
                                children: [
                                  Container(
                                    width: double.infinity,
                                    color: BauhausColors.blue,
                                    padding: const EdgeInsets.all(16),
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 40,
                                          height: 40,
                                          color: BauhausColors.white,
                                          child: Icon(
                                            Icons.contact_support,
                                            color: BauhausColors.blue,
                                            size: 20,
                                          ),
                                        ),
                                        const SizedBox(width: 15),
                                        Text(
                                          'GET IN TOUCH',
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w900,
                                            color: BauhausColors.white,
                                            letterSpacing: 2,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.all(20),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Questions? Feedback? We\'d love to hear from you!',
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                            color: BauhausColors.black,
                                            height: 1.4,
                                          ),
                                        ),
                                        const SizedBox(height: 15),
                                        Row(
                                          children: [
                                            Icon(
                                              Icons.email,
                                              size: 16,
                                              color: BauhausColors.gray,
                                            ),
                                            const SizedBox(width: 8),
                                            Text(
                                              'support@itsago.ai',
                                              style: TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w900,
                                                color: BauhausColors.blue,
                                                letterSpacing: 1,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 8),
                                        Row(
                                          children: [
                                            Icon(
                                              Icons.web,
                                              size: 16,
                                              color: BauhausColors.gray,
                                            ),
                                            const SizedBox(width: 8),
                                            Text(
                                              'www.itsago.app',
                                              style: TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w900,
                                                color: BauhausColors.blue,
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
                            
                            const SizedBox(height: 30),
                            
                            // Version info
                            Center(
                              child: Column(
                                children: [
                                  Container(
                                    width: 60,
                                    height: 3,
                                    color: BauhausColors.red,
                                  ),
                                  const SizedBox(height: 15),
                                  Text(
                                    'VERSION 1.0.0',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: BauhausColors.gray,
                                      letterSpacing: 2,
                                    ),
                                  ),
                                  const SizedBox(height: 5),
                                  Text(
                                    '© 2025 ITSAGO AI SYSTEMS',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                      color: BauhausColors.gray,
                                      letterSpacing: 1,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            
                            const SizedBox(height: 40),
                          ],
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
    );
  }

  Widget _buildInfoSection(String title, String content, Color color, IconData icon) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        border: Border.all(
          color: BauhausColors.black,
          width: 3,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            color: color,
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  color: color == BauhausColors.yellow 
                      ? BauhausColors.black.withOpacity(0.1)
                      : color == BauhausColors.black
                          ? BauhausColors.white
                          : BauhausColors.white.withOpacity(0.2),
                  child: Icon(
                    icon,
                    size: 20,
                    color: color == BauhausColors.yellow 
                        ? BauhausColors.black 
                        : color == BauhausColors.black
                            ? BauhausColors.black
                            : BauhausColors.white,
                  ),
                ),
                const SizedBox(width: 15),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: color == BauhausColors.yellow 
                          ? BauhausColors.black 
                          : color == BauhausColors.black
                              ? BauhausColors.white
                              : BauhausColors.white,
                      letterSpacing: 1,
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
              content,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: BauhausColors.black,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}