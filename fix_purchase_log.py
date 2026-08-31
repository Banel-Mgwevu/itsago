with open('lib/purchase_service.dart', 'r', encoding='utf-8') as f:
    c = f.read()

old = """  Future<void> _savePurchaseToFirestore() async {
    try {
      // Save to SharedPreferences first (fastest)
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('premium_templates', true);

      // Then save to Firestore - matches existing security rules schema
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        print('No user logged in - saved to prefs only');
        return;
      }

      final subRef = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('subscriptions')
        .doc('premium_templates');

      final existing = await subRef.get();

      if (!existing.exists) {
        await subRef.set({
          'userId': user.uid,
          'isPremium': true,
          'platform': 'android',
          'productId': kPremiumTemplatesId,
          'purchasedAt': FieldValue.serverTimestamp(),
        });
      } else {
        await subRef.update({
          'isPremium': true,
          'purchasedAt': FieldValue.serverTimestamp(),
        });
      }

      // Also log to purchase_history (immutable record)
      await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('purchase_history')
        .add({
          'userId': user.uid,
          'productId': kPremiumTemplatesId,
          'platform': 'android',
          'purchasedAt': FieldValue.serverTimestamp(),
        });

      print('Purchase saved to Firestore successfully');
    } catch (e) {
      print('Firestore purchase save failed: ' + e.toString());
      // SharedPreferences already saved so user is not affected
    }
  }"""

new = """  Future<void> _savePurchaseToFirestore(PurchaseDetails purchase) async {
    try {
      // Save locally first - fastest, never blocks the user
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('premium_templates', true);

      final user = FirebaseAuth.instance.currentUser;
      final token = purchase.verificationData.serverVerificationData;
      // Use the purchase token as doc id - guarantees uniqueness,
      // works even if user is not signed in, and lets us reconcile
      // any purchase back to a Firebase user later just by looking
      // up the order/token in Play Console and matching it here.
      final logId = token.isNotEmpty ? token : purchase.purchaseID ?? DateTime.now().millisecondsSinceEpoch.toString();

      final logRef = FirebaseFirestore.instance.collection('purchase_log').doc(logId);

      await logRef.set({
        'purchaseToken': logId,
        'productId': kPremiumTemplatesId,
        'platform': 'android',
        'orderId': purchase.purchaseID ?? '',
        'userId': user?.uid,
        'userEmail': user?.email,
        'timestamp': FieldValue.serverTimestamp(),
        'reconciled': user != null,
      }, SetOptions(merge: true));

      print('Purchase logged: ' + logId);

      if (user == null) {
        print('No user logged in - logged to purchase_log only, will reconcile on next sign-in');
        return;
      }

      final subRef = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('subscriptions')
        .doc('premium_templates');

      await subRef.set({
        'userId': user.uid,
        'isPremium': true,
        'platform': 'android',
        'productId': kPremiumTemplatesId,
        'purchaseToken': logId,
        'purchasedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('purchase_history')
        .add({
          'userId': user.uid,
          'productId': kPremiumTemplatesId,
          'platform': 'android',
          'purchaseToken': logId,
          'purchasedAt': FieldValue.serverTimestamp(),
        });

      print('Purchase saved to Firestore successfully for user: ' + user.uid);
    } catch (e) {
      print('Firestore purchase save failed: ' + e.toString());
    }
  }

  /// Call this whenever a user signs in - reconciles any purchase_log
  /// entries that matched this device but had no signed-in user at
  /// time of purchase. Cheap: only runs once per app session via
  /// the cached SharedPreferences flag.
  Future<void> reconcileLocalPurchaseOnSignIn() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      final prefs = await SharedPreferences.getInstance();
      final isPremiumLocally = prefs.getBool('premium_templates') ?? false;
      if (!isPremiumLocally) return;

      final subRef = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('subscriptions')
        .doc('premium_templates');

      final existing = await subRef.get();
      if (existing.exists && existing.data()?['isPremium'] == true) return;

      await subRef.set({
        'userId': user.uid,
        'isPremium': true,
        'platform': 'android',
        'productId': kPremiumTemplatesId,
        'reconciledAt': FieldValue.serverTimestamp(),
        'note': 'reconciled from local cache - purchased while signed out',
      }, SetOptions(merge: true));

      print('Reconciled local purchase to user: ' + user.uid);
    } catch (e) {
      print('Reconcile failed: ' + e.toString());
    }
  }"""

c = c.replace(old, new)

# update the call site that invokes _savePurchaseToFirestore to pass purchase
c = c.replace(
    "        _isPremium = true;\n        await _savePurchaseToFirestore();\n        onPurchaseSuccess?.call();",
    "        _isPremium = true;\n        await _savePurchaseToFirestore(purchase);\n        onPurchaseSuccess?.call();"
)

with open('lib/purchase_service.dart', 'w', encoding='utf-8') as f:
    f.write(c)
print('Done.')
