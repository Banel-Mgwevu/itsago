import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'main.dart';

class TermsScreen extends StatefulWidget {
  final List<CameraDescription> cameras;
  
  const TermsScreen({super.key, required this.cameras});

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
                              'By accessing and using ITSAGO (the "Service"), you accept and agree to be bound by the terms and provision of this agreement. If you do not agree to these terms, please do not use our service.',
                              BauhausColors.red,
                            ),
                            
                            _buildSection(
                              'SERVICE DESCRIPTION',
                              'ITSAGO is an AI-powered interview coaching application that provides personalized practice sessions, calendar-integrated coaching, push notifications, feedback on communication skills, body language analysis, and comprehensive interview preparation tools powered by advanced artificial intelligence.',
                              BauhausColors.blue,
                            ),

                            _buildSection(
                              'CALENDAR INTEGRATION & DATA',
                              'Our calendar integration feature accesses your Google Calendar to provide personalized coaching based on upcoming interviews. We only read calendar events that contain interview-related keywords. Calendar data is processed locally on your device and used solely to enhance your coaching experience. You can revoke calendar access at any time.',
                              BauhausColors.yellow,
                            ),

                            _buildSection(
                              'PUSH NOTIFICATIONS & CONSENT',
                              'We send push notifications to remind you of upcoming interviews, provide daily motivation, and deliver coaching tips. You control notification preferences and can disable them at any time. Notifications may include interview reminders based on your calendar events and general coaching content to improve your skills.',
                              BauhausColors.black,
                            ),
                            
                            _buildSection(
                              'USER DATA & PRIVACY PROTECTION',
                              'We collect and process your data to provide personalized coaching experiences. Your interview sessions may be recorded for AI analysis purposes. We implement industry-standard security measures to protect your data. We are committed to protecting your privacy and will never sell your personal information to third parties. Your data rights under GDPR, CCPA, and other privacy laws are fully respected.',
                              BauhausColors.red,
                            ),
                            
                            _buildSection(
                              'ARTIFICIAL INTELLIGENCE & MACHINE LEARNING',
                              'Our advanced AI technology analyzes your speech patterns, facial expressions, body language, and interview responses to provide personalized feedback. All AI processing is designed to improve your interview skills. The AI learns from aggregated, anonymized data to enhance coaching quality while maintaining your privacy. Individual sessions remain private to you.',
                              BauhausColors.blue,
                            ),

                            _buildSection(
                              'GOOGLE SERVICES INTEGRATION',
                              'Our app integrates with Google services including Google Calendar and Google Sign-In. Your use of these features is also governed by Google\'s Privacy Policy and Terms of Service. We only access the minimum necessary data to provide our coaching services. You can disconnect Google services at any time through your device settings.',
                              BauhausColors.yellow,
                            ),

                            _buildSection(
                              'DATA RETENTION & DELETION',
                              'We retain your data only as long as necessary to provide our services or as required by law. You can request deletion of your account and associated data at any time. Upon deletion request, we will remove your personal data within 30 days, except where retention is required for legal compliance or legitimate business purposes.',
                              BauhausColors.black,
                            ),
                            
                            _buildSection(
                              'USER RESPONSIBILITIES',
                              'You are responsible for providing accurate information and using the service in a lawful manner. You must not attempt to reverse engineer, modify, or distribute any part of our AI technology. You are responsible for maintaining the confidentiality of your account credentials and for all activities under your account.',
                              BauhausColors.red,
                            ),

                            _buildSection(
                              'COACHING DISCLAIMER',
                              'ITSAGO provides AI-powered coaching suggestions and feedback for educational and skill development purposes. Our service is designed to help improve interview skills but cannot guarantee specific interview outcomes or job offers. Results may vary based on individual effort, market conditions, and other factors beyond our control.',
                              BauhausColors.blue,
                            ),
                            
                            _buildSection(
                              'LIMITATION OF LIABILITY',
                              'The service is provided "as is" without warranties of any kind, either express or implied. We shall not be liable for any indirect, incidental, special, consequential, or punitive damages resulting from your use of the service. Our total liability shall not exceed the amount paid by you for the service in the twelve months preceding the claim.',
                              BauhausColors.yellow,
                            ),
                            
                            _buildSection(
                              'SUBSCRIPTION & PAYMENTS',
                              'Certain premium features require a subscription. Payment terms, pricing, and cancellation policies are clearly stated at the time of purchase. Subscriptions automatically renew unless cancelled. You may cancel your subscription at any time through your device\'s app store. Refunds are subject to our refund policy and applicable app store policies.',
                              BauhausColors.black,
                            ),

                            _buildSection(
                              'FREE TIER & PREMIUM FEATURES',
                              'We offer both free and premium features. Free tier users have access to basic interview coaching. Premium features include advanced AI analysis, unlimited practice sessions, detailed performance analytics, and priority customer support. Feature availability may change with notice.',
                              BauhausColors.red,
                            ),
                            
                            _buildSection(
                              'INTELLECTUAL PROPERTY',
                              'All content, features, AI models, and functionality of ITSAGO are owned by us and are protected by international copyright, trademark, and other intellectual property laws. You may not copy, modify, distribute, sell, or lease any part of our services or included software.',
                              BauhausColors.blue,
                            ),

                            _buildSection(
                              'THIRD-PARTY SERVICES',
                              'Our app may integrate with third-party services and platforms. We are not responsible for the privacy practices or content of these third-party services. Your use of third-party services is subject to their respective terms and privacy policies.',
                              BauhausColors.yellow,
                            ),

                            _buildSection(
                              'PROHIBITED USES',
                              'You may not use our service for any unlawful purposes, to violate any laws, to transmit harmful or malicious content, to attempt unauthorized access to our systems, or to interfere with other users\' experience. We reserve the right to investigate and take appropriate action against violations.',
                              BauhausColors.black,
                            ),
                            
                            _buildSection(
                              'TERMINATION & SUSPENSION',
                              'We reserve the right to terminate or suspend your access to the service at any time for violation of these terms, suspected fraudulent activity, or for any other reason deemed necessary for the protection of our service and users. Upon termination, your right to use the service ceases immediately.',
                              BauhausColors.red,
                            ),

                            _buildSection(
                              'UPDATES & MODIFICATIONS',
                              'We regularly update our service to improve functionality and add new features. Some updates may require acceptance of new terms. We will notify you of significant changes to these terms through the app or via email. Continued use after notification constitutes acceptance.',
                              BauhausColors.blue,
                            ),
                            
                            _buildSection(
                              'CHANGES TO TERMS',
                              'We reserve the right to modify these terms at any time. We will provide notice of material changes through the app, email, or other communication methods. Your continued use of the service after changes become effective constitutes acceptance of the new terms.',
                              BauhausColors.yellow,
                            ),

                            _buildSection(
                              'GOVERNING LAW & DISPUTE RESOLUTION',
                              'These terms shall be governed by and construed in accordance with applicable laws. Any disputes arising under these terms shall be resolved through binding arbitration where permitted by law. You retain the right to bring claims in small claims court for qualifying disputes.',
                              BauhausColors.black,
                            ),

                            _buildSection(
                              'ACCESSIBILITY & SUPPORT',
                              'We strive to make our service accessible to users with disabilities. If you encounter accessibility barriers, please contact our support team. We provide customer support through multiple channels and aim to respond to inquiries within 48 hours.',
                              BauhausColors.red,
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
                                          'CONTACT & SUPPORT',
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
                                      'For questions about these terms, privacy concerns, data requests, or technical support:',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: BauhausColors.black,
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: BauhausColors.lightGray,
                                        border: Border.all(color: BauhausColors.gray, width: 1),
                                      ),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            '📧 Email: support@itsago.ai',
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w700,
                                              color: BauhausColors.blue,
                                            ),
                                          ),
                                          const SizedBox(height: 5),
                                          Text(
                                            '🌐 Website: www.itsago.ai',
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w700,
                                              color: BauhausColors.blue,
                                            ),
                                          ),
                                          const SizedBox(height: 5),
                                          Text(
                                            '📄 Privacy Policy: www.itsago.ai/privacy',
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w700,
                                              color: BauhausColors.blue,
                                            ),
                                          ),
                                          const SizedBox(height: 5),
                                          Text(
                                            '⚖️ Terms: www.itsago.ai/terms',
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w700,
                                              color: BauhausColors.blue,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            
                            const SizedBox(height: 30),

                            // Compliance notice
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(15),
                              decoration: BoxDecoration(
                                color: BauhausColors.yellow,
                                border: Border.all(color: BauhausColors.black, width: 2),
                              ),
                              child: Column(
                                children: [
                                  Icon(
                                    Icons.verified_user,
                                    color: BauhausColors.black,
                                    size: 24,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'COMPLIANCE & PRIVACY',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w900,
                                      color: BauhausColors.black,
                                      letterSpacing: 1,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 5),
                                  Text(
                                    'GDPR Compliant • CCPA Compliant • SOC 2 Type II',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: BauhausColors.black,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            ),
                            
                            const SizedBox(height: 20),
                            
                            // Last updated
                            Center(
                              child: Text(
                                'LAST UPDATED: JANUARY 2025 • VERSION 2.0',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: BauhausColors.gray,
                                  letterSpacing: 1,
                                ),
                                textAlign: TextAlign.center,
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