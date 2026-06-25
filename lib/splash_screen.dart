import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';
import 'app_theme.dart';
import 'main.dart';
import 'main_menu_screen.dart';
import 'onboarding_screen.dart';
import 'notification_service.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {

  late final AnimationController _logoCtrl = AnimationController(
    vsync: this, duration: const Duration(milliseconds: 1100));
  late final AnimationController _textCtrl = AnimationController(
    vsync: this, duration: const Duration(milliseconds: 900));
  late final AnimationController _geoCtrl = AnimationController(
    vsync: this, duration: const Duration(milliseconds: 1400));
  late final AnimationController _pulseCtrl = AnimationController(
    vsync: this, duration: const Duration(milliseconds: 1800));

  late final Animation<double> _logoScale =
      Tween<double>(begin: 0, end: 1).animate(
          CurvedAnimation(parent: _logoCtrl, curve: Curves.elasticOut));
  late final Animation<double> _logoOpacity =
      Tween<double>(begin: 0, end: 1).animate(
          CurvedAnimation(parent: _logoCtrl,
              curve: const Interval(0, 0.7, curve: Curves.easeOut)));
  late final Animation<double> _textOpacity =
      Tween<double>(begin: 0, end: 1).animate(
          CurvedAnimation(parent: _textCtrl, curve: Curves.easeOut));
  late final Animation<double> _textSlide =
      Tween<double>(begin: 28, end: 0).animate(
          CurvedAnimation(parent: _textCtrl, curve: Curves.easeOut));
  late final Animation<double> _geoAnim =
      Tween<double>(begin: 0, end: 1).animate(
          CurvedAnimation(parent: _geoCtrl, curve: Curves.easeOut));
  late final Animation<double> _lineAnim =
      Tween<double>(begin: 0, end: 1).animate(
          CurvedAnimation(parent: _geoCtrl,
              curve: const Interval(0.5, 1.0, curve: Curves.easeOut)));
  late final Animation<double> _pulse =
      Tween<double>(begin: 0.92, end: 1.0).animate(
          CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));

  @override
  void initState() {
    super.initState();
    _runSequence();
  }

  Future<void> _runSequence() async {
    _geoCtrl.forward();
    await Future.delayed(const Duration(milliseconds: 250));
    _logoCtrl.forward();
    await Future.delayed(const Duration(milliseconds: 500));
    _textCtrl.forward();
    await Future.delayed(const Duration(milliseconds: 350));
    _pulseCtrl.repeat(reverse: true);
    await Future.delayed(const Duration(milliseconds: 1800));
    if (mounted) _navigate();
  }

  Future<void> _navigate() async {
    try {
      final cameras = await availableCameras();
      if (!mounted) return;
      await NotificationService().checkAndRequestPermissions();
      // Wait for Firebase Auth to restore persisted session
      await Future.delayed(const Duration(milliseconds: 500));
      final user = FirebaseAuth.instance.currentUser;
      if (!mounted) return;
      Navigator.of(context).pushReplacement(PageRouteBuilder(
        pageBuilder: (_, __, ___) => user != null
            ? MainMenuScreen(cameras: cameras)
            : OnboardingScreen(cameras: cameras),
        transitionsBuilder: (_, a, __, child) =>
            FadeTransition(opacity: a, child: child),
        transitionDuration: const Duration(milliseconds: 600)));
    } catch (e) {
      if (mounted) Navigator.of(context).pushReplacement(PageRouteBuilder(
        pageBuilder: (_, __, ___) => ErrorApp(message: 'Init failed: $e'),
        transitionsBuilder: (_, a, __, child) =>
            FadeTransition(opacity: a, child: child),
        transitionDuration: const Duration(milliseconds: 400)));
    }
  }

  @override
  void dispose() {
    _logoCtrl.dispose(); _textCtrl.dispose();
    _geoCtrl.dispose();  _pulseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.cream,
      body: AnimatedBuilder(
        animation: Listenable.merge([_logoCtrl, _textCtrl, _geoCtrl, _pulseCtrl]),
        builder: (_, __) => Stack(children: [
          // Ã¢â€â‚¬Ã¢â€â‚¬ Geometric background Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬
          // Red rule Ã¢â‚¬â€ top left
          Positioned(top: 72, left: 36,
            child: Opacity(opacity: _geoAnim.value,
              child: Container(
                width: 56 * _geoAnim.value, height: 4,
                color: AppColors.red))),
          // Amber circle Ã¢â‚¬â€ top right bleed
          Positioned(top: -44, right: -44,
            child: Transform.scale(scale: _geoAnim.value,
              child: Container(width: 130, height: 130,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.amber.withOpacity(0.18),
                  border: Border.all(
                    color: AppColors.amber.withOpacity(0.35), width: 1.5))))),
          // Blue rectangle Ã¢â‚¬â€ mid left
          Positioned(top: 220, left: -24,
            child: Opacity(opacity: _geoAnim.value,
              child: Container(
                width: 56, height: 14,
                color: AppColors.blue.withOpacity(0.25)))),
          // Ink small square
          Positioned(top: 290, left: 56,
            child: Transform.scale(scale: _geoAnim.value,
              child: Container(width: 10, height: 10, color: AppColors.ink))),
          // Vertical ink rule Ã¢â‚¬â€ left
          Positioned(top: 152, left: 28,
            child: Opacity(opacity: _lineAnim.value,
              child: Container(
                width: 2.5,
                height: 52 * _lineAnim.value,
                color: AppColors.inkAt(0.35)))),
          // Horizontal ink rule Ã¢â‚¬â€ bottom right
          Positioned(bottom: 180, right: 36,
            child: Opacity(opacity: _lineAnim.value,
              child: Container(
                width: 72 * _lineAnim.value, height: 2.5,
                color: AppColors.inkAt(0.25)))),
          // Red small dot Ã¢â‚¬â€ bottom left
          Positioned(bottom: 140, left: 52,
            child: Transform.scale(scale: _geoAnim.value,
              child: Container(width: 8, height: 8,
                decoration: const BoxDecoration(
                  color: AppColors.red, shape: BoxShape.circle)))),

          // Ã¢â€â‚¬Ã¢â€â‚¬ Main content Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬
          Center(child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Logo box
              Transform.scale(
                scale: _logoScale.value * _pulse.value,
                child: Opacity(opacity: _logoOpacity.value,
                  child: Container(
                    width: 110, height: 110,
                    decoration: const BoxDecoration(
                      color: AppColors.white,
                      border: AppBorders.ink3,
                      boxShadow: [AppShadows.hard5]),
                    child: Stack(children: [
                      // Amber block Ã¢â‚¬â€ bottom left
                      Positioned(bottom: 0, left: 0,
                        child: Container(width: 36, height: 36,
                          color: AppColors.amber)),
                      // Red dot Ã¢â‚¬â€ top right
                      Positioned(top: 14, right: 14,
                        child: Container(width: 16, height: 16,
                          decoration: const BoxDecoration(
                            color: AppColors.red,
                            shape: BoxShape.circle))),
                      // Blue dot Ã¢â‚¬â€ top left
                      Positioned(top: 14, left: 14,
                        child: Container(width: 8, height: 8,
                          decoration: const BoxDecoration(
                            color: AppColors.blue,
                            shape: BoxShape.circle))),
                      // Letter
                      Center(child: Text('I',
                        style: AppText.display.copyWith(
                          fontSize: 46, letterSpacing: 2))),
                    ])))),

              const SizedBox(height: 36),

              // App name
              Transform.translate(
                offset: Offset(0, _textSlide.value),
                child: Opacity(opacity: _textOpacity.value,
                  child: Column(children: [
                    Text('ITSAGO',
                      style: AppText.display.copyWith(letterSpacing: 7, fontSize: 40)),
                    const SizedBox(height: 10),
                    // Colour rule
                    Row(mainAxisSize: MainAxisSize.min, children: [
                      Container(width: 32, height: 3, color: AppColors.red),
                      Container(width: 32, height: 3, color: AppColors.amber),
                      Container(width: 32, height: 3, color: AppColors.blue),
                    ]),
                    const SizedBox(height: 12),
                    Text('AI INTERVIEW PREP',
                      style: AppText.label.copyWith(color: AppColors.dim, fontSize: 10)),
                  ]))),

              const SizedBox(height: 56),

              // Loading dots
              Opacity(opacity: _textOpacity.value,
                child: Column(children: [
                  Row(mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(3, (i) {
                      double v = ((_pulseCtrl.value - i * 0.28) % 1.0).clamp(0.0, 1.0);
                      return Container(
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: 7, height: 7,
                        decoration: BoxDecoration(
                          color: AppColors.inkAt(0.25 + v * 0.75),
                          shape: BoxShape.circle));
                    })),
                  const SizedBox(height: 10),
                  Text('INITIALISING',
                    style: AppText.label.copyWith(color: AppColors.dim)),
                ])),
            ])),
        ]),
      ),
    );
  }
}
