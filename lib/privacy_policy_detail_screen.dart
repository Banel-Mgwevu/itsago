import 'package:flutter/material.dart';
import 'app_theme.dart';
import 'privacy_rights_screen.dart';

/// Read-only detail screen explaining what ITSAGO's camera, microphone,
/// and AI processing involve. Reached by tapping "View Privacy Policy"
/// next to the consent checkbox on AuthScreen - not a mandatory gate
/// itself. Agreement happens via that checkbox; this screen just lets
/// anyone who wants the detail read it before ticking it.
class PrivacyPolicyDetailScreen extends StatelessWidget {
  const PrivacyPolicyDetailScreen({super.key});

  Widget _point(IconData icon, Color accent, String title, String sub) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(width: 32, height: 32,
        decoration: BoxDecoration(color: accent.withOpacity(0.1),
          border: Border.all(color: accent, width: 1)),
        child: Icon(icon, color: accent, size: 16)),
      const SizedBox(width: 12),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: const TextStyle(fontSize: 12.5,
          fontWeight: FontWeight.w800, color: AppColors.ink)),
        const SizedBox(height: 2),
        Text(sub, style: TextStyle(fontSize: 10.5, color: AppColors.dim, height: 1.4)),
      ])),
    ]));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.cream,
      body: SafeArea(child: Column(children: [
        AppWidgets.header(
          title:       'PRIVACY POLICY',
          context:     context,
          leading:     AppWidgets.backButton(context),
          accentColor: AppColors.blue),

        Expanded(child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 32),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

            AppWidgets.sectionLabel('WHAT WE COLLECT', accent: AppColors.blue),
            const SizedBox(height: 10),
            Text('Camera, microphone\n& your data',
              style: AppText.headline),
            const SizedBox(height: 6),
            Text('ITSAGO uses your camera and microphone to run practice '
              'interviews. Here\'s exactly what that means.',
              style: AppText.caption.copyWith(height: 1.5)),

            const SizedBox(height: 22),

            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.white,
                border: Border.all(color: AppColors.ink, width: 2),
                boxShadow: const [AppShadows.hard4]),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                _point(Icons.videocam_rounded, AppColors.red,
                  'Camera video',
                  'Used live to check you\'re framed in shot and check '
                  'eye contact during practice answers. Processed on '
                  'your device - full video isn\'t uploaded or stored.'),
                _point(Icons.mic_rounded, AppColors.blue,
                  'Microphone audio',
                  'Your spoken answers are sent to Google Cloud for '
                  'speech-to-text, so we can score your answer. '
                  'Recordings are deleted after transcription.'),
                _point(Icons.smart_toy_rounded, AppColors.amber,
                  'AI scoring',
                  'Your transcript (text only, never video or audio) '
                  'goes to Google\'s Gemini AI to score answers and '
                  'generate coaching feedback.'),
                _point(Icons.gpp_good_rounded, AppColors.ink,
                  'Your POPIA rights',
                  'Access, correct or delete your data anytime from '
                  'Settings (Manage my data), or email support@itsago.app - '
                  'we reply within 72 hours.'),
                _point(Icons.badge_rounded, AppColors.red,
                  'Your profile',
                  'When you sign up, we ask a few optional questions - '
                  'province, employment status, age, education and target '
                  'industry - to tailor your practice questions and '
                  'pre-fill your CV. You can skip any of it, and it\'s '
                  'never shared outside ITSAGO.'),
              ])),

            const SizedBox(height: 14),

            GestureDetector(
              onTap: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => const PrivacyRightsScreen())),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
                decoration: BoxDecoration(color: AppColors.white,
                  border: Border.all(color: AppColors.mist, width: 1.5)),
                child: Row(children: [
                  const Icon(Icons.gpp_good_outlined, color: AppColors.blue, size: 15),
                  const SizedBox(width: 10),
                  Expanded(child: Text('MANAGE MY DATA & POPIA RIGHTS',
                    style: AppText.label.copyWith(color: AppColors.blue, fontSize: 9))),
                  const Icon(Icons.chevron_right_rounded, color: AppColors.dim, size: 18),
                ]))),

            const SizedBox(height: 28),

            AppWidgets.sectionLabel('OTHER FEATURES', accent: AppColors.red),
            const SizedBox(height: 10),
            Text('Sign-in, CV Builder\n& AI Coach',
              style: AppText.headline),
            const SizedBox(height: 6),
            Text('These features also use your data - here\'s how.',
              style: AppText.caption.copyWith(height: 1.5)),

            const SizedBox(height: 22),

            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.white,
                border: Border.all(color: AppColors.ink, width: 2),
                boxShadow: const [AppShadows.hard4]),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                _point(Icons.login_rounded, AppColors.blue,
                  'Signing in',
                  'When you sign in with Google, Microsoft or Apple, we '
                  'receive your name and email address (and profile photo, '
                  'if the provider shares it) to create and identify your '
                  'account. With Apple you can choose to hide your email.'),
                _point(Icons.description_rounded, AppColors.red,
                  'CV Builder',
                  'CVs you upload to Revamp are processed by AI and stored '
                  'securely so you can download them again. CVs you build '
                  'yourself stay on your phone. Either way, your CV is only '
                  'used to create your CV - never shared or used to train '
                  'AI models.'),
                _point(Icons.chat_bubble_rounded, AppColors.amber,
                  'AI Coach chat',
                  'Messages you send the AI Coach are sent to Google\'s '
                  'Gemini AI to generate a reply. Your chat history is saved '
                  'on your phone so you can pick up later - tap New chat to '
                  'clear it.'),
              ])),

            const SizedBox(height: 28),

            AppWidgets.sectionLabel('BEHIND THE SCENES', accent: AppColors.amber),
            const SizedBox(height: 10),
            Text('Payments, analytics\n& how AI handles data',
              style: AppText.headline),
            const SizedBox(height: 6),
            Text('The services that keep ITSAGO running, and what they see.',
              style: AppText.caption.copyWith(height: 1.5)),

            const SizedBox(height: 22),

            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.white,
                border: Border.all(color: AppColors.ink, width: 2),
                boxShadow: const [AppShadows.hard4]),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                _point(Icons.memory_rounded, AppColors.amber,
                  'How Google\'s AI handles your data',
                  'Text sent to Google\'s Gemini AI may be temporarily '
                  'cached by Google for up to 24 hours to make responses '
                  'faster. It is encrypted, kept separate from other '
                  'customers, and never used to train Google\'s AI models.'),
                _point(Icons.insights_rounded, AppColors.blue,
                  'App analytics',
                  'We use Firebase Analytics to understand how the app is '
                  'used - for example, when a CV is built or an interview '
                  'is completed. We never send your answers, CV content, '
                  'name or email to analytics.'),
                _point(Icons.bug_report_rounded, AppColors.red,
                  'Crash reports',
                  'If the app crashes, Firebase Crashlytics sends us a '
                  'technical report (such as phone model, OS version and '
                  'where the error happened) so we can fix it.'),
                _point(Icons.payments_rounded, AppColors.ink,
                  'Payments',
                  'Subscriptions are paid through Google Play or the App '
                  'Store. We never see your card details - we only receive '
                  'confirmation of your subscription and when it renews.'),
                _point(Icons.groups_rounded, AppColors.blue,
                  'Sponsored access',
                  'If a university, employer or sponsor gives you free '
                  'access with a code, we share only totals with them '
                  '(for example, how many people used it) - never your '
                  'name, answers or CV.'),
                _point(Icons.public_rounded, AppColors.amber,
                  'Where your data is stored',
                  'We use Google Cloud and Firebase, which may store and '
                  'process data on servers outside South Africa, with '
                  'safeguards in place as POPIA requires.'),
              ])),
          ]))),
      ])));
  }
}
