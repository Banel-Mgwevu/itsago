import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:interviewai/splash_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'purchase_service.dart';
import 'app_theme.dart';
import 'cv_storage_service.dart';

class PrivacyRightsScreen extends StatefulWidget {
  const PrivacyRightsScreen({super.key});
  @override
  State<PrivacyRightsScreen> createState() => _PrivacyRightsScreenState();
}

class _PrivacyRightsScreenState extends State<PrivacyRightsScreen> {
  bool _loading = false;
  int  _cvCount = 0;

  @override
  void initState() { super.initState(); _loadStats(); }

  Future<void> _loadStats() async {
    final cvs = await CVStorageService.getCVs();
    if (mounted) setState(() => _cvCount = cvs.length);
  }

  Future<void> _deleteAllCVs() async {
    final confirm = await _dialog(
      title: 'DELETE ALL CVS', color: AppColors.red,
      message: 'Permanently removes all $_cvCount CVs and files from our servers.\n\nThis exercises your POPIA right to erasure and cannot be undone.',
      action: 'DELETE ALL CVS');
    if (confirm != true) return;
    setState(() => _loading = true);
    await CVStorageService.deleteAllCVs();
    await CVStorageService.revokeConsent();
    if (mounted) setState(() { _loading = false; _cvCount = 0; });
    if (mounted) _toast('All CVs deleted from our servers.');
  }

