import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app_theme.dart';
import 'main.dart';
import 'terms_screen.dart';
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

  bool _loading = false;
  final _googleSignIn = GoogleSignIn(scopes: ['email', 'profile']);

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

  Future<void> _signInGoogle() async {
    if (_loading) return;
    setState(() => _loading = true);
    try {
      final acct = await _googleSignIn.signIn();
      if (acct == null) { setState(() => _loading = false); return; }
      final auth = await acct.authentication;
      await FirebaseAuth.instance.signInWithCredential(
        GoogleAuthProvider.credential(
          accessToken: auth.accessToken, idToken: auth.idToken));
      await _navigate();
    } catch (_) {
      if (mounted) {
        setState(() => _loading = false);
        _err('SIGN-IN FAILED',
          'Could not sign in with Google. Please try again.');
      }
    }
  }

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
                  Text('Google', style: AppText.caption),
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

                const SizedBox(height: 28),

                // Google sign-in button
                GestureDetector(
                  onTap: _loading ? null : _signInGoogle,
                  child: Container(
                    width: double.infinity, height: 56,
                    decoration: BoxDecoration(
                      color: _loading ? AppColors.dim : AppColors.white,
                      border: AppBorders.ink2,
                      boxShadow: _loading
                        ? null : const [AppShadows.hard4]),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                      Container(width: 32, height: 32,
                        decoration: BoxDecoration(
                          color: _loading
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
                          color: _loading
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

                Center(child: GestureDetector(
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
                    ])))),

                const SizedBox(height: 14),

                Center(child: Text(
                  'By signing in you agree to our Terms of Service\n'
                  'and Privacy Policy.',
                  style: AppText.caption.copyWith(height: 1.5),
                  textAlign: TextAlign.center)),
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
