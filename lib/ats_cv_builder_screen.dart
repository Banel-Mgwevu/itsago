import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:file_picker/file_picker.dart';
import 'package:archive/archive.dart';
import 'package:http/http.dart' as http;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'app_config.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'app_theme.dart';
import 'ats_scoring_service.dart';
import 'cv_storage_service.dart';
import 'popia_consent_dialog.dart';
import 'main.dart';
import 'cv_library_screen.dart';
import 'cloud_function_service.dart';
import 'remote_config_service.dart';
import 'purchase_service.dart';
import 'review_service.dart';
import 'notification_service.dart';

enum _S { privacy, upload, processing, gapQA, generating, designPicker, download, success }

class _Gap {
  final String field;
  final String question;
  final bool required;
  String? answer;
  _Gap({required this.field, required this.question, this.required = false});
}

class ATSCVBuilderScreen extends StatefulWidget {
  final List<CameraDescription> cameras;
  const ATSCVBuilderScreen({super.key, required this.cameras});
  @override
  State<ATSCVBuilderScreen> createState() => _ATSCVBuilderScreenState();
}

class _ATSCVBuilderScreenState extends State<ATSCVBuilderScreen> {

  static const String _kClaudeModel  = 'claude-haiku-4-5-20251001';
  _S _state = _S.upload;

  @override
  void initState() {
    super.initState();
    _initPurchases();
    _init();
  }

  Future<void> _initPurchases() async {
    final svc = PurchaseService();
    svc.onPurchaseSuccess = () {
      if (mounted) setState(() => _isPremium = true);
    };
    await svc.init();
    if (mounted) setState(() => _isPremium = svc.isPremium);
  }

  File?  _file;
  String _fileName = '';
  String _fileExt  = '';
  Map<String, dynamic> _extracted = {};
  List<_Gap> _gaps = [];
  int _gapIndex = 0;
  Map<String, dynamic> _optimized = {};
  final List<Uint8List> _pdfs = [];
  int _selectedDesign = 0;
  final TextEditingController _answerCtrl = TextEditingController();
  String _processingMsg = 'Reading your CV...';
  double _genProgress   = 0.0;
  static const _designNames = ['EXECUTIVE', 'SPECTRUM', 'MINIMAL', 'GRID', 'UBUNTU', 'VIVID'];
  static const _premiumDesigns = {3, 4, 5};
  String? _docErrorType;
  int _savedCount = 0;
  bool _isPremium = false;
  String? _docErrorMsg;

  static const _sessionKey = 'ats_last_session';

