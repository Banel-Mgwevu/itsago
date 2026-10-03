import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// All app analytics in one place. Events show up in the Firebase console
/// under Analytics > Events (allow up to 24 hours), and in DebugView
/// straight away while testing.
///
/// No names, emails or CV/interview content are ever sent - only what
/// happened and on which feature. Parameter values are strings or numbers
/// (Firebase doesn't accept booleans).
class Analytics {
  Analytics._();

  static final FirebaseAnalytics _a = FirebaseAnalytics.instance;

  static Future<void> _log(String name, [Map<String, Object>? params]) async {
    try {
      await _a.logEvent(name: name, parameters: params);
    } catch (e) {
      if (kDebugMode) debugPrint('Analytics "$name" failed: $e');
    }
  }

  /// Activity counters on users/{uid}.activity - read by the nightly
  /// sponsor report (promo_reports). Counts only, never content.
  static Future<void> _bump(String field) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    try {
      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'activity': {field: FieldValue.increment(1)},
      }, SetOptions(merge: true));
    } catch (_) {}
  }

  // ── Paywall & money ──
  static Future<void> paywallShown(String feature) =>
      _log('paywall_shown', {'feature': feature});

  static Future<void> paywallClosed(String feature, bool unlocked) =>
      _log('paywall_closed', {'feature': feature, 'unlocked': unlocked ? 1 : 0});

  static Future<void> subscribeTapped(String plan, String feature) =>
      _log('subscribe_tapped', {'plan': plan, 'feature': feature});

  static Future<void> subscribed(String productId) =>
      _log('subscribed', {'product_id': productId});

  static Future<void> promoRedeemed(String code) =>
      _log('promo_redeemed', {'code': code});

  static Future<void> setPremium(bool premium) async {
    try {
      await _a.setUserProperty(name: 'is_premium', value: premium ? 'yes' : 'no');
    } catch (_) {}
  }

  // ── CVs ──
  static Future<void> cvBuildCompleted() {
    _bump('cvBuilds');
    return _log('cv_build_completed');
  }

  static Future<void> cvDesignChosen(String design, bool freePath) =>
      _log('cv_design_chosen', {'design': design, 'path': freePath ? 'build' : 'revamp'});

  static Future<void> cvExported(String format, bool freePath) {
    _bump('cvExports');
    return _log('cv_exported', {'format': format, 'path': freePath ? 'build' : 'revamp'});
  }

  // ── Interviews ──
  static Future<void> interviewStarted(bool withRole) =>
      _log('interview_started', {'with_role': withRole ? 1 : 0});

  static Future<void> interviewCompleted({required int questions, required int scored, required int avgScore}) =>
      _log('interview_completed', {'questions': questions, 'scored': scored, 'avg_score': avgScore});

  // ── AI Coach ──
  static Future<void> coachMessage(bool premium) {
    _bump('coachMessages');
    return _log('coach_message', {'premium': premium ? 1 : 0});
  }
}
