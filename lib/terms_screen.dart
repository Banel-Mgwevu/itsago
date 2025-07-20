import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'main.dart';

class TermsScreen extends StatefulWidget {
  final List<CameraDescription> cameras;
  
  const TermsScreen({Key? key, required this.cameras}) : super(key: key);

  @override
  State<TermsScreen> createState() => _TermsScreenState();
}

class _TermsScreenState extends State<TermsScreen>
    with TickerProviderStateMixin {
  
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _slideAnimation;
  
  final ScrollController _scrollController = ScrollController();

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
  }

  void _startAnimations() {
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _scrollController.dispose();
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
            Positioned(
              top: -50,
              right: -50,
              child: Container(
                width: 150,
                height: 150,
                decoration: BoxDecoration(
                  color: BauhausColors.yellow.withOpacity(0.3),
                  shape: BoxShape.circle,
                ),
              ),
            ),
            Positioned(
              bottom: -80,
              left: -80,
              child: Container(
                width: 200,
                height: 120,
                color: BauhausColors.blue.withOpacity(0.3),
              ),
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
                                        width: 2,
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
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'TERMS &',
                                        style: TextStyle(
                                          fontSize: 24,
                                          fontWeight: FontWeight.w900,
                                          color: BauhausColors.black,
                                          letterSpacing: 3,
                                          height: 0.9,
                                        ),
                                      ),
                                      Text(
                                        'CONDITIONS',
                                        style: TextStyle(
                                          fontSize: 24,
                                          fontWeight: FontWeight.w900,
                                          color: BauhausColors.blue,
                                          letterSpacing: 3,
                                          height: 0.9,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  width: 50,
                                  height: 50,
                                  decoration: BoxDecoration(
                                    color: BauhausColors.yellow,
                                    border: Border.all(
                                      color: BauhausColors.black,
                                      width: 2,
                                    ),
                                  ),
                                  child: Icon(
                                    Icons.description,
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
                      controller: _scrollController,
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildSection(
                              'ACCEPTANCE OF TERMS',
                              'By accessing and using ITAGO (the "Service"), you accept and agree to be bound by the terms and provision of this agreement.',
                              BauhausColors.red,
                            ),
                            
                            _buildSection(
                              'SERVICE DESCRIPTION',
                              'ITSAGO is an AI-powered interview coaching application that provides personalized practice sessions, feedback on communication skills, body language analysis, and interview preparation tools.',
                              BauhausColors.blue,
                            ),
                            
                            _buildSection(
                              'USER DATA & PRIVACY',
                              'We collect and process your data to provide personalized coaching experiences. Your interview sessions may be recorded for analysis purposes. We are committed to protecting your privacy and will not share your personal information with third parties without your consent.',
                              BauhausColors.yellow,
                            ),
                            
                            _buildSection(
                              'AI ANALYSIS',
                              'Our AI technology analyzes your speech patterns, facial expressions, and body language to provide feedback. This analysis is performed automatically and results are used solely for improving your interview skills.',
                              BauhausColors.black,
                            ),
                            
                            _buildSection(
                              'USER RESPONSIBILITIES',
                              'You are responsible for providing accurate information and using the service in a lawful manner. You must not attempt to reverse engineer, modify, or distribute any part of our AI technology.',
                              BauhausColors.red,
                            ),
                            
                            _buildSection(
                              'LIMITATION OF LIABILITY',
                              'ITSAGO provides coaching suggestions and feedback for educational purposes. We cannot guarantee specific interview outcomes. The service is provided "as is" without warranties of any kind.',
                              BauhausColors.blue,
                            ),
                            
                            _buildSection(
                              'SUBSCRIPTION & PAYMENTS',
                              'Certain features may require a subscription. Payment terms and cancellation policies will be clearly stated at the time of purchase. Refunds are subject to our refund policy.',
                              BauhausColors.yellow,
                            ),
                            
                            _buildSection(
                              'INTELLECTUAL PROPERTY',
                              'All content, features, and functionality of ITAGO are owned by us and are protected by copyright, trademark, and other intellectual property laws.',
                              BauhausColors.black,
                            ),
                            
                            _buildSection(
                              'TERMINATION',
                              'We reserve the right to terminate or suspend your access to the service at any time for violation of these terms or for any other reason deemed necessary.',
                              BauhausColors.red,
                            ),
                            
                            _buildSection(
                              'CHANGES TO TERMS',
                              'We reserve the right to modify these terms at any time. Continued use of the service after changes constitutes acceptance of the new terms.',
                              BauhausColors.blue,
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
                              child: Padding(
                                padding: const EdgeInsets.all(20),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Container(
                                          width: 40,
                                          height: 40,
                                          color: BauhausColors.yellow,
                                          child: Icon(
                                            Icons.contact_support,
                                            color: BauhausColors.black,
                                            size: 20,
                                          ),
                                        ),
                                        const SizedBox(width: 15),
                                        Text(
                                          'CONTACT US',
                                          style: TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.w900,
                                            color: BauhausColors.black,
                                            letterSpacing: 2,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 15),
                                    Text(
                                      'For questions about these terms or our service, contact us at:',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: BauhausColors.black,
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    Text(
                                      'support@itago.ai\nwww.itago.ai/terms',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w900,
                                        color: BauhausColors.blue,
                                        letterSpacing: 1,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            
                            const SizedBox(height: 30),
                            
                            // Last updated
                            Text(
                              'LAST UPDATED: JANUARY 2025',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: BauhausColors.gray,
                                letterSpacing: 1,
                              ),
                              textAlign: TextAlign.center,
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

  Widget _buildSection(String title, String content, Color accentColor) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        border: Border.all(
          color: BauhausColors.black,
          width: 2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            color: accentColor,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Text(
              title,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w900,
                color: accentColor == BauhausColors.yellow 
                    ? BauhausColors.black 
                    : BauhausColors.white,
                letterSpacing: 1,
              ),
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