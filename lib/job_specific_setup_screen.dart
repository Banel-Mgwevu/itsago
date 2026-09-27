import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'app_theme.dart';
import 'loading_screen.dart';
import 'app_config.dart';
import 'paywall.dart';

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
  final _jobDescCtrl = TextEditingController();
  bool _companyError = false;
  bool _jobTitleError = false;
  String _roleLevel = 'Mid-Level';
  static const _roleLevels = ['Junior', 'Mid-Level', 'Senior'];

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
  void dispose() {
    _companyCtrl.dispose();
    _jobTitleCtrl.dispose();
    _jobDescCtrl.dispose();
    _entryCtrl.dispose();
    super.dispose();
  }

  bool _starting = false;

  Future<void> _start() async {
    if (_starting) return;
    final companyEmpty = _companyCtrl.text.trim().isEmpty;
    final jobTitleEmpty = _jobTitleCtrl.text.trim().isEmpty;
    if (companyEmpty || jobTitleEmpty) {
      setState(() { _companyError = companyEmpty; _jobTitleError = jobTitleEmpty; });
      return;
    }
    setState(() { _companyError = false; _jobTitleError = false; });

    _starting = true;
    final allowed = await Paywall.ensureAccess(context, PaywallFeature.jobInterview);
    _starting = false;
    if (!allowed || !mounted) return;

    final company  = _companyCtrl.text.trim();
    final jobTitle = _jobTitleCtrl.text.trim();
    final realJobDesc = _jobDescCtrl.text.trim();

    // A real pasted job posting gives the AI actual responsibilities,
    // skills and tools to write questions from - far more specific than
    // a title alone. If the person skipped it, fall back to a synthetic
    // description that explicitly forces the AI to reason about what
    // this exact role/seniority/company combination actually involves,
    // rather than defaulting to generic soft-skill questions.
    final jobDescription = realJobDesc.isNotEmpty
      ? 'Role: "$jobTitle" ($_roleLevel level) at $company.\n\n'
        'Job description:\n$realJobDesc'
      : 'The candidate is applying for a $_roleLevel level "$jobTitle" role at $company. '
        'No job posting was provided, so first think concretely about what a '
        '$_roleLevel $jobTitle actually does day-to-day - the specific skills, '
        'tools, tasks and responsibilities typical of that exact title and '
        'seniority (not a generic office job) - then base the interview '
        'questions on that real substance, not on the job title alone.';

    Navigator.of(context).push(PageRouteBuilder(
      pageBuilder: (_, __, ___) => LoadingScreen(
        cameras:            widget.cameras,
        jobDescription:     jobDescription,
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
        Expanded(child: Stack(children: [

          // Decorative accents - matches the geometric language used on
          // ProfileSetupScreen/AuthScreen so this doesn't read as a
          // plainer, older-feeling screen than the rest of the flow.
          Positioned(top: -40, right: -40,
            child: Container(width: 120, height: 120,
              decoration: BoxDecoration(shape: BoxShape.circle,
                color: AppColors.red.withOpacity(0.08),
                border: Border.all(color: AppColors.red.withOpacity(0.18), width: 1.5)))),
          Positioned(bottom: 60, left: -30,
            child: Container(width: 80, height: 60,
              color: AppColors.blue.withOpacity(0.05))),

          SingleChildScrollView(
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
                  Container(width: 44, height: 44,
                    decoration: BoxDecoration(color: Colors.white.withOpacity(0.18),
                      border: Border.all(color: Colors.white, width: 1.5)),
                    child: const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 22)),
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
            const SizedBox(height: 20),

            FadeTransition(opacity: _fade(0.28, 0.68), child: SlideTransition(
              position: _slide(0.28, 0.68),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Container(width: 4, height: 14, color: AppColors.ink),
                  const SizedBox(width: 8),
                  Text('JOB DESCRIPTION', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900,
                    color: AppColors.ink, letterSpacing: 1.2)),
                  const SizedBox(width: 6),
                  Text('(OPTIONAL, RECOMMENDED)', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700,
                    color: AppColors.dim, letterSpacing: 0.5)),
                ]),
                const SizedBox(height: 8),
                Container(
                  decoration: BoxDecoration(color: Colors.white,
                    border: Border.all(color: AppColors.ink, width: 1.5),
                    boxShadow: const [AppShadows.hard3]),
                  child: TextField(
                    controller: _jobDescCtrl,
                    minLines: 4,
                    maxLines: 8,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                    decoration: InputDecoration(
                      hintText: 'Paste the job posting here for much more '
                        'tailored questions - responsibilities, required '
                        'skills, tools, etc.',
                      hintStyle: TextStyle(fontSize: 12.5, color: AppColors.dim,
                        fontWeight: FontWeight.w400, height: 1.4),
                      contentPadding: const EdgeInsets.all(14),
                      border: InputBorder.none))),
                const SizedBox(height: 6),
                Text('Without this, questions are based on the job title alone.',
                  style: TextStyle(fontSize: 10.5, color: AppColors.dim, fontWeight: FontWeight.w500)),
              ]))),
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
                Row(children: [
                  for (int i = 0; i < _roleLevels.length; i++) ...[
                    if (i > 0) const SizedBox(width: 8),
                    Expanded(child: _levelChip(_roleLevels[i])),
                  ],
                ]),
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
          ])),
        ])),
      ])));
  }
}