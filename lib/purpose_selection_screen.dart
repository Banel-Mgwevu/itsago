import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'app_theme.dart';
import 'profile_setup_screen.dart';

class PurposeSelectionScreen extends StatefulWidget {
  final List<CameraDescription> cameras;
  const PurposeSelectionScreen({super.key, required this.cameras});
  @override
  State<PurposeSelectionScreen> createState() => _PurposeSelectionScreenState();
}

class _PurposeSelectionScreenState extends State<PurposeSelectionScreen>
    with TickerProviderStateMixin {

  String? _selected;

  late final AnimationController _entryCtrl = AnimationController(
    vsync: this, duration: const Duration(milliseconds: 700))..forward();

  Animation<double> _fade(double a, double b) => Tween<double>(begin: 0, end: 1)
      .animate(CurvedAnimation(parent: _entryCtrl,
          curve: Interval(a, b, curve: Curves.easeOut)));
  Animation<Offset> _slide(double a, double b) =>
      Tween<Offset>(begin: const Offset(0, 0.05), end: Offset.zero)
          .animate(CurvedAnimation(parent: _entryCtrl,
              curve: Interval(a, b, curve: Curves.easeOut)));

  @override
  void dispose() { _entryCtrl.dispose(); super.dispose(); }

  void _continue() {
    if (_selected == null) return;
    Navigator.of(context).push(PageRouteBuilder(
      pageBuilder: (_, __, ___) =>
          ProfileSetupScreen(cameras: widget.cameras, selectedPurpose: _selected!),
      transitionsBuilder: (_, a, __, child) => SlideTransition(
        position: Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero)
            .animate(CurvedAnimation(parent: a, curve: Curves.easeOut)),
        child: child),
      transitionDuration: const Duration(milliseconds: 500)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.cream,
      body: SafeArea(child: Column(children: [
        // ── Header ──────────────────────────────────────
        AppWidgets.header(
          title: 'YOUR GOALS',
          context: context,
          leading: AppWidgets.backButton(context)),

        // ── Body ─────────────────────────────────────────
        Expanded(child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 32),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

            FadeTransition(opacity: _fade(0.0, 0.5),
              child: SlideTransition(position: _slide(0.0, 0.5),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  AppWidgets.sectionLabel('TELL US'),
                  const SizedBox(height: 10),
                  Text('Why do you want\nto use ITSAGO?',
                    style: AppText.headline),
                  const SizedBox(height: 6),
                  Text('Select one to continue.',
                    style: AppText.caption),
                ]))),

            const SizedBox(height: 24),

            // Option cards
            ..._options.asMap().entries.map((e) {
              final i = e.key; final opt = e.value;
              return FadeTransition(
                opacity: _fade(0.1 + i * 0.1, 0.6 + i * 0.08),
                child: SlideTransition(
                  position: _slide(0.1 + i * 0.1, 0.6 + i * 0.08),
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: _optionCard(opt))));
            }),

            const SizedBox(height: 24),

            // Continue button
            FadeTransition(opacity: _fade(0.6, 1.0),
              child: SlideTransition(position: _slide(0.6, 1.0),
                child: Column(children: [
                  GestureDetector(
                    onTap: _selected != null ? _continue : null,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      width: double.infinity, height: 56,
                      decoration: BoxDecoration(
                        color: _selected != null
                          ? AppColors.ink : AppColors.dim,
                        border: AppBorders.ink2,
                        boxShadow: _selected != null
                          ? const [AppShadows.hard4] : null),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                        Text('CONTINUE',
                          style: AppText.button.copyWith(letterSpacing: 2)),
                        const SizedBox(width: 10),
                        const Icon(Icons.arrow_forward_rounded,
                          color: Colors.white, size: 18),
                      ]))),
                  const SizedBox(height: 12),
                  // Quick skip
                  GestureDetector(
                    onTap: () {
                      setState(() => _selected = _options.first.id);
                      _continue();
                    },
                    child: Container(
                      width: double.infinity, height: 46,
                      decoration: BoxDecoration(
                        color: AppColors.cream,
                        border: Border.all(color: AppColors.mist, width: 1.5)),
                      child: Center(child: Text(
                        'SKIP — USE DEFAULT',
                        style: AppText.label.copyWith(color: AppColors.dim))))),
                ]))),
          ]))),
      ])));
  }

  Widget _optionCard(_Option opt) {
    final bool selected = _selected == opt.id;
    final isAmber = opt.accent == AppColors.amber;
    return GestureDetector(
      onTap: () => setState(() => _selected = opt.id),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        decoration: BoxDecoration(
          color: AppColors.white,
          border: Border.all(
            color: selected ? opt.accent : AppColors.mist, width: selected ? 2.5 : 1.5),
          boxShadow: selected
            ? [AppShadows.colored(opt.accent)]
            : const [AppShadows.hard3]),
        child: Row(children: [
          // Colour block
          SizedBox(width: 70, height: 80,
            child: Stack(children: [
              Positioned.fill(child: Container(
                color: selected ? opt.accent : AppColors.mist)),
              if (selected)
                Positioned(top: 0, right: 0,
                  child: Container(width: 16, height: 16,
                    color: isAmber
                      ? AppColors.inkAt(0.1)
                      : Colors.white.withOpacity(0.15))),
              Center(child: Icon(opt.icon, size: 26,
                color: selected
                  ? (isAmber ? AppColors.ink : Colors.white)
                  : AppColors.dim)),
            ])),
          // Text
          Expanded(child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
              Text(opt.title,
                style: AppText.title.copyWith(
                  color: selected ? opt.accent : AppColors.ink)),
              const SizedBox(height: 4),
              Text(opt.subtitle, style: AppText.caption),
            ]))),
          // Check or arrow
          Container(width: 36, height: 80,
            color: selected ? opt.accent : AppColors.cream,
            child: Center(child: Icon(
              selected ? Icons.check_rounded : Icons.chevron_right_rounded,
              color: selected
                ? (isAmber ? AppColors.ink : Colors.white)
                : AppColors.dim,
              size: 20))),
        ])));
  }

  static final List<_Option> _options = [
    _Option(id: 'upcoming_interview', accent: AppColors.red,
      icon: Icons.event_rounded,
      title: 'UPCOMING INTERVIEW',
      subtitle: 'I have a job interview scheduled'),
    _Option(id: 'general_preparation', accent: AppColors.blue,
      icon: Icons.trending_up_rounded,
      title: 'GENERAL PREPARATION',
      subtitle: 'I want to be ready for future roles'),
    _Option(id: 'communication_skills', accent: AppColors.amber,
      icon: Icons.record_voice_over_rounded,
      title: 'COMMUNICATION SKILLS',
      subtitle: 'I want to improve how I speak'),
    _Option(id: 'career_change', accent: AppColors.ink,
      icon: Icons.swap_horiz_rounded,
      title: 'CAREER TRANSITION',
      subtitle: 'I am switching to a new field'),
  ];
}

class _Option {
  final String id, title, subtitle;
  final Color accent;
  final IconData icon;
  const _Option({
    required this.id, required this.title, required this.subtitle,
    required this.accent, required this.icon});
}
