import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'main.dart';
import 'subscription_service.dart';

class UpgradePremiumScreen extends StatefulWidget {
  final List<CameraDescription> cameras;
  
  const UpgradePremiumScreen({super.key, required this.cameras});

  @override
  State<UpgradePremiumScreen> createState() => _UpgradePremiumScreenState();
}

class _UpgradePremiumScreenState extends State<UpgradePremiumScreen>
    with TickerProviderStateMixin {
  
  late AnimationController _animationController;
  late AnimationController _geometryController;
  late AnimationController _starController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _slideAnimation;
  late Animation<double> _geometryAnimation;
  late Animation<double> _starRotation;
  
  String _selectedPlan = 'monthly';
  List<ProductDetails> _products = [];
  bool _isLoading = false;
  bool _isLoadingProducts = true;

  final SubscriptionService _subscriptionService = SubscriptionService();

  // Updated Product identifiers to match your Play Console setup
  static const String monthlyProductId = 'itsago_prod';  // Updated to match Play Console
  static const String annualProductId = 'itsago_annual_prod';  // You'll need to create this in Play Console

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _startAnimations();
    _setupSubscriptionCallbacks();
    _loadProducts();
  }

  void _setupSubscriptionCallbacks() {
    _subscriptionService.onPurchaseSuccess = () {
      setState(() {
        _isLoading = false;
      });
      _showUpgradeSuccessDialog();
    };

    _subscriptionService.onPurchaseError = (error) {
      setState(() {
        _isLoading = false;
      });
      _showErrorDialog(error);
    };

    _subscriptionService.onPremiumStatusChanged = (isPremium) {
      if (isPremium) {
        print('Premium status activated');
      }
    };
  }

  void _initializeAnimations() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    
    _geometryController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    
    _starController = AnimationController(
      duration: const Duration(milliseconds: 3000),
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
    
    _starRotation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _starController,
      curve: Curves.linear,
    ));
  }

  void _startAnimations() {
    _geometryController.forward();
    _animationController.forward();
    _starController.repeat();
  }

  Future<void> _loadProducts() async {
    try {
      final products = await _subscriptionService.getAvailableProducts();
      setState(() {
        _products = products;
        _isLoadingProducts = false;
      });
      
      if (_products.isEmpty) {
        _showErrorDialog('No subscription plans available. Please try again later.');
      }
    } catch (e) {
      setState(() {
        _isLoadingProducts = false;
      });
      _showErrorDialog('Failed to load subscription plans: ${e.toString()}');
    }
  }

  ProductDetails? _getProductForPlan(String planId) {
    if (_products.isEmpty) return null;
    
    try {
      if (planId == 'monthly') {
        return _products.firstWhere(
          (product) => product.id == monthlyProductId,
        );
      } else if (planId == 'annual') {
        return _products.firstWhere(
          (product) => product.id == annualProductId,
        );
      }
    } catch (e) {
      print('Product not found for plan $planId: $e');
    }
    return null;
  }

  String _getFormattedPrice(String planId) {
    final product = _getProductForPlan(planId);
    if (product != null) {
      return product.price;
    }
    // Fallback prices - update these based on your actual pricing
    return planId == 'monthly' ? '\$19.99' : '\$199.99';
  }

  @override
  void dispose() {
    _animationController.dispose();
    _geometryController.dispose();
    _starController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BauhausColors.black,
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
                      top: -80,
                      right: -80,
                      child: Transform.scale(
                        scale: _geometryAnimation.value,
                        child: Container(
                          width: 200,
                          height: 200,
                          decoration: BoxDecoration(
                            color: BauhausColors.yellow.withOpacity(0.8),
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: -100,
                      left: -100,
                      child: Transform.scale(
                        scale: _geometryAnimation.value,
                        child: Container(
                          width: 250,
                          height: 150,
                          color: BauhausColors.red.withOpacity(0.8),
                        ),
                      ),
                    ),
                    Positioned(
                      top: 200,
                      left: 30,
                      child: Transform.scale(
                        scale: _geometryAnimation.value,
                        child: Container(
                          width: 40,
                          height: 40,
                          color: BauhausColors.blue,
                        ),
                      ),
                    ),
                    // Animated stars
                    ...List.generate(5, (index) {
                      return Positioned(
                        top: 100 + (index * 80),
                        right: 20 + (index * 30),
                        child: AnimatedBuilder(
                          animation: _starController,
                          builder: (context, child) {
                            return Transform.rotate(
                              angle: _starRotation.value * 6.28 + (index * 1.2),
                              child: Icon(
                                Icons.star,
                                size: 20 + (index * 4),
                                color: BauhausColors.yellow.withOpacity(0.6),
                              ),
                            );
                          },
                        ),
                      );
                    }),
                  ],
                );
              },
            ),
            
            // Loading overlay
            if (_isLoading)
              Container(
                color: Colors.black54,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: BauhausColors.white,
                      border: Border.all(color: BauhausColors.black, width: 3),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(BauhausColors.blue),
                        ),
                        const SizedBox(height: 15),
                        Text(
                          'Processing Payment...',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: BauhausColors.black,
                          ),
                        ),
                      ],
                    ),
                  ),
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
                                color: BauhausColors.yellow,
                                width: 4,
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
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'UPGRADE TO',
                                        style: TextStyle(
                                          fontSize: 20,
                                          fontWeight: FontWeight.w900,
                                          color: BauhausColors.black,
                                          letterSpacing: 2,
                                        ),
                                      ),
                                      Text(
                                        'PREMIUM',
                                        style: TextStyle(
                                          fontSize: 20,
                                          fontWeight: FontWeight.w900,
                                          color: BauhausColors.red,
                                          letterSpacing: 2,
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
                                      width: 3,
                                    ),
                                  ),
                                  child: Icon(
                                    Icons.star,
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
                          children: [
                            const SizedBox(height: 20),
                            
                            // Premium badge
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 15,
                              ),
                              decoration: BoxDecoration(
                                color: BauhausColors.yellow,
                                border: Border.all(
                                  color: BauhausColors.white,
                                  width: 3,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.diamond,
                                    color: BauhausColors.black,
                                    size: 24,
                                  ),
                                  const SizedBox(width: 10),
                                  Text(
                                    'PREMIUM FEATURES',
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
                            
                            const SizedBox(height: 30),
                            
                            // Features list
                            _buildPremiumFeature(
                              'UNLIMITED PRACTICE SESSIONS',
                              'Practice as much as you want without restrictions',
                              Icons.all_inclusive,
                              BauhausColors.blue,
                            ),
                            
                            const SizedBox(height: 15),
                            
                            _buildPremiumFeature(
                              'ADVANCED AI ANALYSIS',
                              'Deep learning insights into speech patterns and body language',
                              Icons.psychology,
                              BauhausColors.red,
                            ),
                            
                            const SizedBox(height: 15),
                            
                            _buildPremiumFeature(
                              'INDUSTRY-SPECIFIC QUESTIONS',
                              'Tailored questions for tech, finance, healthcare, and more',
                              Icons.business_center,
                              BauhausColors.yellow,
                            ),
                            
                            const SizedBox(height: 15),
                            
                            _buildPremiumFeature(
                              'DETAILED PROGRESS REPORTS',
                              'Comprehensive analytics and improvement tracking',
                              Icons.analytics,
                              BauhausColors.blue,
                            ),
                            
                            const SizedBox(height: 15),
                            
                            _buildPremiumFeature(
                              'PRIORITY SUPPORT',
                              '24/7 premium customer support and coaching assistance',
                              Icons.support_agent,
                              BauhausColors.red,
                            ),
                            
                            const SizedBox(height: 15),
                            
                            _buildPremiumFeature(
                              'EXPORT CAPABILITIES',
                              'Download your session recordings and feedback reports',
                              Icons.download,
                              BauhausColors.yellow,
                            ),
                            
                            const SizedBox(height: 40),
                            
                            // Pricing plans
                            Text(
                              'CHOOSE YOUR PLAN',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                                color: BauhausColors.white,
                                letterSpacing: 3,
                              ),
                            ),
                            
                            const SizedBox(height: 20),

                            if (_isLoadingProducts)
                              Container(
                                padding: const EdgeInsets.all(40),
                                child: CircularProgressIndicator(
                                  valueColor: AlwaysStoppedAnimation<Color>(BauhausColors.yellow),
                                ),
                              )
                            else ...[
                              // Monthly plan
                              _buildPricingPlan(
                                'MONTHLY',
                                _getFormattedPrice('monthly'),
                                'per month',
                                'monthly',
                                BauhausColors.blue,
                              ),
                              
                              const SizedBox(height: 15),
                              
                              // Annual plan (only show if available)
                              if (_getProductForPlan('annual') != null)
                                _buildPricingPlan(
                                  'ANNUAL',
                                  _getFormattedPrice('annual'),
                                  'per year (save 17%)',
                                  'annual',
                                  BauhausColors.red,
                                  isPopular: true,
                                ),
                            ],
                            
                            const SizedBox(height: 30),
                            
                            // Upgrade button
                            Container(
                              width: double.infinity,
                              height: 80,
                              decoration: BoxDecoration(
                                color: _isLoadingProducts 
                                    ? BauhausColors.gray 
                                    : BauhausColors.yellow,
                                border: Border.all(
                                  color: BauhausColors.white,
                                  width: 4,
                                ),
                              ),
                              child: MaterialButton(
                                onPressed: _isLoadingProducts ? null : _upgradeToPremium,
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.rocket_launch,
                                      color: BauhausColors.black,
                                      size: 28,
                                    ),
                                    const SizedBox(width: 15),
                                    Text(
                                      _isLoadingProducts ? 'LOADING...' : 'UPGRADE NOW',
                                      style: TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.w900,
                                        color: BauhausColors.black,
                                        letterSpacing: 3,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            
                            const SizedBox(height: 20),
                            
                            // Terms and restore buttons
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                TextButton(
                                  onPressed: _restorePurchases,
                                  child: Text(
                                    'Restore Purchases',
                                    style: TextStyle(
                                      color: BauhausColors.white,
                                      fontSize: 12,
                                      decoration: TextDecoration.underline,
                                    ),
                                  ),
                                ),
                                TextButton(
                                  onPressed: _showTermsAndConditions,
                                  child: Text(
                                    'Terms & Conditions',
                                    style: TextStyle(
                                      color: BauhausColors.white,
                                      fontSize: 12,
                                      decoration: TextDecoration.underline,
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
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPremiumFeature(String title, String description, IconData icon, Color color) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        border: Border.all(
          color: BauhausColors.white,
          width: 2,
        ),
      ),
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
            child: Container(
              color: BauhausColors.white,
              padding: const EdgeInsets.all(15),
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
                  const SizedBox(height: 5),
                  Text(
                    description,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: BauhausColors.gray,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPricingPlan(
    String planName,
    String price,
    String period,
    String planId,
    Color color, {
    bool isPopular = false,
  }) {
    bool isSelected = _selectedPlan == planId;
    
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedPlan = planId;
        });
      },
      child: Stack(
        children: [
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              border: Border.all(
                color: isSelected ? BauhausColors.yellow : BauhausColors.white,
                width: isSelected ? 4 : 2,
              ),
            ),
            child: Column(
              children: [
                Container(
                  width: double.infinity,
                  color: color,
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Icon(
                        isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                        color: color == BauhausColors.yellow 
                            ? BauhausColors.black 
                            : BauhausColors.white,
                        size: 24,
                      ),
                      const SizedBox(width: 15),
                      Expanded(
                        child: Text(
                          planName,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            color: color == BauhausColors.yellow 
                                ? BauhausColors.black 
                                : BauhausColors.white,
                            letterSpacing: 2,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: double.infinity,
                  color: BauhausColors.white,
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      Text(
                        price,
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                          color: BauhausColors.black,
                          letterSpacing: 1,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          period,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: BauhausColors.gray,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          // Popular badge
          if (isPopular)
            Positioned(
              top: -10,
              right: 20,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: BauhausColors.yellow,
                  border: Border.all(
                    color: BauhausColors.black,
                    width: 2,
                  ),
                ),
                child: Text(
                  'MOST POPULAR',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    color: BauhausColors.black,
                    letterSpacing: 1,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _upgradeToPremium() async {
    if (!_subscriptionService.isAvailable) {
      _showErrorDialog('In-app purchases are not available on this device.');
      return;
    }

    final product = _getProductForPlan(_selectedPlan);
    
    if (product == null) {
      _showErrorDialog('Subscription plan not available. Please try again.');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      String productId = _selectedPlan == 'monthly' ? monthlyProductId : annualProductId;
      await _subscriptionService.purchaseSubscription(productId);
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      _showErrorDialog('Failed to start purchase: ${e.toString()}');
    }
  }

  Future<void> _restorePurchases() async {
    setState(() {
      _isLoading = true;
    });

    try {
      await _subscriptionService.restorePurchases();
      
      // Check if user now has premium after restore
      final isPremium = await PremiumStatus.isPremium();
      
      setState(() {
        _isLoading = false;
      });

      if (isPremium) {
        _showUpgradeSuccessDialog();
      } else {
        _showInfoDialog(
          'No Active Subscriptions',
          'No active premium subscriptions found for this account.',
        );
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      _showErrorDialog('Failed to restore purchases: ${e.toString()}');
    }
  }

  void _showTermsAndConditions() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          width: 320,
          decoration: BoxDecoration(
            border: Border.all(color: BauhausColors.white, width: 4),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                color: BauhausColors.blue,
                child: Text(
                  'TERMS & CONDITIONS',
                  style: TextStyle(
                    fontSize: 16,
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
                      'By subscribing, you agree to our Terms of Service and Privacy Policy. Subscriptions auto-renew unless cancelled. You can manage your subscription in your device settings.',
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

  void _showUpgradeSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          width: 320,
          decoration: BoxDecoration(
            border: Border.all(color: BauhausColors.white, width: 4),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                color: BauhausColors.yellow,
                child: Row(
                  children: [
                    Icon(
                      Icons.star,
                      color: BauhausColors.black,
                      size: 24,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'UPGRADE SUCCESS!',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: BauhausColors.black,
                          letterSpacing: 2,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                color: BauhausColors.white,
                child: Column(
                  children: [
                    Text(
                      'Welcome to ITSAGO Premium!',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: BauhausColors.black,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'You now have access to all premium features. Start your advanced interview preparation journey!',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: BauhausColors.gray,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),
                    Container(
                      width: 120,
                      height: 40,
                      color: BauhausColors.blue,
                      child: MaterialButton(
                        onPressed: () {
                          Navigator.of(context).pop();
                          Navigator.of(context).pop();
                        },
                        child: Text(
                          'CONTINUE',
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

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          width: 320,
          decoration: BoxDecoration(
            border: Border.all(color: BauhausColors.white, width: 4),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                color: BauhausColors.red,
                child: Row(
                  children: [
                    Icon(
                      Icons.error,
                      color: BauhausColors.white,
                      size: 24,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'ERROR',
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
                      color: BauhausColors.red,
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

  void _showInfoDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          width: 320,
          decoration: BoxDecoration(
            border: Border.all(color: BauhausColors.white, width: 4),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                color: BauhausColors.blue,
                child: Text(
                  title.toUpperCase(),
                  style: TextStyle(
                    fontSize: 16,
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