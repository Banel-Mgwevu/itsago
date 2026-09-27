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
                    Text('AUGUST 2026 · v4.0',
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
                    Text('Data, privacy or account deletion requests, and general support:',
                      style: AppText.body),
                    const SizedBox(height: 12),
                    Container(padding: const EdgeInsets.all(12),
                      color: AppColors.cream,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                        _link('📧', 'banele.mgwevu@itsago.app'),
                        const SizedBox(height: 6),
                        _link('🌐', 'www.itsago.ai'),
                        const SizedBox(height: 6),
                        _link('🔒', 'www.itsago.ai/privacy'),
                        const SizedBox(height: 6),
                        _link('⚖️', 'www.itsago.ai/terms'),
                      ])),
                    const SizedBox(height: 10),
                    Text('To cancel a paid subscription, use your Google Play or App Store '
                      'subscription settings directly - this keeps cancellation in your '
                      'control at all times. Email us if you need help finding it.',
                      style: AppText.caption.copyWith(height: 1.5)),
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
                  Text('POPIA (South Africa)',
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
      'title': 'GOOGLE & MICROSOFT SIGN-IN',
      'body':  'We use Google Sign-In or Microsoft Sign-In (your choice) for authentication via Firebase Auth. By signing in you authorise us to access your basic profile (name, email, profile photo) from your chosen provider to create and manage your ITSAGO account. You are responsible for maintaining the security of your account.',
      'color': AppColors.ink,
    },
    {
      'title': 'CAMERA & MICROPHONE ACCESS',
      'body':  'ITSAGO requires access to your device camera and microphone during mock interview sessions. Camera video is analysed on your device for eye contact and face detection - full video is not uploaded. Your spoken answers ARE sent to Google Cloud for speech-to-text transcription so we can score your answer; audio recordings are deleted after transcription completes.',
      'color': AppColors.red,
    },
    {
      'title': 'GOOGLE CALENDAR INTEGRATION',
      'body':  'The AI Coach can optionally connect to your Google Calendar (read-only access) to identify upcoming interviews by scanning event titles for interview-related keywords. Only the title and date of matching events - never the location, attendees, or description - is shared with Google\'s Gemini AI to help the coach give timely, relevant advice. Calendar data is not stored on our servers beyond your active session. You may revoke calendar access at any time through your Google account settings.',
      'color': AppColors.amber,
    },
    {
      'title': 'CV UPLOAD & PROCESSING',
      'body':  'When you use the ATS CV Builder, your CV is uploaded and processed by Google\'s Gemini AI to generate optimised CV designs. Unlike a one-time processing tool, ITSAGO stores your CVs and generated designs in your account (the CV Library) so you can access them again later. You may delete any stored CV at any time. We do not sell or share your CV with third parties. You confirm any CV you upload belongs to you.',
      'color': AppColors.blue,
    },
    {
      'title': 'AI PROCESSING & THIRD PARTIES',
      'body':  'ITSAGO uses the following third-party services to deliver its features: Google Gemini (interview scoring, coaching feedback, CV optimisation, question generation), Google Cloud (speech-to-text transcription, text-to-speech voice output), and Google Firebase (authentication, data storage, Cloud Functions). By using ITSAGO you consent to data being processed by these services in accordance with their respective privacy policies.',
      'color': AppColors.amber,
    },
    {
      'title': 'USER DATA & PRIVACY',
      'body':  'We collect interview session results, CV data, profile answers (province, employment status, education, and similar), and usage analytics to provide personalised coaching. We never sell your personal information. Interview transcripts, scores, and CVs are stored securely in Firebase under your account. You may request full deletion of your data at any time through the My Data & Privacy section of the app.',
      'color': AppColors.ink,
    },
    {
      'title': 'PUSH NOTIFICATIONS',
      'body':  'ITSAGO sends push notifications for interview reminders, daily motivation, practice nudges, and coaching tips. You may disable notifications at any time in your device settings. Disabling notifications will not affect your ability to use the app.',
      'color': AppColors.blue,
    },
    {
      'title': 'DATA RETENTION & DELETION',
      'body':  'CVs, interview sessions, and profile data are retained for as long as your account is active. You may delete your account and all associated data at any time via My Data & Privacy, or by emailing banele.mgwevu@itsago.app. Upon a deletion request, all personal data including CVs, sessions, and scores will be permanently removed within 30 days in compliance with POPIA.',
      'color': AppColors.amber,
    },
    {
      'title': 'ACCEPTABLE USE',
      'body':  'You agree not to: use ITSAGO for any unlawful purpose; upload a CV or content that is not your own or that infringes someone else\'s rights; attempt to reverse-engineer, scrape, or extract the underlying AI models or system prompts; use automated tools (bots) to interact with the service; interfere with or disrupt the service or its servers; or attempt to bypass usage limits or subscription requirements. Violation may result in suspension or termination of your account without refund.',
      'color': AppColors.red,
    },
    {
      'title': 'LICENSE TO YOUR CONTENT',
      'body':  'You retain ownership of any CV, answer, or content you provide. By using ITSAGO, you grant us a limited licence to process, store, and display that content solely to provide the service to you (e.g. generating your CV designs, scoring your answers, showing your session history). This licence ends when you delete the content or your account, except where we are required to retain data by law.',
      'color': AppColors.blue,
    },
    {
      'title': 'ACCOUNT SUSPENSION & TERMINATION',
      'body':  'We may suspend or terminate your account if you violate these Terms, engage in fraudulent or abusive behaviour, or if required by law. Where reasonably possible, we will notify you first. If your account is terminated for cause, any active subscription may be cancelled without refund for the remaining period. You may also close your own account at any time.',
      'color': AppColors.ink,
    },
    {
      'title': 'SERVICE AVAILABILITY',
      'body':  'ITSAGO depends on third-party services (including Google Gemini and Google Cloud) to function. We do not guarantee uninterrupted availability and are not liable for outages, delays, or errors caused by these third-party providers or other events outside our reasonable control (including load-shedding, network outages, or force majeure events).',
      'color': AppColors.amber,
    },
    {
      'title': 'INDEMNIFICATION',
      'body':  '[REQUIRES LEGAL REVIEW - standard protective clause, wording below is a starting point] You agree to indemnify and hold ITSAGO harmless from any claims, damages, or expenses arising from your misuse of the service, your violation of these Terms, or content you upload that infringes the rights of a third party.',
      'color': AppColors.red,
    },
    {
      'title': 'INTELLECTUAL PROPERTY',
      'body':  'All ITSAGO content, AI models, CV designs, branding, and functionality are the intellectual property of ITSAGO. You may not copy, reverse-engineer, resell or redistribute any part of the service. Generated CVs and interview feedback belong to the user who created them.',
      'color': AppColors.ink,
    },
    {
      'title': 'SUBSCRIPTIONS & PAYMENTS',
      'body':  '[TO CONFIRM WITH LEGAL/BILLING BEFORE PUBLISHING] Certain features (including video mock interviews) require an active paid subscription. Subscriptions are billed [monthly, at R__/month] via [Google Play / Apple App Store]. You may cancel at any time; cancellation takes effect at the end of the current billing period, and no partial refunds are given for unused time within a period, except where required by law. Some features (such as Premium CV Templates) are available as a one-time purchase that does not expire. Prices may change with reasonable prior notice.',
      'color': AppColors.red,
    },
    {
      'title': 'DISCLAIMER & LIMITATION OF LIABILITY',
      'body':  '[REQUIRES LEGAL REVIEW - liability cap and specific wording below are placeholders, not final] ITSAGO is provided "as is" without warranties of any kind. We do not guarantee specific interview outcomes, job offers, or CV success rates. Our AI feedback is intended as coaching guidance only, not professional career advice. Our total liability shall not exceed the amount paid by you in the preceding 12 months.',
      'color': AppColors.blue,
    },
    {
      'title': 'GOVERNING LAW',
      'body':  '[REQUIRES LEGAL REVIEW - jurisdiction below is a placeholder] These Terms are governed by the laws of the Republic of South Africa. ITSAGO complies with the Protection of Personal Information Act (POPIA).',
      'color': AppColors.amber,
    },
    {
      'title': 'GENERAL PROVISIONS',
      'body':  'If any part of these Terms is found unenforceable, the rest remains in full effect. These Terms are the entire agreement between you and ITSAGO regarding the service. Our failure to enforce any provision is not a waiver of our right to do so later. We may assign these Terms in connection with a merger, acquisition, or sale of assets; you may not assign your rights under these Terms without our consent.',
      'color': AppColors.blue,
    },
    {
      'title': 'CHANGES TO TERMS',
      'body':  'We may update these Terms at any time. Material changes - including changes to pricing or which features require a subscription - will be communicated through an in-app notice at least 7 days before taking effect. Continued use of ITSAGO after changes constitutes your acceptance of the updated Terms. The current version is always available within the app.',
      'color': AppColors.ink,
    },
  ];
}
