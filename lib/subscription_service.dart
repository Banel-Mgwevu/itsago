import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'analytics_service.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart'
    show InAppPurchaseAndroidPlatformAddition, GooglePlayProductDetails;
import 'package:in_app_purchase_android/billing_client_wrappers.dart'
    show PurchaseStateWrapper;
import 'package:in_app_purchase_storekit/in_app_purchase_storekit.dart';
import 'package:in_app_purchase_storekit/store_kit_wrappers.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class SubscriptionService {
  static final SubscriptionService _instance = SubscriptionService._internal();
  factory SubscriptionService() => _instance;
  SubscriptionService._internal();

  final InAppPurchase _inAppPurchase = InAppPurchase.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  late StreamSubscription<List<PurchaseDetails>> _subscription;
  bool _isAvailable = false;
  List<ProductDetails> _products = [];
  bool _listening = false;

  /// Broadcast stream the paywall modal listens to while it is open.
  final StreamController<SubscriptionEvent> _events =
      StreamController<SubscriptionEvent>.broadcast();
  Stream<SubscriptionEvent> get events => _events.stream;

  /// The R80/month base plan as loaded from Google Play (null until loaded).
  ProductDetails? get monthlyProduct => _findPlan(monthlyBasePlanId);

  /// The R828/year base plan (null until loaded, or if it isn't live yet).
  ProductDetails? get annualProduct => _findPlan(annualBasePlanId);

  ProductDetails? _findPlan(String basePlanId) {
    if (Platform.isIOS) {
      final wanted = basePlanId == annualBasePlanId
          ? iosAnnualProductId
          : iosMonthlyProductId;
      for (final p in _products) {
        if (p.id == wanted) return p;
      }
      return null;
    }
    for (final p in _products) {
      if (p.id != monthlyProductId) continue;
      final plan = _basePlanOf(p);
      // iOS / non-Play products have no base plan - treat as monthly.
      if (plan == basePlanId || (plan == null && basePlanId == monthlyBasePlanId)) {
        return p;
      }
    }
    return null;
  }

  static String? _basePlanOf(ProductDetails p) {
    if (p is GooglePlayProductDetails && p.subscriptionIndex != null) {
      return p.productDetails
          .subscriptionOfferDetails![p.subscriptionIndex!].basePlanId;
    }
    return null;
  }
  
  // Play Console: subscription "itsago_paid", base plan "itsagopaid"
  // (monthly, auto-renewing, R80/month). The price shown in the app comes
  // straight from Google Play, so changing it in Play Console is enough.
  static const String monthlyProductId = 'itsago_paid';
  static const String monthlyBasePlanId = 'itsagopaid';

  /// Annual base plan on the SAME subscription (R828/year = R69 x 12).
  /// Create it in Play Console: itsago_paid > Add base plan > "itsagoannual".
  static const String annualBasePlanId = 'itsagoannual';

  /// Kept only for backwards compatibility with the old product id. It is
  /// no longer sold, but anyone still holding an active one keeps premium.
  static const String annualProductId = 'itsago_annual_prod';
  static const Set<String> _kLegacyProductIds = <String>{
    'itsago_prod',
    'itsago_annual_prod',
  };

  /// Products the paywall loads and sells on Android.
  static const Set<String> _kProductIds = <String>{
    monthlyProductId,
  };

  /// App Store has no "base plans": monthly and annual are two separate
  /// auto-renewable products in one subscription group ("ITSAGO Premium").
  /// Create them in App Store Connect with exactly these IDs.
  static const String iosMonthlyProductId = 'itsago_premium_monthly';
  static const String iosAnnualProductId  = 'itsago_premium_annual';
  static const Set<String> _kIosProductIds = <String>{
    iosMonthlyProductId,
    iosAnnualProductId,
  };

  static Set<String> get _productIdsForPlatform =>
      Platform.isIOS ? _kIosProductIds : _kProductIds;

  /// Every product id that grants premium (current + legacy).
  static final Set<String> _kEntitlementProductIds = <String>{
    ..._kProductIds,
    ..._kIosProductIds,
    ..._kLegacyProductIds,
  };

  // Callbacks
  VoidCallback? onPurchaseSuccess;
  Function(String)? onPurchaseError;
  Function(bool)? onPremiumStatusChanged;

  bool get isAvailable => _isAvailable;
  List<ProductDetails> get products => _products;

  Future<void> initialize() async {
    if (kDebugMode) {
      print('SubscriptionService: Initializing...');
    }
    
    // Enable pending purchases on Android
    if (Platform.isIOS) {
      final InAppPurchaseStoreKitPlatformAddition iosPlatformAddition =
          _inAppPurchase.getPlatformAddition<InAppPurchaseStoreKitPlatformAddition>();
      await iosPlatformAddition.setDelegate(ExamplePaymentQueueDelegate());
    }

    _isAvailable = await _inAppPurchase.isAvailable();
    
    if (!_isAvailable) {
      if (kDebugMode) {
        print('SubscriptionService: Store not available');
      }
      return;
    }

    // Listen to purchase updates (only once, even if initialize runs again)
    if (!_listening) {
      _subscription = _inAppPurchase.purchaseStream.listen(
        _onPurchaseUpdate,
        onDone: _updateStreamOnDone,
        onError: _updateStreamOnError,
      );
      _listening = true;
    }

    await _loadProducts();
    await _checkExistingPurchases();

    // Monthly subscriptions can lapse - make sure premium is switched off
    // for anyone whose subscription is no longer active on Google Play.
    await _refreshEntitlement();
    
    // Sync with Firestore if user is authenticated
    await _syncWithFirestore();
    
    if (kDebugMode) {
      print('SubscriptionService: Initialization complete');
    }
  }

  Future<void> _loadProducts() async {
    try {
      final ProductDetailsResponse response = await _inAppPurchase.queryProductDetails(_productIdsForPlatform);
      
      if (response.notFoundIDs.isNotEmpty) {
        if (kDebugMode) {
          print('SubscriptionService: Products not found: ${response.notFoundIDs}');
        }
      }
      
      _products = _pickBasePlanOffers(response.productDetails);
      
      if (kDebugMode) {
        print('SubscriptionService: Loaded ${_products.length} products');
        for (var product in _products) {
          print('Product: ${product.id} - ${product.title} - ${product.price}');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('SubscriptionService: Error loading products: $e');
      }
      rethrow;
    }
  }

  /// On Android, Google Play returns one ProductDetails per base plan/offer
  /// of a subscription. Keep exactly one entry per product: the
  /// "itsagopaid" base plan (the plain R80/month price, no promo offer).
  List<ProductDetails> _pickBasePlanOffers(List<ProductDetails> all) {
    if (!Platform.isAndroid) return all;

    const wantedPlans = {monthlyBasePlanId, annualBasePlanId};
    final Map<String, ProductDetails> picked = {};
    for (final product in all) {
      if (product is GooglePlayProductDetails &&
          product.subscriptionIndex != null) {
        final offer = product.productDetails
            .subscriptionOfferDetails![product.subscriptionIndex!];
        final isWantedBasePlan = product.id == monthlyProductId
            ? wantedPlans.contains(offer.basePlanId)
            : true;
        // offerId == null means the base plan itself, not a promo offer.
        // Keyed per base plan so monthly and annual both survive.
        if (isWantedBasePlan && offer.offerId == null) {
          picked['${product.id}:${offer.basePlanId}'] = product;
        }
      } else {
        picked.putIfAbsent(product.id, () => product);
      }
    }
    return picked.values.toList();
  }

  /// Makes sure the store is connected and the subscription is loaded.
  /// Safe to call many times - the paywall calls it before every purchase,
  /// so a failed start-up (no network, Play Store updating) heals itself.
  Future<void> ensureReady() async {
    if (!_isAvailable) {
      await initialize();
      return;
    }
    if (monthlyProduct == null) {
      await _loadProducts();
    }
  }

  Future<List<ProductDetails>> getAvailableProducts() async {
    if (_products.isEmpty) {
      await _loadProducts();
    }
    return _products;
  }

  Future<bool> purchaseSubscription(String productId) async {
    if (!_isAvailable) {
      throw Exception('Store not available');
    }

    final ProductDetails? productDetails = _products.firstWhere(
      (product) => product.id == productId,
      orElse: () => throw Exception('Product not found: $productId'),
    );

    if (productDetails == null) {
      throw Exception('Product details not found for: $productId');
    }

    if (kDebugMode) {
      print('SubscriptionService: Starting purchase for ${productDetails.id}');
    }

    final PurchaseParam purchaseParam = PurchaseParam(
      productDetails: productDetails,
    );

    try {
      final bool success = await _inAppPurchase.buyNonConsumable(
        purchaseParam: purchaseParam,
      );
      
      if (kDebugMode) {
        print('SubscriptionService: Purchase initiated: $success');
      }
      
      return success;
    } catch (e) {
      if (kDebugMode) {
        print('SubscriptionService: Purchase error: $e');
      }
      rethrow;
    }
  }

  /// Buys a specific base plan (monthly or annual) - use this from the
  /// paywall, since both plans share the product id "itsago_paid".
  Future<bool> purchaseProduct(ProductDetails productDetails) async {
    if (!_isAvailable) throw Exception('Store not available');
    if (kDebugMode) {
      print('SubscriptionService: Starting purchase for '
          '${productDetails.id} (${_basePlanOf(productDetails) ?? 'default'})');
    }
    return _inAppPurchase.buyNonConsumable(
      purchaseParam: PurchaseParam(productDetails: productDetails),
    );
  }

  Future<void> restorePurchases() async {
    if (!_isAvailable) {
      throw Exception('Store not available');
    }

    try {
      if (kDebugMode) {
        print('SubscriptionService: Restoring purchases...');
      }
      
      await _inAppPurchase.restorePurchases();
    } catch (e) {
      if (kDebugMode) {
        print('SubscriptionService: Restore error: $e');
      }
      rethrow;
    }
  }

  Future<void> _checkExistingPurchases() async {
    try {
      // This will trigger the purchase stream with existing purchases
      await _inAppPurchase.restorePurchases();
    } catch (e) {
      if (kDebugMode) {
        print('SubscriptionService: Error checking existing purchases: $e');
      }
    }
  }

  // Additional methods needed by main.dart
  Future<void> checkSubscriptionStatus() async {
    try {
      if (kDebugMode) {
        print('SubscriptionService: Checking subscription status...');
      }
      await _checkExistingPurchases();
      await _refreshEntitlement();
      await _syncWithFirestore();
    } catch (e) {
      if (kDebugMode) {
        print('SubscriptionService: Error checking subscription status: $e');
      }
    }
  }

  Future<bool> isPremiumActive() async {
    return await PremiumStatus.isPremium();
  }

  Future<Map<String, dynamic>> getSubscriptionInfo() async {
    try {
      // First try to get from Firestore if user is authenticated
      if (_auth.currentUser != null) {
        final firestoreData = await _getSubscriptionFromFirestore();
        if (firestoreData != null) {
          return firestoreData;
        }
      }
      
      // Fallback to local storage
      final prefs = await SharedPreferences.getInstance();
      final isPremium = prefs.getBool('is_premium') ?? false;
      final productId = prefs.getString('premium_product_id');
      final purchaseDate = prefs.getInt('purchase_date');
      
      return {
        'isPremium': isPremium,
        'productId': productId,
        'purchaseDate': purchaseDate != null ? DateTime.fromMillisecondsSinceEpoch(purchaseDate) : null,
      };
    } catch (e) {
      if (kDebugMode) {
        print('SubscriptionService: Error getting subscription info: $e');
      }
      return {
        'isPremium': false,
        'productId': null,
        'purchaseDate': null,
      };
    }
  }

  // Firestore Integration Methods

  Future<void> _syncWithFirestore() async {
    final user = _auth.currentUser;
    if (user == null) {
      if (kDebugMode) {
        print('SubscriptionService: No authenticated user, skipping Firestore sync');
      }
      return;
    }

    try {
      // Get local subscription data
      final prefs = await SharedPreferences.getInstance();
      final localIsPremium = prefs.getBool('is_premium') ?? false;
      
      // Get Firestore subscription data
      final firestoreData = await _getSubscriptionFromFirestore();
      
      if (firestoreData != null) {
        final firestoreIsPremium = firestoreData['isPremium'] ?? false;
        
        // If Firestore has more recent data, update local storage
        if (firestoreIsPremium != localIsPremium) {
          await _updateLocalFromFirestore(firestoreData);
          onPremiumStatusChanged?.call(firestoreIsPremium);
        }
      } else if (localIsPremium) {
        // If we have local premium data but nothing in Firestore, upload to Firestore
        await _uploadLocalSubscriptionToFirestore();
      }
      
    } catch (e) {
      if (kDebugMode) {
        print('SubscriptionService: Error syncing with Firestore: $e');
      }
    }
  }

  Future<Map<String, dynamic>?> _getSubscriptionFromFirestore() async {
    final user = _auth.currentUser;
    if (user == null) return null;

    try {
      final doc = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('subscriptions')
          .doc('current')
          .get();

      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        return {
          'isPremium': data['isPremium'] ?? false,
          'productId': data['productId'],
          'purchaseId': data['purchaseId'],
          'purchaseDate': data['purchaseDate'] != null 
              ? (data['purchaseDate'] as Timestamp).toDate() 
              : null,
          'platform': data['platform'],
          'isActive': data['isActive'] ?? false,
          'expiryDate': data['expiryDate'] != null 
              ? (data['expiryDate'] as Timestamp).toDate() 
              : null,
        };
      }
      
      return null;
    } catch (e) {
      if (kDebugMode) {
        print('SubscriptionService: Error getting subscription from Firestore: $e');
      }
      return null;
    }
  }

  Future<void> _saveSubscriptionToFirestore(Map<String, dynamic> subscriptionData) async {
    final user = _auth.currentUser;
    if (user == null) {
      if (kDebugMode) {
        print('SubscriptionService: No authenticated user, cannot save to Firestore');
      }
      return;
    }

    try {
      final docRef = _firestore
          .collection('users')
          .doc(user.uid)
          .collection('subscriptions')
          .doc('current');

      await docRef.set({
        'userId': user.uid,
        'isPremium': subscriptionData['isPremium'] ?? false,
        'productId': subscriptionData['productId'],
        'purchaseId': subscriptionData['purchaseId'],
        'purchaseDate': subscriptionData['purchaseDate'] != null 
            ? Timestamp.fromDate(subscriptionData['purchaseDate'] as DateTime)
            : null,
        'platform': Platform.isAndroid ? 'android' : 'ios',
        'isActive': subscriptionData['isActive'] ?? true,
        'expiryDate': subscriptionData['expiryDate'] != null 
            ? Timestamp.fromDate(subscriptionData['expiryDate'] as DateTime)
            : null,
        'lastUpdated': FieldValue.serverTimestamp(),
        'userEmail': user.email,
      }, SetOptions(merge: true));

      // Also save to purchase history
      await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('purchase_history')
          .add({
        'userId': user.uid,
        'productId': subscriptionData['productId'],
        'purchaseId': subscriptionData['purchaseId'],
        'purchaseDate': subscriptionData['purchaseDate'] != null 
            ? Timestamp.fromDate(subscriptionData['purchaseDate'] as DateTime)
            : null,
        'platform': Platform.isAndroid ? 'android' : 'ios',
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (kDebugMode) {
        print('SubscriptionService: Subscription saved to Firestore successfully');
      }
    } catch (e) {
      if (kDebugMode) {
        print('SubscriptionService: Error saving subscription to Firestore: $e');
      }
    }
  }

  Future<void> _updateLocalFromFirestore(Map<String, dynamic> firestoreData) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      await prefs.setBool('is_premium', firestoreData['isPremium'] ?? false);
      
      if (firestoreData['productId'] != null) {
        await prefs.setString('premium_product_id', firestoreData['productId']);
      }
      
      if (firestoreData['purchaseId'] != null) {
        await prefs.setString('purchase_id', firestoreData['purchaseId']);
      }
      
      if (firestoreData['purchaseDate'] != null) {
        await prefs.setInt('purchase_date', 
            (firestoreData['purchaseDate'] as DateTime).millisecondsSinceEpoch);
      }
      
      if (kDebugMode) {
        print('SubscriptionService: Local storage updated from Firestore');
      }
    } catch (e) {
      if (kDebugMode) {
        print('SubscriptionService: Error updating local from Firestore: $e');
      }
    }
  }

  Future<void> _uploadLocalSubscriptionToFirestore() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final isPremium = prefs.getBool('is_premium') ?? false;
      
      if (!isPremium) return;
      
      final subscriptionData = {
        'isPremium': isPremium,
        'productId': prefs.getString('premium_product_id'),
        'purchaseId': prefs.getString('purchase_id'),
        'purchaseDate': prefs.getInt('purchase_date') != null 
            ? DateTime.fromMillisecondsSinceEpoch(prefs.getInt('purchase_date')!)
            : null,
        'isActive': true,
      };
      
      await _saveSubscriptionToFirestore(subscriptionData);
      
      if (kDebugMode) {
        print('SubscriptionService: Local subscription uploaded to Firestore');
      }
    } catch (e) {
      if (kDebugMode) {
        print('SubscriptionService: Error uploading local subscription to Firestore: $e');
      }
    }
  }

  void _onPurchaseUpdate(List<PurchaseDetails> purchaseDetailsList) async {
    for (final PurchaseDetails purchaseDetails in purchaseDetailsList) {
      if (kDebugMode) {
        print('SubscriptionService: Processing purchase: ${purchaseDetails.productID}, Status: ${purchaseDetails.status}');
      }
      
      await _handlePurchase(purchaseDetails);
    }
  }

  Future<void> _handlePurchase(PurchaseDetails purchaseDetails) async {
    if (purchaseDetails.status == PurchaseStatus.purchased ||
        purchaseDetails.status == PurchaseStatus.restored) {
      
      // iOS restore returns old transactions too - ignore ones whose
      // period has already ended (renewals arrive as new transactions).
      final iosExpiry = _iosExpiryFor(purchaseDetails);
      if (iosExpiry != null && iosExpiry.isBefore(DateTime.now())) {
        if (purchaseDetails.pendingCompletePurchase) {
          await _inAppPurchase.completePurchase(purchaseDetails);
        }
        return;
      }

      // Verify purchase on your server here if needed
      bool isValid = await _verifyPurchase(purchaseDetails);
      
      if (isValid) {
        await _activatePremium(purchaseDetails);
        onPurchaseSuccess?.call();
        onPremiumStatusChanged?.call(true);
        _events.add(const SubscriptionEvent(SubscriptionEventType.success));
        Analytics.setPremium(true);
        if (purchaseDetails.status == PurchaseStatus.purchased) {
          Analytics.subscribed(purchaseDetails.productID);
        }
        
        if (kDebugMode) {
          print('SubscriptionService: Purchase successful for ${purchaseDetails.productID}');
        }
      } else {
        onPurchaseError?.call('Purchase verification failed');
        _events.add(SubscriptionEvent(SubscriptionEventType.error,
            Platform.isIOS
            ? "The App Store couldn't confirm this payment. Tap Restore purchase."
            : "Google Play couldn't confirm this payment. Tap Restore purchase."));
      }
      
    } else if (purchaseDetails.status == PurchaseStatus.error) {
      final error = purchaseDetails.error;
      final errorMessage = error?.message ?? 'Unknown purchase error';
      
      if (kDebugMode) {
        print('SubscriptionService: Purchase error: $errorMessage');
      }
      
      onPurchaseError?.call(errorMessage);
      _events.add(SubscriptionEvent(SubscriptionEventType.error, errorMessage));
      
    } else if (purchaseDetails.status == PurchaseStatus.pending) {
      _events.add(const SubscriptionEvent(SubscriptionEventType.pending));

    } else if (purchaseDetails.status == PurchaseStatus.canceled) {
      if (kDebugMode) {
        print('SubscriptionService: Purchase cancelled by user');
      }
      onPurchaseError?.call('Purchase cancelled');
      _events.add(const SubscriptionEvent(SubscriptionEventType.cancelled));
    }

    if (purchaseDetails.pendingCompletePurchase) {
      await _inAppPurchase.completePurchase(purchaseDetails);
      if (kDebugMode) {
        print('SubscriptionService: Purchase completed');
      }
    }
  }

  Future<bool> _verifyPurchase(PurchaseDetails purchaseDetails) async {
    // For basic implementation, we'll accept all purchases from the store
    // In production, you should verify the purchase on your backend server
    
    if (kDebugMode) {
      print('SubscriptionService: Verifying purchase ${purchaseDetails.productID}');
    }
    
    try {
      // Basic validation - check if it's one of our products
      if (!_kEntitlementProductIds.contains(purchaseDetails.productID)) {
        return false;
      }

      // For Android, you would typically send purchaseDetails.verificationData to your server
      // For iOS, you would send purchaseDetails.verificationData.serverVerificationData
      
      // For now, we'll do basic local validation
      return purchaseDetails.verificationData.localVerificationData.isNotEmpty;
      
    } catch (e) {
      if (kDebugMode) {
        print('SubscriptionService: Purchase verification error: $e');
      }
      return false;
    }
  }

  Future<void> _activatePremium(PurchaseDetails purchaseDetails) async {
    try {
      final subscriptionData = {
        'isPremium': true,
        'productId': purchaseDetails.productID,
        'purchaseId': purchaseDetails.purchaseID ?? '',
        'purchaseDate': DateTime.now(),
        'isActive': true,
        if (_iosExpiryFor(purchaseDetails) != null)
          'expiryDate': _iosExpiryFor(purchaseDetails),
      };

      // Save to local storage first
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('is_premium', true);
      await prefs.setString('premium_product_id', purchaseDetails.productID);
      await prefs.setString('purchase_id', purchaseDetails.purchaseID ?? '');
      await prefs.setInt('purchase_date', DateTime.now().millisecondsSinceEpoch);

      // Save to Firestore if user is authenticated
      await _saveSubscriptionToFirestore(subscriptionData);
      
      if (kDebugMode) {
        print('SubscriptionService: Premium activated for product ${purchaseDetails.productID}');
      }
      
    } catch (e) {
      if (kDebugMode) {
        print('SubscriptionService: Error activating premium: $e');
      }
      rethrow;
    }
  }

  /// Asks Google Play which subscriptions are active right now. Play only
  /// returns subscriptions that are still paid up (including grace period),
  /// so if none of ours come back the user cancelled and it has run out.
  /// Fails open: if Play can't be reached, nothing is changed.
  /// iOS: end of the paid period for this transaction, with a 2-day buffer
  /// for Apple's billing retries. Null on Android or if the date is unknown.
  DateTime? _iosExpiryFor(PurchaseDetails p) {
    if (!Platform.isIOS) return null;
    final ms = int.tryParse(p.transactionDate ?? '');
    if (ms == null) return null;
    final start = DateTime.fromMillisecondsSinceEpoch(ms);
    final days = p.productID == iosAnnualProductId ? 366 : 31;
    return start.add(Duration(days: days + 2));
  }

  /// iOS: switch premium off once the last known paid period has ended
  /// and no renewal has arrived. (Full server-side App Store verification
  /// is planned together with the Google Play server check.)
  Future<void> _refreshIosEntitlement() async {
    try {
      final data = await _getSubscriptionFromFirestore();
      if (data == null || data['platform'] != 'ios') return;
      final expiry = data['expiryDate'];
      final active = (data['isPremium'] ?? false) == true && (data['isActive'] ?? false) == true;
      if (active && expiry is DateTime && expiry.isBefore(DateTime.now())) {
        await _deactivatePremium();
        onPremiumStatusChanged?.call(false);
      }
    } catch (e) {
      if (kDebugMode) print('SubscriptionService: iOS entitlement check failed: $e');
    }
  }

  Future<void> _refreshEntitlement() async {
    if (Platform.isIOS) {
      await _refreshIosEntitlement();
      return;
    }
    if (!Platform.isAndroid || !_isAvailable) return;

    try {
      final addition = _inAppPurchase
          .getPlatformAddition<InAppPurchaseAndroidPlatformAddition>();
      final response = await addition.queryPastPurchases();

      if (response.error != null) {
        if (kDebugMode) {
          print('SubscriptionService: Could not query Play purchases '
              '(${response.error!.message}) - leaving premium unchanged');
        }
        return;
      }

      final hasActiveSubscription = response.pastPurchases.any((p) =>
          _kEntitlementProductIds.contains(p.productID) &&
          p.billingClientPurchase.purchaseState == PurchaseStateWrapper.purchased);

      final prefs = await SharedPreferences.getInstance();
      final wasPremium = prefs.getBool('is_premium') ?? false;
      final firestoreData = await _getSubscriptionFromFirestore();
      final firestorePremium = (firestoreData?['isPremium'] ?? false) == true &&
          (firestoreData?['isActive'] ?? false) == true;

      // Don't touch premium that was bought on an iPhone.
      final boughtOnIos = firestoreData?['platform'] == 'ios';

      if (!hasActiveSubscription && !boughtOnIos && (wasPremium || firestorePremium)) {
        await _deactivatePremium();
        onPremiumStatusChanged?.call(false);
        if (kDebugMode) {
          print('SubscriptionService: No active subscription on Play - premium switched off');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('SubscriptionService: Error refreshing entitlement: $e');
      }
    }
  }

  Future<void> _deactivatePremium() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_premium', false);

    final user = _auth.currentUser;
    if (user == null) return;
    try {
      await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('subscriptions')
          .doc('current')
          .set({
        'userId': user.uid,
        'isPremium': false,
        'isActive': false,
        'platform': Platform.isIOS ? 'ios' : 'android',
        'expiredAt': FieldValue.serverTimestamp(),
        'lastUpdated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      if (kDebugMode) {
        print('SubscriptionService: Error deactivating premium in Firestore: $e');
      }
    }
  }

  // Method to handle user authentication changes
  Future<void> onUserAuthChanged(User? user) async {
    if (user != null) {
      // User signed in - sync with Firestore
      await _syncWithFirestore();
    } else {
      // User signed out - optionally clear local data or keep it
      if (kDebugMode) {
        print('SubscriptionService: User signed out');
      }
    }
  }

  // Method to manually sync subscription status
  Future<void> syncSubscriptionStatus() async {
    await _syncWithFirestore();
  }

  void _updateStreamOnDone() {
    if (kDebugMode) {
      print('SubscriptionService: Purchase stream closed');
    }
  }

  void _updateStreamOnError(dynamic error) {
    if (kDebugMode) {
      print('SubscriptionService: Purchase stream error: $error');
    }
    onPurchaseError?.call('Purchase stream error: $error');
  }

  void dispose() {
    if (Platform.isIOS) {
      final InAppPurchaseStoreKitPlatformAddition iosPlatformAddition =
          _inAppPurchase.getPlatformAddition<InAppPurchaseStoreKitPlatformAddition>();
      iosPlatformAddition.setDelegate(null);
    }
    if (_listening) {
      _subscription.cancel();
      _listening = false;
    }
  }
}