  Future<void> _saveSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final session = jsonEncode({
        'optimized':     _optimized,
        'extracted':     _extracted,
        'selectedDesign': _selectedDesign,
      });
      await prefs.setString(_sessionKey, session);
    } catch (_) {}
  }

  Future<bool> _restoreSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw   = prefs.getString(_sessionKey);
      if (raw == null || raw.isEmpty) return false;
      final data  = jsonDecode(raw) as Map<String, dynamic>;
      final opt   = data['optimized']  as Map<String, dynamic>?;
      final ext   = data['extracted']  as Map<String, dynamic>?;
      final des   = data['selectedDesign'] as int? ?? 0;
      if (opt == null || opt.isEmpty) return false;
      setState(() {
        _optimized      = opt;
        _extracted      = ext ?? {};
        _selectedDesign = des;
        _state          = _S.designPicker;
      });
      return true;
    } catch (_) { return false; }
  }

  Future<void> _clearSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_sessionKey);
    } catch (_) {}
  }

  Future<void> _init() async {
    final prefs    = await SharedPreferences.getInstance();
    final accepted = prefs.getBool('ats_privacy_accepted') ?? false;
    if (accepted) {
      final restored = await _restoreSession();
      if (!restored) setState(() => _state = _S.upload);
    } else {
      setState(() => _state = _S.privacy);
    }
    final cvs = await CVStorageService.getCVs();
    if (mounted) setState(() => _savedCount = cvs.length);
  }

  Widget _pp(IconData icon, String text) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Icon(icon, size: 13, color: AppColors.blue),
      const SizedBox(width: 8),
      Expanded(child: Text(text, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w500, color: AppColors.dim, height: 1.4))),
    ]));

  @override
  void dispose() { _answerCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _state == _S.privacy || _state == _S.upload,
      onPopInvoked: (didPop) {
        if (!didPop) {
          if (_state == _S.success)           setState(() => _state = _S.download);
          else if (_state == _S.download)     setState(() => _state = _S.designPicker);
          else if (_state == _S.designPicker) setState(() => _state = _S.upload);
          else if (_state == _S.gapQA)        setState(() => _state = _S.upload);
          else if (_state == _S.generating)   setState(() => _state = _S.upload);
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.cream,
        body: SafeArea(child: Column(children: [
          _header(),
          Expanded(child: _body()),
        ]))));
  }

  Widget _header() {
    final steps = ['PRIVACY','UPLOAD','ANALYZE','Q&A','BUILD','PICK','EXPORT'];
    final idx   = _S.values.indexOf(_state);
    return Container(
      color: AppColors.ink,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Row(children: [
        GestureDetector(
          onTap: () => Navigator.of(context).pop(),
          child: Container(width: 38, height: 38,
            decoration: const BoxDecoration(color: AppColors.white, border: AppBorders.ink2, boxShadow: [AppShadows.hard3]),
            child: const Icon(Icons.arrow_back_rounded, color: AppColors.ink, size: 18))),
        const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(width: 6, height: 6, color: AppColors.amber),
            const SizedBox(width: 6),
            Text('ATS CV BUILDER', style: AppText.title.copyWith(color: Colors.white, letterSpacing: 1.5)),
          ]),
          Text(steps[idx], style: AppText.caption.copyWith(color: AppColors.amber)),
        ])),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(color: AppColors.amber, border: Border.all(color: AppColors.ink, width: 1.5)),
          child: Text('${idx + 1}/${steps.length}',
            style: AppText.label.copyWith(color: AppColors.ink, fontSize: 10))),
      ]));
  }

  Widget _body() {
    switch (_state) {
      case _S.privacy:      return _privacyUI();
      case _S.upload:       return _uploadUI();
      case _S.processing:   return _processingUI();
      case _S.gapQA:        return _gapQAUI();
      case _S.generating:   return _generatingUI();
      case _S.designPicker: return _designPickerUI();
      case _S.download:     return _downloadUI();
      case _S.success:     return _successUI();
    }
  }

  Widget _privacyUI() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(width: double.infinity, padding: const EdgeInsets.all(18), color: AppColors.blue,
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(width: 40, height: 40,
              decoration: BoxDecoration(color: AppColors.amber, shape: BoxShape.circle),
              child: Icon(Icons.shield_outlined, color: AppColors.ink, size: 20)),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('PRIVACY & DATA NOTICE', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 1)),
              Text('Please read before continuing', style: TextStyle(fontSize: 10, color: AppColors.amber, fontWeight: FontWeight.w500)),
            ])),
          ])),
        const SizedBox(height: 16),
        Container(width: double.infinity, padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(color: Colors.white, border: AppBorders.ink2, boxShadow: const [AppShadows.hard4]),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _pp(Icons.lock_outline,     'Your CV is sent to ITSAGO AI for processing. Never stored, sold, or shared with any third party.'),
            _pp(Icons.delete_outline,   'ITSAGO does not retain your data after processing. Discarded once designs are generated.'),
            _pp(Icons.gpp_good_outlined,'Compliant with POPIA (South Africa), GDPR (EU), CCPA (USA) and global privacy standards.'),
            _pp(Icons.person_outline,   'You own your CV and all generated documents. We claim no rights to your data.'),
            _pp(Icons.mail_outline,     'You can request data deletion at any time by contacting our support team.'),
            _pp(Icons.info_outline,     'By tapping I AGREE you confirm this CV is yours and you have the right to process it.'),
          ])),
        const SizedBox(height: 14),
        Center(child: Text('You only need to accept this once.', style: AppText.caption)),
        const SizedBox(height: 14),
        GestureDetector(
          onTap: () async {
            final prefs = await SharedPreferences.getInstance();
            await prefs.setBool('ats_privacy_accepted', true);
            setState(() => _state = _S.upload);
          },
          child: Container(width: double.infinity, height: 52,
            decoration: const BoxDecoration(color: AppColors.blue, border: AppBorders.ink2, boxShadow: [AppShadows.hard4]),
            child: Center(child: Text('I AGREE - CONTINUE', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 2))))),
        const SizedBox(height: 12),
        GestureDetector(
          onTap: () => Navigator.of(context).pop(),
          child: Container(width: double.infinity, height: 46,
            decoration: BoxDecoration(color: AppColors.cream, border: Border.all(color: AppColors.dim, width: 1)),
            child: Center(child: Text('GO BACK', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: AppColors.dim, letterSpacing: 1))))),
        const SizedBox(height: 20),
      ]));
  }

  Widget _uploadUI() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (_savedCount > 0)
          GestureDetector(
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CVLibraryScreen())),
            child: Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 14),
              padding: const EdgeInsets.all(14),
              decoration: const BoxDecoration(color: AppColors.ink, border: AppBorders.ink2, boxShadow: [AppShadows.hard3]),
              child: Row(children: [
                Container(width: 5, height: 36, color: AppColors.amber),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('YOU HAVE $_savedCount SAVED CV${_savedCount == 1 ? "" : "S"}',
                    style: AppText.label.copyWith(color: Colors.white, fontSize: 11)),
                  Text('Tap to view, download or delete',
                    style: AppText.caption.copyWith(color: AppColors.dim)),
                ])),
                const Icon(Icons.arrow_forward_rounded, color: AppColors.amber, size: 18),
              ]))),
        Container(width: double.infinity, padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(color: AppColors.blue, border: Border.all(color: AppColors.ink, width: 3)),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(width: 42, height: 42,
              decoration: BoxDecoration(color: AppColors.amber, shape: BoxShape.circle),
              child: Icon(Icons.auto_fix_high, color: AppColors.ink, size: 20)),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('YOUR DREAM JOB STARTS HERE', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 1)),
              const SizedBox(height: 5),
              Text('Upload your CV and we rewrite it to get you noticed by employers - then build 4 job-ready ATS designs you can send today.',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: Colors.white70, height: 1.5)),
            ])),
          ])),
        if (_docErrorType != null) ...[
          const SizedBox(height: 14),
          Container(width: double.infinity,
            decoration: BoxDecoration(color: AppColors.red, border: Border.all(color: AppColors.ink, width: 3)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(width: double.infinity, padding: const EdgeInsets.all(14), color: AppColors.ink,
                child: Row(children: [
                  Icon(Icons.block, color: AppColors.red, size: 22),
                  const SizedBox(width: 10),
                  Text('WRONG DOCUMENT DETECTED', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 1.5)),
                ])),
              Padding(padding: const EdgeInsets.all(16),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), color: Colors.white,
                      child: Text(_docErrorType!.toUpperCase(), style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: AppColors.red, letterSpacing: 1))),
                    const SizedBox(width: 8),
                    Expanded(child: Text(_docErrorMsg!, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white, height: 1.4))),
                  ]),
                  const SizedBox(height: 12),
                  Container(width: double.infinity, padding: const EdgeInsets.all(10), color: Colors.white24,
                    child: Row(children: [
                      Icon(Icons.lightbulb_outline, color: AppColors.amber, size: 16),
                      const SizedBox(width: 8),
                      Expanded(child: Text('Please upload your CV or resume. This should be a document listing your work experience, education, and skills.',
                        style: TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.w500, height: 1.4))),
                    ])),
                ])),
            ])),
        ],
        const SizedBox(height: 14),
        Row(children: [
          _qStep(Icons.upload_file,   'Upload\nYour CV',   AppColors.blue),
          _arrow(),
          _qStep(Icons.quiz_outlined, 'Quick\nQuestions',  AppColors.amber),
          _arrow(),
          _qStep(Icons.auto_fix_high, 'We\nRewrite It',    AppColors.red),
          _arrow(),
          _qStep(Icons.download,      'Ready\nTo Send',    AppColors.blue),
        ]),
        const SizedBox(height: 20),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text('UPLOAD YOUR CV', style: AppText.title.copyWith(color: AppColors.blue, letterSpacing: 2)),
          FutureBuilder<int>(
            future: _getRemainingUploads(),
            builder: (ctx, snap) {
              final remaining = snap.data ?? _weeklyLimit;
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: remaining > 0 ? AppColors.blue : AppColors.red,
                  border: AppBorders.ink2),
                child: Text('$remaining left this week',
                  style: AppText.label.copyWith(color: Colors.white, fontSize: 9)));
            }),
        ]),
        const SizedBox(height: 4),
        Text('PDF or Word (.docx)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.dim)),
        const SizedBox(height: 12),
        GestureDetector(
          onTap: _pickFile,
          child: Container(width: double.infinity, height: 160,
            decoration: BoxDecoration(
              color: _file != null ? AppColors.blue.withOpacity(0.04) : AppColors.white,
              border: Border.all(color: _file != null ? AppColors.blue : AppColors.dim, width: _file != null ? 3 : 2)),
            child: _file != null ? _filePreview() : _dropZoneEmpty())),
        if (_file != null) ...[
          const SizedBox(height: 16),
          GestureDetector(
            onTap: _startProcessing,
            child: Container(width: double.infinity, height: 52,
              decoration: const BoxDecoration(color: AppColors.blue, border: AppBorders.ink2, boxShadow: [AppShadows.hard4]),
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(Icons.auto_fix_high, color: Colors.white, size: 18),
                const SizedBox(width: 8),
                Text('BUILD MY JOB-READY CV', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 1.5)),
              ]))),
        ],
        const SizedBox(height: 20),
      ]));
  }

  Widget _qStep(IconData icon, String label, Color color) {
    final isY = color == AppColors.amber;
    return Expanded(child: Container(height: 72,
      decoration: BoxDecoration(color: color, border: Border.all(color: AppColors.ink, width: 2)),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(icon, size: 18, color: isY ? AppColors.ink : AppColors.white),
        const SizedBox(height: 5),
        Text(label, style: TextStyle(fontSize: 8, fontWeight: FontWeight.w700, color: isY ? AppColors.ink : AppColors.white, height: 1.3), textAlign: TextAlign.center),
      ])));
  }

  Widget _arrow() => Container(width: 14, height: 72, color: AppColors.cream,
    child: Center(child: Icon(Icons.arrow_forward_ios, size: 9, color: AppColors.dim)));

  Widget _dropZoneEmpty() => Column(mainAxisAlignment: MainAxisAlignment.center, children: [
    Container(width: 52, height: 52, decoration: BoxDecoration(color: AppColors.cream, shape: BoxShape.circle),
      child: Icon(Icons.upload_file, color: AppColors.dim, size: 26)),
    const SizedBox(height: 10),
    Text('TAP TO UPLOAD CV', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: AppColors.ink, letterSpacing: 1)),
    const SizedBox(height: 4),
    Text('PDF or Word document', style: TextStyle(fontSize: 11, color: AppColors.dim, fontWeight: FontWeight.w500)),
  ]);

  Widget _filePreview() {
    final isWord = _fileExt == 'docx';
    return Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Container(width: 52, height: 52,
        decoration: BoxDecoration(color: isWord ? AppColors.blue : AppColors.red, shape: BoxShape.circle),
        child: Icon(isWord ? Icons.description : Icons.picture_as_pdf, color: Colors.white, size: 26)),
      const SizedBox(height: 8),
      Text(_fileExt.toUpperCase(), style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: AppColors.dim, letterSpacing: 2)),
      const SizedBox(height: 4),
      Padding(padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Text(_fileName, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.ink), textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis)),
      const SizedBox(height: 6),
      GestureDetector(onTap: _pickFile,
        child: Text('CHANGE FILE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.blue, decoration: TextDecoration.underline, letterSpacing: 1))),
    ]);
  }

  Widget _processingUI() => Center(child: Padding(padding: const EdgeInsets.all(40),
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Container(width: 90, height: 90,
        decoration: BoxDecoration(color: AppColors.amber, border: Border.all(color: AppColors.ink, width: 2)),
        child: const Center(child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3))),
      const SizedBox(height: 28),
      Text(_processingMsg, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: AppColors.ink, letterSpacing: 1), textAlign: TextAlign.center),
      const SizedBox(height: 8),
      Text('ITSAGO AI is analyzing your CV\nThis may take up to 30 seconds...',
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.dim, height: 1.6), textAlign: TextAlign.center),
    ])));

  Widget _gapQAUI() {
    if (_gaps.isEmpty || _gapIndex >= _gaps.length) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _startGenerating());
      return _processingUI();
    }
    final q        = _gaps[_gapIndex];
    final progress = (_gapIndex + 1) / _gaps.length;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Container(height: 6,
            decoration: BoxDecoration(color: AppColors.cream, border: Border.all(color: AppColors.ink, width: 1)),
            child: FractionallySizedBox(alignment: Alignment.centerLeft, widthFactor: progress, child: Container(color: AppColors.amber)))),
          const SizedBox(width: 12),
          Text('${_gapIndex + 1} / ${_gaps.length}', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: AppColors.dim)),
        ]),
        const SizedBox(height: 28),
        Container(width: double.infinity,
          decoration: BoxDecoration(color: Colors.white, border: Border.all(color: AppColors.ink, width: 3)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(width: double.infinity, padding: const EdgeInsets.all(16), color: q.required ? AppColors.red : AppColors.amber,
              child: Row(children: [
                Container(width: 34, height: 34,
                  decoration: BoxDecoration(color: q.required ? Colors.white : AppColors.ink, shape: BoxShape.circle),
                  child: Center(child: Text('${_gapIndex + 1}', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: q.required ? AppColors.red : AppColors.white)))),
                const SizedBox(width: 12),
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(q.required ? 'MISSING FROM YOUR CV' : 'QUICK QUESTION', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: q.required ? Colors.white : AppColors.ink, letterSpacing: 1)),
                  Text(q.required ? 'This is required to complete your CV' : 'Optional - skip if you prefer',
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: q.required ? Colors.white.withOpacity(0.85) : AppColors.ink.withOpacity(0.6))),
                ]),
              ])),
            Padding(padding: const EdgeInsets.all(20),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(q.question, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.ink, height: 1.4)),
                const SizedBox(height: 18),
                Container(decoration: BoxDecoration(border: Border.all(color: AppColors.ink, width: 2)),
                  child: TextField(controller: _answerCtrl, maxLines: 4,
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.ink),
                    decoration: InputDecoration(hintText: 'Type your answer here...', hintStyle: TextStyle(color: AppColors.dim),
                      border: InputBorder.none, contentPadding: const EdgeInsets.all(14), filled: true, fillColor: AppColors.white))),
              ])),
            Padding(padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: Row(children: [
                if (!q.required) ...[
                  Expanded(child: GestureDetector(onTap: _skipGap,
                    child: Container(height: 46,
                      decoration: BoxDecoration(color: AppColors.cream, border: Border.all(color: AppColors.dim, width: 2)),
                      child: Center(child: Text('SKIP', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: AppColors.dim, letterSpacing: 1)))))),
                  const SizedBox(width: 12),
                ],
                Expanded(flex: 2, child: GestureDetector(onTap: _submitAnswer,
                  child: Container(height: 46, color: q.required ? AppColors.red : AppColors.blue,
                    child: Center(child: Text('NEXT', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 1)))))),
          ])),
          ])),
        const SizedBox(height: 20),
        Container(width: double.infinity, padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: AppColors.amber.withOpacity(0.08), border: Border.all(color: AppColors.amber, width: 2)),
          child: Row(children: [
            Icon(Icons.info_outline, color: AppColors.blue, size: 18),
            const SizedBox(width: 10),
            Expanded(child: Text('Almost done! We will build your 4 job-ready ATS CV designs right after this.',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.ink, height: 1.4))),
          ])),
      ]));
  }

  Widget _generatingUI() {
    final current = (_genProgress * 4).floor().clamp(0, 3);
    return Center(child: Padding(padding: const EdgeInsets.all(40),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        SizedBox(width: 100, height: 100,
          child: Stack(alignment: Alignment.center, children: [
            Container(width: 100, height: 100, color: AppColors.blue),
            Container(width: 70, height: 70, decoration: BoxDecoration(color: AppColors.amber, shape: BoxShape.circle)),
            Container(width: 40, height: 40, color: AppColors.red),
            const SizedBox(width: 28, height: 28, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3)),
          ])),
        const SizedBox(height: 28),
        Text('BUILDING YOUR DREAM CVS', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: AppColors.blue, letterSpacing: 2)),
        const SizedBox(height: 6),
        Text('Crafting ${_designNames[current]} design...', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.dim, letterSpacing: 1)),
        const SizedBox(height: 24),
        Container(width: double.infinity, height: 10,
          decoration: BoxDecoration(color: AppColors.cream, border: Border.all(color: AppColors.ink, width: 2)),
          child: FractionallySizedBox(alignment: Alignment.centerLeft, widthFactor: _genProgress, child: Container(color: AppColors.blue))),
        const SizedBox(height: 8),
        Text('${(_genProgress * 100).toInt()}%', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: AppColors.ink)),
        Wrap(alignment: WrapAlignment.center, spacing: 4, runSpacing: 4,

          children: List.generate(6, (i) {
            final done   = i < current;
            final active = i == current && _genProgress < 1.0;
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 2),
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              decoration: BoxDecoration(
                color: done ? AppColors.blue : active ? AppColors.amber : AppColors.mist,
                border: Border.all(color: AppColors.ink, width: 1)),
              child: Text(_designNames[i], style: TextStyle(fontSize: 7, fontWeight: FontWeight.w900,
                color: done ? AppColors.white : AppColors.ink, letterSpacing: 0.5)));
          })),
      ])));
  }

  Widget _designPickerUI() {
    final tags   = ['CORPORATE', 'CREATIVE', 'UNIVERSAL', 'TECH', 'ENTRY LEVEL', 'CREATIVE'];
    final colors = [const Color(0xFF1C1C3A), const Color(0xFF2E4057), const Color(0xFF333333), AppColors.blue, const Color(0xFF2D6A4F), const Color(0xFF6B2D8B)];
    return Column(children: [
      Container(width: double.infinity, padding: const EdgeInsets.all(16), color: Colors.white,
        child: Column(children: [
          Text('PICK YOUR FAVOURITE LOOK', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: AppColors.blue, letterSpacing: 2)),
          const SizedBox(height: 6),
          const SizedBox(height: 4),
          Text('Tap a design to preview  -  Select  -  Tap USE to download',
            style: TextStyle(fontSize: 10, color: AppColors.dim), textAlign: TextAlign.center),
          const SizedBox(height: 2),
          Text('Takes about 3 minutes total', style: TextStyle(fontSize: 10, color: AppColors.dim)),
        ])),  // Column + Container
      Expanded(child: ListView.builder(




        itemCount: 6,
        itemBuilder: (ctx, i) {
          final isSelected = _selectedDesign == i;
          final isPremiumDesign = _premiumDesigns.contains(i);
          final isLocked = isPremiumDesign && !_isPremium;
          return GestureDetector(
            onTap: () {
              if (isLocked) {
                _showPremiumDialog();
                return;
              }
              setState(() => _selectedDesign = i);
            },
            child: Container(margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(color: Colors.white,
                border: Border.all(color: isSelected ? AppColors.blue : AppColors.ink, width: isSelected ? 3 : 2)),
              child: Column(children: [
                Container(width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  color: isSelected ? AppColors.blue : colors[i],
                  child: Row(children: [
                    Text(_designNames[i], style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 2)),
                    const SizedBox(width: 8),
                    Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), color: Colors.white24,
                      child: Text(tags[i], style: const TextStyle(fontSize: 8, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 1))),
                    const Spacer(),
                    if (isSelected) const Icon(Icons.check_circle, color: Colors.white, size: 18)
                    else Text('TAP TO SELECT', style: TextStyle(fontSize: 8, fontWeight: FontWeight.w700, color: Colors.white70, letterSpacing: 1)),
                  ])),
                _cvCardPreview(i),
                Container(width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  color: isSelected ? AppColors.blue.withOpacity(0.06) : AppColors.mist,
                  child: Row(children: [
                    Text(isSelected ? 'SELECTED  -  TAP AGAIN FOR FULL PREVIEW' : 'TAP TO SELECT THIS DESIGN',
                      style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: isSelected ? AppColors.blue : AppColors.dim, letterSpacing: 0.8)),
                    const Spacer(),
                    GestureDetector(
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => _ATSPreviewPage(
                        data: _optimized, designIndex: i, onSelect: () { Navigator.pop(context); setState(() => _state = _S.download); }))),
                      child: Icon(isSelected ? Icons.fullscreen : Icons.remove_red_eye, color: isSelected ? AppColors.blue : AppColors.dim, size: 16)),
                  ])),
              ])));
        })),
      Container(width: double.infinity, padding: const EdgeInsets.all(16), color: Colors.white,
        child: GestureDetector(
          onTap: () => setState(() => _state = _S.download),
          child: Container(width: double.infinity, height: 52,
            decoration: BoxDecoration(color: AppColors.blue, border: Border.all(color: AppColors.ink, width: 2), boxShadow: const [BoxShadow(color: Colors.black, offset: Offset(4,4), blurRadius: 0)]),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              const Icon(Icons.check_circle_outline, color: Colors.white, size: 18),
              const SizedBox(width: 8),
              Text('USE ${_designNames[_selectedDesign]} DESIGN', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 1.5)),
            ])))),
    ]);
  }

  Widget _cvCardPreview(int i) {
    switch (i) {
      case 0: return _execCardPreview();
      case 1: return _specCardPreview();
      case 2: return _minCardPreview();
      case 3: return _gridCardPreview();
      case 4: return _ubuntuCardPreview();
      case 5: return _vividCardPreview();
      default: return _execCardPreview();
    }
  }

  Widget _ubuntuCardPreview() {
    const green = Color(0xFF2D6A4F);
    const lightGreen = Color(0xFF52B788);
    return Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(width: double.infinity, padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(border: Border(left: BorderSide(color: green, width: 4))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(_s('name').toUpperCase(), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, letterSpacing: 2)),
          const SizedBox(height: 3),
          if (_s('headline').isNotEmpty) Text(_s('headline'), style: TextStyle(fontSize: 11, color: green, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text([_s('email'), _s('phone')].where((v) => v.isNotEmpty).join('  .  '), style: TextStyle(fontSize: 9, color: Colors.grey[600])),
        ])),
      const SizedBox(height: 10),
      Container(width: double.infinity, height: 1, color: lightGreen),
      const SizedBox(height: 10),
      if (_s('summary').isNotEmpty) ...[
        Text('PROFILE', style: TextStyle(fontSize: 8, fontWeight: FontWeight.w900, color: green, letterSpacing: 2)),
        const SizedBox(height: 4),
        Text(_s('summary'), maxLines: 3, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 10, height: 1.5)),
        const SizedBox(height: 8),
      ],
      if (_list('skills').isNotEmpty) ...[
        Text('SKILLS', style: TextStyle(fontSize: 8, fontWeight: FontWeight.w900, color: green, letterSpacing: 2)),
        const SizedBox(height: 4),
        Wrap(spacing: 6, runSpacing: 4, children: _list('skills').take(6).map((s) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          color: lightGreen.withOpacity(0.15),
          child: Text(s, style: TextStyle(fontSize: 9, color: green, fontWeight: FontWeight.w600)))).toList()),
      ],
    ]));
  }

  Widget _vividCardPreview() {
    const purple = Color(0xFF6B2D8B);
    const pink = Color(0xFFE91E8C);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(width: double.infinity,
        decoration: BoxDecoration(gradient: LinearGradient(colors: [purple, pink], begin: Alignment.centerLeft, end: Alignment.centerRight)),
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(_s('name').toUpperCase(), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 2)),
          const SizedBox(height: 3),
          if (_s('headline').isNotEmpty) Text(_s('headline'), style: TextStyle(fontSize: 11, color: Colors.white.withOpacity(0.85), fontWeight: FontWeight.w500)),
          const SizedBox(height: 4),
          Text([_s('email'), _s('phone')].where((v) => v.isNotEmpty).join('  .  '), style: TextStyle(fontSize: 9, color: Colors.white.withOpacity(0.7))),
        ])),
      Padding(padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (_s('summary').isNotEmpty) ...[
          Row(children: [Container(width: 16, height: 16, color: pink, child: const SizedBox()), const SizedBox(width: 6), Text('ABOUT ME', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: purple, letterSpacing: 2))]),
          const SizedBox(height: 6),
          Text(_s('summary'), maxLines: 3, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 10, height: 1.5)),
          const SizedBox(height: 10),
        ],
        if (_list('skills').isNotEmpty) ...[
          Row(children: [Container(width: 16, height: 16, color: purple, child: const SizedBox()), const SizedBox(width: 6), Text('SKILLS', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: purple, letterSpacing: 2))]),
          const SizedBox(height: 6),
          Wrap(spacing: 6, runSpacing: 4, children: _list('skills').take(6).map((s) => Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(border: Border.all(color: pink), borderRadius: BorderRadius.circular(12)),
            child: Text(s, style: TextStyle(fontSize: 9, color: purple)))).toList()),
        ],
      ])),
    ]);
  }

  Widget _execCardPreview() {
    const navy = Color(0xFF1C1C3A); const gold = Color(0xFFD4AF37);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(width: double.infinity, color: navy, padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(_s('name').toUpperCase(), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 2)),
          const SizedBox(height: 3), Container(width: 40, height: 2, color: gold), const SizedBox(height: 6),
          if (_s('headline').isNotEmpty) Text(_s('headline'), style: TextStyle(fontSize: 11, color: gold, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text([_s('email'), _s('phone'), _s('location')].where((v) => v.isNotEmpty).join('  -  '),
            style: TextStyle(fontSize: 10, color: Colors.white.withOpacity(0.7))),
        ])),
      Padding(padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (_s('summary').isNotEmpty) ...[
          Row(children: [
            Text('PROFESSIONAL SUMMARY', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: navy, letterSpacing: 1.5)),
            const SizedBox(width: 6), Expanded(child: Container(height: 1, color: gold)),
          ]),
          const SizedBox(height: 6),
          Text(_s('summary'), maxLines: 3, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 10, height: 1.5, color: Colors.black87)),
          const SizedBox(height: 10),
        ],
        if (_list('skills').isNotEmpty) ...[
          Row(children: [
            Text('SKILLS', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: navy, letterSpacing: 1.5)),
            const SizedBox(width: 6), Expanded(child: Container(height: 1, color: gold)),
          ]),
          const SizedBox(height: 6),
          Wrap(spacing: 6, runSpacing: 4,
            children: _list('skills').take(6).map((s) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(border: Border.all(color: gold)),
              child: Text(s, style: const TextStyle(fontSize: 9)))).toList()),
        ],
        const SizedBox(height: 4),
      ])),
    ]);
  }

  Widget _specCardPreview() {
    const sidebar = Color(0xFF2E4057); const teal = Color(0xFF048A81);
    return IntrinsicHeight(child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Container(width: 90, color: sidebar, padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(_s('name').split(' ').first.toUpperCase(), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 1)),
          if (_s('name').split(' ').length > 1)
            Text(_s('name').split(' ').skip(1).join(' ').toUpperCase(), style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: teal, letterSpacing: 1)),
          const SizedBox(height: 4), Container(width: 24, height: 2, color: teal), const SizedBox(height: 10),
          Text('SKILLS', style: TextStyle(fontSize: 7, fontWeight: FontWeight.w900, color: teal, letterSpacing: 1)),
          const SizedBox(height: 4),
          ..._list('skills').take(5).map((s) => Padding(padding: const EdgeInsets.only(bottom: 3),
            child: Text(s, style: TextStyle(fontSize: 8, color: Colors.white.withOpacity(0.8)), maxLines: 1, overflow: TextOverflow.ellipsis))),
        ])),
      Expanded(child: Padding(padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (_s('headline').isNotEmpty) Text(_s('headline'), style: TextStyle(fontSize: 11, color: teal, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          if (_s('summary').isNotEmpty) Text(_s('summary'), maxLines: 4, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 10, height: 1.5, color: Colors.black87)),
          const SizedBox(height: 8),
          if (_exp().isNotEmpty) ...[
            Row(children: [Container(width: 3, height: 10, color: teal), const SizedBox(width: 5), Text('EXPERIENCE', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: sidebar, letterSpacing: 1))]),
            const SizedBox(height: 4),
            Text((_exp().first['title'] ?? '').toString(), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700)),
            Text((_exp().first['company'] ?? '').toString(), style: TextStyle(fontSize: 9, color: teal)),
          ],
        ]))),
    ]));
  }

  Widget _minCardPreview() {
    return Padding(padding: const EdgeInsets.all(16), child: Column(children: [
      Text(_s('name').toUpperCase(), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, letterSpacing: 4), textAlign: TextAlign.center),
      const SizedBox(height: 4),
      if (_s('headline').isNotEmpty) Text(_s('headline'), style: TextStyle(fontSize: 11, color: Colors.grey[600]), textAlign: TextAlign.center),
      const SizedBox(height: 6),
      Divider(color: Colors.grey[300], thickness: 0.5),
      Text([_s('email'), _s('phone'), _s('location')].where((v) => v.isNotEmpty).join('  .  '), style: TextStyle(fontSize: 10, color: Colors.grey[500]), textAlign: TextAlign.center),
      Divider(color: Colors.grey[300], thickness: 0.5),
      const SizedBox(height: 10),
      if (_s('summary').isNotEmpty) ...[
        Row(children: [const Text('PROFILE', style: TextStyle(fontSize: 8, fontWeight: FontWeight.w900, letterSpacing: 3)), const SizedBox(width: 8), Expanded(child: Divider(color: Colors.grey[300], thickness: 0.5))]),
        const SizedBox(height: 6),
        Text(_s('summary'), maxLines: 3, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 10, height: 1.6, color: Colors.black87)),
      ],
      const SizedBox(height: 8),
      if (_list('skills').isNotEmpty)
        Wrap(spacing: 4, runSpacing: 3, children: _list('skills').take(6).map((s) => Text('$s  .', style: const TextStyle(fontSize: 9, color: Colors.black87))).toList()),
      const SizedBox(height: 4),
    ]));
  }

  Widget _gridCardPreview() {
    const blue = Color(0xFF1565C0); const red = Color(0xFFE53935);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(width: double.infinity, color: blue, padding: const EdgeInsets.all(14),
        child: Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(_s('name').toUpperCase(), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 1.5)),
            const SizedBox(height: 3), Container(width: 30, height: 2, color: red), const SizedBox(height: 4),
            if (_s('headline').isNotEmpty) Text(_s('headline'), style: TextStyle(fontSize: 10, color: Colors.white.withOpacity(0.7))),
          ])),
          const SizedBox(width: 10),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (_s('email').isNotEmpty)    Text(_s('email'),    style: TextStyle(fontSize: 9, color: Colors.white.withOpacity(0.7))),
            if (_s('phone').isNotEmpty)    Text(_s('phone'),    style: TextStyle(fontSize: 9, color: Colors.white.withOpacity(0.7))),
            if (_s('location').isNotEmpty) Text(_s('location'), style: TextStyle(fontSize: 9, color: Colors.white.withOpacity(0.7))),
          ]),
        ])),
      Padding(padding: const EdgeInsets.all(14), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(flex: 3, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (_s('summary').isNotEmpty) ...[
            Row(children: [Container(width: 2, height: 11, color: red), const SizedBox(width: 5), Text('SUMMARY', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: blue, letterSpacing: 1))]),
            const SizedBox(height: 5),
            Text(_s('summary'), maxLines: 4, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 10, height: 1.5, color: Colors.black87)),
          ],
          if (_exp().isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(children: [Container(width: 2, height: 11, color: red), const SizedBox(width: 5), Text('EXPERIENCE', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: blue, letterSpacing: 1))]),
            const SizedBox(height: 4),
            Text((_exp().first['title'] ?? '').toString(), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700)),
            Text((_exp().first['company'] ?? '').toString(), style: TextStyle(fontSize: 9, color: blue, fontWeight: FontWeight.w600)),
          ],
        ])),
        const SizedBox(width: 10),
        Expanded(flex: 2, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [Container(width: 2, height: 11, color: red), const SizedBox(width: 5), Text('SKILLS', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: blue, letterSpacing: 1))]),
          const SizedBox(height: 5),
          ..._list('skills').take(5).map((s) => Container(margin: const EdgeInsets.only(bottom: 3), padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3), color: const Color(0xFFF0F0F0),
            child: Text(s, style: const TextStyle(fontSize: 9), maxLines: 1, overflow: TextOverflow.ellipsis))),
        ])),
      ])),
    ]);
  }

  Widget _downloadUI() {
    final labels   = ['Executive', 'Spectrum', 'Minimal', 'Grid', 'Ubuntu', 'Vivid'];
    final atsScore = _optimized['atsScore'];
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(width: double.infinity, padding: const EdgeInsets.all(20), color: AppColors.blue,
          child: Row(children: [
            Container(width: 48, height: 48, decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle),
              child: Icon(Icons.check_circle, color: AppColors.blue, size: 26)),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('YOUR JOB-READY CV IS SET!', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 2)),
              Text('${labels[_selectedDesign]} design - ATS-optimized', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.amber)),
            ])),
          ])),
        const SizedBox(height: 16),
        Text('YOUR CV PREVIEW', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: AppColors.ink, letterSpacing: 2)),
        const SizedBox(height: 10),
        Container(width: double.infinity,
          decoration: BoxDecoration(color: Colors.white, border: Border.all(color: AppColors.ink, width: 2), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 6, offset: const Offset(0, 3))]),
          child: _cvCardPreview(_selectedDesign)),
        const SizedBox(height: 24),
        Text('SAVE & SEND YOUR CV', style: AppText.title.copyWith(color: AppColors.blue, letterSpacing: 2)),
        const SizedBox(height: 12),
        _dlOption(Icons.picture_as_pdf, 'SAVE AS PDF',         'Best for sending to employers and job portals', AppColors.red,  _downloadPDF),
        const SizedBox(height: 12),
        _dlOption(Icons.description,    'SAVE AS WORD (.DOCX)', 'Best if you want to make personal edits first', AppColors.blue, _downloadWord),
        const SizedBox(height: 20),

        // - TRANSFORMATION SCORE -
        Builder(builder: (ctx) {
          final before = (_extracted['currentATSScore'] as num?)?.toInt() ?? 45;
          final after  = (atsScore as num?)?.toInt()  ?? 80;
          final gain   = after - before;
          final percentile = after >= 90 ? 5 : after >= 80 ? 12 : after >= 70 ? 25 : after >= 60 ? 40 : 55;
          final gainColor  = gain > 0 ? AppColors.blue : AppColors.red;
          return Container(width: double.infinity,
            decoration: BoxDecoration(color: AppColors.ink, border: AppBorders.ink2, boxShadow: [AppShadows.hard4]),
            child: Column(children: [
              // Header
              Container(width: double.infinity, padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                color: AppColors.blue,
                child: Row(children: [
                  const Icon(Icons.trending_up_rounded, color: Colors.white, size: 20),
                  const SizedBox(width: 10),
                  Text('YOUR CV TRANSFORMATION', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 1.5)),
                ])),
              // Before / After scores
              Padding(padding: const EdgeInsets.all(20), child: Column(children: [
                Row(children: [
                  // Before
                  Expanded(child: Column(children: [
                    Text('BEFORE', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: AppColors.dim, letterSpacing: 2)),
                    const SizedBox(height: 8),
                    Container(width: 72, height: 72,
                      decoration: BoxDecoration(color: AppColors.red, border: Border.all(color: Colors.white24, width: 2)),
                      child: Center(child: Text('$before', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: Colors.white)))),
                    const SizedBox(height: 6),
                    Container(width: double.infinity, height: 8, margin: const EdgeInsets.symmetric(horizontal: 4),
                      decoration: BoxDecoration(color: Colors.white12, borderRadius: BorderRadius.circular(4)),
                      child: FractionallySizedBox(alignment: Alignment.centerLeft, widthFactor: before / 100,
                        child: Container(decoration: BoxDecoration(color: AppColors.red, borderRadius: BorderRadius.circular(4))))),
                  ])),
                  // Arrow + gain
                  Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: Column(children: [
                    Icon(Icons.arrow_forward_rounded, color: AppColors.amber, size: 28),
                    const SizedBox(height: 4),
                    Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      color: gainColor,
                      child: Text(gain > 0 ? '+$gain' : '$gain',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: Colors.white))),
                  ])),
                  // After
                  Expanded(child: Column(children: [
                    Text('AFTER', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: AppColors.amber, letterSpacing: 2)),
                    const SizedBox(height: 8),
                    Container(width: 72, height: 72,
                      decoration: BoxDecoration(color: AppColors.blue, border: Border.all(color: AppColors.amber, width: 2)),
                      child: Center(child: Text('$after', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: Colors.white)))),
                    const SizedBox(height: 6),
                    Container(width: double.infinity, height: 8, margin: const EdgeInsets.symmetric(horizontal: 4),
                      decoration: BoxDecoration(color: Colors.white12, borderRadius: BorderRadius.circular(4)),
                      child: FractionallySizedBox(alignment: Alignment.centerLeft, widthFactor: after / 100,
                        child: Container(decoration: BoxDecoration(color: AppColors.blue, borderRadius: BorderRadius.circular(4))))),
                  ])),
                ]),
                const SizedBox(height: 16),
                // Percentile banner
                Container(width: double.infinity, padding: const EdgeInsets.all(14),
                  color: AppColors.amber,
                  child: Column(children: [
                    Text('YOU ARE NOW IN THE TOP $percentile% OF APPLICANTS',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: AppColors.ink, letterSpacing: 0.5), textAlign: TextAlign.center),
                    const SizedBox(height: 4),
                    Text('Your CV went from $before% to $after% - recruiters will notice.',
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.ink.withOpacity(0.7)), textAlign: TextAlign.center),
                  ])),
              ])),
            ]));
        }),

        const SizedBox(height: 20),

        // - SHARE BUTTONS -
        GestureDetector(onTap: _share,
          child: Container(width: double.infinity, height: 50,
            decoration: BoxDecoration(color: Colors.white, border: Border.all(color: AppColors.ink, width: 2)),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(Icons.share, color: AppColors.ink, size: 18),
              const SizedBox(width: 8),
              Text('SHARE CV', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: AppColors.ink, letterSpacing: 1)),
            ]))),
        const SizedBox(height: 10),
        GestureDetector(onTap: _shareWhatsApp,
          child: Container(width: double.infinity, height: 50,
            decoration: BoxDecoration(color: const Color(0xFF25D366), border: Border.all(color: AppColors.ink, width: 2), boxShadow: [AppShadows.hard3]),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Container(width: 24, height: 24,
                decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                child: Center(child: Icon(Icons.chat_rounded, color: const Color(0xFF25D366), size: 14))),
              const SizedBox(width: 10),
              Text('SHARE ON WHATSAPP', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 1)),
            ]))),
        const SizedBox(height: 14),
        const SizedBox(height: 14),
        GestureDetector(
          onTap: () => setState(() {
            _file = null; _fileName = ''; _fileExt = '';
            _extracted = {}; _gaps = []; _gapIndex = 0;
            _optimized = {}; _pdfs.clear(); _selectedDesign = 0;
            _state = _S.upload;
          }),
          child: Container(width: double.infinity, padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: AppColors.cream, border: Border.all(color: AppColors.dim, width: 1)),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(Icons.refresh, color: AppColors.dim, size: 15),
              const SizedBox(width: 8),
              Text('OPTIMISE ANOTHER CV', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.dim, letterSpacing: 1)),
            ]))),
        const SizedBox(height: 20),
      ]));
  }

  Widget _dlOption(IconData icon, String title, String subtitle, Color color, VoidCallback onTap) =>
    GestureDetector(onTap: onTap,
      child: Container(width: double.infinity, padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: Colors.white, border: Border.all(color: AppColors.ink, width: 2)),
        child: Row(children: [
          Container(width: 48, height: 48, decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            child: Icon(icon, color: Colors.white, size: 22)),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: AppColors.ink, letterSpacing: 1)),
            const SizedBox(height: 3),
            Text(subtitle, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w500, color: AppColors.dim)),
          ])),
          Icon(Icons.download, color: AppColors.dim, size: 20),
        ])));

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['pdf', 'docx'], allowMultiple: false);
    if (result != null && result.files.isNotEmpty) {
      final f = result.files.first;
      setState(() { _file = File(f.path!); _fileName = f.name; _fileExt = f.extension?.toLowerCase() ?? ''; _docErrorType = null; _docErrorMsg = null; });
    }
  }

  static const _uploadKey    = 'cv_upload_timestamps';
  static const _weeklyLimit   = 2;

  Future<int> _getRemainingUploads() async {
    final prefs   = await SharedPreferences.getInstance();
    final raw     = prefs.getStringList(_uploadKey) ?? [];
    final weekAgo = DateTime.now().subtract(const Duration(days: 7));
    final recent  = raw.map((s) => DateTime.parse(s))
                      .where((d) => d.isAfter(weekAgo)).length;
    return (_weeklyLimit - recent).clamp(0, _weeklyLimit);
  }

  Future<bool> _checkWeeklyLimit() async {
    final prefs     = await SharedPreferences.getInstance();
    final raw       = prefs.getStringList(_uploadKey) ?? [];
    final now       = DateTime.now();
    final weekAgo   = now.subtract(const Duration(days: 7));
    // Keep only uploads from the last 7 days
    final recent    = raw.map((s) => DateTime.parse(s))
                        .where((d) => d.isAfter(weekAgo)).toList();
    if (recent.length >= _weeklyLimit) {
      // Find when the oldest one expires
      recent.sort();
      final nextUnlock = recent.first.add(const Duration(days: 7));
      final daysLeft   = nextUnlock.difference(now).inDays + 1;
      final hoursLeft  = nextUnlock.difference(now).inHours;
      // Schedule reminder notification
      await _scheduleUnlockNotification(nextUnlock);
      // Show limit dialog
      if (mounted) {
        showDialog(context: context, barrierDismissible: false,
          builder: (dlg) => Dialog(backgroundColor: Colors.transparent,
            child: Container(
              decoration: BoxDecoration(color: Colors.white,
                border: Border.all(color: AppColors.ink, width: 2),
                boxShadow: const [AppShadows.hard4]),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Container(width: double.infinity, padding: const EdgeInsets.all(14),
                  color: AppColors.amber,
                  child: Row(children: [
                    const Icon(Icons.lock_clock, color: AppColors.ink, size: 22),
                    const SizedBox(width: 10),
                    Text('WEEKLY LIMIT REACHED',
                      style: AppText.title.copyWith(color: AppColors.ink)),
                  ])),
                Padding(padding: const EdgeInsets.all(20),
                  child: Column(children: [
                    Container(width: double.infinity, padding: const EdgeInsets.all(16),
                      color: AppColors.cream,
                      child: Column(children: [
                        Text('2 / 2', style: TextStyle(fontSize: 36,
                          fontWeight: FontWeight.w900, color: AppColors.ink)),
                        Text('CVs used this week',
                          style: AppText.caption.copyWith(color: AppColors.dim)),
                      ])),
                    const SizedBox(height: 16),
                    Text(hoursLeft < 24
                      ? 'You can upload again in  hours.'
                      : 'You can upload again in  day.',
                      style: AppText.body.copyWith(height: 1.5),
                      textAlign: TextAlign.center),
                    const SizedBox(height: 8),
                    Text('We will remind you when your uploads reset.',
                      style: AppText.caption.copyWith(color: AppColors.dim),
                      textAlign: TextAlign.center),
                    const SizedBox(height: 20),
                    GestureDetector(
                      onTap: () => Navigator.pop(dlg),
                      child: Container(width: double.infinity, height: 46,
                        decoration: const BoxDecoration(
                          color: AppColors.blue, border: AppBorders.ink2,
                          boxShadow: [AppShadows.hard3]),
                        child: Center(child: Text('GOT IT',
                          style: AppText.button)))),
                  ])),
              ]))));
      }
      return false;
    }
    // Record this upload
    recent.add(now);
    await prefs.setStringList(_uploadKey,
      recent.map((d) => d.toIso8601String()).toList());
    return true;
  }

  Future<void> _scheduleUnlockNotification(DateTime unlockTime) async {
    try {
      final notif = FlutterLocalNotificationsPlugin();
      const android = AndroidNotificationDetails(
        'cv_unlock', 'CV Upload Reset',
        channelDescription: 'Notifies when weekly CV uploads reset',
        importance: Importance.high, priority: Priority.high,
        color: Color(0xFFE8A200));
      const details = NotificationDetails(android: android);
      // Cancel any existing unlock notification
      await notif.cancel(999);
      final tz_loc = tz.local;
      final scheduled = tz.TZDateTime.from(unlockTime, tz_loc);
      await notif.zonedSchedule(
        999,
        'Your CV uploads are back!',
        'You have 2 new CV uploads ready. Build your job-ready ATS CV now.',
        scheduled, details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle);
    } catch (e) { print('Unlock notification failed: $e'); }
  }

  Future<void> _startProcessing() async {
    if (_file == null) return;
    // Check weekly upload limit
    final allowed = await _checkWeeklyLimit();
    if (!allowed) { setState(() => _state = _S.upload); return; }
    setState(() { _state = _S.processing; _processingMsg = 'Reading your CV...'; });
    try {
      if (_fileExt == 'pdf') {
        final bytes = await _file!.readAsBytes();
        setState(() => _processingMsg = 'ITSAGO AI is analyzing your CV...');
        await _extractFromPDF(bytes);
      } else {
        final text = _extractDocxText(await _file!.readAsBytes());
        setState(() => _processingMsg = 'ITSAGO AI is analyzing your CV...');
        await _extractFromText(text);
      }
      setState(() { _state = _S.gapQA; _gapIndex = 0; _answerCtrl.clear(); });
      if (_gaps.isEmpty) _startGenerating();
    } on _NotCVException catch (e) {
      setState(() { _state = _S.upload; _docErrorType = e.docType; _docErrorMsg = e.message; _file = null; _fileName = ''; _fileExt = ''; });
    } catch (e) { _err('Failed to process CV: $e'); }
  }

  String _extractDocxText(Uint8List bytes) {
    try {
      final archive = ZipDecoder().decodeBytes(bytes);
      final doc     = archive.findFile('word/document.xml');
      if (doc == null) return '';
      return utf8.decode(doc.content as List<int>)
        .replaceAll(RegExp(r'<w:br[^>]*/>'), '\n').replaceAll(RegExp(r'<w:p[ >]'), '\n')
        .replaceAll(RegExp(r'<[^>]+>'), ' ').replaceAll('&amp;', '&').replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>').replaceAll('&quot;', '"').replaceAll(RegExp(r'\s+'), ' ').trim();
    } catch (_) { return ''; }
  }

  Future<void> _extractFromPDF(Uint8List bytes) async {
    final response = await CloudFunctionService.callClaude(
      model: _kClaudeModel, maxTokens: 2500,
      messages: [{'role': 'user', 'content': [
        {'type': 'document', 'source': {'type': 'base64', 'media_type': 'application/pdf', 'data': base64Encode(bytes)}},
        {'type': 'text', 'text': _extractPrompt},
      ]}]);
    _parseExtractionMap(response);
  }

  Future<void> _extractFromText(String text) async {
    final response = await CloudFunctionService.callClaude(
      model: _kClaudeModel, maxTokens: 2500,
      messages: [{'role': 'user', 'content': 'CV content:\n\n' + text + '\n\n' + _extractPrompt}]);
    _parseExtractionMap(response);
  }

  static const _extractPrompt = '''
You are a strict CV/resume validation and extraction specialist.

STEP 1 - DOCUMENT VALIDATION (mandatory, non-negotiable):
Carefully examine this document. A genuine CV or resume contains: applicant personal details, work experience history, education background, professional skills - structured for job applications.

Common non-CV documents to reject: bank statements, invoices, payslips, tax documents, contracts, ID documents, letters, reports, receipts, medical records, utility bills, insurance documents.

If this document is NOT a genuine CV or resume, respond ONLY with this exact JSON and nothing else:
{"error":"NOT_CV","documentType":"[2-4 word description]","message":"[One clear sentence]"}

STEP 2 - CV EXTRACTION (only proceed here if document passed Step 1):
Extract ALL information. NEVER drop certifications, achievements, awards, or courses.
Return ONLY valid JSON, no markdown:
{
  "extractedData": {
    "name":"","email":"","phone":"","location":"","linkedin":"",
    "website":"","headline":"","summary":"",
    "experience":[{"title":"","company":"","duration":"","description":""}],
    "education":[{"degree":"","institution":"","year":""}],
    "skills":[],"certifications":[],"achievements":[],"awards":[],"languages":[]
  },
  "gaps":[{"field":"fieldName","question":"Specific question asking for exact details","required":false}],
  "currentATSScore":45
}
IMPORTANT: Always extract certifications and achievements even if buried in the CV.
GRADUATE RULE: If the person has no formal work experience, look for and extract: academic projects, final year projects, WIL placements, internships, volunteer work, part-time jobs, extracurricular activities, SRC membership, sports teams. Put these in the experience array formatted professionally.
If email or phone is missing add required:true. CRITICAL: Be specific - for education ask qualification+institution+year, for experience ask jobtitle+company+duration, never ask vague questions like what is your background.
Max 5 gaps. Return ONLY the JSON.''';

  void _parseExtraction(http.Response res) {
    if (res.statusCode != 200) throw Exception('API error ${res.statusCode}');
    final body   = jsonDecode(res.body);
    final raw    = (body['content'][0]['text'] as String).replaceAll('`json', '').replaceAll('`', '').trim();
    final parsed = jsonDecode(raw);
    if (parsed['error'] == 'NOT_CV') throw _NotCVException(parsed['documentType'] ?? 'Unknown', parsed['message'] ?? 'Not a CV');
    _extracted   = parsed['extractedData'] ?? {};
    final gapList = parsed['gaps'] as List<dynamic>? ?? [];
    _gaps = gapList.map((g) => _Gap(field: g['field'] ?? '', question: g['question'] ?? '', required: g['required'] ?? false)).toList();
  }

  void _parseExtractionMap(Map<String, dynamic> body) {
    final raw    = (body['content'][0]['text'] as String).replaceAll('`json', '').replaceAll('`', '').trim();
    final parsed = jsonDecode(raw);
    if (parsed['error'] == 'NOT_CV') throw _NotCVException(parsed['documentType'] ?? 'Unknown', parsed['message'] ?? 'Not a CV');
    _extracted   = parsed['extractedData'] ?? {};
    final gapList = parsed['gaps'] as List<dynamic>? ?? [];
    _gaps = gapList.map((g) => _Gap(field: g['field'] ?? '', question: g['question'] ?? '', required: g['required'] ?? false)).toList();
  }


  void _skipGap()  { _answerCtrl.clear(); _nextGap(); }

  void _submitAnswer() {
    final ans = _answerCtrl.text.trim();
    if (ans.isNotEmpty) { _gaps[_gapIndex].answer = ans; _extracted[_gaps[_gapIndex].field] = ans; }
    _answerCtrl.clear();
    _nextGap();
  }

  void _nextGap() {
    if (_gapIndex < _gaps.length - 1) { setState(() => _gapIndex++); }
    else { _validateAndGenerate(); }
  }

  void _validateAndGenerate() {
    final email = (_extracted['email'] ?? '').toString().trim();
    final phone = (_extracted['phone'] ?? '').toString().trim();
    if (email.isEmpty && phone.isEmpty) {
      _showContactDialog('We need at least your email address or phone number to build a complete CV. Employers need a way to contact you.', true);
      return;
    }
    if (email.isEmpty) {
      _showContactDialog('Your CV is missing an email address. Employers need this to contact you - please add it.', true);
      return;
    }
    if (phone.isEmpty) {
      _showContactDialog('Your CV is missing a phone number. Add it so employers can reach you easily.', false);
      return;
    }
    _startGenerating();
  }

  void _showContactDialog(String message, bool isEmail) {
    final ctrl = TextEditingController();
    showDialog(context: context, barrierDismissible: false,
      builder: (dlg) => Dialog(backgroundColor: Colors.transparent,
        child: Container(
          decoration: BoxDecoration(color: Colors.white, border: Border.all(color: AppColors.ink, width: 2), boxShadow: const [AppShadows.hard4]),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(width: double.infinity, padding: const EdgeInsets.all(14), color: AppColors.red,
              child: Row(children: [
                const Icon(Icons.warning_rounded, color: Colors.white, size: 20),
                const SizedBox(width: 10),
                Text(isEmail ? 'EMAIL REQUIRED' : 'PHONE REQUIRED',
                  style: AppText.title.copyWith(color: Colors.white)),
              ])),
            Padding(padding: const EdgeInsets.all(20),
              child: Column(children: [
                Text(message, style: AppText.body.copyWith(height: 1.5)),
                const SizedBox(height: 16),
                Container(
                  decoration: BoxDecoration(border: Border.all(color: AppColors.ink, width: 2)),
                  child: TextField(
                    controller: ctrl,
                    keyboardType: isEmail ? TextInputType.emailAddress : TextInputType.phone,
                    style: TextStyle(fontSize: 13, color: AppColors.ink),
                    decoration: InputDecoration(
                      hintText: isEmail ? 'your@email.com' : '071 234 5678',
                      hintStyle: TextStyle(color: AppColors.dim),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.all(14),
                      filled: true, fillColor: AppColors.white))),
                const SizedBox(height: 16),
                Row(children: [
                  Expanded(child: GestureDetector(
                    onTap: () => Navigator.pop(dlg),
                    child: Container(height: 44,
                      decoration: BoxDecoration(border: Border.all(color: AppColors.mist, width: 1.5)),
                      child: Center(child: Text('GO BACK', style: AppText.label.copyWith(color: AppColors.dim)))))),
                  const SizedBox(width: 12),
                  Expanded(child: GestureDetector(
                    onTap: () {
                      final val = ctrl.text.trim();
                      if (val.isEmpty) return;
                      _extracted[isEmail ? 'email' : 'phone'] = val;
                      Navigator.pop(dlg);
                      _validateAndGenerate();
                    },
                    child: Container(height: 44,
                      decoration: const BoxDecoration(color: AppColors.blue, border: AppBorders.ink2, boxShadow: [AppShadows.hard3]),
                      child: Center(child: Text('ADD & CONTINUE', style: AppText.button))))),
                ]),
              ])),
          ]))));
  }

  Future<void> _startGenerating() async {
    setState(() { _state = _S.generating; _genProgress = 0.0; });
    try {
      await _optimizeWithAI();
      setState(() => _genProgress = 0.08);
      _pdfs.clear();
      final gens = [_execDesign, _spectrumDesign, _minimalDesign, _gridDesign, _ubuntuDesign, _vividDesign];
      for (int i = 0; i < gens.length; i++) {
        try {
          _pdfs.add(await gens[i]());
          setState(() => _genProgress = 0.08 + ((i + 1) / 6) * 0.92);
          await Future.delayed(const Duration(milliseconds: 200));
        } catch (e) {
          print('Design $i failed: $e');
          throw Exception('Design ${["EXEC","SPEC","MIN","GRID"][i]} failed: $e');
        }
      }
      await _saveToFirebase();
      await _saveAllLocally();
      setState(() => _state = _S.designPicker);
      _saveSession();
    } catch (e) { _err('Failed to generate CVs: $e'); }
  }
  Future<void> _saveToFirebase() async {
    try {
      if (FirebaseAuth.instance.currentUser == null) return;
      final originalBytes  = _file != null ? await _file!.readAsBytes() : null;
      final optimisedPdf   = _pdfs.isNotEmpty ? _pdfs[0] : null;
      final optimisedDocx = _optimized.isNotEmpty ? _buildDocx() : null;
      final company        = _optimized['name'] as String? ?? 'My CV';
      final jobTitle       = _optimized['headline'] as String? ?? '';
      final beforeScoreVal = _extracted['currentATSScore'] as int? ?? 45;
      final afterScoreVal  = _optimized['atsScore'] as int? ?? 80;
      final consent = await CVStorageService.hasConsent();
      if (!consent) await CVStorageService.recordConsent();
      final before = ATSScore(score: beforeScoreVal, grade: beforeScoreVal >= 70 ? 'B' : 'C',
        summary: 'Before optimisation', keywordsFound: [], keywordsMissing: [], strengths: [], weaknesses: [], quickWins: []);
      final after  = ATSScore(score: afterScoreVal,  grade: afterScoreVal  >= 80 ? 'A' : 'B',
        summary: 'After ITSAGO AI optimisation', keywordsFound: [], keywordsMissing: [], strengths: [], weaknesses: [], quickWins: []);
      await CVStorageService.saveCVRecord(
        company:          company,
        jobTitle:         jobTitle,
        beforeScore:      before,
        afterScore:       after,
        originalPdfBytes: originalBytes,
        optimisedPdfBytes: optimisedPdf,
        optimisedDocxBytes: optimisedDocx,
        designIndex:      _selectedDesign,
        cvName:           _optimized['name']     as String? ?? '',
        cvHeadline:       _optimized['headline'] as String? ?? '',
        cvSkills:         _list('skills').take(6).toList(),
        cvSummary:        (_optimized['summary'] as String? ?? '').length > 150
                          ? (_optimized['summary'] as String).substring(0, 150) + '...'
                          : _optimized['summary'] as String? ?? '');
    } catch (e) { print('Firebase CV save failed: $e'); }
  }

  Future<void> _saveAllLocally() async {
    try {
      final dir  = await _saveDir();
      final name = _safeName().isEmpty ? 'ITSAGO_CV' : _safeName();
      final ts   = _ts();
      for (int i = 0; i < _pdfs.length; i++) {
        final file = File('${dir.path}/${name}_${_designNames[i]}_$ts.pdf');
        await file.writeAsBytes(_pdfs[i]);
      }
      print('All 4 CVs saved locally to ${(await _saveDir()).path}');
    } catch (e) { print('Local save failed: $e'); }
  }

  Future<void> _optimizeWithAI() async {
    final answers = _gaps.where((g) => g.answer != null).map((g) => g.field + ': ' + (g.answer ?? '')).join('\n');
    final response = await CloudFunctionService.callClaude(
      model: _kClaudeModel, maxTokens: 2500,
      messages: [{'role': 'user', 'content':
        'You are an ATS CV optimizer. Rewrite this CV to maximise ATS score.\n'
        'Original data: ' + jsonEncode(_extracted) + '\n'
        'Additional answers: ' + answers + '\n'
        'Return ONLY valid JSON with these fields: name, headline, email, phone, location, linkedin, summary, experience, education, skills, certifications, achievements, awards, languages, atsScore.\n'
        'CRITICAL: Preserve ALL certifications achievements and awards.\n'
        'GRADUATE RULE: Use academic projects WIL volunteer for experience if no formal work.\n'
        'SUMMARY RULE: Write compelling 2-3 sentence summary never leave blank.\n'
        'Use action verbs in all bullets. Return ONLY the JSON.'}]);


    if (response['type'] == 'error') throw Exception('Optimization failed');
    final raw = CloudFunctionService.extractText(response).replaceAll('`json', '').replaceAll('`', '').trim();
    _optimized = jsonDecode(raw);
  }


  String _s(String k, [String fb = '']) { final v = (_optimized[k] ?? fb).toString(); return v.replaceAll('\u2013', '-').replaceAll('\u2014', '-'); }
  List<String> _list(String k) { final v = _optimized[k]; return v is List ? v.map((e) => e.toString()).toList() : []; }
  List<Map<String, dynamic>> _exp() { final v = _optimized['experience']; if (v is! List) return []; return v.map((e) { final m = Map<String,dynamic>.from(e); m.forEach((k, val) { if (val is String) m[k] = val.replaceAll('\u2013', '-').replaceAll('\u2014', '-'); }); return m; }).toList(); }
  List<Map<String, dynamic>> _edu() { final v = _optimized['education']; if (v is! List) return []; return v.map((e) { final m = Map<String,dynamic>.from(e); m.forEach((k, val) { if (val is String) m[k] = val.replaceAll('\u2013', '-').replaceAll('\u2014', '-'); }); return m; }).toList(); }
  List<String> _bullets(Map<String, dynamic> exp) {
    final b = exp['bullets'];
    if (b is List && b.isNotEmpty) return b.map((e) => e.toString()).toList();
    final d = exp['description'];
    return d != null && d.toString().isNotEmpty ? [d.toString()] : [];
  }
  String _contact() => [_s('email'), _s('phone'), _s('location')].where((v) => v.isNotEmpty).join('  |  ');

  Future<Uint8List> _execDesign() async {
    const navy = PdfColor.fromInt(0xFF1C1C3A); const gold = PdfColor.fromInt(0xFFD4AF37);
    const dark = PdfColor.fromInt(0xFF1A1A1A); const muted = PdfColor.fromInt(0xFF666666);
    final doc = pw.Document();
    doc.addPage(pw.MultiPage(pageFormat: PdfPageFormat.a4, margin: pw.EdgeInsets.zero, build: (ctx) => [
      pw.Container(color: navy, padding: const pw.EdgeInsets.all(30), child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        pw.Text(_s('name').toUpperCase(), style: pw.TextStyle(fontSize: 26, fontWeight: pw.FontWeight.bold, color: PdfColors.white, letterSpacing: 3)),
        pw.SizedBox(height: 6), pw.Container(width: 60, height: 3, color: gold), pw.SizedBox(height: 8),
        if (_s('headline').isNotEmpty) pw.Text(_s('headline'), style: pw.TextStyle(fontSize: 12, color: gold, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 10),
        pw.Text(_contact(), style: pw.TextStyle(fontSize: 10, color: PdfColor(1,1,1,0.7))),
        if (_s('linkedin').isNotEmpty) ...[pw.SizedBox(height: 4), pw.Text(_s('linkedin'), style: pw.TextStyle(fontSize: 9, color: PdfColor(1,1,1,0.54)))],
      ])),
      pw.Container(padding: const pw.EdgeInsets.all(30), child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        if (_s('summary').isNotEmpty) ...[_eSec('PROFESSIONAL SUMMARY', gold, navy), pw.SizedBox(height: 8), pw.Text(_s('summary'), style: pw.TextStyle(fontSize: 11, color: dark, lineSpacing: 2)), pw.SizedBox(height: 20)],
        if (_exp().isNotEmpty) ...[_eSec('PROFESSIONAL EXPERIENCE', gold, navy), pw.SizedBox(height: 10),
          ..._exp().map((e) => pw.Container(margin: const pw.EdgeInsets.only(bottom: 16), child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            pw.Text(e['title'].toString().toUpperCase(), style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: dark)),
            pw.SizedBox(height: 2),
            pw.Text('${e['company']}  |  ${e['duration']}', style: pw.TextStyle(fontSize: 10, color: muted, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 5),
            ..._bullets(e).map((b) => pw.Padding(padding: const pw.EdgeInsets.only(bottom: 3),
              child: pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                pw.Text('- ', style: pw.TextStyle(fontSize: 10, color: gold)),
                pw.Expanded(child: pw.Text(b, style: pw.TextStyle(fontSize: 10, color: dark, lineSpacing: 1.5))),
              ]))),
          ]))), pw.SizedBox(height: 10)],
        if (_edu().isNotEmpty) ...[_eSec('EDUCATION', gold, navy), pw.SizedBox(height: 10),
          ..._edu().map((e) => pw.Container(margin: const pw.EdgeInsets.only(bottom: 10), child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            pw.Text(e['degree'].toString().toUpperCase(), style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: dark)),
            pw.Text('${e['institution']}  |  ${e['year']}', style: pw.TextStyle(fontSize: 10, color: muted)),
          ]))), pw.SizedBox(height: 10)],
        if (_list('certifications').isNotEmpty) ...[_eSec('CERTIFICATIONS', gold, navy), pw.SizedBox(height: 10),
          ..._list('certifications').map((c) => pw.Padding(padding: const pw.EdgeInsets.only(bottom: 4),
            child: pw.Row(children: [pw.Container(width: 6, height: 6, color: gold), pw.SizedBox(width: 8), pw.Text(c, style: pw.TextStyle(fontSize: 10, color: dark))]))),
          pw.SizedBox(height: 10)],
        if (_list('achievements').isNotEmpty) ...[_eSec('ACHIEVEMENTS & AWARDS', gold, navy), pw.SizedBox(height: 10),
          ..._list('achievements').map((a) => pw.Padding(padding: const pw.EdgeInsets.only(bottom: 4),
            child: pw.Row(children: [pw.Container(width: 6, height: 6, color: gold), pw.SizedBox(width: 8), pw.Text(a, style: pw.TextStyle(fontSize: 10, color: dark))]))),
          pw.SizedBox(height: 10)],
        if (_list('skills').isNotEmpty) ...[_eSec('CORE COMPETENCIES', gold, navy), pw.SizedBox(height: 10),
          pw.Wrap(spacing: 8, runSpacing: 6, children: _list('skills').map((s) => pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: pw.BoxDecoration(border: pw.Border.all(color: gold, width: 1)),
            child: pw.Text(s, style: pw.TextStyle(fontSize: 9, color: dark)))).toList())],
      ])),
    ]));
    return doc.save();
  }

  pw.Widget _eSec(String t, PdfColor accent, PdfColor titleC) => pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
    pw.Text(t, style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: titleC, letterSpacing: 2)),
    pw.SizedBox(height: 4), pw.Container(width: double.infinity, height: 1, color: accent),
  ]);

  Future<Uint8List> _spectrumDesign() async {
    const sidebar = PdfColor.fromInt(0xFF2E4057); const teal = PdfColor.fromInt(0xFF048A81); const dark = PdfColor.fromInt(0xFF1A1A1A);
    const sidebarW = 175.0;
    final mainW = PdfPageFormat.a4.width - sidebarW;
    final doc = pw.Document();
    final sidebarContent = <pw.Widget>[
      pw.Text(_s('name').split(' ').first.toUpperCase(), style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: PdfColors.white, letterSpacing: 2)),
      if (_s('name').split(' ').length > 1) pw.Text(_s('name').split(' ').skip(1).join(' ').toUpperCase(), style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: teal, letterSpacing: 2)),
      pw.SizedBox(height: 6), pw.Container(width: 36, height: 3, color: teal), pw.SizedBox(height: 8),
      if (_s('headline').isNotEmpty) pw.Text(_s('headline'), style: pw.TextStyle(fontSize: 9, color: PdfColor(1,1,1,0.7))),
      pw.SizedBox(height: 20), _spSH('CONTACT', teal), pw.SizedBox(height: 6),
      if (_s('email').isNotEmpty)    _spST(_s('email')),
      if (_s('phone').isNotEmpty)    _spST(_s('phone')),
      if (_s('location').isNotEmpty) _spST(_s('location')),
      if (_s('linkedin').isNotEmpty) _spST(_s('linkedin')),
      pw.SizedBox(height: 18),
      if (_list('skills').isNotEmpty) ...[_spSH('SKILLS', teal), pw.SizedBox(height: 8),
        ..._list('skills').take(9).map((s) => pw.Container(margin: const pw.EdgeInsets.only(bottom: 6), child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          pw.Text(s, style: pw.TextStyle(fontSize: 8, color: PdfColors.white)), pw.SizedBox(height: 3),
          pw.Container(width: 130, height: 3, color: PdfColor(1,1,1,0.2), child: pw.Align(alignment: pw.Alignment.centerLeft, child: pw.Container(width: 100, height: 3, color: teal))),
        ])))],
      if (_list('certifications').isNotEmpty) ...[pw.SizedBox(height: 18), _spSH('CERTIFICATIONS', teal), pw.SizedBox(height: 6),
        ..._list('certifications').map((c) => pw.Text('- $c', style: pw.TextStyle(fontSize: 8, color: PdfColors.white)))],
      if (_list('languages').isNotEmpty) ...[pw.SizedBox(height: 18), _spSH('LANGUAGES', teal), pw.SizedBox(height: 6),
        ..._list('languages').map((l) => pw.Text('- $l', style: pw.TextStyle(fontSize: 8, color: PdfColors.white)))],
    ];
    doc.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: pw.EdgeInsets.zero,
      build: (ctx) => [
        pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          pw.Container(width: sidebarW, color: sidebar, padding: const pw.EdgeInsets.all(20),
            child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: sidebarContent)),
          pw.SizedBox(width: mainW, child: pw.Container(padding: const pw.EdgeInsets.all(24),
            child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
              if (_s('summary').isNotEmpty) ...[_spH('ABOUT ME', teal), pw.SizedBox(height: 8), pw.Text(_s('summary'), style: pw.TextStyle(fontSize: 10, color: dark, lineSpacing: 1.9)), pw.SizedBox(height: 18)],
              if (_exp().isNotEmpty) ...[_spH('EXPERIENCE', teal), pw.SizedBox(height: 10),
                ..._exp().map((e) => pw.Container(margin: const pw.EdgeInsets.only(bottom: 14), child: pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                  pw.Container(width: 3, height: 52, color: teal, margin: const pw.EdgeInsets.only(right: 10, top: 2)),
                  pw.Expanded(child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                    pw.Text(e['title'].toString(), style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: dark)),
                    pw.Text('${e['company']}  -  ${e['duration']}', style: pw.TextStyle(fontSize: 9, color: teal, fontWeight: pw.FontWeight.bold)),
                    pw.SizedBox(height: 4),
                    ..._bullets(e).take(3).map((b) => pw.Text('- $b', style: pw.TextStyle(fontSize: 9, color: dark, lineSpacing: 1.5))),
                  ])),
                ])))],
              if (_edu().isNotEmpty) ...[_spH('EDUCATION', teal), pw.SizedBox(height: 8),
                ..._edu().map((e) => pw.Container(margin: const pw.EdgeInsets.only(bottom: 8), child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                  pw.Text(e['degree'].toString(), style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: dark)),
                  pw.Text('${e['institution']}  -  ${e['year']}', style: pw.TextStyle(fontSize: 9, color: teal)),
                ])))],
              if (_list('achievements').isNotEmpty) ...[_spH('ACHIEVEMENTS', teal), pw.SizedBox(height: 8),
                ..._list('achievements').map((a) => pw.Text('- $a', style: pw.TextStyle(fontSize: 9, color: dark, lineSpacing: 1.5)))],
            ]))),
        ]),
      ]));
    return doc.save();
  }

  pw.Widget _spSH(String t, PdfColor a) => pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
    pw.Text(t, style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: a, letterSpacing: 2)),
    pw.SizedBox(height: 3), pw.Container(width: 28, height: 1, color: a),
  ]);
  pw.Widget _spST(String t) => pw.Padding(padding: const pw.EdgeInsets.only(bottom: 4), child: pw.Text(t, style: pw.TextStyle(fontSize: 8, color: PdfColor(1,1,1,0.7))));
  pw.Widget _spH(String t, PdfColor a) => pw.Row(children: [
    pw.Container(width: 4, height: 14, color: a), pw.SizedBox(width: 8),
    pw.Text(t, style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: const PdfColor.fromInt(0xFF2E4057), letterSpacing: 1.5)),
  ]);

  Future<Uint8List> _minimalDesign() async {
    const dark = PdfColor.fromInt(0xFF1A1A1A); const gray = PdfColor.fromInt(0xFF888888);
    const line = PdfColor.fromInt(0xFFDDDDDD); const accent = PdfColor.fromInt(0xFF333333);
    final doc = pw.Document();
    doc.addPage(pw.MultiPage(pageFormat: PdfPageFormat.a4, margin: const pw.EdgeInsets.all(48), build: (ctx) => [
      pw.Center(child: pw.Column(children: [
        pw.Text(_s('name').toUpperCase(), style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold, color: dark, letterSpacing: 6)),
        pw.SizedBox(height: 6),
        if (_s('headline').isNotEmpty) pw.Text(_s('headline'), style: pw.TextStyle(fontSize: 11, color: gray, letterSpacing: 1)),
        pw.SizedBox(height: 10), pw.Container(width: double.infinity, height: 0.5, color: line), pw.SizedBox(height: 7),
        pw.Text(_contact(), style: pw.TextStyle(fontSize: 9, color: gray)),
        if (_s('linkedin').isNotEmpty) ...[pw.SizedBox(height: 3), pw.Text(_s('linkedin'), style: pw.TextStyle(fontSize: 9, color: gray))],
        pw.SizedBox(height: 7), pw.Container(width: double.infinity, height: 0.5, color: line),
      ])),
      pw.SizedBox(height: 22),
      if (_s('summary').isNotEmpty) ...[_mSec('PROFILE', line, accent), pw.SizedBox(height: 8), pw.Text(_s('summary'), style: pw.TextStyle(fontSize: 10, color: dark, lineSpacing: 2)), pw.SizedBox(height: 20)],
      if (_exp().isNotEmpty) ...[_mSec('EXPERIENCE', line, accent), pw.SizedBox(height: 10),
        ..._exp().map((e) => pw.Container(margin: const pw.EdgeInsets.only(bottom: 14), child: pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          pw.SizedBox(width: 88, child: pw.Text(e['duration'].toString(), style: pw.TextStyle(fontSize: 8, color: gray))),
          pw.Expanded(child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            pw.Text(e['title'].toString(), style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: dark)),
            pw.Text(e['company'].toString(), style: pw.TextStyle(fontSize: 9, color: gray)),
            pw.SizedBox(height: 4),
            ..._bullets(e).take(3).map((b) => pw.Text('- $b', style: pw.TextStyle(fontSize: 9, color: dark, lineSpacing: 1.5))),
          ])),
        ]))), pw.SizedBox(height: 8)],
      pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        pw.Expanded(child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          if (_edu().isNotEmpty) ...[_mSec('EDUCATION', line, accent), pw.SizedBox(height: 8),
            ..._edu().map((e) => pw.Container(margin: const pw.EdgeInsets.only(bottom: 8), child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
              pw.Text(e['degree'].toString(), style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: dark)),
              pw.Text(e['institution'].toString(), style: pw.TextStyle(fontSize: 8, color: gray)),
              pw.Text(e['year'].toString(), style: pw.TextStyle(fontSize: 8, color: gray)),
            ])))],
          if (_list('certifications').isNotEmpty) ...[pw.SizedBox(height: 10), _mSec('CERTIFICATIONS', line, accent), pw.SizedBox(height: 8),
            ..._list('certifications').map((c) => pw.Text('- $c', style: pw.TextStyle(fontSize: 9, color: dark)))],
        ])),
        pw.SizedBox(width: 28),
        pw.Expanded(child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          if (_list('skills').isNotEmpty) ...[_mSec('SKILLS', line, accent), pw.SizedBox(height: 8),
            pw.Wrap(spacing: 5, runSpacing: 4, children: _list('skills').map((s) => pw.Text('$s  .', style: pw.TextStyle(fontSize: 9, color: dark))).toList())],
          if (_list('achievements').isNotEmpty) ...[pw.SizedBox(height: 10), _mSec('ACHIEVEMENTS', line, accent), pw.SizedBox(height: 8),
            ..._list('achievements').map((a) => pw.Text('- $a', style: pw.TextStyle(fontSize: 9, color: dark)))],
        ])),
      ]),
    ]));
    return doc.save();
  }

  pw.Widget _mSec(String t, PdfColor line, PdfColor accent) => pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
    pw.Text(t, style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: accent, letterSpacing: 3)),
    pw.SizedBox(height: 4), pw.Container(width: double.infinity, height: 0.5, color: line),
  ]);

  Future<Uint8List> _gridDesign() async {
    const blue  = PdfColor.fromInt(0xFF1565C0); const red   = PdfColor.fromInt(0xFFE53935);
    const dark  = PdfColor.fromInt(0xFF212121); const lgray = PdfColor.fromInt(0xFFF0F0F0); const mgray = PdfColor.fromInt(0xFF757575);
    final doc = pw.Document();
    doc.addPage(pw.MultiPage(pageFormat: PdfPageFormat.a4, margin: pw.EdgeInsets.zero, build: (ctx) => [
      pw.Container(color: blue, padding: const pw.EdgeInsets.symmetric(horizontal: 28, vertical: 20), child: pw.Row(children: [
        pw.Expanded(flex: 3, child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          pw.Text(_s('name').toUpperCase(), style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold, color: PdfColors.white, letterSpacing: 2)),
          pw.SizedBox(height: 4), pw.Container(width: 44, height: 3, color: red), pw.SizedBox(height: 6),
          if (_s('headline').isNotEmpty) pw.Text(_s('headline'), style: pw.TextStyle(fontSize: 10, color: PdfColor(1,1,1,0.7))),
        ])),
        pw.SizedBox(width: 20),
        pw.Expanded(flex: 2, child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          if (_s('email').isNotEmpty)    pw.Text(_s('email'),    style: pw.TextStyle(fontSize: 9, color: PdfColor(1,1,1,0.7))),
          if (_s('phone').isNotEmpty)    pw.Text(_s('phone'),    style: pw.TextStyle(fontSize: 9, color: PdfColor(1,1,1,0.7))),
          if (_s('location').isNotEmpty) pw.Text(_s('location'), style: pw.TextStyle(fontSize: 9, color: PdfColor(1,1,1,0.7))),
          if (_s('linkedin').isNotEmpty) pw.Text(_s('linkedin'), style: pw.TextStyle(fontSize: 8, color: PdfColor(1,1,1,0.54))),
        ])),
      ])),
      if (_s('summary').isNotEmpty) pw.Container(padding: const pw.EdgeInsets.fromLTRB(28, 16, 28, 0), child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [_gSec('SUMMARY', blue, red), pw.SizedBox(height: 8), pw.Text(_s('summary'), style: pw.TextStyle(fontSize: 10, color: dark, lineSpacing: 1.8))])),
      if (_list('skills').isNotEmpty) pw.Container(padding: const pw.EdgeInsets.fromLTRB(28, 14, 28, 0), child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [_gSec('SKILLS', blue, red), pw.SizedBox(height: 8), pw.Wrap(spacing: 6, runSpacing: 4, children: _list('skills').map((s) => pw.Container(padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4), color: lgray, child: pw.Text(s, style: pw.TextStyle(fontSize: 8, color: dark)))).toList())])),
      if (_exp().isNotEmpty) pw.Container(padding: const pw.EdgeInsets.fromLTRB(28, 14, 28, 0), child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        _gSec('EXPERIENCE', blue, red), pw.SizedBox(height: 10),
        ..._exp().map((e) => pw.Container(margin: const pw.EdgeInsets.only(bottom: 14), child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          pw.Row(children: [pw.Expanded(child: pw.Text(e['title'].toString(), style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: dark))), pw.Text(e['duration'].toString(), style: pw.TextStyle(fontSize: 8, color: mgray))]),
          pw.Text(e['company'].toString(), style: pw.TextStyle(fontSize: 9, color: blue, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 4),
          ..._bullets(e).take(3).map((b) => pw.Padding(padding: const pw.EdgeInsets.only(bottom: 2), child: pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [pw.Container(width: 4, height: 4, color: red, margin: const pw.EdgeInsets.only(top: 4, right: 6)), pw.Expanded(child: pw.Text(b, style: pw.TextStyle(fontSize: 9, color: dark, lineSpacing: 1.4)))]))),
        ]))),
      ])),
      if (_edu().isNotEmpty) pw.Container(padding: const pw.EdgeInsets.fromLTRB(28, 14, 28, 0), child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [_gSec('EDUCATION', blue, red), pw.SizedBox(height: 8), ..._edu().map((e) => pw.Container(margin: const pw.EdgeInsets.only(bottom: 10), child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [pw.Text(e['degree'].toString(), style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: dark)), pw.Text(e['institution'].toString(), style: pw.TextStyle(fontSize: 8, color: mgray)), pw.Text(e['year'].toString(), style: pw.TextStyle(fontSize: 8, color: mgray))])))])),
      if (_list('certifications').isNotEmpty) pw.Container(padding: const pw.EdgeInsets.fromLTRB(28, 14, 28, 0), child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [_gSec('CERTIFICATIONS', blue, red), pw.SizedBox(height: 8), ..._list('certifications').map((c) => pw.Text('- $c', style: pw.TextStyle(fontSize: 8, color: dark)))])),
      if (_list('achievements').isNotEmpty) pw.Container(padding: const pw.EdgeInsets.fromLTRB(28, 14, 28, 0), child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [_gSec('ACHIEVEMENTS', blue, red), pw.SizedBox(height: 8), ..._list('achievements').map((a) => pw.Text('- $a', style: pw.TextStyle(fontSize: 9, color: dark, lineSpacing: 1.5)))])),
    ]));
    return doc.save();
  }

  pw.Widget _gSec(String t, PdfColor b, PdfColor r) => pw.Row(children: [
    pw.Container(width: 3, height: 13, color: r), pw.SizedBox(width: 6),
    pw.Text(t, style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: b, letterSpacing: 1.5)),
  ]);

  Future<void> _downloadPDF() async {
    if (_pdfs.isEmpty) return;
    try {
      final dir  = await _saveDir();
      final name = '${_safeName()}_CV_${_designNames[_selectedDesign]}_${_ts()}.pdf';
      await File('${dir.path}/$name').writeAsBytes(_pdfs[_selectedDesign]);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('PDF saved to Downloads', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
        backgroundColor: AppColors.blue, duration: const Duration(seconds: 3)));
    } catch (e) { _err('Could not save PDF: $e'); }
  }

  Future<void> _downloadWord() async {
    if (_optimized.isEmpty) return;
    try {
      final dir  = await _saveDir();
      final name = '${_safeName()}_CV_${_designNames[_selectedDesign]}_${_ts()}.docx';
      await File('${dir.path}/$name').writeAsBytes(_buildDocx());
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Word document saved to Downloads', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
        backgroundColor: AppColors.blue, duration: const Duration(seconds: 3)));
    } catch (e) { _err('Could not save Word document: $e'); }
  }

  Future<void> _share() async {
    if (_pdfs.isEmpty) return;
    try {
      final tmp  = await getTemporaryDirectory();
      final file = File('${tmp.path}/${_safeName()}_CV.pdf');
      await file.writeAsBytes(_pdfs[_selectedDesign]);
      await Share.shareXFiles([XFile(file.path)], subject: '${_s('name')} - CV', text: 'My job-ready ATS CV built with ITSAGO AI.');
    } catch (e) { if (mounted) _err('Could not share: $e'); }
  }

  Future<void> _shareWhatsApp() async {
    if (_pdfs.isEmpty) return;
    try {
      final tmp  = await getTemporaryDirectory();
      final file = File('${tmp.path}/${_safeName()}_CV.pdf');
      await file.writeAsBytes(_pdfs[_selectedDesign]);
      final before = (_extracted['currentATSScore'] as num?)?.toInt() ?? 45;
      final after  = (_optimized['atsScore']  as num?)?.toInt()  ?? 80;
      await Share.shareXFiles(
        [XFile(file.path)],
        subject: '${_s('name')} - Job-Ready ATS CV',
        text: 'My CV went from $before% to $after% with ITSAGO AI! '
              'Download the free app to build your job-ready ATS CV: '
              'https://play.google.com/store/apps/details?id=com.itsago.interviewai',
      );
    } catch (e) { if (mounted) _err('Could not share: $e'); }
  }

  Future<Directory> _saveDir() async {
    if (Platform.isAndroid) { final d = Directory('/storage/emulated/0/Download'); if (await d.exists()) return d; }
    return getApplicationDocumentsDirectory();
  }

  String _safeName() => _s('name').replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '_');
  String _ts()       => DateTime.now().millisecondsSinceEpoch.toString();

  Uint8List _buildDocx() {
    // Helpers
    String esc(String s) => s.replaceAll('\u2013', '-').replaceAll('\u2014', '-').replaceAll('&','&amp;').replaceAll('<','&lt;').replaceAll('>','&gt;').replaceAll('"','&quot;');

    // Design colours based on selected design
    final headerBg = ['1C1C3A','2E4057','333333','1565C0'][_selectedDesign];
    final accentHex = ['D4AF37','048A81','333333','E53935'][_selectedDesign];

    String rgb(String hex) => '${int.parse(hex.substring(0,2),radix:16)} ${int.parse(hex.substring(2,4),radix:16)} ${int.parse(hex.substring(4,6),radix:16)}';

    // Paragraph helpers
    String heading(String text, String colorHex, {double size = 28, bool bold = true, String? bgHex}) {
      final bg = bgHex != null ? '<w:shd w:val="clear" w:color="auto" w:fill="$bgHex"/>' : '';
      return '<w:p><w:pPr><w:pStyle w:val="Normal"/><w:spacing w:after="0"/><w:pBdr><w:bottom w:val="single" w:sz="4" w:space="1" w:color="$accentHex"/></w:pBdr><w:jc w:val="left"/>$bg</w:pPr>'
        '<w:r><w:rPr><w:b/><w:color w:val="$colorHex"/><w:sz w:val="${(size*2).toInt()}"/></w:rPr><w:t>${esc(text)}</w:t></w:r></w:p>';
    }

    String subheading(String text, String colorHex, {double size = 11}) =>
      '<w:p><w:pPr><w:spacing w:after="0"/></w:pPr>'
      '<w:r><w:rPr><w:b/><w:color w:val="$colorHex"/><w:sz w:val="${(size*2).toInt()}"/></w:rPr><w:t>${esc(text)}</w:t></w:r></w:p>';

    String sectionHeader(String text) =>
      '<w:p><w:pPr><w:spacing w:before="160" w:after="60"/>'
      '<w:pBdr><w:bottom w:val="single" w:sz="6" w:space="1" w:color="$accentHex"/></w:pBdr></w:pPr>'
      '<w:r><w:rPr><w:b/><w:color w:val="$headerBg"/><w:sz w:val="22"/><w:caps/></w:rPr><w:t>${esc(text)}</w:t></w:r></w:p>';

    String bodyText(String text, {double size = 10}) =>
      '<w:p><w:pPr><w:spacing w:after="40"/></w:pPr>'
      '<w:r><w:rPr><w:sz w:val="${(size*2).toInt()}"/></w:rPr><w:t xml:space="preserve">${esc(text)}</w:t></w:r></w:p>';

    String bulletItem(String text) =>
      '<w:p><w:pPr><w:ind w:left="360"/><w:spacing w:after="40"/></w:pPr>'
      '<w:r><w:rPr><w:sz w:val="20"/></w:rPr><w:t xml:space="preserve">- ${esc(text)}</w:t></w:r></w:p>';

    String contactLine(String text, String colorHex) =>
      '<w:p><w:pPr><w:spacing w:after="0"/></w:pPr>'
      '<w:r><w:rPr><w:color w:val="$colorHex"/><w:sz w:val="18"/></w:rPr><w:t>${esc(text)}</w:t></w:r></w:p>';

    String spacer() => '<w:p><w:pPr><w:spacing w:after="80"/></w:pPr></w:p>';

    // Build document body
    final buf = StringBuffer();

    // - HEADER BLOCK -
    buf.write('<w:p><w:pPr><w:shd w:val="clear" w:color="auto" w:fill="$headerBg"/>'
      '<w:spacing w:before="200" w:after="40"/></w:pPr>'
      '<w:r><w:rPr><w:b/><w:color w:val="FFFFFF"/><w:sz w:val="52"/></w:rPr>'
      '<w:t>${esc(_s('name').toUpperCase())}</w:t></w:r></w:p>');

    if (_s('headline').isNotEmpty)
      buf.write('<w:p><w:pPr><w:shd w:val="clear" w:color="auto" w:fill="$headerBg"/>'
        '<w:spacing w:after="40"/></w:pPr>'
        '<w:r><w:rPr><w:b/><w:color w:val="$accentHex"/><w:sz w:val="24"/></w:rPr>'
        '<w:t>${esc(_s('headline'))}</w:t></w:r></w:p>');

    if (_contact().isNotEmpty)
      buf.write('<w:p><w:pPr><w:shd w:val="clear" w:color="auto" w:fill="$headerBg"/>'
        '<w:spacing w:after="200"/></w:pPr>'
        '<w:r><w:rPr><w:color w:val="CCCCCC"/><w:sz w:val="18"/></w:rPr>'
        '<w:t>${esc(_contact())}</w:t></w:r></w:p>');

    buf.write(spacer());

    // - SUMMARY -
    if (_s('summary').isNotEmpty) {
      buf.write(sectionHeader('Professional Summary'));
      buf.write(bodyText(_s('summary')));
      buf.write(spacer());
    }

    // - EXPERIENCE -
    if (_exp().isNotEmpty) {
      buf.write(sectionHeader('Professional Experience'));
      for (final e in _exp()) {
        buf.write(subheading('${e['title']}', headerBg, size: 12));
        buf.write(bodyText('${e['company']}  |  ${e['duration']}', size: 10));
        for (final b in _bullets(e)) buf.write(bulletItem(b));
        buf.write(spacer());
      }
    }

    // - EDUCATION -
    if (_edu().isNotEmpty) {
      buf.write(sectionHeader('Education'));
      for (final e in _edu()) {
        buf.write(subheading(e['degree'].toString(), headerBg, size: 11));
        buf.write(bodyText('${e['institution']}  |  ${e['year']}'));
        buf.write(spacer());
      }
    }

    // - SKILLS -
    if (_list('skills').isNotEmpty) {
      buf.write(sectionHeader('Core Competencies'));
      buf.write(bodyText(_list('skills').join('   -   ')));
      buf.write(spacer());
    }

    // - CERTIFICATIONS -
    if (_list('certifications').isNotEmpty) {
      buf.write(sectionHeader('Certifications'));
      for (final c in _list('certifications')) buf.write(bulletItem(c));
      buf.write(spacer());
    }

    // - ACHIEVEMENTS -
    if (_list('achievements').isNotEmpty) {
      buf.write(sectionHeader('Achievements & Awards'));
      for (final a in _list('achievements')) buf.write(bulletItem(a));
      buf.write(spacer());
    }

    // - LANGUAGES -
    if (_list('languages').isNotEmpty) {
      buf.write(sectionHeader('Languages'));
      buf.write(bodyText(_list('languages').join('   -   ')));
    }

    // DOCX package
    const ct = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
      '<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">'
      '<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>'
      '<Default Extension="xml" ContentType="application/xml"/>'
      '<Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/>'
      '<Override PartName="/word/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.styles+xml"/>'
      '</Types>';

    const rels = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
      '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
      '<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/>'
      '</Relationships>';

    const wRels = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
      '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
      '<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/>'
      '</Relationships>';

    final stylesXml = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
      '<w:styles xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">'
      '<w:style w:type="paragraph" w:styleId="Normal"><w:name w:val="Normal"/>'
      '<w:rPr><w:sz w:val="20"/></w:rPr></w:style>'
      '</w:styles>';

    final docXml = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
      '<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">'
      '<w:body>'
      '<w:sectPr><w:pgMar w:top="720" w:right="720" w:bottom="720" w:left="720"/></w:sectPr>'
      '${buf.toString()}'
      '</w:body></w:document>';

    final archive = Archive();
    void add(String n, String c) {
      final b = utf8.encode(c);
      archive.addFile(ArchiveFile(n, b.length, b));
    }
    add('[Content_Types].xml', ct);
    add('_rels/.rels', rels);
    add('word/document.xml', docXml);
    add('word/styles.xml', stylesXml);
    add('word/_rels/document.xml.rels', wRels);
    final encoded = ZipEncoder().encode(archive) ?? ZipEncoder().encode(archive);
    if (encoded == null || encoded.isEmpty) {
      // Fallback: try encoding again
      final encoded2 = ZipEncoder().encode(archive);
      if (encoded2 == null) throw Exception('DOCX encoding failed');
      return Uint8List.fromList(encoded2);
    }
    return Uint8List.fromList(encoded);


  }


  Future<Uint8List> _ubuntuDesign() async {
    const green = PdfColor.fromInt(0xFF2D6A4F);
    const lightGreen = PdfColor.fromInt(0xFF52B788);
    const dark = PdfColor.fromInt(0xFF1A1A1A);
    const gray = PdfColor.fromInt(0xFF555555);
    final doc = pw.Document();
    doc.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(40),
      build: (ctx) => [
        pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          pw.Container(width: 4, height: 60, color: green),
          pw.SizedBox(width: 12),
          pw.Expanded(child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            pw.Text(_s("name").toUpperCase(), style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold, color: dark, letterSpacing: 2)),
            pw.SizedBox(height: 4),
            if (_s("headline").isNotEmpty) pw.Text(_s("headline"), style: pw.TextStyle(fontSize: 11, color: green, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 4),
            pw.Text(_contact(), style: pw.TextStyle(fontSize: 9, color: gray)),
          ])),
        ]),
        pw.SizedBox(height: 12),
        pw.Container(width: double.infinity, height: 1.5, color: lightGreen),
        pw.SizedBox(height: 16),
        if (_s("summary").isNotEmpty) ...[
          _ubuSec("PROFILE", green, lightGreen),
          pw.SizedBox(height: 8),
          pw.Text(_s("summary"), style: pw.TextStyle(fontSize: 10, color: dark, lineSpacing: 1.8)),
          pw.SizedBox(height: 16),
        ],
        if (_list("skills").isNotEmpty) ...[
          _ubuSec("SKILLS", green, lightGreen),
          pw.SizedBox(height: 8),
          pw.Wrap(spacing: 8, runSpacing: 6, children: _list("skills").map((s) => pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            color: PdfColor.fromInt(0xFFD8F3DC),
            child: pw.Text(s, style: pw.TextStyle(fontSize: 9, color: green, fontWeight: pw.FontWeight.bold)))).toList()),
          pw.SizedBox(height: 16),
        ],
        if (_exp().isNotEmpty) ...[
          _ubuSec("EXPERIENCE", green, lightGreen),
          pw.SizedBox(height: 10),
          ..._exp().take(3).map((e) => pw.Container(margin: const pw.EdgeInsets.only(bottom: 10),
            child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
              pw.Text(e["title"].toString(), style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: dark)),
              pw.Text(e['company'].toString() + '  -  ' + e['duration'].toString(), style: pw.TextStyle(fontSize: 9, color: green, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 4),
              ..._bullets(e).take(3).map((b) => pw.Text('-  ' + b, style: pw.TextStyle(fontSize: 9, color: dark, lineSpacing: 1.5))),
            ]))),
        ],
        if (_edu().isNotEmpty) ...[
          _ubuSec("EDUCATION", green, lightGreen),
          pw.SizedBox(height: 8),
          ..._edu().map((e) => pw.Container(margin: const pw.EdgeInsets.only(bottom: 8),
            child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
              pw.Text(e["degree"].toString(), style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: dark)),
              pw.Text(e['institution'].toString() + '  -  ' + e['year'].toString(), style: pw.TextStyle(fontSize: 9, color: green)),
            ]))),
        ],
      ]));
    return doc.save();
  }

  pw.Widget _ubuSec(String t, PdfColor green, PdfColor light) => pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
    pw.Row(children: [
      pw.Container(width: 20, height: 3, color: green),
      pw.SizedBox(width: 6),
      pw.Text(t, style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: green, letterSpacing: 2)),
    ]),
    pw.SizedBox(height: 4),
    pw.Container(width: double.infinity, height: 0.5, color: light),
  ]);

  Future<Uint8List> _vividDesign() async {
    const purple = PdfColor.fromInt(0xFF6B2D8B);
    const pink = PdfColor.fromInt(0xFFE91E8C);
    const dark = PdfColor.fromInt(0xFF1A1A1A);
    const light = PdfColor.fromInt(0xFFF3E5F5);
    final doc = pw.Document();
    doc.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: pw.EdgeInsets.zero,
      build: (ctx) => [
        pw.Container(
          width: double.infinity,
          color: purple,
          padding: const pw.EdgeInsets.all(28),
          child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            pw.Text(_s("name").toUpperCase(), style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold, color: PdfColors.white, letterSpacing: 3)),
            pw.SizedBox(height: 6),
            if (_s("headline").isNotEmpty) pw.Text(_s("headline"), style: pw.TextStyle(fontSize: 11, color: PdfColor(1,1,1,0.8))),
            pw.SizedBox(height: 8),
            pw.Container(width: 60, height: 3, color: pink),
            pw.SizedBox(height: 8),
            pw.Text(_contact(), style: pw.TextStyle(fontSize: 9, color: PdfColor(1,1,1,0.7))),
          ])),
        pw.Container(
          padding: const pw.EdgeInsets.all(28),
          child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            if (_s("summary").isNotEmpty) ...[
              _vividSec("ABOUT ME", purple, pink),
              pw.SizedBox(height: 8),
              pw.Text(_s("summary"), style: pw.TextStyle(fontSize: 10, color: dark, lineSpacing: 1.8)),
              pw.SizedBox(height: 16),
            ],
            if (_list("skills").isNotEmpty) ...[
              _vividSec("SKILLS", purple, pink),
              pw.SizedBox(height: 8),
              pw.Wrap(spacing: 8, runSpacing: 6, children: _list("skills").map((s) => pw.Container(
                padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: pw.BoxDecoration(border: pw.Border.all(color: pink, width: 1)),
                child: pw.Text(s, style: pw.TextStyle(fontSize: 9, color: purple)))).toList()),
              pw.SizedBox(height: 16),
            ],
            if (_exp().isNotEmpty) ...[
              _vividSec("EXPERIENCE", purple, pink),
              pw.SizedBox(height: 10),
              ..._exp().take(3).map((e) => pw.Container(
                margin: const pw.EdgeInsets.only(bottom: 8),
                padding: const pw.EdgeInsets.all(8),
                color: light,
                child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                  pw.Text(e["title"].toString(), style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: dark)),
                  pw.Text(e['company'].toString() + '  -  ' + e['duration'].toString(), style: pw.TextStyle(fontSize: 9, color: pink, fontWeight: pw.FontWeight.bold)),
                  pw.SizedBox(height: 4),
                  ..._bullets(e).take(3).map((b) => pw.Text('-  ' + b, style: pw.TextStyle(fontSize: 9, color: dark, lineSpacing: 1.5))),
                ]))),
            ],
            if (_edu().isNotEmpty) ...[
              _vividSec("EDUCATION", purple, pink),
              pw.SizedBox(height: 8),
              ..._edu().map((e) => pw.Container(margin: const pw.EdgeInsets.only(bottom: 8),
                child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                  pw.Text(e["degree"].toString(), style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: dark)),
                  pw.Text(e['institution'].toString() + '  -  ' + e['year'].toString(), style: pw.TextStyle(fontSize: 9, color: purple)),
                ]))),
            ],
          ])),
      ]));
    return doc.save();
  }

  pw.Widget _vividSec(String t, PdfColor purple, PdfColor pink) => pw.Row(children: [
    pw.Container(width: 16, height: 16, color: pink),
    pw.SizedBox(width: 8),
    pw.Text(t, style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: purple, letterSpacing: 2)),
  ]);
  void _showPremiumDialog() {
    showDialog(context: context, builder: (_) => Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        decoration: BoxDecoration(color: Colors.white, border: Border.all(color: Colors.black, width: 2),
          boxShadow: const [BoxShadow(color: Colors.black, offset: Offset(4,4), blurRadius: 0)]),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: double.infinity, color: const Color(0xFF1C1C3A), padding: const EdgeInsets.all(16),
            child: const Column(children: [
              Icon(Icons.lock_open_rounded, color: Color(0xFFFFD700), size: 32),
              SizedBox(height: 8),
              Text('PREMIUM TEMPLATES', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 2)),
              SizedBox(height: 4),
              Text('Unlock Grid, Ubuntu and Vivid', style: TextStyle(fontSize: 11, color: Colors.white70)),
            ])),
          Padding(padding: const EdgeInsets.all(20), child: Column(children: [
            _premiumFeature(Icons.grid_view_rounded, 'Grid Template', 'Modern tech layout'),
            _premiumFeature(Icons.eco_rounded, 'Ubuntu Template', 'Clean entry-level design'),
            _premiumFeature(Icons.palette_rounded, 'Vivid Template', 'Bold creative design'),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              color: Color(0xFFFFD700),
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: Center(child: Text('LIMITED LAUNCH OFFER', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.black, letterSpacing: 2)))),
            const SizedBox(height: 12),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Text('R59', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: Colors.grey, decoration: TextDecoration.lineThrough)),
              const SizedBox(width: 12),
              Text('R29', style: TextStyle(fontSize: 36, fontWeight: FontWeight.w900, color: Color(0xFF1C1C3A))),
            ]),
            const SizedBox(height: 4),
            const Text('You save R30 - 50% off', style: TextStyle(fontSize: 11, color: Colors.green, fontWeight: FontWeight.w700)),
            const SizedBox(height: 16),
            GestureDetector(
              onTap: () async {
                Navigator.pop(context);
                final svc = PurchaseService();
                await svc.buyPremiumTemplates();
              },
              child: Container(width: double.infinity, height: 52,
                decoration: BoxDecoration(color: const Color(0xFF1C1C3A), border: Border.all(color: Colors.black, width: 2),
                  boxShadow: const [BoxShadow(color: Colors.black, offset: Offset(4,4), blurRadius: 0)]),
                child: const Center(child: Text('UNLOCK PREMIUM', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 2))))),
            const SizedBox(height: 10),
            GestureDetector(
              onTap: () async {
                Navigator.pop(context);
                await PurchaseService().restorePurchases();
              },
              child: const Text('Restore purchase', style: TextStyle(fontSize: 11, color: Colors.grey, decoration: TextDecoration.underline))),
          ])),
        ]))));
  }

  Widget _premiumFeature(IconData icon, String title, String sub) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Row(children: [
      Icon(icon, color: const Color(0xFF1C1C3A), size: 20),
      const SizedBox(width: 12),
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
        Text(sub, style: const TextStyle(fontSize: 10, color: Colors.grey)),
      ]),
    ]));

  Map<String, String> _hdrs() => {};
  Widget _stepChip(String num, String label) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(color: AppColors.ink, border: AppBorders.ink2),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Container(width: 16, height: 16, color: AppColors.amber,
        child: Center(child: Text(num, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: AppColors.ink)))),
      const SizedBox(width: 6),
      Text(label, style: AppText.caption.copyWith(color: Colors.white, fontSize: 9)),
    ]));

  Widget _successUI() {
    final before = (_extracted['currentATSScore'] as num?)?.toInt() ?? 45;
    final after  = (_optimized['atsScore']  as num?)?.toInt()  ?? 80;
    final gain   = after - before;
    final percentile = after >= 90 ? 5 : after >= 80 ? 12 : after >= 70 ? 25 : after >= 60 ? 40 : 55;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Celebration header
        Container(width: double.infinity, padding: const EdgeInsets.all(24),
          decoration: const BoxDecoration(color: AppColors.blue, border: AppBorders.ink2, boxShadow: [AppShadows.hard4]),
          child: Column(children: [
            Container(width: 72, height: 72,
              decoration: const BoxDecoration(color: AppColors.amber, shape: BoxShape.circle),
              child: const Icon(Icons.check_rounded, color: AppColors.ink, size: 40)),
            const SizedBox(height: 16),
            Text('YOUR CV IS READY!', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 2), textAlign: TextAlign.center),
            const SizedBox(height: 6),
            Text('Saved to your Downloads folder', style: TextStyle(fontSize: 12, color: Colors.white70), textAlign: TextAlign.center),
          ])),
        const SizedBox(height: 20),
        // Dramatic before/after
        Container(width: double.infinity,
          decoration: BoxDecoration(color: AppColors.ink, border: AppBorders.ink2, boxShadow: [AppShadows.hard4]),
          child: Column(children: [
            Container(width: double.infinity, padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              color: AppColors.amber,
              child: Text('YOUR CV TRANSFORMATION', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: AppColors.ink, letterSpacing: 1.5), textAlign: TextAlign.center)),
            Padding(padding: const EdgeInsets.all(20), child: Column(children: [
              Row(children: [
                Expanded(child: Column(children: [
                  Text('BEFORE', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: AppColors.dim, letterSpacing: 2)),
                  const SizedBox(height: 8),
                  Container(width: 80, height: 80,
                    decoration: BoxDecoration(color: AppColors.red, border: Border.all(color: Colors.white24, width: 2)),
                    child: Center(child: Text('$before', style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: Colors.white)))),
                  const SizedBox(height: 6),
                  Container(width: double.infinity, height: 8, margin: const EdgeInsets.symmetric(horizontal: 4),
                    color: Colors.white12,
                    child: FractionallySizedBox(alignment: Alignment.centerLeft, widthFactor: before / 100,
                      child: Container(color: AppColors.red))),
                ])),
                Padding(padding: const EdgeInsets.symmetric(horizontal: 12), child: Column(children: [
                  const Icon(Icons.arrow_forward_rounded, color: AppColors.amber, size: 32),
                  const SizedBox(height: 6),
                  Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    color: AppColors.blue,
                    child: Text('+$gain', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Colors.white))),
                ])),
                Expanded(child: Column(children: [
                  Text('AFTER', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: AppColors.amber, letterSpacing: 2)),
                  const SizedBox(height: 8),
                  Container(width: 80, height: 80,
                    decoration: BoxDecoration(color: AppColors.blue, border: Border.all(color: AppColors.amber, width: 3)),
                    child: Center(child: Text('$after', style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: Colors.white)))),
                  const SizedBox(height: 6),
                  Container(width: double.infinity, height: 8, margin: const EdgeInsets.symmetric(horizontal: 4),
                    color: Colors.white12,
                    child: FractionallySizedBox(alignment: Alignment.centerLeft, widthFactor: after / 100,
                      child: Container(color: AppColors.blue))),
                ])),
              ]),
              const SizedBox(height: 16),
              Container(width: double.infinity, padding: const EdgeInsets.all(16),
                color: AppColors.amber,
                child: Column(children: [
                  Text('TOP $percentile% OF APPLICANTS', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: AppColors.ink), textAlign: TextAlign.center),
                  const SizedBox(height: 4),
                  Text('Your CV went from $before% to $after% - recruiters will notice you.', style: TextStyle(fontSize: 11, color: AppColors.ink.withOpacity(0.75)), textAlign: TextAlign.center),
                ])),
            ])),
          ])),
        const SizedBox(height: 20),
        // Share on WhatsApp - viral button
        GestureDetector(onTap: _shareWhatsApp,
          child: Container(width: double.infinity, height: 56,
            decoration: BoxDecoration(color: const Color(0xFF25D366), border: Border.all(color: AppColors.ink, width: 2), boxShadow: [AppShadows.hard4]),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Container(width: 28, height: 28, decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                child: Center(child: Icon(Icons.chat_rounded, color: const Color(0xFF25D366), size: 16))),
              const SizedBox(width: 12),
              Text('SHARE ON WHATSAPP', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 1)),
            ]))),
        const SizedBox(height: 10),
        GestureDetector(onTap: _share,
          child: Container(width: double.infinity, height: 46,
            decoration: BoxDecoration(color: Colors.white, border: Border.all(color: AppColors.ink, width: 2)),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              const Icon(Icons.share, color: AppColors.ink, size: 16),
              const SizedBox(width: 8),
              Text('SHARE CV', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.ink, letterSpacing: 1)),
            ]))),
        const SizedBox(height: 20),
        GestureDetector(
          onTap: () => setState(() {
            _file = null; _fileName = ''; _fileExt = '';
            _extracted = {}; _gaps = []; _gapIndex = 0;
            _optimized = {}; _pdfs.clear(); _selectedDesign = 0;
            _state = _S.upload;
          }),
          child: Container(width: double.infinity, padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: AppColors.cream, border: Border.all(color: AppColors.dim, width: 1)),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              const Icon(Icons.refresh, color: AppColors.dim, size: 15),
              const SizedBox(width: 8),
              Text('OPTIMISE ANOTHER CV', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.dim, letterSpacing: 1)),
            ]))),
        const SizedBox(height: 20),
      ]));
  }

  void _err(String msg) {
    if (!mounted) return;
    setState(() => _state = _S.upload);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
      backgroundColor: AppColors.red, duration: const Duration(seconds: 4)));
  }

  void _loadingDlg(String msg) => showDialog(context: context, barrierDismissible: false,
    builder: (ctx) => Center(child: Container(padding: const EdgeInsets.all(24), color: Colors.white, child: Column(mainAxisSize: MainAxisSize.min, children: [
      CircularProgressIndicator(color: AppColors.blue), const SizedBox(height: 14),
      Text(msg, style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.ink)),
    ]))));

  void _successDlg(String msg) => showDialog(context: context,
    builder: (ctx) => Dialog(backgroundColor: Colors.transparent, child: Container(
      decoration: BoxDecoration(border: Border.all(color: AppColors.ink, width: 3)),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(width: double.infinity, padding: const EdgeInsets.all(16), color: AppColors.blue,
          child: Row(children: [Icon(Icons.check_circle, color: Colors.white, size: 22), const SizedBox(width: 10), Text('SAVED!', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 2))])),
        Container(width: double.infinity, padding: const EdgeInsets.all(20), color: Colors.white, child: Column(children: [
          Text(msg, textAlign: TextAlign.center, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.ink, height: 1.5)),
          const SizedBox(height: 20),
          GestureDetector(onTap: () => Navigator.pop(ctx),
            child: Container(width: double.infinity, height: 44, color: AppColors.blue,
              child: Center(child: Text('OK', style: TextStyle(fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 2))))),
        ])),
      ]))));
}


