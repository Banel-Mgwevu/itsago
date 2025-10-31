import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
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
  
  // Updated Product IDs to match your Play Console configuration
  static const String monthlyProductId = 'itsago_prod';
  static const String annualProductId = 'itsago_annual_prod';
  
  static const Set<String> _kProductIds = <String>{
    monthlyProductId,
    annualProductId,
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

    // Listen to purchase updates
    _subscription = _inAppPurchase.purchaseStream.listen(
      _onPurchaseUpdate,
      onDone: _updateStreamOnDone,
      onError: _updateStreamOnError,
    );

    await _loadProducts();
    await _checkExistingPurchases();
    
    // Sync with Firestore if user is authenticated
    await _syncWithFirestore();
    
    if (kDebugMode) {
      print('SubscriptionService: Initialization complete');
    }
  }

  Future<void> _loadProducts() async {
    try {
      final ProductDetailsResponse response = await _inAppPurchase.queryProductDetails(_kProductIds);
      
      if (response.notFoundIDs.isNotEmpty) {
        if (kDebugMode) {
          print('SubscriptionService: Products not found: ${response.notFoundIDs}');
        }
      }
      
      _products = response.productDetails;
      
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
      
      // Verify purchase on your server here if needed
      bool isValid = await _verifyPurchase(purchaseDetails);
      
      if (isValid) {
        await _activatePremium(purchaseDetails);
        onPurchaseSuccess?.call();
        onPremiumStatusChanged?.call(true);
        
        if (kDebugMode) {
          print('SubscriptionService: Purchase successful for ${purchaseDetails.productID}');
        }
      } else {
        onPurchaseError?.call('Purchase verification failed');
      }
      
    } else if (purchaseDetails.status == PurchaseStatus.error) {
      final error = purchaseDetails.error;
      final errorMessage = error?.message ?? 'Unknown purchase error';
      
      if (kDebugMode) {
        print('SubscriptionService: Purchase error: $errorMessage');
      }
      
      onPurchaseError?.call(errorMessage);
      
    } else if (purchaseDetails.status == PurchaseStatus.canceled) {
      if (kDebugMode) {
        print('SubscriptionService: Purchase cancelled by user');
      }
      onPurchaseError?.call('Purchase cancelled');
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
      if (!_kProductIds.contains(purchaseDetails.productID)) {
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
    _subscription.cancel();
  }
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