enum SubscriptionEventType { success, cancelled, pending, error }

class SubscriptionEvent {
  final SubscriptionEventType type;
  final String? message;
  const SubscriptionEvent(this.type, [this.message]);
}

// Enhanced Premium status utility class with Firestore support
class PremiumStatus {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  static Future<bool> isPremium() async {
    try {
      // First try Firestore if user is authenticated
      final user = _auth.currentUser;
      if (user != null) {
        final doc = await _firestore
            .collection('users')
            .doc(user.uid)
            .collection('subscriptions')
            .doc('current')
            .get();

        if (doc.exists && doc.data() != null) {
          final data = doc.data()!;
          final isPremium = data['isPremium'] ?? false;
          final isActive = data['isActive'] ?? false;
          
          // Check if subscription is still active (if expiry date exists)
          if (data['expiryDate'] != null) {
            final expiryDate = (data['expiryDate'] as Timestamp).toDate();
            if (DateTime.now().isAfter(expiryDate)) {
              return false; // Subscription expired
            }
          }
          
          return isPremium && isActive;
        }
      }
      
      // Fallback to local storage
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool('is_premium') ?? false;
    } catch (e) {
      if (kDebugMode) {
        print('PremiumStatus: Error checking premium status: $e');
      }
      // Fallback to local storage on error
      try {
        final prefs = await SharedPreferences.getInstance();
        return prefs.getBool('is_premium') ?? false;
      } catch (localError) {
        return false;
      }
    }
  }

