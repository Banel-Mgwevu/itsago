import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'app_theme.dart';

class TermsScreen extends StatefulWidget {
  final List<CameraDescription> cameras;
  const TermsScreen({super.key, required this.cameras});
  @override
  State<TermsScreen> createState() => _TermsScreenState();
}

class _TermsScreenState extends State<TermsScreen>
    with TickerProviderStateMixin {

  late final AnimationController _entryCtrl = AnimationController(
    vsync: this, duration: const Duration(milliseconds: 600))..forward();

  @override
  void dispose() { _entryCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.cream,
      body: SafeArea(child: Column(children: [

        AppWidgets.header(
          title:   'TERMS & CONDITIONS',
          context: context,
          leading: AppWidgets.backButton(context)),

        Expanded(child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [

            // Intro banner
            Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                color: AppColors.ink,
                boxShadow: [AppShadows.hard5]),
              child: Column(children: [
                Container(height: 4, color: AppColors.amber),
                Padding(padding: const EdgeInsets.all(16),
                  child: Row(children: [
                  Container(width: 44, height: 44,
                    decoration: const BoxDecoration(
                      color: AppColors.amber, border: AppBorders.ink2),
                    child: const Icon(Icons.description_rounded,
                      color: AppColors.ink, size: 20)),
                  const SizedBox(width: 14),
                  Expanded(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                    Text('LAST UPDATED',
                      style: AppText.label.copyWith(
                        color: AppColors.amber)),
                    Text('MAY 2025 · v3.0',
                      style: AppText.body.copyWith(color: Colors.white)),
                  ])),
                ])),
              ])),

            const SizedBox(height: 20),

            // Term sections
            ..._terms.asMap().entries.map((e) {
              final s = e.value;
              return Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: _termCard(
                  title:  s['title'] as String,
                  body:   s['body']  as String,
                  accent: s['color'] as Color));
            }),

            const SizedBox(height: 8),

            // Contact block
            Container(
              decoration: AppDecorations.card,
              child: Column(children: [
                Container(width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  color: AppColors.amber,
                  child: Row(children: [
                    Container(width: 36, height: 36,
                      color: AppColors.ink,
                      child: const Icon(Icons.contact_support_rounded,
                        color: AppColors.amber, size: 18)),
                    const SizedBox(width: 12),
                    Text('CONTACT & SUPPORT',
                      style: AppText.title.copyWith(
                        color: AppColors.ink, letterSpacing: 1.5)),
                  ])),
                Padding(padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                    Text('For questions, privacy requests, or legal enquiries:',
                      style: AppText.body),
                    const SizedBox(height: 12),
                    Container(padding: const EdgeInsets.all(12),
                      color: AppColors.cream,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                        _link('📧', 'support@itsago.ai'),
                        const SizedBox(height: 6),
                        _link('🌐', 'www.itsago.ai'),
                        const SizedBox(height: 6),
                        _link('🔒', 'www.itsago.ai/privacy'),
                        const SizedBox(height: 6),
                        _link('⚖️', 'www.itsago.ai/terms'),
                      ])),
                  ])),
              ])),

            const SizedBox(height: 16),

            // Compliance badge
            Container(
              width: double.infinity, padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: AppColors.amber,
                border: AppBorders.ink2,
                boxShadow: [AppShadows.hard4]),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                const Icon(Icons.verified_user_rounded,
                  color: AppColors.ink, size: 20),
                const SizedBox(width: 10),
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('COMPLIANCE',
                    style: AppText.label.copyWith(color: AppColors.ink)),
                  Text('GDPR · POPIA · CCPA · SOC 2',
                    style: AppText.caption.copyWith(
                      color: AppColors.ink,
                      fontWeight: FontWeight.w900)),
                ]),
              ])),
          ]))),
      ])));
  }

  Widget _termCard({
    required String title,
    required String body,
    required Color accent,
  }) {
    final isAmber = accent == AppColors.amber;
    return Container(
      decoration: AppDecorations.cardSmall,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          color: accent,
          child: Text(title.toUpperCase(),
            style: AppText.label.copyWith(
              color: isAmber ? AppColors.ink : Colors.white,
              fontSize: 10))),
        Padding(padding: const EdgeInsets.all(14),
          child: Text(body, style: AppText.body)),
      ]));
  }

  Widget _link(String emoji, String text) => Row(children: [
    Text(emoji, style: const TextStyle(fontSize: 13)),
    const SizedBox(width: 8),
    Text(text, style: AppText.body.copyWith(
      color: AppColors.blue, fontWeight: FontWeight.w900)),
  ]);

  // ── Content ────────────────────────────────────────────
  static const _terms = [
    {
      'title': 'ACCEPTANCE OF TERMS',
      'body':  'By downloading, installing or using ITSAGO, you agree to be bound by these Terms and Conditions. If you do not agree, please uninstall the app and discontinue use immediately. These terms apply to all users of the ITSAGO AI platform.',
      'color': AppColors.red,
    },
    {
      'title': 'SERVICE DESCRIPTION',
      'body':  'ITSAGO is an AI-powered career preparation platform providing: AI mock interview sessions with real-time scoring, an AI career coach, an ATS CV Builder that rewrites and redesigns your CV, eye contact and filler word tracking, confidence scoring, and push notification reminders. Features may change or be updated at any time.',
      'color': AppColors.blue,
    },
    {
      'title': 'ELIGIBILITY & AGE REQUIREMENT',
      'body':  'You must be at least 16 years of age to use ITSAGO. Users under 18 must have parental or guardian consent. By using the app you confirm you meet this requirement. ITSAGO reserves the right to terminate accounts found to be in violation of this policy.',
      'color': AppColors.amber,
    },
    {
      'title': 'GOOGLE SIGN-IN & ACCOUNT',
      'body':  'We use Google Sign-In for authentication via Firebase Auth. By signing in you authorise us to access your basic Google profile (name, email, profile photo) to create and manage your ITSAGO account. You are responsible for maintaining the security of your account.',
      'color': AppColors.ink,
    },
    {
      'title': 'CAMERA & MICROPHONE ACCESS',
      'body':  'ITSAGO requires access to your device camera and microphone during mock interview sessions. Camera is used for eye contact tracking and face detection. Microphone is used for speech-to-text transcription and filler word detection. This data is processed locally and is not transmitted or stored without your knowledge.',
      'color': AppColors.red,
    },
    {
      'title': 'CV UPLOAD & PROCESSING',
      'body':  'When you use the ATS CV Builder, your CV is uploaded and processed by ITSAGO AI (powered by Anthropic Claude). Your CV data is used solely to generate optimised CV designs. We do not store, sell or share your CV with third parties. CV data is discarded after processing. You confirm any CV you upload belongs to you.',
      'color': AppColors.blue,
    },
    {
      'title': 'AI PROCESSING & THIRD PARTIES',
      'body':  'ITSAGO uses the following third-party AI and cloud services to deliver its features: Anthropic Claude (interview coaching, CV optimisation, feedback generation), Microsoft Azure (text-to-speech voice output), Google Firebase (authentication, data storage), and Google ML Kit (face and eye detection). By using ITSAGO you consent to data being processed by these services in accordance with their respective privacy policies.',
      'color': AppColors.amber,
    },
    {
      'title': 'USER DATA & PRIVACY',
      'body':  'We collect interview session results, CV data, and usage analytics to provide personalised coaching. We never sell your personal information. Interview transcripts and scores are stored securely in Firebase under your account. You may request full deletion of your data at any time through the My Data & Privacy section of the app.',
      'color': AppColors.ink,
    },
    {
      'title': 'CALENDAR INTEGRATION',
      'body':  'The AI Coach feature may request access to your Google Calendar to identify upcoming interview dates and provide timely coaching. We only read interview-relevant events. Calendar data is never stored on our servers or shared with third parties. You may revoke calendar access at any time through your Google account settings.',
      'color': AppColors.red,
    },
    {
      'title': 'PUSH NOTIFICATIONS',
      'body':  'ITSAGO sends push notifications for interview reminders, daily motivation, practice nudges, and coaching tips. You may disable notifications at any time in your device settings. Disabling notifications will not affect your ability to use the app.',
      'color': AppColors.blue,
    },
    {
      'title': 'DATA RETENTION & DELETION',
      'body':  'Interview sessions and CV records are retained for up to 30 days. You may delete your account and all associated data at any time via My Data & Privacy. Upon deletion, all personal data including CVs, sessions, and scores will be permanently removed within 30 days in compliance with POPIA.',
      'color': AppColors.amber,
    },
    {
      'title': 'INTELLECTUAL PROPERTY',
      'body':  'All ITSAGO content, AI models, CV designs, branding, and functionality are the intellectual property of ITSAGO AI Systems. You may not copy, reverse-engineer, resell or redistribute any part of the service. Generated CVs and interview feedback belong to the user who created them.',
      'color': AppColors.ink,
    },
    {
      'title': 'FREE SERVICE & FAIR USE',
      'body':  'ITSAGO is currently free to use. We reserve the right to introduce paid tiers, usage limits, or premium features in future. We may impose reasonable usage limits (such as CV upload limits) to ensure fair access for all users. Abuse of the free service may result in account suspension.',
      'color': AppColors.red,
    },
    {
      'title': 'DISCLAIMER & LIMITATION OF LIABILITY',
      'body':  'ITSAGO is provided "as is" without warranties of any kind. We do not guarantee specific interview outcomes, job offers, or CV success rates. Our AI feedback is intended as coaching guidance only, not professional career advice. Our total liability shall not exceed ZAR 500 or the amount paid by you in the preceding 12 months, whichever is greater.',
      'color': AppColors.blue,
    },
    {
      'title': 'GOVERNING LAW',
      'body':  'These Terms are governed by the laws of the Republic of South Africa. Any disputes shall be resolved in the courts of the Western Cape, South Africa. ITSAGO complies with the Protection of Personal Information Act (POPIA), the General Data Protection Regulation (GDPR), and the California Consumer Privacy Act (CCPA).',
      'color': AppColors.amber,
    },
    {
      'title': 'CHANGES TO TERMS',
      'body':  'We may update these Terms at any time. Material changes will be communicated through an in-app notice at least 7 days before taking effect. Continued use of ITSAGO after changes constitutes your acceptance of the updated Terms. The current version is always available within the app.',
      'color': AppColors.ink,
    },
  ];
}
