import 'package:in_app_purchase/in_app_purchase.dart';
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PurchaseService {
  static final PurchaseService _instance = PurchaseService._internal();
  factory PurchaseService() => _instance;
  PurchaseService._internal();

  static const String kPremiumTemplatesId = 'itsago_premium_templates';
  static const Set<String> _productIds = {kPremiumTemplatesId};

  final InAppPurchase _iap = InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _subscription;

  bool _isPremium = false;
  bool get isPremium => _isPremium;

  Function()? onPurchaseSuccess;
  Function(String)? onPurchaseError;

  Future<void> init() async {
    final available = await _iap.isAvailable();
    if (!available) {
      print('IAP not available');
      return;
    }
    _subscription = _iap.purchaseStream.listen(
      _onPurchaseUpdate,
      onError: (e) {
        print('Purchase stream error: ' + e.toString());
        onPurchaseError?.call(e.toString());
      },
    );
    await _checkFirestorePurchase();
    await _iap.restorePurchases();
  }

  Future<void> _onPurchaseUpdate(List<PurchaseDetails> purchases) async {
    for (final purchase in purchases) {
      print('Purchase update: ' + purchase.productID + ' status: ' + purchase.status.toString());

      if (purchase.productID != kPremiumTemplatesId) continue;

      // Complete purchase FIRST before anything else
      if (purchase.pendingCompletePurchase) {
        await _iap.completePurchase(purchase);
      }

      if (purchase.status == PurchaseStatus.purchased ||
          purchase.status == PurchaseStatus.restored) {
        _isPremium = true;
        await _savePurchaseToFirestore();
        onPurchaseSuccess?.call();
      } else if (purchase.status == PurchaseStatus.error) {
        final msg = purchase.error?.message ?? 'Purchase failed';
        print('Purchase error: ' + msg);
        onPurchaseError?.call(msg);
      } else if (purchase.status == PurchaseStatus.canceled) {
        print('Purchase canceled by user');
      }
    }
  }

  Future<void> restorePurchases() async {
    try {
      await _checkFirestorePurchase();
      if (_isPremium) return;
      await _iap.restorePurchases();
    } catch (e) {
      print('Restore failed: ' + e.toString());
    }
  }

  Future<void> _savePurchaseToFirestore() async {
    try {
      // Save to SharedPreferences first (fastest)
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('premium_templates', true);

      // Then save to Firestore
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        print('No user logged in - saved to prefs only');
        return;
      }
      await FirebaseFirestore.instance
        .collection('purchases')
        .doc(user.uid)
        .set({
          'premium_templates': true,
          'purchased_at': FieldValue.serverTimestamp(),
          'product_id': kPremiumTemplatesId,
          'uid': user.uid,
          'email': user.email ?? '',
        }, SetOptions(merge: true));
      print('Purchase saved to Firestore successfully');
    } catch (e) {
      print('Firestore purchase save failed: ' + e.toString());
      // SharedPreferences already saved so user is not affected
    }
  }

  Future<void> _checkFirestorePurchase() async {
    try {
      // Check local cache first
      final prefs = await SharedPreferences.getInstance();
      final cached = prefs.getBool('premium_templates') ?? false;
      if (cached) {
        _isPremium = true;
        print('Premium restored from local cache');
        return;
      }

      // Check Firestore
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final doc = await FirebaseFirestore.instance
        .collection('purchases')
        .doc(user.uid)
        .get();

      if (doc.exists && doc.data()?['premium_templates'] == true) {
        _isPremium = true;
        await prefs.setBool('premium_templates', true);
        print('Premium restored from Firestore');
      }
    } catch (e) {
      print('Firestore purchase check failed: ' + e.toString());
    }
  }

  Future<bool> buyPremiumTemplates() async {
    try {
      print('Starting purchase flow...');
      final response = await _iap.queryProductDetails(_productIds);

      if (response.error != null) {
        print('Product query error: ' + response.error.toString());
        onPurchaseError?.call('Could not load purchase details. Please check your connection.');
        return false;
      }

      if (response.productDetails.isEmpty) {
        print('No products found for: ' + _productIds.toString());
        onPurchaseError?.call('Purchase not available yet. Please try again later.');
        return false;
      }

      print('Product found: ' + response.productDetails.first.id);
      final product = response.productDetails.first;
      final param = PurchaseParam(productDetails: product);
      return await _iap.buyNonConsumable(purchaseParam: param);
    } catch (e) {
      print('Buy failed: ' + e.toString());
      onPurchaseError?.call('Purchase failed: ' + e.toString());
      return false;
    }
  }

  void dispose() {
    _subscription?.cancel();
  }
}
