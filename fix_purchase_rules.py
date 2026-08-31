with open('lib/purchase_service.dart', 'r', encoding='utf-8') as f:
    c = f.read()

old_save = '''  Future<void> _savePurchaseToFirestore() async {
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
  }'''

new_save = '''  Future<void> _savePurchaseToFirestore() async {
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
  }'''

c = c.replace(old_save, new_save)

old_check = '''  Future<void> _checkFirestorePurchase() async {
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
  }'''

new_check = '''  Future<void> _checkFirestorePurchase() async {
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
        .collection('users')
        .doc(user.uid)
        .collection('subscriptions')
        .doc('premium_templates')
        .get();

      if (doc.exists && doc.data()?['isPremium'] == true) {
        _isPremium = true;
        await prefs.setBool('premium_templates', true);
        print('Premium restored from Firestore');
      }
    } catch (e) {
      print('Firestore purchase check failed: ' + e.toString());
    }
  }'''

c = c.replace(old_check, new_check)

with open('lib/purchase_service.dart', 'w', encoding='utf-8') as f:
    f.write(c)
print('Fixed to match Firestore rules schema.')