class _NotCVException implements Exception {
  final String docType;
  final String message;
  _NotCVException(this.docType, this.message);
}

class _ATSPreviewPage extends StatelessWidget {
  final Map<String, dynamic> data;
  final int designIndex;
  final VoidCallback onSelect;
  _ATSPreviewPage({required this.data, required this.designIndex, required this.onSelect});

  String _s(String k, [String fb = '']) => (data[k] ?? fb).toString();
  List<String> _list(String k) { final v = data[k]; return v is List ? v.map((e) => e.toString()).toList() : []; }
  List<Map<String,dynamic>> _exp() { final v = data['experience']; return v is List ? v.map((e) => Map<String,dynamic>.from(e)).toList() : []; }
  String _contact() => [_s('email'),_s('phone'),_s('location')].where((v) => v.isNotEmpty).join('  -  ');
  List<String> _bullets(Map<String,dynamic> e) { final b = e['bullets']; if (b is List && b.isNotEmpty) return b.map((x) => x.toString()).toList(); final d = e['description']; return d != null && d.toString().isNotEmpty ? [d.toString()] : []; }

  static const _names = ['EXECUTIVE','SPECTRUM','MINIMAL','GRID'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.cream,
      body: SafeArea(child: Column(children: [
        Container(height: 60, color: AppColors.ink, child: Row(children: [
          GestureDetector(onTap: () => Navigator.pop(context),
            child: Container(width: 60, height: 60, color: AppColors.red, child: const Icon(Icons.arrow_back, color: Colors.white))),
          Expanded(child: Center(child: Text('${_names[designIndex]} PREVIEW', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 2)))),
          GestureDetector(onTap: onSelect,
            child: Container(width: 110, height: 60, color: AppColors.blue, child: const Center(child: Text('USE THIS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 1))))),
        ])),
        Expanded(child: SingleChildScrollView(child: Container(margin: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: Colors.white, border: Border.all(color: AppColors.ink, width: 2), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 8, offset: const Offset(0,4))]),
          child: _preview()))),
      ])));
  }

  Widget _preview() {
    switch (designIndex) {
      case 0: return _execP();
      case 1: return _specP();
      case 2: return _minP();
      case 3: return _gridP();
      default: return _execP();
    }
  }

  Widget _execP() {
    const navy = Color(0xFF1C1C3A); const gold = Color(0xFFD4AF37);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(width: double.infinity, color: navy, padding: const EdgeInsets.all(20), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(_s('name').toUpperCase(), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 3)),
        const SizedBox(height: 4), Container(width: 50, height: 3, color: gold), const SizedBox(height: 8),
        if (_s('headline').isNotEmpty) Text(_s('headline'), style: TextStyle(fontSize: 12, color: gold, fontWeight: FontWeight.w600)),
        const SizedBox(height: 6), Text(_contact(), style: TextStyle(fontSize: 11, color: Colors.white.withOpacity(0.7))),
      ])),
      Padding(padding: const EdgeInsets.all(20), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (_s('summary').isNotEmpty) ...[_eH('PROFESSIONAL SUMMARY', gold, navy), const SizedBox(height: 8), Text(_s('summary'), style: const TextStyle(fontSize: 12, height: 1.6, color: Colors.black87)), const SizedBox(height: 18)],
        if (_exp().isNotEmpty) ...[_eH('PROFESSIONAL EXPERIENCE', gold, navy), const SizedBox(height: 10),
          ..._exp().map((e) => Padding(padding: const EdgeInsets.only(bottom: 14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text((e['title']??'').toString().toUpperCase(), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
            Text('${e['company']}  |  ${e['duration']}', style: TextStyle(fontSize: 11, color: Colors.grey[600], fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            ..._bullets(e).take(3).map((b) => Padding(padding: const EdgeInsets.only(bottom: 2), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('- ', style: TextStyle(color: gold, fontSize: 11)),
              Expanded(child: Text(b, style: const TextStyle(fontSize: 11, height: 1.4, color: Colors.black87))),
            ]))),
          ])))],
        if (_list('certifications').isNotEmpty) ...[_eH('CERTIFICATIONS', gold, navy), const SizedBox(height: 8),
          ..._list('certifications').map((c) => Padding(padding: const EdgeInsets.only(bottom: 4), child: Row(children: [Container(width: 6, height: 6, color: gold), const SizedBox(width: 8), Expanded(child: Text(c, style: const TextStyle(fontSize: 11)))])))],
        if (_list('achievements').isNotEmpty) ...[const SizedBox(height: 10), _eH('ACHIEVEMENTS & AWARDS', gold, navy), const SizedBox(height: 8),
          ..._list('achievements').map((a) => Padding(padding: const EdgeInsets.only(bottom: 4), child: Row(children: [Container(width: 6, height: 6, color: gold), const SizedBox(width: 8), Expanded(child: Text(a, style: const TextStyle(fontSize: 11)))])))],
        if (_list('skills').isNotEmpty) ...[const SizedBox(height: 10), _eH('CORE COMPETENCIES', gold, navy), const SizedBox(height: 10),
          Wrap(spacing: 8, runSpacing: 6, children: _list('skills').map((s) => Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(border: Border.all(color: gold)), child: Text(s, style: const TextStyle(fontSize: 10)))).toList())],
      ])),
    ]);
  }

  Widget _eH(String t, Color accent, Color titleC) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text(t, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: titleC, letterSpacing: 2)),
    const SizedBox(height: 3), Container(height: 1, color: accent),
  ]);

  Widget _specP() {
    const sidebar = Color(0xFF2E4057); const teal = Color(0xFF048A81);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(width: double.infinity, color: sidebar, padding: const EdgeInsets.all(20), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(_s('name').toUpperCase(), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 2)),
        const SizedBox(height: 4), Container(width: 36, height: 3, color: teal), const SizedBox(height: 6),
        if (_s('headline').isNotEmpty) Text(_s('headline'), style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.7))),
        const SizedBox(height: 8), Text(_contact(), style: TextStyle(fontSize: 11, color: Colors.white.withOpacity(0.6))),
      ])),
      if (_list('skills').isNotEmpty)
        Container(color: const Color(0xFFEEF2F6), padding: const EdgeInsets.all(14),
          child: Wrap(spacing: 6, runSpacing: 4, children: _list('skills').take(8).map((s) => Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), color: teal, child: Text(s, style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.w600)))).toList())),
      Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (_s('summary').isNotEmpty) ...[_spH2('ABOUT ME', teal), const SizedBox(height: 8), Text(_s('summary'), style: const TextStyle(fontSize: 12, height: 1.6, color: Colors.black87)), const SizedBox(height: 16)],
        if (_exp().isNotEmpty) ...[_spH2('EXPERIENCE', teal), const SizedBox(height: 10),
          ..._exp().map((e) => Padding(padding: const EdgeInsets.only(bottom: 12), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(width: 3, height: 48, color: teal, margin: const EdgeInsets.only(right: 10, top: 2)),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text((e['title']??'').toString(), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
              Text('${e['company']}  -  ${e['duration']}', style: TextStyle(fontSize: 11, color: teal, fontWeight: FontWeight.w600)),
              const SizedBox(height: 3),
              ..._bullets(e).take(3).map((b) => Text('- $b', style: const TextStyle(fontSize: 11, height: 1.4, color: Colors.black87))),
            ])),
          ])))],
        if (_list('certifications').isNotEmpty) ...[_spH2('CERTIFICATIONS', teal), const SizedBox(height: 8),
          ..._list('certifications').map((c) => Text('- $c', style: const TextStyle(fontSize: 11, color: Colors.black87)))],
      ])),
    ]);
  }

  Widget _spH2(String t, Color c) => Row(children: [Container(width: 4, height: 14, color: c), const SizedBox(width: 8), Text(t, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: Color(0xFF2E4057), letterSpacing: 1.5))]);

  Widget _minP() => Padding(padding: const EdgeInsets.all(24), child: Column(children: [
    Text(_s('name').toUpperCase(), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, letterSpacing: 5), textAlign: TextAlign.center),
    const SizedBox(height: 6),
    if (_s('headline').isNotEmpty) Text(_s('headline'), style: TextStyle(fontSize: 12, color: Colors.grey[600]), textAlign: TextAlign.center),
    const SizedBox(height: 8),
    Divider(color: Colors.grey[300], thickness: 0.5),
    Text(_contact(), style: TextStyle(fontSize: 11, color: Colors.grey[500]), textAlign: TextAlign.center),
    Divider(color: Colors.grey[300], thickness: 0.5),
    const SizedBox(height: 16),
    if (_s('summary').isNotEmpty) ...[_mH2('PROFILE'), const SizedBox(height: 8), Text(_s('summary'), style: const TextStyle(fontSize: 12, height: 1.7, color: Colors.black87)), const SizedBox(height: 16)],
    if (_exp().isNotEmpty) ...[_mH2('EXPERIENCE'), const SizedBox(height: 10),
      ..._exp().map((e) => Padding(padding: const EdgeInsets.only(bottom: 12), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(width: 80, child: Text((e['duration']??'').toString(), style: TextStyle(fontSize: 10, color: Colors.grey[500]))),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text((e['title']??'').toString(), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
          Text((e['company']??'').toString(), style: TextStyle(fontSize: 11, color: Colors.grey[500])),
          ..._bullets(e).take(3).map((b) => Text('- $b', style: const TextStyle(fontSize: 11, height: 1.4, color: Colors.black87))),
        ])),
      ])))],
    if (_list('certifications').isNotEmpty) ...[_mH2('CERTIFICATIONS'), const SizedBox(height: 8),
      ..._list('certifications').map((c) => Text('- $c', style: const TextStyle(fontSize: 11, color: Colors.black87)))],
    if (_list('skills').isNotEmpty) ...[_mH2('SKILLS'), const SizedBox(height: 8),
      Wrap(spacing: 4, runSpacing: 4, children: _list('skills').map((s) => Text('$s  .', style: const TextStyle(fontSize: 11, color: Colors.black87))).toList())],
  ]));

  Widget _mH2(String t) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text(t, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 3)),
    const SizedBox(height: 3), Divider(color: Colors.grey[300], height: 1),
  ]);

  Widget _gridP() {
    const blue = Color(0xFF1565C0); const red = Color(0xFFE53935);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(width: double.infinity, color: blue, padding: const EdgeInsets.all(20), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(_s('name').toUpperCase(), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 2)),
        const SizedBox(height: 4), Container(width: 40, height: 3, color: red), const SizedBox(height: 6),
        if (_s('headline').isNotEmpty) Text(_s('headline'), style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.7))),
        const SizedBox(height: 6), Text(_contact(), style: TextStyle(fontSize: 11, color: Colors.white.withOpacity(0.7))),
      ])),
      Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (_s('summary').isNotEmpty) ...[_gH2('SUMMARY', blue, red), const SizedBox(height: 8), Text(_s('summary'), style: const TextStyle(fontSize: 12, height: 1.6, color: Colors.black87)), const SizedBox(height: 16)],
        if (_exp().isNotEmpty) ...[_gH2('EXPERIENCE', blue, red), const SizedBox(height: 10),
          ..._exp().map((e) => Padding(padding: const EdgeInsets.only(bottom: 12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Text((e['title']??'').toString(), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800))),
              Text((e['duration']??'').toString(), style: TextStyle(fontSize: 10, color: Colors.grey[500])),
            ]),
            Text((e['company']??'').toString(), style: TextStyle(fontSize: 11, color: blue, fontWeight: FontWeight.w600)),
            const SizedBox(height: 3),
            ..._bullets(e).take(3).map((b) => Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(width: 4, height: 4, color: red, margin: const EdgeInsets.only(top: 5, right: 6)),
              Expanded(child: Text(b, style: const TextStyle(fontSize: 11, height: 1.4, color: Colors.black87))),
            ])),
          ])))],
        if (_list('certifications').isNotEmpty) ...[_gH2('CERTIFICATIONS', blue, red), const SizedBox(height: 8),
          Wrap(spacing: 6, runSpacing: 4, children: _list('certifications').map((s) => Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), color: Colors.grey[100], child: Text(s, style: const TextStyle(fontSize: 10)))).toList())],
        if (_list('achievements').isNotEmpty) ...[const SizedBox(height: 10), _gH2('ACHIEVEMENTS', blue, red), const SizedBox(height: 8),
          ..._list('achievements').map((a) => Text('- $a', style: const TextStyle(fontSize: 11, height: 1.4, color: Colors.black87)))],
        if (_list('skills').isNotEmpty) ...[const SizedBox(height: 10), _gH2('SKILLS', blue, red), const SizedBox(height: 8),
          Wrap(spacing: 6, runSpacing: 4, children: _list('skills').map((s) => Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), color: Colors.grey[100], child: Text(s, style: const TextStyle(fontSize: 10)))).toList())],
      ])),
    ]);
  }

  Widget _gH2(String t, Color b, Color r) => Row(children: [
    Container(width: 3, height: 13, color: r), const SizedBox(width: 6),
    Text(t, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: b, letterSpacing: 1.5)),
  ]);
}










