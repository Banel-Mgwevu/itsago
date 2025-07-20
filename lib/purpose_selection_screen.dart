import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'main.dart';
import 'auth_screen.dart';

class PurposeSelectionScreen extends StatefulWidget {
  final List<CameraDescription> cameras;
  
  const PurposeSelectionScreen({Key? key, required this.cameras}) : super(key: key);

  @override
  State<PurposeSelectionScreen> createState() => _PurposeSelectionScreenState();
}

class _PurposeSelectionScreenState extends State<PurposeSelectionScreen>
    with TickerProviderStateMixin {
  
  String? _selectedPurpose;
  late AnimationController _animationController;
  late AnimationController _buttonController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  
  final List<PurposeOption> _purposes = [
    PurposeOption(
      id: 'upcoming_interview',
      title: 'UPCOMING INTERVIEW',
      subtitle: 'I have a job interview scheduled',
      description: 'Prepare for a specific interview with targeted questions and practice',
      color: BauhausColors.red,
      icon: Icons.event,
    ),
    PurposeOption(
      id: 'general_preparation',
      title: 'GENERAL PREPARATION',
      subtitle: 'I want to be ready for future opportunities',
      description: 'Build confidence and skills for any interview scenario',
      color: BauhausColors.blue,
      icon: Icons.trending_up,
    ),
    PurposeOption(
      id: 'communication_skills',
      title: 'COMMUNICATION SKILLS',
      subtitle: 'I want to improve my speaking abilities',
      description: 'Focus on body language, clarity, and confidence building',
      color: BauhausColors.yellow,
      icon: Icons.record_voice_over,
    ),
    PurposeOption(
      id: 'career_change',
      title: 'CAREER TRANSITION',
      subtitle: 'I am switching to a new field',
      description: 'Prepare for interviews in a different industry or role',
      color: BauhausColors.black,
      icon: Icons.swap_horiz,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _startAnimations();
  }

  void _initializeAnimations() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    
    _buttonController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    ));
    
    _scaleAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _buttonController,
      curve: Curves.elasticOut,
    ));
  }

  void _startAnimations() async {
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _buttonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BauhausColors.lightGray,
      body: SafeArea(
        child: Stack(
          children: [
            // Geometric background
            Positioned(
              top: -50,
              left: -50,
              child: Container(
                width: 150,
                height: 150,
                decoration: BoxDecoration(
                  color: BauhausColors.yellow.withOpacity(0.6),
                  shape: BoxShape.circle,
                ),
              ),
            ),
            Positioned(
              bottom: -100,
              right: -80,
              child: Container(
                width: 200,
                height: 200,
                color: BauhausColors.blue.withOpacity(0.6),
              ),
            ),
            Positioned(
              top: 200,
              right: 20,
              child: Container(
                width: 30,
                height: 30,
                color: BauhausColors.red,
              ),
            ),
            
            // Main content
            FadeTransition(
              opacity: _fadeAnimation,
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 40),
                      
                      // Header
                      Row(
                        children: [
                          Container(
                            width: 60,
                            height: 60,
                            decoration: BoxDecoration(
                              color: BauhausColors.red,
                              border: Border.all(
                                color: BauhausColors.black,
                                width: 3,
                              ),
                            ),
                            child: Icon(
                              Icons.help_outline,
                              size: 30,
                              color: BauhausColors.white,
                            ),
                          ),
                          const SizedBox(width: 20),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'TELL US',
                                  style: TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.w900,
                                    color: BauhausColors.black,
                                    letterSpacing: 3,
                                  ),
                                ),
                                Text(
                                  'ABOUT YOUR GOALS',
                                  style: TextStyle(
                                    fontSize: 16,
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
                      
                      const SizedBox(height: 30),
                      
                      Text(
                        'Why do you want to use ITAGO?',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: BauhausColors.black,
                          letterSpacing: 1,
                        ),
                      ),
                      
                      const SizedBox(height: 20),
                      
                      // Purpose options
                      ...List.generate(_purposes.length, (index) {
                        return AnimatedBuilder(
                          animation: _animationController,
                          builder: (context, child) {
                            double delay = index * 0.1;
                            double animValue = (_animationController.value - delay).clamp(0.0, 1.0);
                            
                            return Transform.translate(
                              offset: Offset(0, 50 * (1 - animValue)),
                              child: Opacity(
                                opacity: animValue,
                                child: Padding(
                                  padding: const EdgeInsets.only(bottom: 16),
                                  child: _buildPurposeCard(_purposes[index]),
                                ),
                              ),
                            );
                          },
                        );
                      }),
                      
                      const SizedBox(height: 40),
                      
                      // Continue button
                      AnimatedBuilder(
                        animation: _buttonController,
                        builder: (context, child) {
                          return Transform.scale(
                            scale: _scaleAnimation.value,
                            child: Container(
                              width: double.infinity,
                              height: 80,
                              decoration: BoxDecoration(
                                color: _selectedPurpose != null 
                                    ? BauhausColors.red 
                                    : BauhausColors.gray,
                                border: Border.all(
                                  color: BauhausColors.black,
                                  width: 3,
                                ),
                              ),
                              child: MaterialButton(
                                onPressed: _selectedPurpose != null ? _continueToAuth : null,
                                child: Text(
                                  'CONTINUE',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w900,
                                    color: BauhausColors.white,
                                    letterSpacing: 3,
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                      
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPurposeCard(PurposeOption purpose) {
    bool isSelected = _selectedPurpose == purpose.id;
    
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedPurpose = purpose.id;
        });
        if (!_buttonController.isAnimating) {
          _buttonController.forward();
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
        decoration: BoxDecoration(
          border: Border.all(
            color: isSelected ? purpose.color : BauhausColors.black,
            width: isSelected ? 4 : 3,
          ),
          color: BauhausColors.white,
        ),
        child: Column(
          children: [
            // FIXED: Use IntrinsicHeight instead of fixed height
            IntrinsicHeight(
              child: Container(
                width: double.infinity,
                constraints: const BoxConstraints(minHeight: 80), // Minimum height instead of fixed
                color: isSelected ? purpose.color : BauhausColors.lightGray,
                child: Row(
                  children: [
                    Container(
                      width: 80,
                      height: 80,
                      color: isSelected 
                          ? (purpose.color == BauhausColors.yellow 
                              ? BauhausColors.black.withOpacity(0.1)
                              : BauhausColors.white.withOpacity(0.2))
                          : BauhausColors.white,
                      child: Icon(
                        purpose.icon,
                        size: 32,
                        color: isSelected 
                            ? (purpose.color == BauhausColors.yellow 
                                ? BauhausColors.black 
                                : BauhausColors.white)
                            : purpose.color,
                      ),
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min, // FIXED: Use min instead of max
                          children: [
                            Text(
                              purpose.title,
                              style: TextStyle(
                                fontSize: 14, // FIXED: Reduced from 16 to 14
                                fontWeight: FontWeight.w900,
                                color: isSelected 
                                    ? (purpose.color == BauhausColors.yellow 
                                        ? BauhausColors.black 
                                        : BauhausColors.white)
                                    : BauhausColors.black,
                                letterSpacing: 1,
                              ),
                              maxLines: 2, // FIXED: Added max lines
                              overflow: TextOverflow.ellipsis, // FIXED: Added overflow handling
                            ),
                            const SizedBox(height: 2), // FIXED: Reduced from 4 to 2
                            Text(
                              purpose.subtitle,
                              style: TextStyle(
                                fontSize: 11, // FIXED: Reduced from 12 to 11
                                fontWeight: FontWeight.w600,
                                color: isSelected 
                                    ? (purpose.color == BauhausColors.yellow 
                                        ? BauhausColors.black.withOpacity(0.8) 
                                        : BauhausColors.white.withOpacity(0.9))
                                    : BauhausColors.gray,
                              ),
                              maxLines: 2, // FIXED: Added max lines
                              overflow: TextOverflow.ellipsis, // FIXED: Added overflow handling
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (isSelected)
                      Container(
                        width: 60,
                        constraints: const BoxConstraints(minHeight: 80), // FIXED: Use constraints instead of fixed height
                        color: purpose.color == BauhausColors.yellow 
                            ? BauhausColors.black.withOpacity(0.1)
                            : BauhausColors.white.withOpacity(0.2),
                        child: Icon(
                          Icons.check_circle,
                          size: 24,
                          color: purpose.color == BauhausColors.yellow 
                              ? BauhausColors.black 
                              : BauhausColors.white,
                        ),
                      ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                purpose.description,
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
      ),
    );
  }

  void _continueToAuth() {
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            AuthScreen(
              cameras: widget.cameras,
              selectedPurpose: _selectedPurpose!,
            ),
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

class PurposeOption {
  final String id;
  final String title;
  final String subtitle;
  final String description;
  final Color color;
  final IconData icon;

  PurposeOption({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.description,
    required this.color,
    required this.icon,
  });
}