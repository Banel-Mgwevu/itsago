import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:interviewai/subscription_service.dart';
import 'main.dart';
import 'upgrade_premium_screen.dart';

class UpgradeModalService {
  static bool _isModalShowing = false;
  static bool _hasBeenShown = false; // Only show modal once per app session
  static const Duration _modalDelay = Duration(milliseconds: 500);

  // Show upgrade modal if user is not premium and hasn't been shown yet
  static Future<void> showUpgradeModalIfNeeded(
    BuildContext context, 
    List<CameraDescription> cameras
  ) async {
    // Prevent multiple modals or showing again if already shown
    if (_isModalShowing || _hasBeenShown) return;
    
    try {
      // Check if user is already premium
      final isPremium = await PremiumStatus.isPremium();
      if (isPremium) return;
      
      // Add small delay for better UX
      await Future.delayed(_modalDelay);
      
      if (!context.mounted) return;
      
      _isModalShowing = true;
      _hasBeenShown = true; // Mark as shown
      
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => UpgradeModal(cameras: cameras),
      );
      
      _isModalShowing = false;
    } catch (e) {
      _isModalShowing = false;
      print('Error showing upgrade modal: $e');
    }
  }
  
  // Force show modal (ignores _hasBeenShown flag - for manual triggers like menu items)
  static Future<void> forceShowUpgradeModal(
    BuildContext context,
    List<CameraDescription> cameras
  ) async {
    if (_isModalShowing) return;
    
    _isModalShowing = true;
    
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => UpgradeModal(cameras: cameras),
    );
    
    _isModalShowing = false;
  }
  
  // Reset the shown flag (useful for testing or if app restarts and you want to show it again)
  static void resetShownFlag() {
    _hasBeenShown = false;
  }
}

class UpgradeModal extends StatefulWidget {
  final List<CameraDescription> cameras;
  
  const UpgradeModal({Key? key, required this.cameras}) : super(key: key);

  @override
  State<UpgradeModal> createState() => _UpgradeModalState();
}

class _UpgradeModalState extends State<UpgradeModal>
    with TickerProviderStateMixin {
  
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _startAnimations();
  }

  void _initializeAnimations() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    
    _scaleAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    ));
    
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black54,
      child: Center(
        child: AnimatedBuilder(
          animation: _animationController,
          builder: (context, child) {
            return Transform.scale(
              scale: _scaleAnimation.value,
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: Container(
                  width: 340,
                  margin: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: BauhausColors.black,
                      width: 3,
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Header
                      Container(
                        width: double.infinity,
                        color: BauhausColors.red,
                        padding: const EdgeInsets.all(25),
                        child: Column(
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
                              child: Icon(
                                Icons.star,
                                color: BauhausColors.red,
                                size: 30,
                              ),
                            ),
                            const SizedBox(height: 15),
                            Text(
                              'UNLOCK PREMIUM',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                                color: BauhausColors.white,
                                letterSpacing: 3,
                              ),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              'ADVANCED FEATURES',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: BauhausColors.white,
                                letterSpacing: 1,
                              ),
                            ),
                          ],
                        ),
                      ),
                      
                      // Content
                      Container(
                        width: double.infinity,
                        color: BauhausColors.white,
                        padding: const EdgeInsets.all(25),
                        child: Column(
                          children: [
                            _buildFeatureRow('Unlimited Practice Sessions', Icons.all_inclusive),
                            const SizedBox(height: 12),
                            _buildFeatureRow('Advanced AI Analysis', Icons.psychology),
                            const SizedBox(height: 12),
                            _buildFeatureRow('Industry-Specific Questions', Icons.business_center),
                            const SizedBox(height: 12),
                            _buildFeatureRow('Priority Support & More', Icons.support_agent),
                            
                            const SizedBox(height: 25),
                            
                            // Upgrade button
                            Container(
                              width: double.infinity,
                              height: 60,
                              decoration: BoxDecoration(
                                color: BauhausColors.blue,
                                border: Border.all(
                                  color: BauhausColors.black,
                                  width: 3,
                                ),
                              ),
                              child: MaterialButton(
                                onPressed: _navigateToUpgradeScreen,
                                child: Text(
                                  'UPGRADE NOW',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w900,
                                    color: BauhausColors.white,
                                    letterSpacing: 2,
                                  ),
                                ),
                              ),
                            ),
                            
                            const SizedBox(height: 15),
                            
                            // Later button
                            Container(
                              width: double.infinity,
                              height: 45,
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: BauhausColors.gray,
                                  width: 2,
                                ),
                              ),
                              child: MaterialButton(
                                onPressed: _dismissModal,
                                child: Text(
                                  'MAYBE LATER',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: BauhausColors.gray,
                                    letterSpacing: 1,
                                  ),
                                ),
                              ),
                            ),
                            
                            const SizedBox(height: 15),
                            
                            // Disclaimer
                            Text(
                              'Upgrade to unlock all premium features',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: BauhausColors.gray,
                                letterSpacing: 0.5,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildFeatureRow(String text, IconData icon) {
    return Row(
      children: [
        Container(
          width: 35,
          height: 35,
          decoration: BoxDecoration(
            color: BauhausColors.yellow,
            border: Border.all(
              color: BauhausColors.black,
              width: 2,
            ),
          ),
          child: Icon(
            icon,
            size: 18,
            color: BauhausColors.black,
          ),
        ),
        const SizedBox(width: 15),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: BauhausColors.black,
              letterSpacing: 0.5,
            ),
          ),
        ),
      ],
    );
  }

  void _navigateToUpgradeScreen() {
    Navigator.of(context).pop(); // Close modal
    
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
  }

  void _dismissModal() {
    Navigator.of(context).pop();
  }
}

// Extension to easily show upgrade modal from any widget
extension UpgradeModalExtension on BuildContext {
  Future<void> showUpgradeModalIfNeeded(List<CameraDescription> cameras) async {
    await UpgradeModalService.showUpgradeModalIfNeeded(this, cameras);
  }
  
  Future<void> forceShowUpgradeModal(List<CameraDescription> cameras) async {
    await UpgradeModalService.forceShowUpgradeModal(this, cameras);
  }
  
  void resetUpgradeModalFlag() {
    UpgradeModalService.resetShownFlag();
  }
}