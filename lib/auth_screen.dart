import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'main.dart';
import 'terms_screen.dart';
import 'main_menu_screen.dart';
import 'onboarding_screen.dart'; // Import the onboarding screen

class AuthScreen extends StatefulWidget {
  final List<CameraDescription> cameras;
  final String selectedPurpose;
  
  const AuthScreen({
    super.key, 
    required this.cameras,
    required this.selectedPurpose,
  });

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen>
    with TickerProviderStateMixin {
  
  late AnimationController _animationController;
  late AnimationController _logoController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _slideAnimation;
  late Animation<double> _logoRotation;
  
  bool _isLoading = false;
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: ['email', 'profile'],
  );

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _startAnimations();
  }

  void _initializeAnimations() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    
    _logoController = AnimationController(
      duration: const Duration(milliseconds: 2000),
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
      begin: 50.0,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    ));
    
    _logoRotation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _logoController,
      curve: Curves.elasticOut,
    ));
  }

  void _startAnimations() async {
    _animationController.forward();
    await Future.delayed(const Duration(milliseconds: 300));
    _logoController.repeat(reverse: true);
  }

  @override
  void dispose() {
    _animationController.dispose();
    _logoController.dispose();
    super.dispose();
  }

  // Check if user has seen onboarding before
  Future<bool> _hasSeenOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('has_seen_onboarding') ?? false;
  }

  // Mark onboarding as seen
  Future<void> _setOnboardingSeen() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('has_seen_onboarding', true);
  }

  // Navigate to appropriate screen after sign in
  Future<void> _navigateAfterSignIn() async {
    if (mounted) {
      final hasSeenOnboarding = await _hasSeenOnboarding();
      
      if (hasSeenOnboarding) {
        // Returning user - go directly to main menu
        Navigator.of(context).pushReplacement(
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) =>
                MainMenuScreen(cameras: widget.cameras),
            transitionsBuilder: (context, animation, secondaryAnimation, child) {
              return FadeTransition(opacity: animation, child: child);
            },
            transitionDuration: const Duration(milliseconds: 600),
          ),
        );
      } else {
        // First-time user - show onboarding
        await _setOnboardingSeen();
        Navigator.of(context).pushReplacement(
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) =>
                OnboardingScreen(cameras: widget.cameras),
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
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BauhausColors.white,
      body: SafeArea(
        child: Stack(
          children: [
            // Geometric background elements
            Positioned(
              top: -80,
              right: -80,
              child: Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  color: BauhausColors.yellow.withOpacity(0.8),
                  shape: BoxShape.circle,
                ),
              ),
            ),
            Positioned(
              bottom: -60,
              left: -60,
              child: Container(
                width: 180,
                height: 120,
                color: BauhausColors.blue.withOpacity(0.8),
              ),
            ),
            Positioned(
              top: 200,
              left: 30,
              child: Container(
                width: 40,
                height: 40,
                color: BauhausColors.red,
              ),
            ),
            Positioned(
              bottom: 200,
              right: 40,
              child: CustomPaint(
                size: const Size(60, 60),
                painter: TrianglePainter(BauhausColors.red),
              ),
            ),
            
            // Loading overlay
            if (_isLoading)
              Container(
                color: BauhausColors.black.withOpacity(0.5),
                child: Center(
                  child: Container(
                    width: 200,
                    height: 200,
                    decoration: BoxDecoration(
                      color: BauhausColors.white,
                      border: Border.all(
                        color: BauhausColors.black,
                        width: 4,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: BauhausColors.red,
                              width: 4,
                            ),
                          ),
                          child: CircularProgressIndicator(
                            color: BauhausColors.red,
                            strokeWidth: 3,
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          'SIGNING IN...',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                            color: BauhausColors.black,
                            letterSpacing: 2,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            
            // Main content
            SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    const SizedBox(height: 60),
                    
                    // Logo section
                    AnimatedBuilder(
                      animation: Listenable.merge([_animationController, _logoController]),
                      builder: (context, child) {
                        return Transform.translate(
                          offset: Offset(0, _slideAnimation.value),
                          child: FadeTransition(
                            opacity: _fadeAnimation,
                            child: Column(
                              children: [
                                Transform.scale(
                                  scale: 1.0 + (_logoRotation.value * 0.1),
                                  child: Container(
                                    width: 120,
                                    height: 120,
                                    decoration: BoxDecoration(
                                      color: BauhausColors.white,
                                      border: Border.all(
                                        color: BauhausColors.black,
                                        width: 4,
                                      ),
                                    ),
                                    child: Stack(
                                      children: [
                                        // Animated geometric elements
                                        Positioned(
                                          top: 15,
                                          right: 15,
                                          child: Transform.rotate(
                                            angle: _logoRotation.value * 0.5,
                                            child: Container(
                                              width: 20,
                                              height: 20,
                                              decoration: BoxDecoration(
                                                color: BauhausColors.red,
                                                shape: BoxShape.circle,
                                              ),
                                            ),
                                          ),
                                        ),
                                        Positioned(
                                          bottom: 15,
                                          left: 15,
                                          child: Transform.scale(
                                            scale: 1.0 + (_logoRotation.value * 0.2),
                                            child: Container(
                                              width: 15,
                                              height: 25,
                                              color: BauhausColors.yellow,
                                            ),
                                          ),
                                        ),
                                        Positioned(
                                          top: 15,
                                          left: 15,
                                          child: Transform.rotate(
                                            angle: -_logoRotation.value * 0.3,
                                            child: Container(
                                              width: 8,
                                              height: 8,
                                              decoration: BoxDecoration(
                                                color: BauhausColors.blue,
                                                shape: BoxShape.circle,
                                              ),
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
                                
                                const SizedBox(height: 30),
                                
                                Text(
                                  'ITSAGO',
                                  style: TextStyle(
                                    fontSize: 36,
                                    fontWeight: FontWeight.w900,
                                    color: BauhausColors.black,
                                    letterSpacing: 6,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                    
                    const SizedBox(height: 60),
                    
                    // Authentication section
                    FadeTransition(
                      opacity: _fadeAnimation,
                      child: Column(
                        children: [
                          Text(
                            'READY TO START?',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w900,
                              color: BauhausColors.black,
                              letterSpacing: 3,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          
                          const SizedBox(height: 20),
                          
                          Text(
                            'Sign in to save your progress and access personalized features',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: BauhausColors.gray,
                              height: 1.4,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          
                          const SizedBox(height: 50),
                          
                          // Google Sign In Button
                          Container(
                            width: double.infinity,
                            height: 80,
                            decoration: BoxDecoration(
                              color: BauhausColors.white,
                              border: Border.all(
                                color: BauhausColors.black,
                                width: 3,
                              ),
                            ),
                            child: MaterialButton(
                              onPressed: _isLoading ? null : _signInWithGoogle,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Container(
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      color: BauhausColors.red,
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      Icons.g_mobiledata,
                                      size: 28,
                                      color: BauhausColors.white,
                                    ),
                                  ),
                                  const SizedBox(width: 20),
                                  Text(
                                    'CONTINUE WITH GOOGLE',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w900,
                                      color: BauhausColors.black,
                                      letterSpacing: 2,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          
                          const SizedBox(height: 30),
                          
                          // Terms and Conditions
                          GestureDetector(
                            onTap: _showTermsAndConditions,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: BauhausColors.gray,
                                  width: 2,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.description,
                                    size: 16,
                                    color: BauhausColors.gray,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'TERMS & CONDITIONS',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w900,
                                      color: BauhausColors.gray,
                                      letterSpacing: 1,
                                      decoration: TextDecoration.underline,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          
                          const SizedBox(height: 30),
                          
                          Text(
                            'By signing in, you agree to our Terms of Service\nand Privacy Policy',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: BauhausColors.gray,
                              height: 1.4,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          
                          const SizedBox(height: 40),
                          
                          // Skip option (for demo purposes)
                          // Container(
                          //   width: double.infinity,
                          //   height: 60,
                          //   decoration: BoxDecoration(
                          //     color: BauhausColors.lightGray,
                          //     border: Border.all(
                          //       color: BauhausColors.gray,
                          //       width: 2,
                          //     ),
                          //   ),
                          //   // // child: MaterialButton(
                          //   // //   onPressed: _isLoading ? null : _skipToDemo,
                          //   // //   child: Text(
                          //   // //     'CONTINUE AS GUEST',
                          //   // //     style: TextStyle(
                          //   // //       fontSize: 14,
                          //   // //       fontWeight: FontWeight.w900,
                          //   // //       color: BauhausColors.gray,
                          //   // //       letterSpacing: 2,
                          //   // //     ),
                          //   // //   ),
                          //   // ),
                          // ),
                       
                       
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

  Future<void> _signInWithGoogle() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Trigger the authentication flow
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      
      if (googleUser == null) {
        // User canceled the sign-in
        setState(() {
          _isLoading = false;
        });
        return;
      }

      // Obtain the auth details from the request
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

      // Create a new credential
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Sign in to Firebase with the Google [UserCredential]
      await FirebaseAuth.instance.signInWithCredential(credential);

      // Navigate to appropriate screen based on onboarding status
      await _navigateAfterSignIn();
      
    } catch (e) {
      print('Error signing in with Google: $e');
      _showErrorDialog('SIGN IN FAILED', 'Unable to sign in with Google. Please try again.');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _skipToDemo() async {
    // For guest users, always show onboarding (unless they've seen it before)
    await _navigateAfterSignIn();
  }

  void _showTermsAndConditions() {
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            TermsScreen(cameras: widget.cameras),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0.0, 1.0),
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

  void _showErrorDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          width: 300,
          decoration: BoxDecoration(
            border: Border.all(color: BauhausColors.black, width: 4),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                color: BauhausColors.red,
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: BauhausColors.white,
                    letterSpacing: 2,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                color: BauhausColors.white,
                child: Column(
                  children: [
                    Text(
                      message,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: BauhausColors.black,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),
                    Container(
                      width: 100,
                      height: 40,
                      color: BauhausColors.blue,
                      child: MaterialButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: Text(
                          'OK',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                            color: BauhausColors.white,
                            letterSpacing: 1,
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