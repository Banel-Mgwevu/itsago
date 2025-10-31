import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:camera/camera.dart';
import 'main.dart';
import 'setup_screen.dart';
import 'resources_screen.dart';
import 'ai_coach_screen.dart';
import 'about_screen.dart';
import 'upgrade_premium_screen.dart';
import 'upgrade_modal_service.dart'; // Import the new upgrade modal service
import 'resume_builder_screen.dart'; // Uncomment when you create this screen

class MainMenuScreen extends StatefulWidget {
  final List<CameraDescription> cameras;
  
  const MainMenuScreen({super.key, required this.cameras});

  @override
  State<MainMenuScreen> createState() => _MainMenuScreenState();
}

class _MainMenuScreenState extends State<MainMenuScreen> {
  
  @override
  void initState() {
    super.initState();
    // Show upgrade modal after the screen builds
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showUpgradeModalIfNeeded();
    });
  }

  Future<void> _showUpgradeModalIfNeeded() async {
    await UpgradeModalService.showUpgradeModalIfNeeded(context, widget.cameras);
  }

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
                  height: 220,
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
                      // Small white square accent
                      Positioned(
                        top: 50,
                        left: 50,
                        child: Container(
                          width: 30,
                          height: 30,
                          color: BauhausColors.white,
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
                                fontSize: 56,
                                fontWeight: FontWeight.w900,
                                color: BauhausColors.white,
                                letterSpacing: 10,
                                height: 0.8,
                              ),
                            ),
                            Text(
                              'INTERVIEW',
                              style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.w900,
                                color: BauhausColors.yellow,
                                letterSpacing: 6,
                              ),
                            ),
                            Text(
                              'PREP',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w600,
                                color: BauhausColors.white,
                                letterSpacing: 4,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Container(
                              width: 60,
                              height: 3,
                              color: BauhausColors.red,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 30),
                
                // Welcome section
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    children: [
                      // Welcome title with geometric accent
                      Row(
                        children: [
                          Container(
                            width: 60,
                            height: 60,
                            decoration: BoxDecoration(
                              color: BauhausColors.yellow,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.home,
                              color: BauhausColors.black,
                              size: 30,
                            ),
                          ),
                          const SizedBox(width: 25),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'WELCOME',
                                  style: TextStyle(
                                    fontSize: 32,
                                    fontWeight: FontWeight.w900,
                                    color: BauhausColors.black,
                                    letterSpacing: 4,
                                    height: 0.9,
                                  ),
                                ),
                                Text(
                                  'CHOOSE YOUR PATH',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: BauhausColors.gray,
                                    letterSpacing: 2,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      
                      const SizedBox(height: 28),
                      
                      // Main menu options - Updated with upgrade modal triggers
                      _buildMainMenuOption(
                        title: 'START VIDEO\nINTERVIEW',
                        subtitle: 'PREPARE WITH AI-POWERED\nMOCK VIDEO INTERVIEWS',
                        icon: Icons.video_camera_front,
                        color: BauhausColors.red,
                        onTap: () async {
                          // Show upgrade modal before navigating
                          await context.showUpgradeModalIfNeeded(widget.cameras);
                          
                          if (mounted) {
                            Navigator.of(context).push(
                              PageRouteBuilder(
                                pageBuilder: (context, animation, secondaryAnimation) =>
                                    SetupScreen(cameras: widget.cameras),
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
                        },
                      ),
                      
                      const SizedBox(height: 20),
                      
                      _buildMainMenuOption(
                        title: 'ASK AI\nCOACH',
                        subtitle: 'CALENDAR-AWARE COACHING\n& INSTANT INTERVIEW HELP',
                        icon: Icons.psychology,
                        color: BauhausColors.yellow,
                        onTap: () async {
                          // Show upgrade modal before navigating
                          await context.showUpgradeModalIfNeeded(widget.cameras);
                          
                          if (mounted) {
                            Navigator.of(context).push(
                              PageRouteBuilder(
                                pageBuilder: (context, animation, secondaryAnimation) =>
                                    AiCoachScreen(cameras: widget.cameras),
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
                        },
                      ),
                      
                      const SizedBox(height: 20),
                      
                      // Resume Builder menu option - Updated with BLUE color (swapped from orange)
                      _buildMainMenuOption(
                        title: 'BUILD\nRESUME',
                        subtitle: 'CREATE PROFESSIONAL RESUMES\nWITH AI ASSISTANCE',
                        icon: Icons.description,
                        color: BauhausColors.blue, // Changed from orange to blue
                        onTap: () async {
                          // Show upgrade modal before navigating
                          await context.showUpgradeModalIfNeeded(widget.cameras);
                          
                          if (mounted) {
                            
                            // Uncomment when you create ResumeBuilderScreen:
                            
                            Navigator.of(context).push(
                              PageRouteBuilder(
                                pageBuilder: (context, animation, secondaryAnimation) =>
                                    ResumeBuilderScreen(cameras: widget.cameras),
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
                        },
                      ),
                      
                      const SizedBox(height: 20),
                      
                      // Interview Resources - Updated with ORANGE color (swapped from blue)
                      _buildMainMenuOption(
                        title: 'INTERVIEW\nRESOURCES',
                        subtitle: 'ACCESS PREMIUM GUIDES,\nTIPS & STRATEGIES',
                        icon: Icons.library_books,
                        color: const Color(0xFFFF6B35), // Changed from blue to orange
                        onTap: () async {
                          // Show upgrade modal before navigating
                          await context.showUpgradeModalIfNeeded(widget.cameras);
                          
                          if (mounted) {
                            Navigator.of(context).push(
                              PageRouteBuilder(
                                pageBuilder: (context, animation, secondaryAnimation) =>
                                    ResourcesScreen(cameras: widget.cameras),
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
                        },
                      ),
                      
                      const SizedBox(height: 40),
                      
                      // Feature highlights
                      Row(
                        children: [
                          Expanded(
                            child: _buildFeatureCard(
                              'AI\nPOWERED',
                              BauhausColors.yellow,
                              Icons.psychology,
                            ),
                          ),
                          const SizedBox(width: 15),
                          Expanded(
                            child: _buildFeatureCard(
                              'REAL-TIME\nFEEDBACK',
                              BauhausColors.red,
                              Icons.analytics,
                            ),
                          ),
                          const SizedBox(width: 15),
                          Expanded(
                            child: _buildFeatureCard(
                              'PRACTICE\nANYWHERE',
                              BauhausColors.blue,
                              Icons.smartphone,
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

  Widget _buildMainMenuOption({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Container(
      width: double.infinity,
      height: 120,
      decoration: BoxDecoration(
        border: Border.all(color: BauhausColors.black, width: 4),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: Row(
            children: [
              // Icon section
              Container(
                width: 100,
                height: double.infinity,
                color: color,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      icon,
                      size: 32,
                      color: color == BauhausColors.yellow 
                          ? BauhausColors.black 
                          : BauhausColors.white,
                    ),
                    const SizedBox(height: 6),
                    Container(
                      width: 24,
                      height: 2,
                      color: color == BauhausColors.yellow 
                          ? BauhausColors.black 
                          : BauhausColors.white,
                    ),
                  ],
                ),
              ),
              
              // Content section
              Expanded(
                child: Container(
                  color: BauhausColors.white,
                  padding: const EdgeInsets.all(15),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Flexible(
                        child: Text(
                          title,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            color: BauhausColors.black,
                            letterSpacing: 1.5,
                            height: 1.0,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Flexible(
                        child: Text(
                          subtitle,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: BauhausColors.gray,
                            letterSpacing: 0.5,
                            height: 1.1,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              
              // Arrow section
              Container(
                width: 40,
                height: double.infinity,
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
    );
  }

  Widget _buildFeatureCard(String text, Color color, IconData icon) {
    return Container(
      height: 100,
      decoration: BoxDecoration(
        border: Border.all(color: BauhausColors.black, width: 3),
      ),
      child: Column(
        children: [
          Container(
            height: 50,
            width: double.infinity,
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
            child: Container(
              width: double.infinity,
              color: BauhausColors.white,
              child: Center(
                child: Text(
                  text,
                  style: TextStyle(
                    fontSize: 10,
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
                
                // Practice Interview menu item
                _buildDrawerItem(
                  icon: Icons.video_camera_front,
                  title: 'PRACTICE INTERVIEW',
                  subtitle: 'Start your interview prep',
                  color: BauhausColors.red,
                  onTap: () async {
                    Navigator.of(context).pop();
                    await context.showUpgradeModalIfNeeded(widget.cameras);
                    
                    if (mounted) {
                      Navigator.of(context).push(
                        PageRouteBuilder(
                          pageBuilder: (context, animation, secondaryAnimation) =>
                              SetupScreen(cameras: widget.cameras),
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
                  },
                ),
                
                const SizedBox(height: 15),
                
                // AI Coach menu item
                _buildDrawerItem(
                  icon: Icons.psychology,
                  title: 'ASK AI COACH',
                  subtitle: 'Calendar sync & interview prep',
                  color: BauhausColors.yellow,
                  onTap: () async {
                    Navigator.of(context).pop();
                    await context.showUpgradeModalIfNeeded(widget.cameras);
                    
                    if (mounted) {
                      Navigator.of(context).push(
                        PageRouteBuilder(
                          pageBuilder: (context, animation, secondaryAnimation) =>
                              AiCoachScreen(cameras: widget.cameras),
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
                  },
                ),
                
                const SizedBox(height: 15),
                
                // Resume Builder drawer menu item - Updated with BLUE color (swapped from orange)
                _buildDrawerItem(
                  icon: Icons.description,
                  title: 'BUILD RESUME',
                  subtitle: 'Create professional resumes',
                  color: BauhausColors.blue, // Changed from orange to blue
                  onTap: () async {
                    Navigator.of(context).pop();
                    await context.showUpgradeModalIfNeeded(widget.cameras);
                    
                    if (mounted) {
                      // TODO: Replace this placeholder with your actual ResumeBuilderScreen
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Resume Builder - Coming Soon!',
                            style: TextStyle(
                              color: BauhausColors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          backgroundColor: BauhausColors.blue, // Blue snackbar
                          duration: const Duration(seconds: 2),
                        ),
                      );
                      
                      // Uncomment when you create ResumeBuilderScreen:
                      /*
                      Navigator.of(context).push(
                        PageRouteBuilder(
                          pageBuilder: (context, animation, secondaryAnimation) =>
                              ResumeBuilderScreen(cameras: widget.cameras),
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
                      */
                    }
                  },
                ),
                
                const SizedBox(height: 15),
                
                // Resources menu item - Updated with ORANGE color (swapped from blue)
                _buildDrawerItem(
                  icon: Icons.library_books,
                  title: 'INTERVIEW RESOURCES',
                  subtitle: 'Guides and study materials',
                  color: const Color(0xFFFF6B35), // Changed from blue to orange
                  onTap: () async {
                    Navigator.of(context).pop();
                    await context.showUpgradeModalIfNeeded(widget.cameras);
                    
                    if (mounted) {
                      Navigator.of(context).push(
                        PageRouteBuilder(
                          pageBuilder: (context, animation, secondaryAnimation) =>
                              ResourcesScreen(cameras: widget.cameras),
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
                  },
                ),
                
                const SizedBox(height: 15),
                
                // About menu item
                _buildDrawerItem(
                  icon: Icons.info_outline,
                  title: 'ABOUT',
                  subtitle: 'Learn more about ITSAGO',
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
                      'Are you sure you want to exit ITSAGO?',
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
}