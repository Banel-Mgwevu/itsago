import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'app_theme.dart';
import 'loading_screen.dart';
import 'app_config.dart';
import 'purchase_service.dart';

class JobSpecificSetupScreen extends StatefulWidget {
  final List<CameraDescription> cameras;
  const JobSpecificSetupScreen({super.key, required this.cameras});
  @override
  State<JobSpecificSetupScreen> createState() => _JobSpecificSetupScreenState();
}

class _JobSpecificSetupScreenState extends State<JobSpecificSetupScreen>
    with TickerProviderStateMixin {

  final _companyCtrl = TextEditingController();
  final _jobTitleCtrl = TextEditingController();
  bool _companyError = false;
  bool _jobTitleError = false;
  String _roleLevel = 'Mid-Level';
  static const _roleLevels = ['Junior', 'Mid-Level', 'Senior'];
  bool _isUnlocked = false;

  late final AnimationController _entryCtrl = AnimationController(
    vsync: this, duration: const Duration(milliseconds: 700))..forward();

  Animation<double> _fade(double a, double b) => Tween<double>(begin: 0, end: 1)
      .animate(CurvedAnimation(parent: _entryCtrl,
          curve: Interval(a, b, curve: Curves.easeOut)));
  Animation<Offset> _slide(double a, double b) =>
      Tween<Offset>(begin: const Offset(0, 0.06), end: Offset.zero)
          .animate(CurvedAnimation(parent: _entryCtrl,
              curve: Interval(a, b, curve: Curves.easeOut)));

  @override
  void initState() {
    super.initState();
    _initPurchase();
  }

  Future<void> _initPurchase() async {
    final svc = PurchaseService();
    svc.onJobSpecificPurchaseSuccess = (_) {
      if (mounted) {
        setState(() => _isUnlocked = true);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Unlocked! Tap Generate to continue.'),
          backgroundColor: AppColors.ink));
      }
    };
    await svc.init();
    if (mounted) setState(() => _isUnlocked = svc.isJobSpecificUnlocked);
  }

  @override
  void dispose() {
    _companyCtrl.dispose();
    _jobTitleCtrl.dispose();
    _entryCtrl.dispose();
    super.dispose();
  }

  void _start() {
    final companyEmpty = _companyCtrl.text.trim().isEmpty;
    final jobTitleEmpty = _jobTitleCtrl.text.trim().isEmpty;
    if (companyEmpty || jobTitleEmpty) {
      setState(() { _companyError = companyEmpty; _jobTitleError = jobTitleEmpty; });
      return;
    }
    setState(() { _companyError = false; _jobTitleError = false; });

    // Job-specific interview is free - no paywall.

    final company  = _companyCtrl.text.trim();
    final jobTitle = _jobTitleCtrl.text.trim();

    final syntheticJobDescription =
      'The candidate is applying for a $_roleLevel level role of "$jobTitle" at $company. '
      'Generate interview questions appropriate for someone at $_roleLevel level, '
      'matching the typical responsibilities, skills and expectations of this '
      'specific role and seniority.';

    Navigator.of(context).push(PageRouteBuilder(
      pageBuilder: (_, __, ___) => LoadingScreen(
        cameras:            widget.cameras,
        jobDescription:     syntheticJobDescription,
        interviewStyle:     'friendly',
        questionCategories: const ['behavioural','situational','values','strength'],
        company:            company,
        apiKey:             AppConfig.geminiApiKey),
      transitionsBuilder: (_, a, __, child) => SlideTransition(
        position: Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero)
            .animate(CurvedAnimation(parent: a, curve: Curves.easeOut)),
        child: child),
      transitionDuration: const Duration(milliseconds: 420)));
  }

  Widget _field({
    required String label,
    required String icon,
    required TextEditingController ctrl,
    required String hint,
    bool error = false,
  }) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Container(width: 4, height: 14, color: error ? AppColors.red : AppColors.ink),
        const SizedBox(width: 8),
        Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900,
          color: AppColors.ink, letterSpacing: 1.2)),
      ]),
      const SizedBox(height: 8),
      Container(
        decoration: BoxDecoration(color: Colors.white,
          border: Border.all(color: error ? AppColors.red : AppColors.ink,
            width: error ? 2 : 1.5),
          boxShadow: const [AppShadows.hard3]),
        child: TextField(
          controller: ctrl,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(fontSize: 13, color: AppColors.dim, fontWeight: FontWeight.w400),
            prefixIcon: Padding(
              padding: const EdgeInsets.only(left: 14, right: 10),
              child: Text(icon, style: const TextStyle(fontSize: 18))),
            prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
            contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 4),
            border: InputBorder.none),
        )),
      if (error) Padding(
        padding: const EdgeInsets.only(top: 5, left: 12),
        child: Text('This field is required',
          style: TextStyle(fontSize: 10.5, color: AppColors.red, fontWeight: FontWeight.w600))),
    ]);
  }

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
              const Text('Questions built for this exact role',
                style: TextStyle(fontSize: 11, color: Colors.white70)),
            ])),
          Padding(padding: const EdgeInsets.all(20), child: Column(children: [
            _paywallFeature(Icons.auto_awesome_rounded, 'AI-generated questions', 'Tailored to the company and role'),
            _paywallFeature(Icons.trending_up_rounded, 'Matched to your level', 'Junior, mid-level or senior difficulty'),
            _paywallFeature(Icons.all_inclusive_rounded, 'Yours for good', 'One-time payment, unlimited use after'),
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
                if (mounted) Navigator.pop(context);
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
                if (mounted) setState(() => _isUnlocked = PurchaseService().isJobSpecificUnlocked);
              },
              child: const Text('Restore purchase', style: TextStyle(
                fontSize: 11, color: Colors.grey, decoration: TextDecoration.underline))),
          ])),
        ]))));
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

  Widget _levelChip(String label) {
    final on = _roleLevel == label;
    return GestureDetector(
      onTap: () => setState(() => _roleLevel = label),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: double.infinity,
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: on ? AppColors.ink : Colors.white,
          border: Border.all(color: on ? AppColors.ink : AppColors.mist, width: 1.5),
          boxShadow: on ? const [AppShadows.hard3] : null),
        child: Text(label.toUpperCase(), style: AppText.label.copyWith(
          color: on ? Colors.white : AppColors.dim, fontSize: 9))));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.cream,
      resizeToAvoidBottomInset: true,
      body: SafeArea(child: Column(children: [
        AppWidgets.header(
          title:       'JOB SPECIFIC INTERVIEW',
          context:     context,
          leading:     AppWidgets.backButton(context),
          accentColor: AppColors.red),
        Expanded(child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 32),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

            FadeTransition(opacity: _fade(0.0, 0.4), child: SlideTransition(
              position: _slide(0.0, 0.4),
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft, end: Alignment.bottomRight,
                    colors: [AppColors.red, AppColors.red.withOpacity(0.75)]),
                  border: Border.all(color: AppColors.ink, width: 2),
                  boxShadow: const [AppShadows.hard4]),
                padding: const EdgeInsets.all(16),
                child: Row(children: [
                  Container(width: 40, height: 40,
                    decoration: BoxDecoration(color: Colors.white.withOpacity(0.2),
                      shape: BoxShape.circle),
                    child: const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 20)),
                  const SizedBox(width: 12),
                  Expanded(child: Text(
                    'Just the company and role, our AI builds the rest of your practice questions.',
                    style: const TextStyle(fontSize: 12.5, color: Colors.white,
                      fontWeight: FontWeight.w600, height: 1.4))),
                ])))),
            const SizedBox(height: 28),

            FadeTransition(opacity: _fade(0.15, 0.55), child: SlideTransition(
              position: _slide(0.15, 0.55),
              child: _field(
                label: 'COMPANY NAME',
                icon: '\u{1F3E2}',
                ctrl: _companyCtrl,
                hint: 'e.g. Standard Bank',
                error: _companyError))),
            const SizedBox(height: 20),

            FadeTransition(opacity: _fade(0.25, 0.65), child: SlideTransition(
              position: _slide(0.25, 0.65),
              child: _field(
                label: 'JOB TITLE',
                icon: '\u{1F4BC}',
                ctrl: _jobTitleCtrl,
                hint: 'e.g. Junior Software Developer',
                error: _jobTitleError))),
            const SizedBox(height: 24),

            FadeTransition(opacity: _fade(0.3, 0.7), child: SlideTransition(
              position: _slide(0.3, 0.7),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Container(width: 4, height: 14, color: AppColors.ink),
                  const SizedBox(width: 8),
                  Text('ROLE LEVEL', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900,
                    color: AppColors.ink, letterSpacing: 1.2)),
                ]),
                const SizedBox(height: 10),
                Row(children: _roleLevels.map((l) => Expanded(
                  child: Padding(padding: const EdgeInsets.only(right: 8),
                    child: _levelChip(l)))).toList()),
              ]))),
            const SizedBox(height: 28),

            FadeTransition(opacity: _fade(0.35, 0.75), child: SlideTransition(
              position: _slide(0.35, 0.75),
              child: GestureDetector(
                onTap: _start,
                child: Container(width: double.infinity, height: 54,
                  decoration: const BoxDecoration(color: AppColors.red,
                    border: AppBorders.ink2, boxShadow: [AppShadows.hard4]),
                  child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    const Icon(Icons.auto_awesome_rounded,
                      color: Colors.white, size: 19),
                    const SizedBox(width: 9),
                    Text('GENERATE MY QUESTIONS',
                      style: TextStyle(fontSize: 13.5,
                      fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 1.3)),
                  ]))))),
            const SizedBox(height: 12),

            FadeTransition(opacity: _fade(0.4, 0.8), child: SlideTransition(
              position: _slide(0.4, 0.8),
              child: Center(child: Text('Takes about 10 seconds',
                style: TextStyle(fontSize: 11, color: AppColors.dim, fontWeight: FontWeight.w600))))),
          ]))),
      ])));
  }
}