  static Future<String?> getPremiumProductId() async {
    try {
      // First try Firestore if user is authenticated
      final user = _auth.currentUser;
      if (user != null) {
        final doc = await _firestore
            .collection('users')
            .doc(user.uid)
            .collection('subscriptions')
            .doc('current')
            .get();

        if (doc.exists && doc.data() != null) {
          return doc.data()!['productId'] as String?;
        }
      }
      
      // Fallback to local storage
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString('premium_product_id');
    } catch (e) {
      if (kDebugMode) {
        print('PremiumStatus: Error getting premium product ID: $e');
      }
      return null;
    }
  }

  static Future<void> clearPremiumStatus() async {
    try {
      // Clear from Firestore if user is authenticated
      final user = _auth.currentUser;
      if (user != null) {
        await _firestore
            .collection('users')
            .doc(user.uid)
            .collection('subscriptions')
            .doc('current')
            .update({
          'isPremium': false,
          'isActive': false,
          'lastUpdated': FieldValue.serverTimestamp(),
        });
      }
      
      // Clear from local storage
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('is_premium');
      await prefs.remove('premium_product_id');
      await prefs.remove('purchase_id');
      await prefs.remove('purchase_date');
    } catch (e) {
      if (kDebugMode) {
        print('PremiumStatus: Error clearing premium status: $e');
      }
    }
  }

  // Get subscription history from Firestore
  static Future<List<Map<String, dynamic>>> getSubscriptionHistory() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return [];

      final querySnapshot = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('purchase_history')
          .orderBy('createdAt', descending: true)
          .get();

      return querySnapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'productId': data['productId'],
          'purchaseId': data['purchaseId'],
          'purchaseDate': data['purchaseDate'] != null 
              ? (data['purchaseDate'] as Timestamp).toDate()
              : null,
          'platform': data['platform'],
          'createdAt': data['createdAt'] != null 
              ? (data['createdAt'] as Timestamp).toDate()
              : null,
        };
      }).toList();
    } catch (e) {
      if (kDebugMode) {
        print('PremiumStatus: Error getting subscription history: $e');
      }
      return [];
    }
  }
}

// iOS payment queue delegate for handling transactions
class ExamplePaymentQueueDelegate implements SKPaymentQueueDelegateWrapper {
  @override
  bool shouldContinueTransaction(
      SKPaymentTransactionWrapper transaction, SKStorefrontWrapper storefront) {
    return true;
  }

  @override
  bool shouldShowPriceConsent() {
    return false;
  }
}