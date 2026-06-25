import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'app_theme.dart';

class AboutScreen extends StatefulWidget {
  final List<CameraDescription> cameras;
  const AboutScreen({super.key, required this.cameras});
  @override
  State<AboutScreen> createState() => _AboutScreenState();
}

class _AboutScreenState extends State<AboutScreen>
    with TickerProviderStateMixin {

  late final AnimationController _entryCtrl = AnimationController(
    vsync: this, duration: const Duration(milliseconds: 700))..forward();

  Animation<double> _fade(double a, double b) => Tween<double>(begin: 0, end: 1)
      .animate(CurvedAnimation(parent: _entryCtrl,
          curve: Interval(a, b, curve: Curves.easeOut)));
  Animation<Offset> _slide(double a, double b) =>
      Tween<Offset>(begin: const Offset(0, 0.04), end: Offset.zero)
          .animate(CurvedAnimation(parent: _entryCtrl,
              curve: Interval(a, b, curve: Curves.easeOut)));

  @override
  void dispose() { _entryCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.cream,
      body: SafeArea(child: Column(children: [

        AppWidgets.header(
          title:   'ABOUT ITSAGO',
          context: context,
          leading: AppWidgets.backButton(context)),

        Expanded(child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 40),
          child: AnimatedBuilder(
            animation: _entryCtrl,
            builder: (_, __) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [

              // ── Logo lockup ────────────────────────────
              FadeTransition(opacity: _fade(0.0, 0.5),
                child: SlideTransition(position: _slide(0.0, 0.5),
                  child: Center(child: Column(children: [
                    Container(width: 96, height: 96,
                      decoration: const BoxDecoration(
                        color: AppColors.white,
                        border: AppBorders.ink3,
                        boxShadow: [AppShadows.hard5]),
                      child: Stack(children: [
                        Positioned(bottom: 0, left: 0,
                          child: Container(width: 30, height: 30,
                            color: AppColors.amber)),
                        Positioned(top: 12, right: 12,
                          child: Container(width: 14, height: 14,
                            decoration: const BoxDecoration(
                              color: AppColors.red,
                              shape: BoxShape.circle))),
                        Positioned(top: 12, left: 12,
                          child: Container(width: 7, height: 7,
                            decoration: const BoxDecoration(
                              color: AppColors.blue,
                              shape: BoxShape.circle))),
                        Center(child: Text('I',
                          style: AppText.display.copyWith(fontSize: 40))),
                      ])),
                    const SizedBox(height: 16),
                    Text('ITSAGO',
                      style: AppText.display.copyWith(
                        letterSpacing: 5, fontSize: 32)),
                    const SizedBox(height: 8),
                    Row(mainAxisSize: MainAxisSize.min, children: [
                      Container(width: 28, height: 3, color: AppColors.red),
                      Container(width: 28, height: 3, color: AppColors.amber),
                      Container(width: 28, height: 3, color: AppColors.blue),
                    ]),
                    const SizedBox(height: 8),
                    Text('AI INTERVIEW PREP',
                      style: AppText.label.copyWith(color: AppColors.dim)),
                    const SizedBox(height: 6),
                    AppWidgets.badge('MADE IN SOUTH AFRICA 🇿🇦',
                      bg: AppColors.ink, fg: Colors.white),
                  ])))),

              const SizedBox(height: 32),

              // ── Info sections ──────────────────────────
              ..._sections.asMap().entries.map((e) {
                final i = e.key; final s = e.value;
                return FadeTransition(
                  opacity: _fade(0.1 + i * 0.08, 0.55 + i * 0.08),
                  child: SlideTransition(
                    position: _slide(0.1 + i * 0.08, 0.55 + i * 0.08),
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: AppWidgets.infoCard(
                        title:  s['title'] as String,
                        body:   s['body']  as String,
                        accent: s['color'] as Color,
                        icon:   s['icon']  as IconData))));
              }),

              const SizedBox(height: 8),

              // ── Contact card ───────────────────────────
              FadeTransition(opacity: _fade(0.6, 0.95),
                child: SlideTransition(position: _slide(0.6, 0.95),
                  child: Container(
                    decoration: AppDecorations.card,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                      Container(width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        color: AppColors.blue,
                        child: Row(children: [
                          Container(width: 36, height: 36,
                            color: AppColors.white,
                            child: const Icon(Icons.contact_support_rounded,
                              color: AppColors.blue, size: 18)),
                          const SizedBox(width: 12),
                          Text('GET IN TOUCH',
                            style: AppText.title.copyWith(
                              color: Colors.white, letterSpacing: 1.5)),
                        ])),
                      Padding(padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                          Text('Questions, feedback, or partnership enquiries?',
                            style: AppText.body),
                          const SizedBox(height: 14),
                          _contactRow(Icons.email_rounded,
                            'support@itsago.ai', AppColors.blue),
                          const SizedBox(height: 8),
                          _contactRow(Icons.language_rounded,
                            'www.itsago.app', AppColors.blue),
                        ])),
                    ])))),

              const SizedBox(height: 24),

              // ── Version footer ─────────────────────────
              FadeTransition(opacity: _fade(0.7, 1.0),
                child: Center(child: Column(children: [
                  Row(mainAxisSize: MainAxisSize.min, children: [
                    Container(width: 10, height: 10, color: AppColors.red),
                    const SizedBox(width: 4),
                    Container(width: 10, height: 10, color: AppColors.amber),
                    const SizedBox(width: 4),
                    Container(width: 10, height: 10, color: AppColors.blue),
                  ]),
                  const SizedBox(height: 10),
                  Text('VERSION 1.0.1',
                    style: AppText.label.copyWith(color: AppColors.dim)),
                  const SizedBox(height: 4),
                  Text('© 2025 ITSAGO AI SYSTEMS',
                    style: AppText.caption),
                ]))),
            ])))),
      ])));
  }

  Widget _contactRow(IconData icon, String text, Color color) =>
    Row(children: [
      Container(width: 32, height: 32,
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          border: Border.all(color: color.withOpacity(0.3), width: 1)),
        child: Icon(icon, size: 14, color: color)),
      const SizedBox(width: 10),
      Text(text, style: AppText.body.copyWith(
        color: color, fontWeight: FontWeight.w900)),
    ]);

  static const _sections = [
    {
      'title': 'OUR MISSION',
      'body':  'ITSAGO empowers every South African job seeker with the confidence and skills to succeed in any interview — from first job to boardroom.',
      'color': AppColors.blue,
      'icon':  Icons.rocket_launch_rounded,
    },
    {
      'title': 'AI TECHNOLOGY',
      'body':  'We combine Claude AI and Gemini to analyse your speech patterns, body language, and communication style — delivering coaching that adapts to you.',
      'color': AppColors.amber,
      'icon':  Icons.psychology_rounded,
    },
    {
      'title': 'KEY FEATURES',
      'body':  'Real-time video analysis · Body language coaching · AI-generated questions · ATS CV Builder with 4 professional designs · Google Calendar integration · Confidence scoring',
      'color': AppColors.red,
      'icon':  Icons.star_rounded,
    },
    {
      'title': 'PRIVACY FIRST',
      'body':  'Your interview sessions and CV data never leave your device without your permission. We follow POPIA guidelines and never sell your personal information.',
      'color': AppColors.ink,
      'icon':  Icons.shield_rounded,
    },
  ];
}
