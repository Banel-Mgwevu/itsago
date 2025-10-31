import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'main.dart';
import 'main_menu_screen.dart';
import 'loading_screen.dart';
import 'about_screen.dart';
import 'upgrade_premium_screen.dart';

class SetupScreen extends StatefulWidget {
  final List<CameraDescription> cameras;
  
  const SetupScreen({super.key, required this.cameras});

  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  final _jobDescController = TextEditingController();
  final _companyController = TextEditingController();
  
  // Updated to use Gemini API key
  static const String _apiKey = 'AIzaSyBcK5CDUQhMY94FJEgGja6UiT4pKAcdWZw';//'AIzaSyBG9Ibtg3a0UTO5DZb4mfhmN7mtij_OMPU';

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {
        if (!didPop) {
          _navigateBackToMainMenu();
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
                  height: 220, // Increased height to accommodate subtitle
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
                      // Back button
                      Positioned(
                        top: 20,
                        left: 20,
                        child: GestureDetector(
                          onTap: _navigateBackToMainMenu,
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
                              Icons.arrow_back,
                              color: BauhausColors.black,
                              size: 24,
                            ),
                          ),
                        ),
                      ),
                      // Hamburger menu button
                      Positioned(
                        top: 20,
                        right: 20,
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
                              'VIDEO INTERVIEW',
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                                color: BauhausColors.yellow,
                                letterSpacing: 3,
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
                            const SizedBox(height: 8),
                            Text(
                              'REAL-TIME CAMERA PRACTICE',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: BauhausColors.yellow.withOpacity(0.8),
                                letterSpacing: 1,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 30),
                
                // Setup section
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
                              Icons.videocam,
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
                                    height: 0.9,
                                  ),
                                ),
                                Text(
                                  'VIDEO INTERVIEW',
                                  style: TextStyle(
                                    fontSize: 16,
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
                      
                      // Interview Type Selection
                      _buildInterviewTypeSelection(),
                      
                      const SizedBox(height: 40),
                      
                      // Info grid with Bauhaus geometric elements
                      Row(
                        children: [
                          Expanded(
                            child: _buildBauhausInfoCard(
                              'LIVE\nCAMERA',
                              BauhausColors.yellow,
                              Icons.camera_front,
                            ),
                          ),
                          const SizedBox(width: 20),
                          Expanded(
                            child: _buildBauhausInfoCard(
                              'REAL-TIME\nRECORDING',
                              BauhausColors.blue,
                              Icons.videocam,
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

  Widget _buildInterviewTypeSelection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: BauhausColors.blue,
          child: Row(
            children: [
              Icon(
                Icons.video_camera_front,
                color: BauhausColors.white,
                size: 20,
              ),
              const SizedBox(width: 10),
              Text(
                'SELECT VIDEO INTERVIEW TYPE',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  color: BauhausColors.white,
                  letterSpacing: 2,
                ),
              ),
            ],
          ),
        ),
        
        const SizedBox(height: 15),
        
        // Standard Interview Option
        _buildInterviewTypeOption(
          type: 'standard',
          title: 'STANDARD VIDEO INTERVIEW',
          subtitle: 'General questions • Instant start',
          icon: Icons.speed,
          color: BauhausColors.yellow,
        ),
        
        const SizedBox(height: 20),
        
        // AI Powered Interview Option
        _buildInterviewTypeOption(
          type: 'ai',
          title: 'AI VIDEO INTERVIEW',
          subtitle: 'AI questions • Job-specific practice',
          icon: Icons.psychology,
          color: BauhausColors.red,
        ),
      ],
    );
  }

  Widget _buildInterviewTypeOption({
    required String type,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
  }) {
    return GestureDetector(
      onTap: () => _showInterviewSetupModal(type, title, color, icon),
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(
            color: BauhausColors.black,
            width: 3,
          ),
        ),
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              color: color,
              child: Row(
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: color == BauhausColors.yellow ? BauhausColors.black : BauhausColors.white,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      icon,
                      color: color == BauhausColors.yellow ? BauhausColors.white : BauhausColors.black,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Text(
                      title,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: color == BauhausColors.yellow ? BauhausColors.black : BauhausColors.white,
                        letterSpacing: 2,
                      ),
                    ),
                  ),
                  Icon(
                    Icons.arrow_forward,
                    color: color == BauhausColors.yellow ? BauhausColors.black : BauhausColors.white,
                    size: 30,
                  ),
                ],
              ),
            ),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              color: BauhausColors.white,
              child: Text(
                subtitle,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: BauhausColors.black,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showInterviewSetupModal(String type, String title, Color color, IconData icon) {
    // Clear form controllers
    _companyController.clear();
    _jobDescController.clear();
    
    showDialog(
      context: context,
      barrierDismissible: true,
      barrierColor: BauhausColors.black.withOpacity(0.8),
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(20),
        child: Container(
          width: double.infinity,
          constraints: const BoxConstraints(maxWidth: 400, maxHeight: 600), // Add maxHeight constraint
          decoration: BoxDecoration(
            border: Border.all(color: BauhausColors.black, width: 4),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Modal Header
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                color: color,
                child: Row(
                  children: [
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: color == BauhausColors.yellow ? BauhausColors.black : BauhausColors.white,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        icon,
                        color: color == BauhausColors.yellow ? BauhausColors.white : BauhausColors.black,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 15),
                    Expanded(
                      child: Text(
                        title,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: color == BauhausColors.yellow ? BauhausColors.black : BauhausColors.white,
                          letterSpacing: 2,
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: () => Navigator.of(context).pop(),
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: color == BauhausColors.yellow ? BauhausColors.black : BauhausColors.white,
                          border: Border.all(
                            color: color == BauhausColors.yellow ? BauhausColors.white : BauhausColors.black,
                            width: 2,
                          ),
                        ),
                        child: Icon(
                          Icons.close,
                          color: color == BauhausColors.yellow ? BauhausColors.white : BauhausColors.black,
                          size: 20,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              
              // Modal Content - Wrapped in Flexible and SingleChildScrollView to handle overflow
              Flexible(
                child: Container(
                  width: double.infinity,
                  color: BauhausColors.white,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(25),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Video interview notice
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: BauhausColors.yellow.withOpacity(0.1),
                            border: Border.all(color: BauhausColors.yellow, width: 2),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.videocam,
                                color: BauhausColors.black,
                                size: 20,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'THIS WILL CREATE A MOCK VIDEO INTERVIEW USING YOUR CAMERA',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: BauhausColors.black,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        
                        const SizedBox(height: 20),
                        
                        // Company field (always shown)
                        _buildModalTextField(
                          controller: _companyController,
                          label: 'ENTER COMPANY',
                          hint: 'GOOGLE, MICROSOFT, APPLE...',
                          color: BauhausColors.yellow,
                        ),
                        
                        // Job description field (only for AI powered)
                        if (type == 'ai') ...[
                          const SizedBox(height: 20),
                          _buildModalTextField(
                            controller: _jobDescController,
                            label: 'JOB DESCRIPTION',
                            hint: 'PASTE COMPLETE JOB DESCRIPTION HERE...',
                            color: BauhausColors.blue,
                            maxLines: 4,
                          ),
                        ],
                        
                        const SizedBox(height: 25), // Reduced from 30 to 25
                        
                        // Action buttons
                        Row(
                          children: [
                            // Cancel button
                            Expanded(
                              flex: 1,
                              child: Container(
                                height: 60,
                                decoration: BoxDecoration(
                                  border: Border.all(color: BauhausColors.black, width: 3),
                                ),
                                child: MaterialButton(
                                  onPressed: () => Navigator.of(context).pop(),
                                  color: BauhausColors.lightGray,
                                  child: Text(
                                    'CANCEL',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w900,
                                      color: BauhausColors.black,
                                      letterSpacing: 1,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            
                            const SizedBox(width: 15),
                            
                            // Start interview button
                            Expanded(
                              flex: 2,
                              child: Container(
                                height: 60,
                                color: color,
                                child: MaterialButton(
                                  onPressed: () {
                                    Navigator.of(context).pop();
                                    _startInterview(type);
                                  },
                                  child: Text(
                                    'START INTERVIEW',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w900,
                                      color: color == BauhausColors.yellow ? BauhausColors.black : BauhausColors.white,
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
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModalTextField({
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
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          color: color,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w900,
              color: BauhausColors.white,
              letterSpacing: 1,
            ),
          ),
        ),
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            border: Border.all(color: BauhausColors.black, width: 2),
          ),
          child: TextField(
            controller: controller,
            maxLines: maxLines,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: BauhausColors.black,
            ),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(
                color: BauhausColors.gray,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
              contentPadding: const EdgeInsets.all(12),
              border: InputBorder.none,
              filled: true,
              fillColor: BauhausColors.white,
            ),
          ),
        ),
      ],
    );
  }

  void _startInterview(String type) {
    if (_companyController.text.trim().isEmpty) {
      _showBauhausDialog('ERROR', 'PLEASE ENTER COMPANY NAME');
      return;
    }

    if (type == 'ai') {
      _startAIPoweredInterview();
    } else {
      _startStandardInterview();
    }
  }

  void _navigateBackToMainMenu() {
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            MainMenuScreen(cameras: widget.cameras),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(-1.0, 0.0),
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
                        'AI VIDEO INTERVIEW PREP',
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
                
                // Main Menu item
                _buildDrawerItem(
                  icon: Icons.home,
                  title: 'MAIN MENU',
                  subtitle: 'Return to home screen',
                  color: BauhausColors.yellow,
                  onTap: () {
                    Navigator.of(context).pop();
                    _navigateBackToMainMenu();
                  },
                ),
                
                const SizedBox(height: 15),
                
                // About menu item
                _buildDrawerItem(
                  icon: Icons.info_outline,
                  title: 'ABOUT',
                  subtitle: 'Learn more about ITSAGO',
                  color: BauhausColors.blue,
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

  void _startStandardInterview() {
    // Navigate to loading screen for standard interview (no API call needed)
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => LoadingScreen(
          cameras: widget.cameras,
          jobDescription: '', // Empty job description for standard interview
          company: _companyController.text.trim(),
          apiKey: _apiKey,
        ),
      ),
    );
  }

  void _startAIPoweredInterview() {
    if (_jobDescController.text.trim().isEmpty) {
      _showBauhausDialog('JOB DESCRIPTION REQUIRED', 
          'AI POWERED VIDEO INTERVIEW REQUIRES JOB DESCRIPTION TO GENERATE PERSONALIZED QUESTIONS');
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