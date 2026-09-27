import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'app_theme.dart';
import 'main_menu_screen.dart';
import 'purpose_selection_screen.dart';

class OnboardingScreen extends StatefulWidget {
  final List<CameraDescription> cameras;
  const OnboardingScreen({super.key, required this.cameras});
  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with TickerProviderStateMixin {

  final PageController _pages = PageController();
  int _current = 0;

  late final AnimationController _slideCtrl = AnimationController(
    vsync: this, duration: const Duration(milliseconds: 700))..forward();
  late final AnimationController _scaleCtrl = AnimationController(
    vsync: this, duration: const Duration(milliseconds: 800))..forward();

  Animation<double> _fade(double a, double b) => Tween<double>(begin: 0, end: 1)
      .animate(CurvedAnimation(parent: _slideCtrl,
          curve: Interval(a, b, curve: Curves.easeOut)));
  Animation<Offset> _slide(double a, double b) =>
      Tween<Offset>(begin: const Offset(0, 0.05), end: Offset.zero)
          .animate(CurvedAnimation(parent: _slideCtrl,
              curve: Interval(a, b, curve: Curves.easeOut)));
  late final Animation<double> _scaleAnim = Tween<double>(begin: 0, end: 1)
      .animate(CurvedAnimation(parent: _scaleCtrl, curve: Curves.elasticOut));

  @override
  void dispose() {
    _pages.dispose(); _slideCtrl.dispose(); _scaleCtrl.dispose();
    super.dispose();
  }

  void _next() {
    if (_current < _slides.length - 1) {
      _pages.nextPage(
        duration: const Duration(milliseconds: 500), curve: Curves.easeOut);
    } else {
      _finish();
    }
  }

  void _finish() => Navigator.of(context).pushReplacement(PageRouteBuilder(
    pageBuilder: (_, __, ___) => PurposeSelectionScreen(cameras: widget.cameras),
    transitionsBuilder: (_, a, __, child) => FadeTransition(
      opacity: a, child: child),
    transitionDuration: const Duration(milliseconds: 600)));

  void _onPageChanged(int i) {
    setState(() => _current = i);
    _scaleCtrl.reset(); _scaleCtrl.forward();
    _slideCtrl.reset(); _slideCtrl.forward();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.cream,
      body: SafeArea(child: Column(children: [
        // ── Header bar ──────────────────────────────────
        Container(
          color: AppColors.ink,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(children: [
            // Progress dots
            Row(children: List.generate(_slides.length, (i) =>
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                margin: const EdgeInsets.only(right: 6),
                width: _current == i ? 24 : 8, height: 4,
                color: _current == i ? AppColors.amber : AppColors.inkAt(0.3)))),
            const Spacer(),
            AppWidgets.badge('ITSAGO AI'),
            const SizedBox(width: 8),
            // Skip
            GestureDetector(
              onTap: _finish,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: const BoxDecoration(
                  border: AppBorders.amber1),
                child: Text('SKIP',
                  style: AppText.label.copyWith(color: AppColors.amber)))),
          ])),

        // ── Pages ────────────────────────────────────────
        Expanded(child: PageView.builder(
          controller: _pages,
          onPageChanged: _onPageChanged,
          itemCount: _slides.length,
          itemBuilder: (_, i) => _buildSlide(_slides[i]))),

        // ── Bottom nav ───────────────────────────────────
        Container(
          color: AppColors.white,
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          child: Column(children: [
            Container(height: 1.5, color: AppColors.mist),
            const SizedBox(height: 16),
            GestureDetector(
              onTap: _next,
              child: Container(
                width: double.infinity, height: 56,
                decoration: BoxDecoration(
                  color: _slides[_current].accent,
                  border: AppBorders.ink2,
                  boxShadow: const [AppShadows.hard4]),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(_current == _slides.length - 1
                        ? 'GET STARTED' : 'NEXT',
                      style: AppText.button.copyWith(
                        color: _slides[_current].accent == AppColors.amber
                          ? AppColors.ink : Colors.white,
                        letterSpacing: 2)),
                    const SizedBox(width: 10),
                    Icon(
                      _current == _slides.length - 1
                        ? Icons.rocket_launch_rounded
                        : Icons.arrow_forward_rounded,
                      color: _slides[_current].accent == AppColors.amber
                        ? AppColors.ink : Colors.white,
                      size: 18),
                  ])),
          )]),
        ),
      ])),
    );
  }

  Widget _buildSlide(_Slide s) {
    final isAmber = s.accent == AppColors.amber;
    final iconFg = isAmber ? AppColors.ink : Colors.white;
    return AnimatedBuilder(
      animation: Listenable.merge([_slideCtrl, _scaleCtrl]),
      builder: (_, __) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Icon box
            Transform.scale(scale: _scaleAnim.value,
              child: Container(
                width: 130, height: 130,
                decoration: BoxDecoration(
                  color: s.accent,
                  border: AppBorders.ink3,
                  boxShadow: [AppShadows.hard5]),
                child: Stack(children: [
                  // Geometric inset
                  Positioned(top: 0, right: 0,
                    child: Container(width: 28, height: 28,
                      color: isAmber
                        ? AppColors.inkAt(0.1)
                        : Colors.white.withOpacity(0.12))),
                  Positioned(bottom: 10, left: 10,
                    child: Container(width: 8, height: 8,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isAmber
                          ? AppColors.inkAt(0.15)
                          : Colors.white.withOpacity(0.2)))),
                  Center(child: Icon(s.icon, size: 52, color: iconFg)),
                ]))),

            const SizedBox(height: 36),

            // Label
            FadeTransition(opacity: _fade(0.2, 0.7),
              child: AppWidgets.sectionLabel(
                s.tagline, accent: s.accent)),

            const SizedBox(height: 14),

            // Title
            FadeTransition(opacity: _fade(0.25, 0.75),
              child: SlideTransition(position: _slide(0.25, 0.75),
                child: Text(s.title,
                  style: AppText.display.copyWith(fontSize: 32, height: 1.0),
                  textAlign: TextAlign.left))),

            const SizedBox(height: 16),

            // Description card
            FadeTransition(opacity: _fade(0.35, 0.9),
              child: SlideTransition(position: _slide(0.35, 0.9),
                child: Container(
                  width: double.infinity,
                  decoration: AppDecorations.cardSmall,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                    Container(height: 4, color: s.accent),
                    Padding(
                      padding: const EdgeInsets.all(14),
                      child: Text(s.desc, style: AppText.body)),
                    // Feature bullets
                    ...s.bullets.map((b) => Padding(
                      padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                        Container(width: 6, height: 6,
                          margin: const EdgeInsets.only(top: 4, right: 10),
                          color: s.accent),
                        Expanded(child: Text(b, style: AppText.caption.copyWith(
                          height: 1.4, fontSize: 11))),
                      ]))),
                    const SizedBox(height: 4),
                  ])))),
          ])));
  }

  static final List<_Slide> _slides = [
    _Slide(
      accent:  AppColors.ink,
      icon:    Icons.rocket_launch_rounded,
      tagline: 'WELCOME',
      title:   'MEET\nITSAGO',
      desc:    'Your AI interview coach and CV builder. Get hired faster, starting today — free, no credit card needed.',
      bullets: ['Practice anytime, anywhere', 'AI that adapts to your role', 'Built in South Africa 🇿🇦']),
    _Slide(
      accent:  AppColors.red,
      icon:    Icons.auto_awesome_rounded,
      tagline: 'HOW IT WORKS',
      title:   'EVERYTHING\nYOU NEED',
      desc:    'Three tools working together to get you interview-ready.',
      bullets: [
        'Practice Interviews — realistic AI mock sessions with instant scoring',
        'AI Coach — personalised tips and strategy, anytime',
        'CV Builder — upload your CV, get 4 ATS-ready designs back']),
  ];
}

class _Slide {
  final Color    accent;
  final IconData icon;
  final String   tagline;
  final String   title;
  final String   desc;
  final List<String> bullets;
  const _Slide({
    required this.accent, required this.icon, required this.tagline,
    required this.title, required this.desc, required this.bullets});
}

