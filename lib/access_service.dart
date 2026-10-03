import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'subscription_service.dart';

/// Single source of truth for "does this account need to pay for this?"
///
/// Paid features (R80/month subscription): video interviews (normal and
/// job specific), CV downloads/sharing, and the AI Coach.
///
/// All paywall settings live in this file as plain constants.
/// Change a value, rebuild, and upload a new version.
class AccessService {
  AccessService._();

  // ── Paywall settings ────────────────────────────────────────────
  /// false = every feature is free (emergency off switch).
  static const bool paywallEnabled = true;

  /// true  = accounts created before [gateStartDate] stay free forever.
  /// false = everyone pays, including existing users.
  static const bool grandfatherExistingUsers = true;

  /// These accounts ALWAYS see the paywall, even if they are old accounts.
  /// Use the email you log in to the app with. Lowercase.
  static const Set<String> paywallTestEmails = {
    'earlearlandpearl2@gmail.com',
  };

  /// How many free video interviews before the paywall. 0 = paid from the first.
  static const int freeInterviews = 0;

  /// Free AI Coach messages per DAY. The count resets at midnight.
  static const int freeAiCoachMessages = 3;
  // ────────────────────────────────────────────────────────────────

  /// The day paid gating went live. Accounts created before this date are
  /// grandfathered while [grandfatherExistingUsers] is true.
  static final DateTime gateStartDate = DateTime(2026, 8, 1);

  static bool get _isGrandfathered {
    if (!grandfatherExistingUsers) return false;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false; // not signed in - no free pass

    final email = user.email?.trim().toLowerCase();
    if (email != null && paywallTestEmails.contains(email)) {
      return false; // tester - always sees the paywall
    }

    final created = user.metadata.creationTime;
    if (created == null) return true; // fail open - never wrongly block a real user
    return created.isBefore(gateStartDate);
  }

  /// True if this account never needs to see a paywall for anything.
  static Future<bool> hasFullAccess() async {
    if (!paywallEnabled) return true;
    if (_isGrandfathered) return true;
    if (await hasPromoAccess()) return true;
    return PremiumStatus.isPremium();
  }

  /// Premium granted by a promo code (TUT pilot, sponsors, events).
  /// Written ONLY by the redeemPromoCode Cloud Function - users can read
  /// their own grant but can't create or extend it themselves.
  static Future<bool> hasPromoAccess() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return false;
    try {
      final doc = await FirebaseFirestore.instance
          .collection('premium_grants').doc(uid).get();
      final until = doc.data()?['until'];
      return until is Timestamp && until.toDate().isAfter(DateTime.now());
    } catch (_) {
      return false;
    }
  }

  /// Video interviews (normal and job specific). Paid from the first one
  /// unless [freeInterviews] is above 0.
  static Future<bool> canStartInterview() async {
    if (await hasFullAccess()) return true;
    const free = freeInterviews;
    if (free <= 0) return false;
    return (await _completedInterviews(free)) < free;
  }

  static Future<int> _completedInterviews(int limit) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return 0;
    try {
      final snap = await FirebaseFirestore.instance
          .collection('users').doc(uid)
          .collection('sessions').limit(limit).get();
      return snap.docs.length;
    } catch (_) {
      return 0; // fail open - a Firestore hiccup shouldn't block a free try
    }
  }

  /// Building/previewing a CV stays free so people see the result first -
  /// downloading, sharing and exporting are paid.
  static Future<bool> canDownloadCV() => hasFullAccess();

  /// AI Coach: [freeAiCoachMessages] free messages per day, then paid.
  static Future<bool> canSendAiCoachMessage() async {
    if (await hasFullAccess()) return true;
    return (await aiCoachMessagesUsed()) < freeAiCoachMessages;
  }

  /// Free messages used so far. Stored on the phone AND on the user's
  /// Firestore doc, and the higher number wins - so reinstalling the app
  /// or clearing its data doesn't reset the free messages.
  /// Today's date as yyyy-mm-dd - the free count is kept per day.
  static String get _today {
    final n = DateTime.now();
    return '${n.year}-${n.month.toString().padLeft(2, '0')}-${n.day.toString().padLeft(2, '0')}';
  }

  /// Free messages used TODAY. Stored on the phone AND on the user's
  /// Firestore doc (per day), and the higher number wins - so reinstalling
  /// the app doesn't give extra messages the same day.
  static Future<int> aiCoachMessagesUsed() async {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? 'guest';
    final day = _today;
    final key = 'ai_coach_free_${uid}_$day';
    final prefs = await SharedPreferences.getInstance();
    int used = prefs.getInt(key) ?? 0;
    if (uid != 'guest') {
      try {
        final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
        final byDay = doc.data()?['aiCoachFreeByDay'];
        final remote = byDay is Map ? ((byDay[day] as num?)?.toInt() ?? 0) : 0;
        if (remote > used) {
          used = remote;
          await prefs.setInt(key, used);
        }
      } catch (_) {
        // Offline - the local count is still enforced.
      }
    }
    return used;
  }

  /// Call after each successful free AI Coach reply.
  static Future<void> recordAiCoachMessage() async {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? 'guest';
    final day = _today;
    final key = 'ai_coach_free_${uid}_$day';
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(key, (prefs.getInt(key) ?? 0) + 1);
    if (uid != 'guest') {
      try {
        // Only today's count is kept on the server - older days are dropped.
        final ref = FirebaseFirestore.instance.collection('users').doc(uid);
        final doc = await ref.get();
        final byDay = doc.data()?['aiCoachFreeByDay'];
        final current = byDay is Map ? ((byDay[day] as num?)?.toInt() ?? 0) : 0;
        await ref.update({'aiCoachFreeByDay': {day: current + 1}})
            .catchError((_) => ref.set(
              {'aiCoachFreeByDay': {day: current + 1}},
              SetOptions(merge: true)));
      } catch (_) {}
    }
  }

}
