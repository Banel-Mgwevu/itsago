import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'purchase_service.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'app_theme.dart';
import 'main.dart';
import 'terms_screen.dart';
import 'privacy_policy_detail_screen.dart';
import 'main_menu_screen.dart';
import 'onboarding_screen.dart';

class AuthScreen extends StatefulWidget {
  final List<CameraDescription> cameras;
  final String selectedPurpose;
  const AuthScreen({
    super.key, required this.cameras, required this.selectedPurpose});
  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen>
    with SingleTickerProviderStateMixin {

  late final AnimationController _ctrl = AnimationController(
    vsync: this, duration: const Duration(milliseconds: 700))..forward();
  late final Animation<double> _fade = CurvedAnimation(
    parent: _ctrl, curve: Curves.easeOut);
  late final Animation<Offset> _slide = Tween<Offset>(
    begin: const Offset(0, 0.04), end: Offset.zero).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));

  String? _loadingProvider; // 'google' | 'microsoft' | null
  bool get _loading => _loadingProvider != null;
  bool _consentChecked = false;
  final _googleSignIn = GoogleSignIn(scopes: ['email', 'profile']);

  @override
  void initState() {
    super.initState();
    // Warm up the GoogleSignIn plugin's native connection ahead of time.
    // Without this, the first tap of "Continue with Google" can silently
    // fail or do nothing while the underlying Android SDK finishes
    // binding to Google Play Services - the second tap then works
    // because that binding is already warm. signInSilently() just
    // checks for an existing session; it doesn't show any UI or count
    // as a real sign-in attempt, so it's safe to fire and forget here.
    _googleSignIn.signInSilently().catchError((e) {
      if (kDebugMode) print('GoogleSignIn warm-up (expected to often fail): $e');
      return null;
    });
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  Future<void> _navigate() async {
    if (!mounted) return;
    if (!mounted) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('has_seen_onboarding', true);
    if (!mounted) return;
    Navigator.of(context).pushReplacement(PageRouteBuilder(
      pageBuilder: (_, __, ___) => MainMenuScreen(cameras: widget.cameras),
      transitionsBuilder: (_, a, __, child) =>
          FadeTransition(opacity: a, child: child),
      transitionDuration: const Duration(milliseconds: 500)));
  }

  /// Shared by every sign-in provider: records consent, syncs whatever
  /// profile data ProfileSetupScreen held locally into this user's
  /// Firestore doc, then navigates on. Keeping this in one place means
  /// adding another provider later never risks re-implementing (and
  /// drifting from) this logic.
  Future<void> _completeSignIn(User? user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('privacy_consent_accepted', true);
    await prefs.setString(
        'privacy_consent_accepted_at', DateTime.now().toIso8601String());

    final uid = user?.uid;
    final pendingJson = prefs.getString('pending_profile_data');
    if (uid != null && pendingJson != null) {
      try {
        final profile = jsonDecode(pendingJson) as Map<String, dynamic>;
        if (profile.isNotEmpty) {
          profile['profileCompletedAt'] = FieldValue.serverTimestamp();
          await FirebaseFirestore.instance.collection('users').doc(uid)
              .set(profile, SetOptions(merge: true));
        }
      } catch (e) {
        if (kDebugMode) print('Profile sync failed (non-fatal): $e');
      }
      await prefs.remove('pending_profile_data');
    }

    await _navigate();
  }

  Future<void> _signInGoogle() async {
    if (_loading || !_consentChecked) return;
    setState(() => _loadingProvider = 'google');
    try {
      final acct = await _googleSignIn.signIn();
      if (acct == null) {
        print('Google sign-in: signIn() returned null (user cancelled, or a transient plugin hiccup)');
        setState(() => _loadingProvider = null);
        return;
      }
      final auth = await acct.authentication;
      final cred = await FirebaseAuth.instance.signInWithCredential(
        GoogleAuthProvider.credential(
          accessToken: auth.accessToken, idToken: auth.idToken));
      await _completeSignIn(cred.user);
    } catch (e) {
      print('Google sign-in error: $e');
      if (mounted) {
        setState(() => _loadingProvider = null);
        _err('SIGN-IN FAILED',
          'Could not sign in with Google. Please try again.');
      }
    }
  }

  Future<void> _signInMicrosoft() async {
    if (_loading || !_consentChecked) return;
    setState(() => _loadingProvider = 'microsoft');
    try {
      final provider = OAuthProvider('microsoft.com')
        ..setCustomParameters({'prompt': 'select_account'});
      final cred = await FirebaseAuth.instance.signInWithProvider(provider);
      await _completeSignIn(cred.user);
    } on FirebaseAuthException catch (e) {
      // User backed out of the Microsoft sign-in page - not an error.
      if (e.code == 'canceled' || e.code == 'web-context-canceled') {
        if (mounted) setState(() => _loadingProvider = null);
        return;
      }
      print('Microsoft sign-in FirebaseAuthException: code=${e.code} message=${e.message}');
      if (mounted) {
        setState(() => _loadingProvider = null);
        _err('SIGN-IN FAILED',
          'Could not sign in with Microsoft. Please try again.');
      }
    } catch (e) {
      print('Microsoft sign-in error: $e');
      if (mounted) {
        setState(() => _loadingProvider = null);
        _err('SIGN-IN FAILED',
          'Could not sign in with Microsoft. Please try again.');
      }
    }
  }

  void _openPrivacyPolicy() => Navigator.of(context).push(PageRouteBuilder(
    pageBuilder: (_, __, ___) => const PrivacyPolicyDetailScreen(),
    transitionsBuilder: (_, a, __, child) =>
        FadeTransition(opacity: a, child: child),
    transitionDuration: const Duration(milliseconds: 400)));

  void _openTerms() => Navigator.of(context).push(PageRouteBuilder(
    pageBuilder: (_, __, ___) => TermsScreen(cameras: widget.cameras),
    transitionsBuilder: (_, a, __, child) =>
        FadeTransition(opacity: a, child: child),
    transitionDuration: const Duration(milliseconds: 400)));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.cream,
      body: SafeArea(child: Stack(children: [

        // Geometric accents
        Positioned(top: -55, right: -55,
          child: Container(width: 140, height: 140,
            decoration: BoxDecoration(shape: BoxShape.circle,
              color: AppColors.amber.withOpacity(0.12),
              border: Border.all(
                color: AppColors.amber.withOpacity(0.25), width: 1.5)))),
        Positioned(bottom: -35, left: -35,
          child: Container(width: 100, height: 70,
            color: AppColors.blue.withOpacity(0.08))),
        Positioned(top: 185, left: 20,
          child: Container(width: 8, height: 8, color: AppColors.red)),
        Positioned(bottom: 185, right: 28,
          child: Container(width: 7, height: 7,
            decoration: const BoxDecoration(
              color: AppColors.blue, shape: BoxShape.circle))),

        // Loading overlay
        if (_loading)
          Container(
            color: AppColors.inkAt(0.55),
            child: Center(child: Container(
              width: 168, height: 120,
              decoration: const BoxDecoration(
                color: AppColors.white,
                border: AppBorders.ink3,
                boxShadow: [AppShadows.hard5]),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(width: 28, height: 28,
                    child: CircularProgressIndicator(
                      color: AppColors.red, strokeWidth: 3)),
                  const SizedBox(height: 12),
                  Text('SIGNING IN...',
                    style: AppText.label.copyWith(fontSize: 10)),
                  const SizedBox(height: 3),
                  Text(_loadingProvider == 'google' ? 'Google' : 'Microsoft',
                    style: AppText.caption),
                ])))),

        // Main content
        FadeTransition(
          opacity: _fade,
          child: SlideTransition(
            position: _slide,
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 32, 20, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [

                Center(child: Container(
                  width: 86, height: 86,
                  decoration: const BoxDecoration(
                    color: AppColors.white,
                    border: AppBorders.ink3,
                    boxShadow: [AppShadows.hard5]),
                  child: Stack(children: [
                    Positioned(bottom: 0, left: 0,
                      child: Container(width: 22, height: 22,
                        color: AppColors.amber)),
                    Positioned(top: 10, right: 10,
                      child: Container(width: 11, height: 11,
                        decoration: const BoxDecoration(
                          color: AppColors.red,
                          shape: BoxShape.circle))),
                    Center(child: Text('I',
                      style: AppText.display.copyWith(fontSize: 34))),
                  ]))),

                const SizedBox(height: 16),

                Center(child: Column(children: [
                  Text('ITSAGO',
                    style: AppText.display.copyWith(
                      letterSpacing: 6, fontSize: 26)),
                  const SizedBox(height: 6),
                  Row(mainAxisSize: MainAxisSize.min, children: [
                    Container(width: 20, height: 3, color: AppColors.red),
                    Container(width: 20, height: 3, color: AppColors.amber),
                    Container(width: 20, height: 3, color: AppColors.blue),
                  ]),
                  const SizedBox(height: 6),
                  Text('AI INTERVIEW PREP',
                    style: AppText.label.copyWith(color: AppColors.dim)),
                ])),

                const SizedBox(height: 36),

                AppWidgets.sectionLabel('SIGN IN'),
                const SizedBox(height: 10),
                Text('Ready to ace\nyour interview?',
                  style: AppText.headline),
                const SizedBox(height: 6),
                Text(
                  'Sign in to save your progress and access\n'
                  'personalised coaching features.',
                  style: AppText.caption.copyWith(height: 1.5)),

                const SizedBox(height: 24),

                // Consent checkbox - must be ticked before sign-in works.
                // Unchecked by default; tapping "Privacy Policy" opens the
                // full detail without needing to leave this screen.
                GestureDetector(
                  onTap: () => setState(() => _consentChecked = !_consentChecked),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Container(width: 22, height: 22,
                      margin: const EdgeInsets.only(top: 2),
                      decoration: BoxDecoration(
                        color: _consentChecked ? AppColors.ink : Colors.white,
                        border: Border.all(color: AppColors.ink, width: 2)),
                      child: _consentChecked
                        ? const Icon(Icons.check_rounded, color: Colors.white, size: 15)
                        : null),
                    const SizedBox(width: 10),
                    Expanded(child: RichText(text: TextSpan(
                      style: AppText.caption.copyWith(height: 1.45, color: AppColors.ink),
                      children: [
                        const TextSpan(text: 'I agree to ITSAGO accessing my camera, '
                          'microphone and profile answers for practice interviews and '
                          'personalisation, as described in the '),
                        TextSpan(text: 'Privacy Policy',
                          style: const TextStyle(fontWeight: FontWeight.w800,
                            color: AppColors.blue, decoration: TextDecoration.underline),
                          recognizer: (TapGestureRecognizer()..onTap = _openPrivacyPolicy)),
                        const TextSpan(text: '.'),
                      ]))),
                  ])),

                const SizedBox(height: 20),

                // Google sign-in button
                GestureDetector(
                  onTap: (_loading || !_consentChecked) ? null : _signInGoogle,
                  child: Container(
                    width: double.infinity, height: 56,
                    decoration: BoxDecoration(
                      color: (_loading || !_consentChecked) ? AppColors.dim : AppColors.white,
                      border: AppBorders.ink2,
                      boxShadow: (_loading || !_consentChecked)
                        ? null : const [AppShadows.hard4]),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                      Container(width: 32, height: 32,
                        decoration: BoxDecoration(
                          color: (_loading || !_consentChecked)
                            ? AppColors.dim
                            : const Color(0xFFEA4335),
                          border: Border.all(
                            color: AppColors.ink, width: 1.5)),
                        child: const Center(child: Text('G',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            color: Colors.white)))),
                      const SizedBox(width: 12),
                      Text('CONTINUE WITH GOOGLE',
                        style: AppText.button.copyWith(
                          color: (_loading || !_consentChecked)
                            ? Colors.white : AppColors.ink,
                          letterSpacing: 1.5)),
                    ]))),

                const SizedBox(height: 12),

                // Microsoft / Outlook sign-in button
                GestureDetector(
                  onTap: (_loading || !_consentChecked) ? null : _signInMicrosoft,
                  child: Container(
                    width: double.infinity, height: 56,
                    decoration: BoxDecoration(
                      color: (_loading || !_consentChecked) ? AppColors.dim : AppColors.white,
                      border: AppBorders.ink2,
                      boxShadow: (_loading || !_consentChecked)
                        ? null : const [AppShadows.hard4]),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                      Container(width: 32, height: 32,
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: (_loading || !_consentChecked)
                            ? AppColors.dim : Colors.white,
                          border: Border.all(
                            color: AppColors.ink, width: 1.5)),
                        child: (_loading || !_consentChecked)
                          ? null
                          : GridView.count(
                              crossAxisCount: 2,
                              physics: const NeverScrollableScrollPhysics(),
                              mainAxisSpacing: 1.5, crossAxisSpacing: 1.5,
                              children: const [
                                ColoredBox(color: Color(0xFFF25022)),
                                ColoredBox(color: Color(0xFF7FBA00)),
                                ColoredBox(color: Color(0xFF00A4EF)),
                                ColoredBox(color: Color(0xFFFFB900)),
                              ])),
                      const SizedBox(width: 12),
                      Text('CONTINUE WITH OUTLOOK',
                        style: AppText.button.copyWith(
                          color: (_loading || !_consentChecked)
                            ? Colors.white : AppColors.ink,
                          letterSpacing: 1.5)),
                    ]))),

                const SizedBox(height: 28),

                Row(children: [
                  Expanded(child: Container(
                    height: 1, color: AppColors.mist)),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text('OR', style: AppText.label.copyWith(
                      color: AppColors.dim, fontSize: 8))),
                  Expanded(child: Container(
                    height: 1, color: AppColors.mist)),
                ]),

                const SizedBox(height: 16),

                Center(child: Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 10, runSpacing: 8,
                  children: [
                    GestureDetector(
                      onTap: _openTerms,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: AppColors.mist, width: 1.5)),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          const Icon(Icons.description_rounded,
                            size: 13, color: AppColors.dim),
                          const SizedBox(width: 8),
                          Text('TERMS & CONDITIONS',
                            style: AppText.label.copyWith(
                              color: AppColors.dim,
                              decoration: TextDecoration.underline)),
                        ]))),
                    GestureDetector(
                      onTap: _openPrivacyPolicy,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: AppColors.mist, width: 1.5)),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          const Icon(Icons.privacy_tip_rounded,
                            size: 13, color: AppColors.dim),
                          const SizedBox(width: 8),
                          Text('PRIVACY POLICY',
                            style: AppText.label.copyWith(
                              color: AppColors.dim,
                              decoration: TextDecoration.underline)),
                        ]))),
                  ])),
              ]))))
      ])));
  }

  void _err(String title, String msg) {
    showDialog(context: context, barrierDismissible: false,
      builder: (dlg) => Dialog(backgroundColor: Colors.transparent,
        child: Container(
          decoration: AppDecorations.dialog,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(width: double.infinity,
              padding: const EdgeInsets.all(14),
              color: AppColors.red,
              child: Text(title, style: AppText.title.copyWith(
                color: Colors.white, letterSpacing: 1.5))),
            Padding(padding: const EdgeInsets.all(20),
              child: Column(children: [
                Text(msg, style: AppText.body,
                  textAlign: TextAlign.center),
                const SizedBox(height: 20),
                GestureDetector(
                  onTap: () => Navigator.pop(dlg),
                  child: Container(
                    width: 80, height: 42,
                    decoration: const BoxDecoration(
                      color: AppColors.blue,
                      border: AppBorders.ink2,
                      boxShadow: [AppShadows.hard3]),
                    child: Center(child: Text('OK',
                      style: AppText.button)))),
              ])),
          ]))));
  }
}