  Future<void> _deleteAccount() async {
    final confirm = await _dialog(
      title: 'DELETE MY ACCOUNT', color: AppColors.red,
      message: 'Permanently deletes:\n\n- All your CVs and files\n- Your interview sessions\n- Your progress data\n- Your account\n\nThis is irreversible.',
      action: 'DELETE EVERYTHING');
    if (confirm != true) return;
    setState(() => _loading = true);
    try {
      // Re-auth check - Firebase requires recent login for delete
      final authUser = FirebaseAuth.instance.currentUser;
      if (authUser == null) { setState(() => _loading = false); _toast('Not signed in.'); return; }
      final uid = authUser.uid;
      try {
        final googleSignIn = GoogleSignIn();
        final googleUser = await googleSignIn.signIn();
        if (googleUser == null) {
          setState(() => _loading = false);
          _toast('Re-authentication required to delete your account.');
          return;
        }
        final googleAuth = await googleUser.authentication;
        final credential = GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        );
        await authUser.reauthenticateWithCredential(credential);
      } catch (e) {
        setState(() => _loading = false);
        _toast('Please sign out and sign back in, then try deleting again.');
        return;
      }
      await authUser.delete();
      await CVStorageService.deleteAllCVs();
      final db = FirebaseFirestore.instance;
      final userDoc = db.collection('users').doc(uid);
      for (final sub in ['cvs','sessions','subscriptions','purchase_history']) {
        final snap = await userDoc.collection(sub).get();
        for (final doc in snap.docs) { await doc.reference.delete(); }
      }
      await userDoc.delete();
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
      await FirebaseAuth.instance.signOut();
      if (mounted) Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const SplashScreen()),
        (r) => false);
    } catch (e) {
      setState(() => _loading = false);
      _toast('Please sign out and sign back in, then try deleting again. Firebase requires recent login.');
    }
  }
  Future<void> _revokeConsent() async {
    final confirm = await _dialog(
      title: 'REVOKE CV CONSENT', color: AppColors.amber,
      message: 'Stops CV storage and deletes all existing CV data from our servers.\n\nYou can re-enable at any time.',
      action: 'REVOKE CONSENT');
    if (confirm != true) return;
    setState(() => _loading = true);
    await CVStorageService.revokeConsent();
    if (mounted) setState(() { _loading = false; _cvCount = 0; });
    if (mounted) _toast('Consent revoked. All CV data deleted.');
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? 'Not signed in';
    final shortUid = uid.length > 12 ? uid.substring(0, 12) + '...' : uid;
    return Scaffold(
      backgroundColor: AppColors.cream,
      body: SafeArea(child: Column(children: [
        Container(color: AppColors.ink,
          padding: const EdgeInsets.fromLTRB(16,16,16,16),
          child: Row(children: [
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(width: 38, height: 38,
                decoration: const BoxDecoration(
                  color: AppColors.white, border: AppBorders.ink2,
                  boxShadow: [AppShadows.hard3]),
                child: const Icon(Icons.arrow_back_rounded, color: AppColors.ink, size: 18))),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('MY DATA & PRIVACY', style: AppText.title.copyWith(color: Colors.white, letterSpacing: 1.5)),
              Text('POPIA rights - South Africa', style: AppText.caption.copyWith(color: AppColors.amber)),
            ])),
            Container(width: 6, height: 38, color: AppColors.amber),
          ])),
        if (_loading) const LinearProgressIndicator(color: AppColors.amber, backgroundColor: AppColors.mist),
        Expanded(child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(width: double.infinity, padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(color: AppColors.blue, border: AppBorders.ink2, boxShadow: [AppShadows.hard4]),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  const Icon(Icons.shield_rounded, color: Colors.white, size: 20),
                  const SizedBox(width: 10),
                  Text('YOUR POPIA RIGHTS', style: AppText.title.copyWith(color: Colors.white)),
                ]),
                const SizedBox(height: 10),
                Text('Under POPIA, you have the right to access, correct, and delete your personal data at any time.',
                  style: AppText.body.copyWith(color: Colors.white.withOpacity(0.85), height: 1.5, fontSize: 11)),
              ])),
            const SizedBox(height: 20),
            _sectionLabel('YOUR DATA'),
            const SizedBox(height: 10),
            GestureDetector(
              onTap: () => showDialog(context: context, builder: (_) => AlertDialog(
                title: const Text('Your User ID', style: TextStyle(fontWeight: FontWeight.w900)),
                content: SelectableText(uid, style: const TextStyle(fontSize: 12, fontFamily: 'monospace')),
                actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('CLOSE'))])),
              onLongPress: () {
                Clipboard.setData(ClipboardData(text: uid));
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                  content: Text('User ID copied to clipboard'),
                  duration: Duration(seconds: 2)));
              },
              child: _infoRow(Icons.fingerprint_rounded, 'User ID', shortUid + '  (tap to view, hold to copy)')),
            _infoRow(Icons.description_rounded,  'Saved CVs',      "$_cvCount CV${_cvCount == 1 ? '' : 's'} on our servers"),
            _infoRow(Icons.timer_rounded,         'Retention',      'Auto-deleted after 30 days'),
            _infoRow(Icons.storage_rounded,       'Data stored',    'Firebase (ZA region)'),
            _infoRow(Icons.people_outline_rounded,'Third parties',  'Anthropic Claude (transient only)'),
            const SizedBox(height: 24),
            _sectionLabel('EXERCISE YOUR RIGHTS'),
            const SizedBox(height: 10),
            _actionTile(
              icon: Icons.delete_outline_rounded,
              title: 'DELETE ALL MY CVS',
              sub: 'Permanently removes all $_cvCount CVs from our servers',
              color: AppColors.red,
              enabled: _cvCount > 0 && !_loading,
              onTap: _deleteAllCVs),
            const SizedBox(height: 10),
            _actionTile(
              icon: Icons.block_rounded,
              title: 'REVOKE CV STORAGE CONSENT',
              sub: 'Stops CV storage and deletes existing CV data',
              color: AppColors.amber,
              enabled: !_loading,
              onTap: _revokeConsent),
            const SizedBox(height: 10),
            _actionTile(
              icon: Icons.person_remove_rounded,
              title: 'DELETE MY ACCOUNT',
              sub: 'Permanently deletes your account and ALL data',
              color: AppColors.red,
              enabled: !_loading,
              onTap: _deleteAccount),
            const SizedBox(height: 24),
            _sectionLabel('LEGAL'),
            const SizedBox(height: 10),
            _legalRow('Responsible Party',  'ITSAGO (Pty) Ltd'),
            _legalRow('Processing Purpose', 'ATS CV optimisation'),
            _legalRow('Legal Basis',        'Legitimate interest + explicit consent'),
            _legalRow('Data Minimisation',  'Raw CV text never stored'),
            _legalRow('Contact',            'support@itsago.co.za'),
            const SizedBox(height: 20),
            Container(width: double.infinity, padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: AppColors.amber.withOpacity(0.08), border: Border.all(color: AppColors.amber, width: 1.5)),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Icon(Icons.info_outline_rounded, color: AppColors.amber, size: 16),
                const SizedBox(width: 10),
                Expanded(child: Text('To request a copy of your data or for privacy concerns, email support@itsago.co.za. We respond within 72 hours as required by POPIA.',
                  style: AppText.caption.copyWith(height: 1.5))),
              ])),
            const SizedBox(height: 20),
          ]))),
      ])));
  }

  Widget _sectionLabel(String t) => Row(children: [
    Container(width: 3, height: 14, color: AppColors.red),
    const SizedBox(width: 8),
    Text(t, style: AppText.label.copyWith(fontSize: 9, color: AppColors.dim, letterSpacing: 2)),
  ]);

  Widget _infoRow(IconData icon, String label, String val) =>
    Container(width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      margin: const EdgeInsets.only(bottom: 2),
      color: Colors.white,
      child: Row(children: [
        Icon(icon, size: 14, color: AppColors.blue),
        const SizedBox(width: 10),
        Expanded(child: Text(label, style: AppText.label.copyWith(fontSize: 10))),
        Text(val, style: AppText.caption.copyWith(color: AppColors.dim, fontSize: 9)),
      ]));

  Widget _legalRow(String label, String val) =>
    Container(width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      margin: const EdgeInsets.only(bottom: 2),
      color: Colors.white,
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(child: Text(label, style: AppText.label.copyWith(fontSize: 9, color: AppColors.dim))),
        const SizedBox(width: 10),
        Expanded(child: Text(val, style: AppText.caption.copyWith(fontSize: 9), textAlign: TextAlign.right)),
      ]));

  Widget _actionTile({required IconData icon, required String title, required String sub,
      required Color color, required bool enabled, required VoidCallback onTap}) =>
    GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(width: double.infinity,
        decoration: BoxDecoration(
          color: enabled ? Colors.white : AppColors.mist,
          border: AppBorders.ink2,
          boxShadow: enabled ? const [AppShadows.hard3] : null),
        child: Row(children: [
          Container(width: 56, height: 56, color: enabled ? color : AppColors.dim,
            child: Icon(icon, color: Colors.white, size: 22)),
          const SizedBox(width: 14),
          Expanded(child: Padding(padding: const EdgeInsets.symmetric(vertical: 12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: AppText.label.copyWith(fontSize: 11, color: enabled ? AppColors.ink : AppColors.dim)),
              const SizedBox(height: 3),
              Text(sub, style: AppText.caption.copyWith(fontSize: 9)),
            ]))),
          Container(width: 28, height: 56, color: AppColors.ink,
            child: const Center(child: Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 14))),
        ])));

  Future<bool?> _dialog({required String title, required Color color,
      required String message, required String action}) =>
    showDialog<bool>(context: context, barrierDismissible: false,
      builder: (dlg) => Dialog(backgroundColor: Colors.transparent,
        child: Container(
          decoration: BoxDecoration(color: Colors.white,
            border: Border.all(color: AppColors.ink, width: 2),
            boxShadow: const [AppShadows.hard4]),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(width: double.infinity, padding: const EdgeInsets.all(14), color: color,
              child: Text(title, style: AppText.title.copyWith(color: Colors.white, letterSpacing: 1.5))),
            Padding(padding: const EdgeInsets.all(20),
              child: Column(children: [
                Text(message, style: AppText.body.copyWith(height: 1.6)),
                const SizedBox(height: 20),
                Row(children: [
                  Expanded(child: GestureDetector(
                    onTap: () => Navigator.pop(dlg, false),
                    child: Container(height: 44,
                      decoration: BoxDecoration(border: Border.all(color: AppColors.mist, width: 1.5)),
                      child: Center(child: Text('CANCEL', style: AppText.label.copyWith(color: AppColors.dim)))))),
                  const SizedBox(width: 12),
                  Expanded(child: GestureDetector(
                    onTap: () => Navigator.pop(dlg, true),
                    child: Container(height: 44,
                      decoration: BoxDecoration(color: color, border: AppBorders.ink2, boxShadow: const [AppShadows.hard3]),
                      child: Center(child: Text(action, style: AppText.button.copyWith(fontSize: 10)))))),
                ]),
              ])),
          ]))));

  void _toast(String msg) => ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(msg, style: const TextStyle(fontWeight: FontWeight.w700)),
      backgroundColor: AppColors.ink, behavior: SnackBarBehavior.floating));
}