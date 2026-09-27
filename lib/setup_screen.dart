import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'app_theme.dart';
import 'loading_screen.dart';
import 'app_config.dart';
import 'paywall.dart';

class SetupScreen extends StatefulWidget {
  final List<CameraDescription> cameras;
  const SetupScreen({super.key, required this.cameras});
  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen>
    with TickerProviderStateMixin {

  final _companyCtrl = TextEditingController();
  bool _companyError = false;
  List<String> _selectedCategories = ['behavioural','situational','values','strength'];

  late final AnimationController _entryCtrl = AnimationController(
    vsync: this, duration: const Duration(milliseconds: 650))..forward();

  Animation<double> _fade(double a, double b) => Tween<double>(begin: 0, end: 1)
      .animate(CurvedAnimation(parent: _entryCtrl,
          curve: Interval(a, b, curve: Curves.easeOut)));
  Animation<Offset> _slide(double a, double b) =>
      Tween<Offset>(begin: const Offset(0, 0.05), end: Offset.zero)
          .animate(CurvedAnimation(parent: _entryCtrl,
              curve: Interval(a, b, curve: Curves.easeOut)));

  @override
  void dispose() {
    _companyCtrl.dispose();
    _entryCtrl.dispose();
    super.dispose();
  }

  bool _starting = false;

  Future<void> _start() async {
    if (_starting) return;
    if (_companyCtrl.text.trim().isEmpty) {
      setState(() => _companyError = true); return;
    }
    setState(() => _companyError = false);

    _starting = true;
    final allowed = await Paywall.ensureAccess(context, PaywallFeature.interview);
    _starting = false;
    if (!allowed || !mounted) return;

    Navigator.of(context).push(PageRouteBuilder(
      pageBuilder: (_, __, ___) => LoadingScreen(
        cameras:            widget.cameras,
        jobDescription:     '',
        interviewStyle:     'friendly',
        questionCategories: _selectedCategories,
        company:            _companyCtrl.text.trim(),
        apiKey:             AppConfig.geminiApiKey),
      transitionsBuilder: (_, a, __, child) => SlideTransition(
        position: Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero)
            .animate(CurvedAnimation(parent: a, curve: Curves.easeOut)),
        child: child),
      transitionDuration: const Duration(milliseconds: 420)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.cream,
      body: SafeArea(child: Column(children: [
        AppWidgets.header(
          title:   'PRACTICE INTERVIEW',
          context: context,
          leading: AppWidgets.backButton(context)),

        Expanded(child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 32),
          child: AnimatedBuilder(
            animation: _entryCtrl,
            builder: (_, __) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [

              // Intro
              FadeTransition(opacity: _fade(0.0, 0.5),
                child: SlideTransition(position: _slide(0.0, 0.5),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                    AppWidgets.sectionLabel('SETUP'),
                    const SizedBox(height: 10),
                    Text('Configure\nyour session', style: AppText.headline),
                    const SizedBox(height: 6),
                    Text('Enter the company name and pick your question types.',
                      style: AppText.caption),
                  ]))),

              const SizedBox(height: 24),

              // Company input
              FadeTransition(opacity: _fade(0.2, 0.65),
                child: SlideTransition(position: _slide(0.2, 0.65),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                    AppWidgets.sectionLabel('COMPANY', accent: AppColors.red),
                    const SizedBox(height: 10),
                    Container(
                      decoration: BoxDecoration(
                        color: AppColors.white,
                        border: Border.all(
                          color: _companyError ? AppColors.red : AppColors.ink,
                          width: 2),
                        boxShadow: const [AppShadows.hard4]),
                      child: TextField(
                        controller: _companyCtrl,
                        onChanged: (_) {
                          if (_companyError) setState(() => _companyError = false);
                        },
                        style: AppText.body,
                        decoration: InputDecoration(
                          hintText: 'e.g. Standard Bank, Shoprite, Vodacom...',
                          hintStyle: AppText.caption,
                          contentPadding: const EdgeInsets.all(14),
                          border: InputBorder.none,
                          prefixIcon: Icon(Icons.business_rounded,
                            color: _companyError ? AppColors.red : AppColors.dim,
                            size: 18)))),
                    if (_companyError)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Row(children: [
                          const Icon(Icons.error_outline_rounded,
                            color: AppColors.red, size: 14),
                          const SizedBox(width: 6),
                          Text('Company name is required',
                            style: AppText.caption.copyWith(color: AppColors.red)),
                        ])),
                  ]))),

              const SizedBox(height: 24),

              // Info tiles
              FadeTransition(opacity: _fade(0.35, 0.8),
                child: SlideTransition(position: _slide(0.35, 0.8),
                  child: Row(children: [
                    _infoTile(Icons.timer_rounded,     '20 SEC', 'per answer', AppColors.amber),
                    const SizedBox(width: 10),
                    _infoTile(Icons.quiz_rounded,      '5',      'questions',  AppColors.red),
                    const SizedBox(width: 10),
                    _infoTile(Icons.analytics_rounded, 'AI',     'scoring',    AppColors.blue),
                  ]))),

              const SizedBox(height: 24),

              // Question type picker
              FadeTransition(opacity: _fade(0.48, 0.9),
                child: SlideTransition(position: _slide(0.48, 0.9),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                    AppWidgets.sectionLabel('QUESTION TYPES', accent: AppColors.blue),
                    const SizedBox(height: 10),
                    Wrap(spacing: 8, runSpacing: 8, children: [
                      _categoryChip('Behavioural',     'behavioural'),
                      _categoryChip('Situational',     'situational'),
                      _categoryChip('Values & Culture','values'),
                      _categoryChip('Strengths',       'strength'),
                      _categoryChip('Technical',       'technical'),
                      _categoryChip('Leadership',      'leadership'),
                      _categoryChip('Salary',          'salary'),
                    ]),
                    const SizedBox(height: 6),
                    Text('Select the types of questions you want to practise.',
                      style: AppText.caption.copyWith(color: AppColors.dim, fontSize: 9)),
                  ]))),

              const SizedBox(height: 32),

              // Start button
              FadeTransition(opacity: _fade(0.6, 1.0),
                child: SlideTransition(position: _slide(0.6, 1.0),
                  child: GestureDetector(
                    onTap: _start,
                    child: Container(
                      width: double.infinity, height: 60,
                      decoration: const BoxDecoration(
                        color: AppColors.red,
                        border: AppBorders.ink2,
                        boxShadow: [AppShadows.hard5]),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                        const Icon(Icons.play_arrow_rounded,
                          color: Colors.white, size: 22),
                        const SizedBox(width: 10),
                        Text('START INTERVIEW',
                          style: AppText.button.copyWith(
                            letterSpacing: 2, fontSize: 15)),
                      ]))))),
            ])))),
      ])));
  }

  Widget _categoryChip(String label, String value) {
    final on = _selectedCategories.contains(value);
    return GestureDetector(
      onTap: () => setState(() {
        if (on) {
          if (_selectedCategories.length > 1) _selectedCategories.remove(value);
        } else {
          _selectedCategories.add(value);
        }
      }),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: on ? AppColors.ink : AppColors.white,
          border: Border.all(
            color: on ? AppColors.ink : AppColors.mist, width: 1.5),
          boxShadow: on ? const [AppShadows.hard3] : null),
        child: Text(label.toUpperCase(), style: AppText.label.copyWith(
          color: on ? Colors.white : AppColors.dim, fontSize: 8))));
  }

  Widget _infoTile(IconData icon, String val, String sub, Color accent) {
    return Expanded(child: Container(
      height: 72,
      decoration: BoxDecoration(
        color: AppColors.white,
        border: AppBorders.ink2,
        boxShadow: const [AppShadows.hard3]),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(width: 28, height: 3, color: accent),
        const SizedBox(height: 6),
        Text(val, style: AppText.title.copyWith(color: accent)),
        Text(sub.toUpperCase(), style: AppText.label.copyWith(
          color: AppColors.dim, fontSize: 7)),
      ])));
  }
}

