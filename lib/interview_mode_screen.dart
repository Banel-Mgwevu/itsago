import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'app_theme.dart';
import 'setup_screen.dart';
import 'job_specific_setup_screen.dart';
import 'purchase_service.dart';

class InterviewModeScreen extends StatefulWidget {
  final List<CameraDescription> cameras;
  const InterviewModeScreen({super.key, required this.cameras});
  @override
  State<InterviewModeScreen> createState() => _InterviewModeScreenState();
}

class _InterviewModeScreenState extends State<InterviewModeScreen>
    with TickerProviderStateMixin {

  late final AnimationController _entryCtrl = AnimationController(
    vsync: this, duration: const Duration(milliseconds: 700))..forward();

  Animation<double> _fade(double a, double b) => Tween<double>(begin: 0, end: 1)
      .animate(CurvedAnimation(parent: _entryCtrl,
          curve: Interval(a, b, curve: Curves.easeOut)));
  Animation<Offset> _slide(double a, double b) =>
      Tween<Offset>(begin: const Offset(0, 0.06), end: Offset.zero)
          .animate(CurvedAnimation(parent: _entryCtrl,
              curve: Interval(a, b, curve: Curves.easeOut)));

  bool _jobSpecificUnlocked = false;

  @override
  void initState() {
    super.initState();
    _initPurchase();
  }

  Future<void> _initPurchase() async {
    final svc = PurchaseService();
    svc.onJobSpecificPurchaseSuccess = (_) {
      if (mounted) {
        setState(() => _jobSpecificUnlocked = true);
        Navigator.of(context).popUntil((r) => r.isCurrent);
        _push(JobSpecificSetupScreen(cameras: widget.cameras));
      }
    };
    await svc.init();
    if (mounted) setState(() => _jobSpecificUnlocked = svc.isJobSpecificUnlocked);
  }

  @override
  void dispose() { _entryCtrl.dispose(); super.dispose(); }

  void _push(Widget screen) {
    Navigator.of(context).push(PageRouteBuilder(
      pageBuilder: (_, __, ___) => screen,
      transitionsBuilder: (_, a, __, child) => SlideTransition(
        position: Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero)
            .animate(CurvedAnimation(parent: a, curve: Curves.easeOut)),
        child: child),
      transitionDuration: const Duration(milliseconds: 420)));
  }

  void _onJobSpecificTap() {
    _push(JobSpecificSetupScreen(cameras: widget.cameras));
  }

  Widget _paywallFeature(IconData icon, String title, String sub) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Row(children: [
      Container(width: 32, height: 32,
        decoration: BoxDecoration(color: AppColors.red.withOpacity(0.1),
          border: Border.all(color: AppColors.red, width: 1)),
        child: Icon(icon, color: AppColors.red, size: 16)),
      const SizedBox(width: 12),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: AppColors.ink)),
        Text(sub, style: TextStyle(fontSize: 10.5, color: AppColors.dim)),
      ])),
    ]));

  void _showPaywallDialog() {
    showDialog(context: context, builder: (_) => Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        decoration: BoxDecoration(color: Colors.white,
          border: Border.all(color: AppColors.ink, width: 2),
          boxShadow: const [AppShadows.hard4]),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: double.infinity, color: AppColors.ink, padding: const EdgeInsets.all(16),
            child: Column(children: [
              const Icon(Icons.psychology_alt_rounded, color: AppColors.red, size: 32),
              const SizedBox(height: 8),
              Text('JOB SPECIFIC INTERVIEW', style: AppText.title.copyWith(
                color: Colors.white, letterSpacing: 1.5)),
              const SizedBox(height: 4),
              const Text('Get the exact questions for the job you want',
                style: TextStyle(fontSize: 11, color: Colors.white70)),
            ])),
          Padding(padding: const EdgeInsets.all(20), child: Column(children: [
            _paywallFeature(Icons.gps_fixed_rounded, 'The exact role, not generic questions',
              'Built from the company and job title you give us'),
            _paywallFeature(Icons.trending_up_rounded, 'Matched to your level',
              'Junior, mid-level or senior difficulty'),
            _paywallFeature(Icons.visibility_rounded, 'Walk in already knowing what is coming',
              'Practice the real questions before the real interview'),
            _paywallFeature(Icons.all_inclusive_rounded, 'Yours for good',
              'One-time payment, unlimited use after'),
            const SizedBox(height: 16),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Text('R50', style: TextStyle(fontSize: 36, fontWeight: FontWeight.w900, color: AppColors.ink)),
              const SizedBox(width: 8),
              Text('once off', style: TextStyle(fontSize: 12, color: AppColors.dim, fontWeight: FontWeight.w600)),
            ]),
            const SizedBox(height: 16),
            GestureDetector(
              onTap: () async {
                final svc = PurchaseService();
                await svc.buyJobSpecificInterview();
              },
              child: Container(width: double.infinity, height: 52,
                decoration: const BoxDecoration(color: AppColors.red,
                  border: AppBorders.ink2, boxShadow: [AppShadows.hard4]),
                child: const Center(child: Text('UNLOCK FOR R50', style: TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 1.5))))),
            const SizedBox(height: 10),
            GestureDetector(
              onTap: () async {
                Navigator.pop(context);
                await PurchaseService().restorePurchases();
                if (mounted) setState(() => _jobSpecificUnlocked = PurchaseService().isJobSpecificUnlocked);
              },
              child: const Text('Restore purchase', style: TextStyle(
                fontSize: 11, color: Colors.grey, decoration: TextDecoration.underline))),
          ])),
        ]))));
  }

  Widget _priceRibbon({required String label, required Color bg, required Color fg, IconData? icon}) {
    return Container(
      width: double.infinity,
      color: bg,
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        if (icon != null) ...[Icon(icon, color: fg, size: 12), const SizedBox(width: 5)],
        Text(label, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w900,
          color: fg, letterSpacing: 1.3)),
      ]));
  }

  Widget _modeCard({
    required VoidCallback onTap,
    required Color accent,
    required IconData icon,
    required String title,
    required String subtitle,
    required String description,
    required Widget ribbon,
    List<String> bullets = const [],
    required double fadeStart,
    required double fadeEnd,
  }) {
    final isAmber = accent == AppColors.amber;
    final iconFg  = isAmber ? AppColors.ink : Colors.white;
    return FadeTransition(
      opacity: _fade(fadeStart, fadeEnd),
      child: SlideTransition(
        position: _slide(fadeStart, fadeEnd),
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: AppColors.ink, width: 2),
              boxShadow: const [AppShadows.hard4]),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // Header row echoes the main menu's card language: an
              // accent icon block on the left and a dark arrow tab on
              // the right, instead of a full-width colour banner.
              // Wrapped in IntrinsicHeight: this Row sits inside a
              // Column with unbounded height (it's in a scroll view), so
              // CrossAxisAlignment.stretch alone would try to stretch
              // children to infinite height. IntrinsicHeight gives the
              // Row a real, finite height (from its children) first.
              IntrinsicHeight(
                child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                SizedBox(width: 78, height: 92,
                  child: Stack(children: [
                    Positioned.fill(child: Container(color: accent)),
                    Positioned(top: 0, right: 0,
                      child: Container(width: 18, height: 18,
                        color: isAmber
                          ? Colors.black.withOpacity(0.09)
                          : Colors.white.withOpacity(0.12))),
                    Positioned(bottom: 7, left: 7,
                      child: Container(width: 7, height: 7,
                        decoration: BoxDecoration(shape: BoxShape.circle,
                          color: isAmber
                            ? Colors.black.withOpacity(0.15)
                            : Colors.white.withOpacity(0.25)))),
                    Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Icon(icon, size: 26, color: iconFg),
                      const SizedBox(height: 4),
                      Container(width: 20, height: 2, color: iconFg.withOpacity(0.4)),
                    ])),
                  ])),
                Expanded(child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center, children: [
                    Text(title, style: TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w900,
                      color: AppColors.ink, letterSpacing: -0.3, height: 1.05)),
                    const SizedBox(height: 6),
                    Text(subtitle, style: TextStyle(
                      fontSize: 10.5, fontWeight: FontWeight.w600,
                      color: AppColors.dim, letterSpacing: 0.2, height: 1.4)),
                  ]))),
                Container(width: 30, height: 92,
                  color: AppColors.ink,
                  child: Column(children: [
                    Container(height: 4, color: accent),
                    const Expanded(child: Center(
                      child: Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 19))),
                  ])),
              ])),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(description, style: TextStyle(fontSize: 12,
                    color: AppColors.dim, height: 1.5)),
                  if (bullets.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    ...bullets.map((b) => Padding(
                      padding: const EdgeInsets.only(bottom: 5),
                      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Container(
                          margin: const EdgeInsets.only(top: 5, right: 8),
                          width: 5, height: 5, color: accent),
                        Expanded(child: Text(b, style: TextStyle(fontSize: 11.5,
                          color: AppColors.ink, fontWeight: FontWeight.w600, height: 1.4))),
                      ]))),
                  ],
                ])),
              ribbon,
            ])))));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.cream,
      body: SafeArea(child: Column(children: [
        AppWidgets.header(
          title:       'VIDEO INTERVIEW',
          context:     context,
          leading:     AppWidgets.backButton(context),
          accentColor: AppColors.amber),
        Expanded(child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            FadeTransition(opacity: _fade(0.0, 0.35), child: SlideTransition(
              position: _slide(0.0, 0.35),
              child: Row(children: [
                Container(width: 4, height: 18, color: AppColors.blue),
                const SizedBox(width: 8),
                Text('HOW DO YOU WANT TO PRACTICE?',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900,
                    color: AppColors.blue, letterSpacing: 1.2)),
              ]))),
            const SizedBox(height: 18),

            _modeCard(
              onTap: () => _push(SetupScreen(cameras: widget.cameras)),
              accent: AppColors.blue,
              icon: Icons.chat_bubble_rounded,
              title: 'NORMAL INTERVIEW',
              subtitle: 'General practice, ready in seconds',
              ribbon: _priceRibbon(label: 'FREE, NO LIMIT', bg: AppColors.ink, fg: Colors.white),
              description: 'Give us a company name and start straight away with a broad '
                'mix of real interview questions.',
              bullets: const [
                'Behavioural, situational, values and strength questions',
                'No prep, no upload, just start',
              ],
              fadeStart: 0.1, fadeEnd: 0.5),
            const SizedBox(height: 16),

            _modeCard(
              onTap: _onJobSpecificTap,
              accent: AppColors.red,
              icon: Icons.psychology_alt_rounded,
              title: 'JOB SPECIFIC INTERVIEW',
              subtitle: "Built for the exact job you're going for",
              ribbon: _priceRibbon(label: 'FREE, TAILORED TO THE ROLE', bg: AppColors.ink, fg: Colors.white),
              description: 'Give us the company, job title and level and get the exact '
                'questions for that interview, built to match how this employer '
                'actually hires.',
              bullets: const [
                'The exact questions for that job, not generic ones',
                'Matched to junior, mid-level or senior difficulty',
                'Walk in already knowing what is coming',
                'Pay once, use it for every interview after, no limit',
              ],
              fadeStart: 0.2, fadeEnd: 0.6),
          ]))),
      ])));
  }
}