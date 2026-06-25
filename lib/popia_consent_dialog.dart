import 'package:flutter/material.dart';
import 'app_theme.dart';
import 'cv_storage_service.dart';

/// Shows POPIA-compliant consent dialog before first CV save.
/// Returns true if user consented, false if declined.
Future<bool> showPOPIAConsentDialog(BuildContext context) async {
  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (dlg) => Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(16),
      child: Container(
        decoration: AppDecorations.dialog,
        child: Column(mainAxisSize: MainAxisSize.min, children: [

          // Header
          Container(
            width: double.infinity,
            color: AppColors.ink,
            child: Column(children: [
              Container(height: 4, color: AppColors.blue),
              Padding(padding: const EdgeInsets.all(14),
                child: Row(children: [
                  Container(width: 36, height: 36,
                    decoration: const BoxDecoration(
                      color: AppColors.blue, border: AppBorders.ink2),
                    child: const Icon(Icons.shield_rounded,
                      color: Colors.white, size: 18)),
                  const SizedBox(width: 12),
                  Column(crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                    Text('DATA CONSENT REQUIRED',
                      style: AppText.title.copyWith(
                        color: Colors.white, letterSpacing: 1)),
                    Text('POPIA — Protection of Personal Information Act',
                      style: AppText.caption.copyWith(
                        color: AppColors.amber, fontSize: 8)),
                  ]),
                ])),
            ])),

          // Content
          Flexible(child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [

              Text('Before we save your CV, we need your explicit consent.',
                style: AppText.body.copyWith(
                  fontWeight: FontWeight.w700, height: 1.4)),

              const SizedBox(height: 14),

              _section('WHAT WE STORE',
                'Your original CV file, the AI-optimised version, '
                'and ATS scores. We do NOT store your raw CV text '
                'in our database — only the files and scores.'),

              _section('WHY WE STORE IT',
                'So you can retrieve and re-download your CVs at any '
                'time without repeating the optimisation process.'),

              _section('HOW LONG WE KEEP IT',
                'All CV files are automatically deleted after 30 days. '
                'You can delete your data at any time from the CV Library.'),

              _section('THIRD-PARTY PROCESSORS',
                'Your CV content is sent to Anthropic (Claude AI) '
                'for optimisation and scoring. This is transient — '
                'Anthropic does not store your CV. '
                'See anthropic.com/privacy for their policy.'),

              _section('YOUR RIGHTS (POPIA s.23-24)',
                '• Access: view all stored CVs in the CV Library\n'
                '• Correction: re-run optimisation to update\n'
                '• Deletion: delete individual or all CVs anytime\n'
                '• Objection: decline consent below — no data is saved'),

              Container(
                padding: const EdgeInsets.all(10),
                color: AppColors.blue.withOpacity(0.06),
                child: Text(
                  'Responsible party: ITSAGO (Pty) Ltd\n'
                  'Processing basis: Explicit consent',
                  style: AppText.caption.copyWith(
                    color: AppColors.blue, height: 1.5))),
            ]))),

          // Actions
          Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Row(children: [
            Expanded(child: GestureDetector(
              onTap: () => Navigator.pop(dlg, false),
              child: Container(height: 46,
                decoration: BoxDecoration(
                  border: Border.all(
                    color: AppColors.mist, width: 1.5)),
                child: Center(child: Text('DECLINE',
                  style: AppText.label.copyWith(
                    color: AppColors.dim)))))),
            const SizedBox(width: 10),
            Expanded(flex: 2, child: GestureDetector(
              onTap: () async {
                await CVStorageService.recordConsent();
                Navigator.pop(dlg, true);
              },
              child: Container(height: 46,
                decoration: const BoxDecoration(
                  color: AppColors.blue, border: AppBorders.ink2,
                  boxShadow: [AppShadows.hard4]),
                child: Center(child: Text('I CONSENT & AGREE',
                  style: AppText.button))))),
          ])),
        ]))));
  return result ?? false;
}

Widget _section(String title, String body) => Padding(
  padding: const EdgeInsets.only(bottom: 12),
  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text(title, style: AppText.label.copyWith(
      fontSize: 9, color: AppColors.dim)),
    const SizedBox(height: 4),
    Text(body, style: AppText.caption.copyWith(height: 1.5)),
  ]));
