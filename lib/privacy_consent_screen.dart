import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:camera/camera.dart';
import 'app_theme.dart';
import 'auth_screen.dart';
import 'privacy_rights_screen.dart';

/// Sits between purpose selection and sign-in - after onboarding, before
/// the person ever taps "Continue with Google". Explains that ITSAGO
/// records camera video and microphone audio during practice interviews,
/// what that's used for, and their POPIA rights, then requires an
/// explicit tap to agree before sign-in is reachable.
class PrivacyConsentScreen extends StatefulWidget {
  final List<CameraDescription> cameras;
  final String selectedPurpose;
  const PrivacyConsentScreen({
    super.key,
    required this.cameras,
    required this.selectedPurpose,
  });

  @override
  State<PrivacyConsentScreen> createState() => _PrivacyConsentScreenState();
}

class _PrivacyConsentScreenState extends State<PrivacyConsentScreen>
    with TickerProviderStateMixin {

  bool _accepted = false;

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
  void dispose() { _entryCtrl.dispose(); super.dispose(); }

  void _continue() {
    if (!_accepted) return;
    Navigator.of(context).push(PageRouteBuilder(
      pageBuilder: (_, __, ___) => AuthScreen(
        cameras: widget.cameras, selectedPurpose: widget.selectedPurpose),
      transitionsBuilder: (_, a, __, child) => SlideTransition(
        position: Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero)
            .animate(CurvedAnimation(parent: a, curve: Curves.easeOut)),
        child: child),
      transitionDuration: const Duration(milliseconds: 500)));
  }

  void _decline() {
    showDialog(context: context, builder: (_) => Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        decoration: AppDecorations.dialog,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: double.infinity, color: AppColors.ink,
            padding: const EdgeInsets.all(16),
            child: Text('CAMERA & MIC REQUIRED', style: AppText.title.copyWith(
              color: Colors.white, letterSpacing: 1.2))),
          Padding(padding: const EdgeInsets.all(20), child: Column(children: [
            Text(
              'ITSAGO can\'t run mock interviews without access to your '
              'camera and microphone - that\'s the whole feature. If '
              'you\'re not comfortable with that, you can close the app now.',
              style: AppText.body.copyWith(height: 1.5),
              textAlign: TextAlign.center),
            const SizedBox(height: 18),
            Row(children: [
              Expanded(child: GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(height: 46,
                  decoration: const BoxDecoration(
                    color: AppColors.white, border: AppBorders.ink2),
                  child: Center(child: Text('GO BACK',
                    style: AppText.button.copyWith(color: AppColors.ink)))))),
              const SizedBox(width: 10),
              Expanded(child: GestureDetector(
                onTap: () => SystemNavigator.pop(),
                child: Container(height: 46,
                  decoration: const BoxDecoration(
                    color: AppColors.ink, border: AppBorders.ink2),
                  child: Center(child: Text('CLOSE APP',
                    style: AppText.button.copyWith(color: Colors.white)))))),
            ]),
          ])),
        ]))));
  }

  // Matches the bordered-icon-square "feature point" pattern already
  // used across the app's paywall dialogs (interview_mode_screen.dart,
  // job_specific_setup_screen.dart).
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
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: AppColors.cream,
        body: SafeArea(child: Column(children: [
          AppWidgets.header(
            title:       'PRIVACY & CONSENT',
            context:     context,
            accentColor: AppColors.blue),

          Expanded(child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

              FadeTransition(opacity: _fade(0.0, 0.5),
                child: SlideTransition(position: _slide(0.0, 0.5),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    AppWidgets.sectionLabel('BEFORE WE CONTINUE', accent: AppColors.blue),
                    const SizedBox(height: 10),
                    Text('One quick thing\nbefore you sign in',
                      style: AppText.headline),
                    const SizedBox(height: 6),
                    Text('ITSAGO uses your camera and microphone to run '
                      'practice interviews. Here\'s exactly what that means.',
                      style: AppText.caption.copyWith(height: 1.5)),
                  ]))),

              const SizedBox(height: 22),

              FadeTransition(opacity: _fade(0.15, 0.6),
                child: SlideTransition(position: _slide(0.15, 0.6),
                  child: Container(
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
                        'Settings, or email support@itsago.co.za - we reply '
                        'within 72 hours.'),
                    ]))))
              ,
              const SizedBox(height: 14),

              FadeTransition(opacity: _fade(0.25, 0.65),
                child: SlideTransition(position: _slide(0.25, 0.65),
                  child: GestureDetector(
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => const PrivacyRightsScreen())),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
                      decoration: BoxDecoration(color: AppColors.white,
                        border: Border.all(color: AppColors.mist, width: 1.5)),
                      child: Row(children: [
                        const Icon(Icons.description_rounded, color: AppColors.blue, size: 15),
                        const SizedBox(width: 10),
                        Expanded(child: Text('READ THE FULL PRIVACY POLICY',
                          style: AppText.label.copyWith(color: AppColors.blue, fontSize: 9))),
                        const Icon(Icons.chevron_right_rounded, color: AppColors.dim, size: 18),
                      ]))))),

              const SizedBox(height: 20),

              FadeTransition(opacity: _fade(0.3, 0.7),
                child: SlideTransition(position: _slide(0.3, 0.7),
                  child: GestureDetector(
                    onTap: () => setState(() => _accepted = !_accepted),
                    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Container(width: 24, height: 24,
                        margin: const EdgeInsets.only(top: 2),
                        decoration: BoxDecoration(
                          color: _accepted ? AppColors.ink : AppColors.white,
                          border: Border.all(color: AppColors.ink, width: 2)),
                        child: _accepted
                          ? const Icon(Icons.check_rounded, color: Colors.white, size: 16)
                          : null),
                      const SizedBox(width: 12),
                      Expanded(child: Text(
                        'I understand and agree that ITSAGO will access my '
                        'camera and microphone, and process my speech via '
                        'Google Cloud, as described above.',
                        style: AppText.body.copyWith(height: 1.45))),
                    ])))),

              const SizedBox(height: 20),
            ]))),

          // Bottom nav - matches OnboardingScreen/PurposeSelectionScreen exactly
          Container(
            color: AppColors.white,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
            child: Column(children: [
              Container(height: 1.5, color: AppColors.mist),
              const SizedBox(height: 14),
              GestureDetector(
                onTap: _accepted ? _continue : null,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: double.infinity, height: 56,
                  decoration: BoxDecoration(
                    color: _accepted ? AppColors.ink : AppColors.dim,
                    border: AppBorders.ink2,
                    boxShadow: _accepted ? const [AppShadows.hard4] : null),
                  child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Text('AGREE & CONTINUE',
                      style: AppText.button.copyWith(letterSpacing: 1.8)),
                    const SizedBox(width: 10),
                    const Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 18),
                  ]))),
              const SizedBox(height: 10),
              GestureDetector(
                onTap: _decline,
                child: Padding(padding: const EdgeInsets.all(6),
                  child: Text('I don\'t agree',
                    style: AppText.caption.copyWith(
                      color: AppColors.dim,
                      decoration: TextDecoration.underline)))),
            ])),
        ])),
      ));
  }
}
