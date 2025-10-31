import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'main.dart';
import 'main_menu_screen.dart';

class OnboardingScreen extends StatefulWidget {
  final List<CameraDescription> cameras;
  
  const OnboardingScreen({Key? key, required this.cameras}) : super(key: key);

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with TickerProviderStateMixin {
  PageController _pageController = PageController();
  int _currentPage = 0;
  
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late AnimationController _scaleController;
  late AnimationController _rotationController;
  
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<double> _rotationAnimation;

  @override
  void initState() {
    super.initState();
    
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    
    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    
    _rotationController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );
    
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeOut),
    );
    
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _slideController, curve: Curves.elasticOut));
    
    _scaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.bounceOut),
    );
    
    _rotationAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _rotationController, curve: Curves.linear),
    );
    
    // Start animations
    _fadeController.forward();
    _slideController.forward();
    _scaleController.forward();
    _rotationController.repeat();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    _scaleController.dispose();
    _rotationController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  void _nextPage() {
    if (_currentPage < 3) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeInOut,
      );
    } else {
      _finishOnboarding();
    }
  }

  void _finishOnboarding() {
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            MainMenuScreen(cameras: widget.cameras),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0.0, 1.0),
                end: Offset.zero,
              ).animate(CurvedAnimation(
                parent: animation,
                curve: Curves.easeOut,
              )),
              child: child,
            ),
          );
        },
        transitionDuration: const Duration(milliseconds: 800),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BauhausColors.lightGray,
      body: SafeArea(
        child: Stack(
          children: [
            // Animated background elements
            _buildAnimatedBackground(),
            
            // Main content
            PageView(
              controller: _pageController,
              onPageChanged: (index) {
                setState(() {
                  _currentPage = index;
                });
                // Restart animations for new page
                _scaleController.reset();
                _scaleController.forward();
              },
              children: [
                _buildWelcomePage(),
                _buildFeaturePage1(),
                _buildFeaturePage2(),
                _buildFeaturePage3(),
                _buildFinalPage(),
              ],
            ),
            
            // Skip button
            if (_currentPage < 4)
              Positioned(
                top: 20,
                right: 20,
                child: AnimatedBuilder(
                  animation: _fadeAnimation,
                  builder: (context, child) {
                    return Opacity(
                      opacity: _fadeAnimation.value,
                      child: Container(
                        decoration: BoxDecoration(
                          color: BauhausColors.white,
                          border: Border.all(color: BauhausColors.black, width: 2),
                        ),
                        child: MaterialButton(
                          onPressed: _finishOnboarding,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                          child: Text(
                            'SKIP',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w900,
                              color: BauhausColors.black,
                              letterSpacing: 1,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            
            // Page indicators and navigation
            if (_currentPage < 4)
              Positioned(
                bottom: 30,
                left: 0,
                right: 0,
                child: Column(
                  children: [
                    // Page indicators
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(4, (index) {
                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          width: _currentPage == index ? 30 : 10,
                          height: 4,
                          decoration: BoxDecoration(
                            color: _currentPage == index 
                                ? BauhausColors.red 
                                : BauhausColors.gray,
                          ),
                        );
                      }),
                    ),
                    
                    const SizedBox(height: 30),
                    
                    // Next button
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 40),
                      child: Container(
                        width: double.infinity,
                        height: 60,
                        decoration: BoxDecoration(
                          color: BauhausColors.blue,
                          border: Border.all(color: BauhausColors.black, width: 3),
                        ),
                        child: MaterialButton(
                          onPressed: _nextPage,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                _currentPage == 3 ? 'GET STARTED' : 'NEXT',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w900,
                                  color: BauhausColors.white,
                                  letterSpacing: 2,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Icon(
                                _currentPage == 3 ? Icons.rocket_launch : Icons.arrow_forward,
                                color: BauhausColors.white,
                                size: 20,
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
      ),
    );
  }

  Widget _buildAnimatedBackground() {
    return AnimatedBuilder(
      animation: _rotationAnimation,
      builder: (context, child) {
        return Stack(
          children: [
            // Floating geometric shapes
            Positioned(
              top: 100 + (50 * _rotationAnimation.value),
              right: 50,
              child: Transform.rotate(
                angle: _rotationAnimation.value * 6.28,
                child: Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: BauhausColors.yellow.withOpacity(0.3),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
            Positioned(
              top: 300 - (30 * _rotationAnimation.value),
              left: 30,
              child: Transform.rotate(
                angle: -_rotationAnimation.value * 6.28,
                child: Container(
                  width: 40,
                  height: 40,
                  color: BauhausColors.red.withOpacity(0.2),
                ),
              ),
            ),
            Positioned(
              bottom: 200 + (40 * _rotationAnimation.value),
              right: 80,
              child: Container(
                width: 80,
                height: 20,
                color: BauhausColors.blue.withOpacity(0.3),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildWelcomePage() {
    return Padding(
      padding: const EdgeInsets.all(40),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Logo animation
          AnimatedBuilder(
            animation: _scaleAnimation,
            builder: (context, child) {
              return Transform.scale(
                scale: _scaleAnimation.value,
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    color: BauhausColors.blue,
                    border: Border.all(color: BauhausColors.black, width: 4),
                  ),
                  child: Stack(
                    children: [
                      Positioned(
                        top: 10,
                        right: 10,
                        child: Container(
                          width: 30,
                          height: 30,
                          decoration: BoxDecoration(
                            color: BauhausColors.yellow,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                      Center(
                        child: Text(
                          'I',
                          style: TextStyle(
                            fontSize: 48,
                            fontWeight: FontWeight.w900,
                            color: BauhausColors.white,
                            letterSpacing: 2,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          
          const SizedBox(height: 40),
          
          // Welcome text
          SlideTransition(
            position: _slideAnimation,
            child: Column(
              children: [
                Text(
                  'WELCOME TO',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    color: BauhausColors.gray,
                    letterSpacing: 3,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),
                Text(
                  'ITSAGO',
                  style: TextStyle(
                    fontSize: 42,
                    fontWeight: FontWeight.w900,
                    color: BauhausColors.black,
                    letterSpacing: 6,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 15),
                Container(
                  width: 100,
                  height: 4,
                  color: BauhausColors.red,
                ),
                const SizedBox(height: 20),
                Text(
                  'Your AI-powered interview preparation companion',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: BauhausColors.gray,
                    letterSpacing: 1,
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

  Widget _buildFeaturePage1() {
    return Padding(
      padding: const EdgeInsets.all(40),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Feature icon
          AnimatedBuilder(
            animation: _scaleAnimation,
            builder: (context, child) {
              return Transform.scale(
                scale: _scaleAnimation.value,
                child: Container(
                  width: 150,
                  height: 150,
                  decoration: BoxDecoration(
                    color: BauhausColors.red,
                    border: Border.all(color: BauhausColors.black, width: 4),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.video_camera_front,
                        size: 60,
                        color: BauhausColors.white,
                      ),
                      const SizedBox(height: 10),
                      Container(
                        width: 40,
                        height: 3,
                        color: BauhausColors.white,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          
          const SizedBox(height: 50),
          
          // Feature description
          FadeTransition(
            opacity: _fadeAnimation,
            child: Column(
              children: [
                Text(
                  'PRACTICE',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w900,
                    color: BauhausColors.black,
                    letterSpacing: 4,
                  ),
                  textAlign: TextAlign.center,
                ),
                Text(
                  'INTERVIEWS',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w900,
                    color: BauhausColors.red,
                    letterSpacing: 4,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 30),
                Text(
                  'Experience realistic AI-powered mock interviews tailored to your industry and role',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: BauhausColors.gray,
                    height: 1.4,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 30),
                // Feature highlights
                _buildFeatureHighlight('• Real-time video analysis'),
                _buildFeatureHighlight('• Industry-specific questions'),
                _buildFeatureHighlight('• Instant feedback & scoring'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeaturePage2() {
    return Padding(
      padding: const EdgeInsets.all(40),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Feature icon
          AnimatedBuilder(
            animation: _scaleAnimation,
            builder: (context, child) {
              return Transform.scale(
                scale: _scaleAnimation.value,
                child: Container(
                  width: 150,
                  height: 150,
                  decoration: BoxDecoration(
                    color: BauhausColors.yellow,
                    border: Border.all(color: BauhausColors.black, width: 4),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.psychology,
                        size: 60,
                        color: BauhausColors.black,
                      ),
                      const SizedBox(height: 10),
                      Container(
                        width: 40,
                        height: 3,
                        color: BauhausColors.black,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          
          const SizedBox(height: 50),
          
          // Feature description
          FadeTransition(
            opacity: _fadeAnimation,
            child: Column(
              children: [
                Text(
                  'AI COACH',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w900,
                    color: BauhausColors.black,
                    letterSpacing: 4,
                  ),
                  textAlign: TextAlign.center,
                ),
                Text(
                  'ASSISTANCE',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w900,
                    color: BauhausColors.yellow,
                    letterSpacing: 4,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 30),
                Text(
                  'Get personalized coaching and calendar-aware preparation strategies',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: BauhausColors.gray,
                    height: 1.4,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 30),
                // Feature highlights
                _buildFeatureHighlight('• 24/7 AI coaching support'),
                _buildFeatureHighlight('• Calendar integration'),
                _buildFeatureHighlight('• Personalized strategies'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeaturePage3() {
    return Padding(
      padding: const EdgeInsets.all(40),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Feature icon
          AnimatedBuilder(
            animation: _scaleAnimation,
            builder: (context, child) {
              return Transform.scale(
                scale: _scaleAnimation.value,
                child: Container(
                  width: 150,
                  height: 150,
                  decoration: BoxDecoration(
                    color: BauhausColors.blue,
                    border: Border.all(color: BauhausColors.black, width: 4),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.library_books,
                        size: 60,
                        color: BauhausColors.white,
                      ),
                      const SizedBox(height: 10),
                      Container(
                        width: 40,
                        height: 3,
                        color: BauhausColors.white,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          
          const SizedBox(height: 50),
          
          // Feature description
          FadeTransition(
            opacity: _fadeAnimation,
            child: Column(
              children: [
                Text(
                  'PREMIUM',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w900,
                    color: BauhausColors.black,
                    letterSpacing: 4,
                  ),
                  textAlign: TextAlign.center,
                ),
                Text(
                  'RESOURCES',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w900,
                    color: BauhausColors.blue,
                    letterSpacing: 4,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 30),
                Text(
                  'Access comprehensive guides, tips, and strategies from industry experts',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: BauhausColors.gray,
                    height: 1.4,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 30),
                // Feature highlights
                _buildFeatureHighlight('• Expert interview guides'),
                _buildFeatureHighlight('• Industry-specific tips'),
                _buildFeatureHighlight('• Success strategies'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFinalPage() {
    return Padding(
      padding: const EdgeInsets.all(40),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Success icon
          AnimatedBuilder(
            animation: _scaleAnimation,
            builder: (context, child) {
              return Transform.scale(
                scale: _scaleAnimation.value,
                child: Container(
                  width: 150,
                  height: 150,
                  decoration: BoxDecoration(
                    color: BauhausColors.yellow,
                    shape: BoxShape.circle,
                    border: Border.all(color: BauhausColors.black, width: 4),
                  ),
                  child: Icon(
                    Icons.rocket_launch,
                    size: 60,
                    color: BauhausColors.black,
                  ),
                ),
              );
            },
          ),
          
          const SizedBox(height: 50),
          
          // Final message
          FadeTransition(
            opacity: _fadeAnimation,
            child: Column(
              children: [
                Text(
                  'YOU\'RE ALL',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w900,
                    color: BauhausColors.black,
                    letterSpacing: 4,
                  ),
                  textAlign: TextAlign.center,
                ),
                Text(
                  'SET!',
                  style: TextStyle(
                    fontSize: 42,
                    fontWeight: FontWeight.w900,
                    color: BauhausColors.red,
                    letterSpacing: 6,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 30),
                Text(
                  'Ready to ace your next interview? Let\'s get started with ITSAGO!',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: BauhausColors.gray,
                    height: 1.4,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 50),
                // CTA Button
                Container(
                  width: double.infinity,
                  height: 80,
                  decoration: BoxDecoration(
                    color: BauhausColors.blue,
                    border: Border.all(color: BauhausColors.black, width: 4),
                  ),
                  child: MaterialButton(
                    onPressed: _finishOnboarding,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'START YOUR JOURNEY',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                            color: BauhausColors.white,
                            letterSpacing: 2,
                          ),
                        ),
                        // const SizedBox(width: 10),
                        Icon(
                          Icons.arrow_forward,
                          color: BauhausColors.white,
                          size: 24,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureHighlight(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Container(
            width: 6,
            height: 6,
            color: BauhausColors.red,
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: BauhausColors.black,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}