import 'package:in_app_purchase/in_app_purchase.dart';
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'dart:io';

class PurchaseService {
  static final PurchaseService _instance = PurchaseService._internal();
  factory PurchaseService() => _instance;
  PurchaseService._internal();

  static const String kPremiumTemplatesId = 'itsago_premium_templates';
  static const String kJobSpecificInterviewId = 'itsago_job_specific_interview';
  static const Set<String> _productIds = {kPremiumTemplatesId, kJobSpecificInterviewId};

  static const Map<String, String> _docNames = {
    kPremiumTemplatesId: 'premium_templates',
    kJobSpecificInterviewId: 'job_specific_interview',
  };
  static const Map<String, String> _prefKeys = {
    kPremiumTemplatesId: 'premium_templates',
    kJobSpecificInterviewId: 'job_specific_interview',
  };

  final InAppPurchase _iap = InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _subscription;

  bool _isPremium = false;
  bool get isPremium => _isPremium;

  bool _isJobSpecificUnlocked = false;
  bool get isJobSpecificUnlocked => _isJobSpecificUnlocked;

  Function()? onPurchaseSuccess;
  Function(String)? onJobSpecificPurchaseSuccess;
  Function(String)? onPurchaseError;

  Future<String?> _getDeviceId() async {
    try {
      final info = DeviceInfoPlugin();
      if (Platform.isAndroid) {
        final android = await info.androidInfo;
        return android.id;
      }
      return null;
    } catch (_) { return null; }
  }

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
    await _checkFirestorePurchase(kPremiumTemplatesId);
    await _checkFirestorePurchase(kJobSpecificInterviewId);
    await _iap.restorePurchases();
  }

  Future<void> _onPurchaseUpdate(List<PurchaseDetails> purchases) async {
    for (final purchase in purchases) {
      print('Purchase update: ' + purchase.productID + ' status: ' + purchase.status.toString());
      if (!_productIds.contains(purchase.productID)) continue;
      if (purchase.pendingCompletePurchase) {
        await _iap.completePurchase(purchase);
      }
      if (purchase.status == PurchaseStatus.purchased ||
          purchase.status == PurchaseStatus.restored) {
        await _savePurchaseToFirestore(purchase);
        if (purchase.productID == kPremiumTemplatesId) {
          _isPremium = true;
          onPurchaseSuccess?.call();
        } else if (purchase.productID == kJobSpecificInterviewId) {
          _isJobSpecificUnlocked = true;
          onJobSpecificPurchaseSuccess?.call(purchase.productID);
        }
      } else if (purchase.status == PurchaseStatus.error) {
        final err = purchase.error;
        final msg = 'Purchase failed: code=' + (err?.code ?? 'unknown') +
                    ' message=' + (err?.message ?? 'no message');
        print(msg);
        onPurchaseError?.call(err?.message ?? 'Purchase failed');
      } else if (purchase.status == PurchaseStatus.canceled) {
        print('Purchase canceled by user');
      }
    }
  }

  Future<void> restorePurchases() async {
    try {
      await _checkFirestorePurchase(kPremiumTemplatesId);
      await _checkFirestorePurchase(kJobSpecificInterviewId);
      if (_isPremium && _isJobSpecificUnlocked) return;
      await _iap.restorePurchases();
    } catch (e) {
      print('Restore failed: ' + e.toString());
    }
  }

  Future<void> _savePurchaseToFirestore(PurchaseDetails purchase) async {
    try {
      final productId = purchase.productID;
      final docName   = _docNames[productId]!;
      final prefKey   = _prefKeys[productId]!;

      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(prefKey, true);

      final user = FirebaseAuth.instance.currentUser;
      final token = purchase.verificationData.serverVerificationData;
      final logId = token.isNotEmpty
          ? token
          : purchase.purchaseID ?? DateTime.now().millisecondsSinceEpoch.toString();
      final deviceId = await _getDeviceId();

      await FirebaseFirestore.instance
        .collection('purchase_log')
        .doc(logId)
        .set({
          'purchaseToken': logId,
          'productId': productId,
          'platform': 'android',
          'orderId': purchase.purchaseID ?? '',
          'userId': user?.uid,
          'userEmail': user?.email,
          'deviceId': deviceId,
          'timestamp': FieldValue.serverTimestamp(),
          'reconciled': user != null,
          'active': true,
        }, SetOptions(merge: true));

      await _flagSuspiciousActivity(deviceId, user?.uid);

      if (user == null) {
        print('No user - saved to purchase_log only');
        return;
      }

      await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('subscriptions')
        .doc(docName)
        .set({
          'userId': user.uid,
          'isPremium': true,
          'platform': 'android',
          'productId': productId,
          'purchaseToken': logId,
          'deviceId': deviceId,
          'purchasedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

      await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('purchase_history')
        .add({
          'userId': user.uid,
          'productId': productId,
          'platform': 'android',
          'purchaseToken': logId,
          'deviceId': deviceId,
          'purchasedAt': FieldValue.serverTimestamp(),
        });

      print('Purchase saved for user: ' + user.uid + ' product: ' + productId);
    } catch (e) {
      print('Firestore purchase save failed: ' + e.toString());
    }
  }

  Future<void> _flagSuspiciousActivity(String? deviceId, String? userId) async {
    try {
      if (deviceId == null) return;

      final devicePurchases = await FirebaseFirestore.instance
        .collection('purchase_log')
        .where('deviceId', isEqualTo: deviceId)
        .where('active', isEqualTo: true)
        .get();

      final uniqueUsers = devicePurchases.docs
        .map((d) => d.data()['userId'])
        .where((uid) => uid != null && uid != userId)
        .toSet();

      if (uniqueUsers.length >= 2) {
        await FirebaseFirestore.instance
          .collection('fraud_flags')
          .add({
            'deviceId': deviceId,
            'currentUserId': userId,
            'previousUserIds': uniqueUsers.toList(),
            'totalAccounts': uniqueUsers.length + 1,
            'flaggedAt': FieldValue.serverTimestamp(),
            'reason': 'multiple_accounts_same_device',
            'reviewed': false,
            'action': 'none',
          });
        print('Suspicious pattern flagged for device: ' + deviceId);
      }
    } catch (e) {
      print('Flag check failed: ' + e.toString());
    }
  }

  Future<void> _checkFirestorePurchase(String productId) async {
    try {
      final docName = _docNames[productId]!;
      final prefKey = _prefKeys[productId]!;

      final prefs = await SharedPreferences.getInstance();
      final cached = prefs.getBool(prefKey) ?? false;
      if (cached) {
        _setUnlocked(productId, true);
        print('$productId restored from local cache');
        return;
      }

      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('subscriptions')
        .doc(docName)
        .get();

      if (doc.exists && doc.data()?['isPremium'] == true) {
        _setUnlocked(productId, true);
        await prefs.setBool(prefKey, true);
        print('$productId restored from Firestore');
      }
    } catch (e) {
      print('Firestore purchase check failed: ' + e.toString());
    }
  }

  void _setUnlocked(String productId, bool value) {
    if (productId == kPremiumTemplatesId) {
      _isPremium = value;
    } else if (productId == kJobSpecificInterviewId) {
      _isJobSpecificUnlocked = value;
    }
  }

  Future<void> reconcileLocalPurchaseOnSignIn() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    for (final productId in _productIds) {
      try {
        final docName = _docNames[productId]!;
        final prefKey = _prefKeys[productId]!;

        final prefs = await SharedPreferences.getInstance();
        final isUnlockedLocally = prefs.getBool(prefKey) ?? false;
        if (!isUnlockedLocally) continue;

        final subRef = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('subscriptions')
          .doc(docName);

        final existing = await subRef.get();
        if (existing.exists && existing.data()?['isPremium'] == true) continue;

        final deviceId = await _getDeviceId();
        await subRef.set({
          'userId': user.uid,
          'isPremium': true,
          'platform': 'android',
          'productId': productId,
          'deviceId': deviceId,
          'reconciledAt': FieldValue.serverTimestamp(),
          'note': 'reconciled from local cache',
        }, SetOptions(merge: true));

        print('Reconciled purchase to user: ' + user.uid + ' product: ' + productId);
      } catch (e) {
        print('Reconcile failed for ' + productId + ': ' + e.toString());
      }
    }
  }

  Future<bool> _buy(String productId) async {
    try {
      print('Starting purchase flow for $productId...');
      final response = await _iap.queryProductDetails({productId});

      if (response.error != null) {
        print('Product query error: ' + response.error.toString());
        onPurchaseError?.call('Could not load purchase details. Please check your connection.');
        return false;
      }

      if (response.productDetails.isEmpty) {
        print('No products found for: $productId');
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

  Future<bool> buyPremiumTemplates() => _buy(kPremiumTemplatesId);

  Future<bool> buyJobSpecificInterview() => _buy(kJobSpecificInterviewId);

  void dispose() {
    _subscription?.cancel();
  }
}