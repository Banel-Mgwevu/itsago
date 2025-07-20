import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:camera/camera.dart';
import 'main.dart';
import 'loading_screen.dart';
import 'interview_screen.dart';
import 'about_screen.dart';
import 'upgrade_premium_screen.dart';

class SetupScreen extends StatefulWidget {
  final List<CameraDescription> cameras;
  
  const SetupScreen({Key? key, required this.cameras}) : super(key: key);

  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  final _jobDescController = TextEditingController();
  final _companyController = TextEditingController();
  
  // Updated to use Gemini API key
  static const String _apiKey = '';

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {
        if (!didPop) {
          _showExitConfirmationDialog();
        }
      },
      child: Scaffold(
        backgroundColor: BauhausColors.lightGray,
        drawer: _buildBauhausDrawer(),
        body: SafeArea(
          child: SingleChildScrollView(
            child: Column(
              children: [
                // Header with Bauhaus geometric design
                Container(
                  width: double.infinity,
                  height: 200,
                  color: BauhausColors.blue,
                  child: Stack(
                    children: [
                      // Yellow circle
                      Positioned(
                        top: -50,
                        right: -50,
                        child: Container(
                          width: 150,
                          height: 150,
                          decoration: BoxDecoration(
                            color: BauhausColors.yellow,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                      // Red rectangle
                      Positioned(
                        bottom: 20,
                        left: 20,
                        child: Container(
                          width: 80,
                          height: 40,
                          color: BauhausColors.red,
                        ),
                      ),
                      // Hamburger menu button
                      Positioned(
                        top: 20,
                        left: 20,
                        child: Builder(
                          builder: (context) => GestureDetector(
                            onTap: () => Scaffold.of(context).openDrawer(),
                            child: Container(
                              width: 50,
                              height: 50,
                              decoration: BoxDecoration(
                                color: BauhausColors.white,
                                border: Border.all(
                                  color: BauhausColors.black,
                                  width: 3,
                                ),
                              ),
                              child: Icon(
                                Icons.menu,
                                color: BauhausColors.black,
                                size: 24,
                              ),
                            ),
                          ),
                        ),
                      ),
                      // Main title
                      Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'AI',
                              style: TextStyle(
                                fontSize: 48,
                                fontWeight: FontWeight.w900,
                                color: BauhausColors.white,
                                letterSpacing: 8,
                                height: 0.8,
                              ),
                            ),
                            Text(
                              'INTERVIEW',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w900,
                                color: BauhausColors.yellow,
                                letterSpacing: 4,
                              ),
                            ),
                            Text(
                              'PREP',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: BauhausColors.white,
                                letterSpacing: 2,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 40),
                
                // Form section with Bauhaus grid layout
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    children: [
                      // Setup title with geometric accent
                      Row(
                        children: [
                          Container(
                            width: 60,
                            height: 60,
                            decoration: BoxDecoration(
                              color: BauhausColors.red,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.settings,
                              color: BauhausColors.white,
                              size: 30,
                            ),
                          ),
                          const SizedBox(width: 20),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'SETUP',
                                  style: TextStyle(
                                    fontSize: 32,
                                    fontWeight: FontWeight.w900,
                                    color: BauhausColors.black,
                                    letterSpacing: 4,
                                    height: 0.9, // Reduced line height for tighter spacing
                                  ),
                                ),
                                Text(
                                  'INTERVIEW',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                    color: BauhausColors.red,
                                    letterSpacing: 2,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      
                      const SizedBox(height: 30),
                      
                      // Company field
                      _buildBauhausTextField(
                        controller: _companyController,
                        label: 'COMPANY',
                        hint: 'GOOGLE, MICROSOFT, APPLE...',
                        color: BauhausColors.yellow,
                      ),
                      
                      const SizedBox(height: 20),
                      
                      // Job description field
                      _buildBauhausTextField(
                        controller: _jobDescController,
                        label: 'JOB DESCRIPTION',
                        hint: 'PASTE COMPLETE JOB DESCRIPTION HERE...',
                        color: BauhausColors.blue,
                        maxLines: 5,
                      ),
                      
                      const SizedBox(height: 40),
                      
                      // Start button with Bauhaus styling
                      Container(
                        width: double.infinity,
                        height: 80,
                        decoration: BoxDecoration(
                          color: BauhausColors.red,
                        ),
                        child: MaterialButton(
                          onPressed: _showInterviewTypeDialog,
                          child: Text(
                            'START INTERVIEW',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                              color: BauhausColors.white,
                              letterSpacing: 3,
                            ),
                          ),
                        ),
                      ),
                      
                      const SizedBox(height: 30),
                      
                      // Info grid with Bauhaus geometric elements
                      Row(
                        children: [
                          Expanded(
                            child: _buildBauhausInfoCard(
                              'HD\nCAMERA',
                              BauhausColors.yellow,
                              Icons.camera_front,
                            ),
                          ),
                          const SizedBox(width: 20),
                          Expanded(
                            child: _buildBauhausInfoCard(
                              'SPEECH\nANALYSIS',
                              BauhausColors.blue,
                              Icons.mic,
                            ),
                          ),
                        ],
                      ),
                      
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBauhausDrawer() {
    return Drawer(
      backgroundColor: BauhausColors.white,
      child: Column(
        children: [
          // Drawer Header
          Container(
            width: double.infinity,
            height: 200,
            color: BauhausColors.blue,
            child: Stack(
              children: [
                // Geometric elements
                Positioned(
                  top: -30,
                  right: -30,
                  child: Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      color: BauhausColors.yellow,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                Positioned(
                  bottom: 10,
                  left: 10,
                  child: Container(
                    width: 60,
                    height: 30,
                    color: BauhausColors.red,
                  ),
                ),
                
                // Header content
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 60,
                        height: 60,
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
                              fontSize: 24,
                              fontWeight: FontWeight.w900,
                              color: BauhausColors.black,
                              letterSpacing: 1,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 15),
                      Text(
                        'ITSAGO',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          color: BauhausColors.white,
                          letterSpacing: 3,
                        ),
                      ),
                      Text(
                        'AI INTERVIEW PREP',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: BauhausColors.yellow,
                          letterSpacing: 1,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          // Menu Items
          Expanded(
            child: Column(
              children: [
                const SizedBox(height: 20),
                
                // About menu item
                _buildDrawerItem(
                  icon: Icons.info_outline,
                  title: 'ABOUT',
                  subtitle: 'Learn more about ITAGO',
                  color: BauhausColors.yellow,
                  onTap: () {
                    Navigator.of(context).pop();
                    Navigator.of(context).push(
                      PageRouteBuilder(
                        pageBuilder: (context, animation, secondaryAnimation) =>
                            AboutScreen(cameras: widget.cameras),
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
                  },
                ),
                
                const SizedBox(height: 15),
                
                // Upgrade to Premium menu item
                _buildDrawerItem(
                  icon: Icons.star_outline,
                  title: 'UPGRADE TO PREMIUM',
                  subtitle: 'Unlock advanced features',
                  color: BauhausColors.red,
                  onTap: () {
                    Navigator.of(context).pop();
                    Navigator.of(context).push(
                      PageRouteBuilder(
                        pageBuilder: (context, animation, secondaryAnimation) =>
                            UpgradePremiumScreen(cameras: widget.cameras),
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
                  },
                ),
                
                const Spacer(),
                
                // Footer
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    border: Border(
                      top: BorderSide(
                        color: BauhausColors.gray,
                        width: 1,
                      ),
                    ),
                  ),
                  child: Column(
                    children: [
                      Container(
                        width: 40,
                        height: 3,
                        color: BauhausColors.red,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'VERSION 1.0.0',
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
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawerItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 15),
      decoration: BoxDecoration(
        border: Border.all(
          color: BauhausColors.black,
          width: 2,
        ),
      ),
      child: Material(
        color: BauhausColors.white,
        child: InkWell(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(0),
            child: Row(
              children: [
                Container(
                  width: 70,
                  height: 70,
                  color: color,
                  child: Icon(
                    icon,
                    size: 24,
                    color: color == BauhausColors.yellow 
                        ? BauhausColors.black 
                        : BauhausColors.white,
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 15),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                            color: BauhausColors.black,
                            letterSpacing: 1,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          subtitle,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: BauhausColors.gray,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Container(
                  width: 30,
                  height: 70,
                  color: BauhausColors.lightGray,
                  child: Icon(
                    Icons.arrow_forward_ios,
                    size: 16,
                    color: BauhausColors.gray,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBauhausTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required Color color,
    int maxLines = 1,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: color,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w900,
              color: BauhausColors.white,
              letterSpacing: 2,
            ),
          ),
        ),
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            border: Border.all(color: BauhausColors.black, width: 3),
          ),
          child: TextField(
            controller: controller,
            maxLines: maxLines,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: BauhausColors.black,
            ),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(
                color: BauhausColors.gray,
                fontWeight: FontWeight.w600,
              ),
              contentPadding: const EdgeInsets.all(16),
              border: InputBorder.none,
              filled: true,
              fillColor: BauhausColors.white,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBauhausInfoCard(String text, Color color, IconData icon) {
    return Container(
      height: 120,
      decoration: BoxDecoration(
        border: Border.all(color: BauhausColors.black, width: 3),
      ),
      child: Column(
        children: [
          Container(
            height: 60,
            width: double.infinity,
            color: color,
            child: Icon(
              icon,
              size: 30,
              color: BauhausColors.white,
            ),
          ),
          Expanded(
            child: Container(
              width: double.infinity,
              color: BauhausColors.white,
              child: Center(
                child: Text(
                  text,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    color: BauhausColors.black,
                    letterSpacing: 1,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showInterviewTypeDialog() {
    if (_companyController.text.trim().isEmpty) {
      _showBauhausDialog('ERROR', 'PLEASE ENTER COMPANY NAME');
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          width: 350,
          decoration: BoxDecoration(
            border: Border.all(color: BauhausColors.black, width: 4),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                color: BauhausColors.blue,
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: BauhausColors.yellow,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.quiz,
                        color: BauhausColors.black,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 15),
                    Expanded(
                      child: Text(
                        'CHOOSE INTERVIEW TYPE',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: BauhausColors.white,
                          letterSpacing: 2,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              
              // Content
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                color: BauhausColors.white,
                child: Column(
                  children: [
                    // Normal Interview Option
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(bottom: 15),
                      decoration: BoxDecoration(
                        border: Border.all(color: BauhausColors.black, width: 2),
                      ),
                      child: Column(
                        children: [
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            color: BauhausColors.yellow,
                            child: Row(
                              children: [
                                Icon(
                                  Icons.speed,
                                  color: BauhausColors.black,
                                  size: 20,
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  'NORMAL INTERVIEW',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w900,
                                    color: BauhausColors.black,
                                    letterSpacing: 1,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            child: Text(
                              '• STANDARD INTERVIEW QUESTIONS\n• INSTANT START\n• NO INTERNET REQUIRED\n• GENERAL PURPOSE QUESTIONS',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: BauhausColors.black,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    // AI Powered Option
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(bottom: 20),
                      decoration: BoxDecoration(
                        border: Border.all(color: BauhausColors.black, width: 2),
                      ),
                      child: Column(
                        children: [
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            color: BauhausColors.red,
                            child: Row(
                              children: [
                                Icon(
                                  Icons.psychology,
                                  color: BauhausColors.white,
                                  size: 20,
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  'AI POWERED INTERVIEW',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w900,
                                    color: BauhausColors.white,
                                    letterSpacing: 1,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            child: Text(
                              '• PERSONALIZED QUESTIONS\n• BASED ON JOB DESCRIPTION\n• REQUIRES INTERNET\n• TAILORED TO YOUR ROLE',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: BauhausColors.black,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    // Buttons
                    Row(
                      children: [
                        // Normal Interview Button
                        Expanded(
                          child: Container(
                            height: 50,
                            color: BauhausColors.yellow,
                            child: MaterialButton(
                              onPressed: () {
                                Navigator.of(context).pop();
                                _startNormalInterview();
                              },
                              child: Text(
                                'NORMAL',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w900,
                                  color: BauhausColors.black,
                                  letterSpacing: 1,
                                ),
                              ),
                            ),
                          ),
                        ),
                        
                        const SizedBox(width: 15),
                        
                        // AI Powered Button
                        Expanded(
                          child: Container(
                            height: 50,
                            color: BauhausColors.red,
                            child: MaterialButton(
                              onPressed: () {
                                Navigator.of(context).pop();
                                _startAIPoweredInterview();
                              },
                              child: Text(
                                'AI POWERED',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w900,
                                  color: BauhausColors.white,
                                  letterSpacing: 1,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 15),
                    
                    // Cancel Button
                    Container(
                      width: double.infinity,
                      height: 40,
                      color: BauhausColors.gray,
                      child: MaterialButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: Text(
                          'CANCEL',
                          style: TextStyle(
                            fontSize: 12,
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

  void _startNormalInterview() {
    // Navigate to loading screen for normal interview (no API call needed)
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => LoadingScreen(
          cameras: widget.cameras,
          jobDescription: '', // Empty job description for normal interview
          company: _companyController.text.trim(),
          apiKey: _apiKey,
        ),
      ),
    );
  }

  void _startAIPoweredInterview() {
    if (_jobDescController.text.trim().isEmpty) {
      _showBauhausDialog('JOB DESCRIPTION REQUIRED', 
          'AI POWERED INTERVIEW REQUIRES JOB DESCRIPTION TO GENERATE PERSONALIZED QUESTIONS');
      return;
    }

    if (_apiKey == 'YOUR_GEMINI_API_KEY_HERE') {
      _showBauhausDialog('API ERROR', 'PLEASE REPLACE GEMINI API KEY IN CODE');
      return;
    }

    // Navigate to loading screen for AI question generation
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => LoadingScreen(
          cameras: widget.cameras,
          jobDescription: _jobDescController.text.trim(),
          company: _companyController.text.trim(),
          apiKey: _apiKey,
        ),
      ),
    );
  }


  void _showExitConfirmationDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          width: 320,
          decoration: BoxDecoration(
            border: Border.all(color: BauhausColors.black, width: 4),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                color: BauhausColors.red,
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: BauhausColors.white,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.exit_to_app,
                        color: BauhausColors.red,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 15),
                    Expanded(
                      child: Text(
                        'EXIT APP?',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: BauhausColors.white,
                          letterSpacing: 2,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              
              // Content
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                color: BauhausColors.white,
                child: Column(
                  children: [
                    Text(
                      'Are you sure you want to exit ITAGO?',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: BauhausColors.black,
                        letterSpacing: 1,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Your progress will be saved automatically.',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: BauhausColors.gray,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 25),
                    
                    // Buttons
                    Row(
                      children: [
                        // Cancel button
                        Expanded(
                          child: Container(
                            height: 50,
                            decoration: BoxDecoration(
                              color: BauhausColors.lightGray,
                              border: Border.all(
                                color: BauhausColors.gray,
                                width: 2,
                              ),
                            ),
                            child: MaterialButton(
                              onPressed: () => Navigator.of(context).pop(),
                              child: Text(
                                'CANCEL',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w900,
                                  color: BauhausColors.gray,
                                  letterSpacing: 1,
                                ),
                              ),
                            ),
                          ),
                        ),
                        
                        const SizedBox(width: 15),
                        
                        // Exit button
                        Expanded(
                          child: Container(
                            height: 50,
                            color: BauhausColors.red,
                            child: MaterialButton(
                              onPressed: () {
                                Navigator.of(context).pop();
                                SystemNavigator.pop(); // Exit the app
                              },
                              child: Text(
                                'EXIT',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w900,
                                  color: BauhausColors.white,
                                  letterSpacing: 1,
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
            ],
          ),
        ),
      ),
    );
  }

  void _showBauhausDialog(String title, String message) {
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