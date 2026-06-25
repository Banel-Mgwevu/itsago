import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart' show launchUrl, LaunchMode;
import 'app_theme.dart';
import 'cv_storage_service.dart';
import 'ats_scoring_service.dart';

class CVLibraryScreen extends StatefulWidget {
  const CVLibraryScreen({super.key});
  @override
  State<CVLibraryScreen> createState() => _CVLibraryScreenState();
}

class _CVLibraryScreenState extends State<CVLibraryScreen> with WidgetsBindingObserver {
  List<CVRecord> _cvs      = [];
  bool _loading              = true;
  String? _downloading;
  final Set<String> _expanded = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _load();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final cvs = await CVStorageService.getCVs();
    if (mounted) setState(() { _cvs = cvs; _loading = false; });
  }

  Future<void> _download(String cvId, CVFileType type) async {
    setState(() => _downloading = '$cvId-${type.name}');
    final url = await CVStorageService.getDownloadUrl(cvId, type);
    if (mounted) setState(() => _downloading = null);
    if (url != null) {
      await launchUrl(Uri.parse(url),
        mode: LaunchMode.externalApplication);
    } else {
      if (mounted) _toast('Download failed. Please try again.');
    }
  }

  Future<void> _confirmDelete(CVRecord cv) async {
    final confirm = await showDialog<bool>(
      context: context, barrierDismissible: false,
      builder: (dlg) => Dialog(backgroundColor: Colors.transparent,
        child: Container(
          decoration: AppDecorations.dialog,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(width: double.infinity,
              padding: const EdgeInsets.all(14),
              color: AppColors.red,
              child: Text('DELETE CV',
                style: AppText.title.copyWith(
                  color: Colors.white, letterSpacing: 1.5))),
            Padding(padding: const EdgeInsets.all(18),
              child: Column(children: [
              Text('Delete the CV for ${cv.company}?\n\n'
                'This permanently removes both the original and '
                'optimised versions from our servers. '
                'This action cannot be undone.',
                style: AppText.body.copyWith(height: 1.5)),
              const SizedBox(height: 20),
              Row(children: [
                Expanded(child: GestureDetector(
                  onTap: () => Navigator.pop(dlg, false),
                  child: Container(height: 42,
                    decoration: BoxDecoration(
                      border: Border.all(color: AppColors.mist, width: 1.5)),
                    child: Center(child: Text('CANCEL',
                      style: AppText.label.copyWith(color: AppColors.dim)))))),
                const SizedBox(width: 10),
                Expanded(child: GestureDetector(
                  onTap: () => Navigator.pop(dlg, true),
                  child: Container(height: 42,
                    decoration: const BoxDecoration(
                      color: AppColors.red, border: AppBorders.ink2,
                      boxShadow: [AppShadows.hard3]),
                    child: Center(child: Text('DELETE',
                      style: AppText.button))))),
              ]),
            ])),
          ]))));
    if (confirm == true) {
      await CVStorageService.deleteCVRecord(cv.id);
      await _load();
      if (mounted) _toast('CV deleted and removed from our servers.');
    }
  }

  Future<void> _confirmDeleteAll() async {
    final confirm = await showDialog<bool>(
      context: context, barrierDismissible: false,
      builder: (dlg) => Dialog(backgroundColor: Colors.transparent,
        child: Container(
          decoration: AppDecorations.dialog,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(width: double.infinity,
              padding: const EdgeInsets.all(14),
              color: AppColors.red,
              child: Text('DELETE ALL CVS',
                style: AppText.title.copyWith(
                  color: Colors.white, letterSpacing: 1.5))),
            Padding(padding: const EdgeInsets.all(18),
              child: Column(children: [
              Text('This permanently deletes all ${_cvs.length} CVs '
                'and exercises your POPIA right to erasure.\n\n'
                'All files are removed from our servers immediately.',
                style: AppText.body.copyWith(height: 1.5)),
              const SizedBox(height: 20),
              Row(children: [
                Expanded(child: GestureDetector(
                  onTap: () => Navigator.pop(dlg, false),
                  child: Container(height: 42,
                    decoration: BoxDecoration(
                      border: Border.all(color: AppColors.mist, width: 1.5)),
                    child: Center(child: Text('CANCEL',
                      style: AppText.label.copyWith(color: AppColors.dim)))))),
                const SizedBox(width: 10),
                Expanded(child: GestureDetector(
                  onTap: () => Navigator.pop(dlg, true),
                  child: Container(height: 42,
                    decoration: const BoxDecoration(
                      color: AppColors.red, border: AppBorders.ink2,
                      boxShadow: [AppShadows.hard3]),
                    child: Center(child: Text('DELETE ALL',
                      style: AppText.button))))),
              ]),
            ])),
          ]))));
    if (confirm == true) {
      await CVStorageService.deleteAllCVs();
      await _load();
      if (mounted) _toast('All CVs deleted from our servers.');
    }
  }

  void _toast(String msg) => ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(msg,
      style: const TextStyle(fontWeight: FontWeight.w700)),
      backgroundColor: AppColors.ink,
      behavior: SnackBarBehavior.floating,
      shape: const RoundedRectangleBorder()));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.cream,
      body: SafeArea(child: Column(children: [

        // Header
        Container(color: AppColors.ink,
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
          child: Row(children: [
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(width: 38, height: 38,
                decoration: const BoxDecoration(
                  color: AppColors.white, border: AppBorders.ink2,
                  boxShadow: [AppShadows.hard3]),
                child: const Icon(Icons.arrow_back_rounded,
                  color: AppColors.ink, size: 18))),
            const SizedBox(width: 14),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('MY JOB-READY CVS',
                style: AppText.title.copyWith(
                  color: Colors.white, letterSpacing: 2)),
              Text('${_cvs.length} saved  ·  30-day retention',
                style: AppText.caption.copyWith(color: AppColors.dim)),
            ])),
            if (_cvs.isNotEmpty)
              GestureDetector(
                onTap: _confirmDeleteAll,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: AppColors.red.withOpacity(0.6), width: 1.5)),
                  child: Text('DELETE ALL',
                    style: AppText.label.copyWith(
                      color: AppColors.red, fontSize: 8)))),
          ])),

        // POPIA notice strip
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: AppColors.blue.withOpacity(0.08),
          child: Row(children: [
            const Icon(Icons.shield_rounded,
              color: AppColors.blue, size: 13),
            const SizedBox(width: 8),
            Expanded(child: Text(
              'POPIA compliant · CVs auto-deleted after 30 days '
              '· Delete anytime',
              style: AppText.caption.copyWith(
                color: AppColors.blue, fontSize: 9))),
          ])),

        Expanded(child: _loading
          ? const Center(child: CircularProgressIndicator(
              color: AppColors.blue, strokeWidth: 2))
          : _cvs.isEmpty
          ? _empty()
          : RefreshIndicator(
              onRefresh: _load,
              color: AppColors.blue,
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _cvs.length,
                itemBuilder: (_, i) => _cvCard(_cvs[i])))),
      ])));
  }

  Widget _empty() => Padding(
    padding: const EdgeInsets.all(32),
    child: Column(mainAxisAlignment: MainAxisAlignment.center,
      children: [
      Container(width: 72, height: 72,
        decoration: const BoxDecoration(
          color: AppColors.white, border: AppBorders.ink2,
          boxShadow: [AppShadows.hard4]),
        child: const Icon(Icons.description_rounded,
          color: AppColors.dim, size: 36)),
      const SizedBox(height: 20),
      Text('NO CVS YET', style: AppText.title),
      const SizedBox(height: 8),
      Text('Upload your CV and we will transform it into something that gets you interviews.',
        style: AppText.caption.copyWith(height: 1.5),
        textAlign: TextAlign.center),
    ]));

  Widget _cvCard(CVRecord cv) {
    final improvement = cv.improvement;
    final improvColor = improvement > 0 ? AppColors.blue
      : improvement < 0 ? AppColors.red : AppColors.dim;
    final daysLeft = cv.retentionExpiry != null
      ? cv.retentionExpiry!.difference(DateTime.now()).inDays
      : 30;
    final isExpanded = _expanded.contains(cv.id);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: AppDecorations.card,
      child: Column(children: [

        // Card header — tap to expand/collapse preview
        GestureDetector(
          onTap: () => setState(() {
            if (isExpanded) _expanded.remove(cv.id);
            else _expanded.add(cv.id);
          }),
          child: Container(
          width: double.infinity, color: AppColors.ink,
          padding: const EdgeInsets.all(12),
          child: Row(children: [
            Container(width: 6, height: 32, color: AppColors.amber),
            const SizedBox(width: 10),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(cv.company.toUpperCase(),
                style: AppText.label.copyWith(
                  color: Colors.white, fontSize: 11),
                maxLines: 1, overflow: TextOverflow.ellipsis),
              Text(cv.jobTitle,
                style: AppText.caption.copyWith(color: AppColors.dim),
                maxLines: 1, overflow: TextOverflow.ellipsis),
            ])),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              color: daysLeft <= 7 ? AppColors.red.withOpacity(0.2) : Colors.transparent,
              child: Text('$daysLeft days left',
                style: AppText.caption.copyWith(
                  color: daysLeft <= 7 ? AppColors.red : AppColors.dim,
                  fontSize: 9))),
            const SizedBox(width: 8),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Icon(isExpanded ? Icons.expand_less : Icons.expand_more,
                color: AppColors.amber, size: 18),
              Text(isExpanded ? 'HIDE' : 'PREVIEW',
                style: AppText.caption.copyWith(color: AppColors.amber, fontSize: 7)),
            ]),
          ]))),

        // CV Preview — collapsible
        if (isExpanded)
          _cvPreview(cv),

        // Before / After score
        Padding(
          padding: const EdgeInsets.all(14),
          child: Column(children: [

            Row(children: [
              // Before
              Expanded(child: _scoreBlock(
                'BEFORE', cv.beforeScore, AppColors.red)),
              // Arrow + improvement
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Column(children: [
                  Icon(Icons.arrow_forward_rounded,
                    color: improvColor, size: 20),
                  const SizedBox(height: 2),
                  Text(improvement > 0 ? '+$improvement' : '$improvement',
                    style: AppText.label.copyWith(
                      color: improvColor, fontSize: 10)),
                ])),
              // After
              Expanded(child: _scoreBlock(
                'AFTER', cv.afterScore, AppColors.blue)),
            ]),

            const SizedBox(height: 12),

            // Keyword pills
            if (cv.afterScore.keywordsFound.isNotEmpty) ...[
              Align(alignment: Alignment.centerLeft,
                child: Text('KEYWORDS MATCHED',
                  style: AppText.label.copyWith(
                    fontSize: 8, color: AppColors.dim))),
              const SizedBox(height: 6),
              Wrap(spacing: 6, runSpacing: 4,
                children: cv.afterScore.keywordsFound
                  .take(6).map((kw) => _pill(kw, AppColors.blue))
                  .toList()),
            ],

            if (cv.afterScore.keywordsMissing.isNotEmpty) ...[
              const SizedBox(height: 8),
              Align(alignment: Alignment.centerLeft,
                child: Text('STILL MISSING',
                  style: AppText.label.copyWith(
                    fontSize: 8, color: AppColors.dim))),
              const SizedBox(height: 6),
              Wrap(spacing: 6, runSpacing: 4,
                children: cv.afterScore.keywordsMissing
                  .take(4).map((kw) => _pill(kw, AppColors.red))
                  .toList()),
            ],

            const SizedBox(height: 14),

            // Download buttons
            Row(children: [
              Expanded(child: _dlButton(
                'ORIGINAL CV', Icons.upload_file_rounded,
                AppColors.dim, cv.id, CVFileType.original)),
              const SizedBox(width: 8),
              Expanded(child: _dlButton(
                'JOB-READY PDF', Icons.picture_as_pdf_rounded,
                AppColors.blue, cv.id, CVFileType.optimisedPdf)),
              const SizedBox(width: 8),
              Expanded(child: _dlButton(
                'WORD', Icons.description_rounded,
                AppColors.amber, cv.id, CVFileType.optimisedDocx)),
            ]),

            const SizedBox(height: 10),

            // Delete
            GestureDetector(
              onTap: () => _confirmDelete(cv),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                const Icon(Icons.delete_outline_rounded,
                  size: 13, color: AppColors.dim),
                const SizedBox(width: 5),
                Text('DELETE & ERASE FROM SERVERS',
                  style: AppText.caption.copyWith(
                    color: AppColors.dim, fontSize: 9,
                    decoration: TextDecoration.underline)),
              ])),
          ])),
      ]));
  }

  Widget _cvPreview(CVRecord cv) {
    final designColors = [
      const Color(0xFF1C1C3A), // Executive navy
      const Color(0xFF2E4057), // Spectrum dark
      const Color(0xFF333333), // Minimal charcoal
      const Color(0xFF1565C0), // Grid blue
    ];
    final designAccents = [
      const Color(0xFFD4AF37), // Executive gold
      const Color(0xFF048A81), // Spectrum teal
      const Color(0xFF333333), // Minimal
      const Color(0xFFE53935), // Grid red
    ];
    final designNames = ['EXECUTIVE', 'SPECTRUM', 'MINIMAL', 'GRID'];
    final idx     = cv.designIndex.clamp(0, 3);
    final bgColor = designColors[idx];
    final accent  = designAccents[idx];
    final score   = cv.afterScore.score;
    final name    = cv.cvName.isNotEmpty    ? cv.cvName    : cv.company;
    final headline = cv.cvHeadline.isNotEmpty ? cv.cvHeadline : cv.jobTitle;

    return Container(
      width: double.infinity,
      color: Colors.white,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Mini CV header in selected design colour
        Container(width: double.infinity, color: bgColor, padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(width: 4, height: 4, color: accent),
              const SizedBox(width: 6),
              Text(designNames[idx], style: TextStyle(fontSize: 8, fontWeight: FontWeight.w900, color: accent, letterSpacing: 2)),
            ]),
            const SizedBox(height: 8),
            Text(name.toUpperCase(), style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 1.5)),
            const SizedBox(height: 3),
            Container(width: 36, height: 2, color: accent),
            if (headline.isNotEmpty) ...[
              const SizedBox(height: 5),
              Text(headline, style: TextStyle(fontSize: 10, color: accent, fontWeight: FontWeight.w600)),
            ],
          ])),
        // Summary if available
        if (cv.cvSummary.isNotEmpty)
          Padding(padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
            child: Text(cv.cvSummary, style: const TextStyle(fontSize: 9, color: Colors.black87, height: 1.4), maxLines: 2, overflow: TextOverflow.ellipsis)),
        // Skills pills
        if (cv.cvSkills.isNotEmpty)
          Padding(padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
            child: Wrap(spacing: 5, runSpacing: 4,
              children: cv.cvSkills.take(5).map((s) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(border: Border.all(color: accent, width: 1)),
                child: Text(s, style: TextStyle(fontSize: 8, color: bgColor)))).toList())),
        const SizedBox(height: 10),
        // ATS score bar
        Padding(padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Row(children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('ATS SCORE', style: TextStyle(fontSize: 7, fontWeight: FontWeight.w900, color: AppColors.dim, letterSpacing: 1)),
              const SizedBox(height: 4),
              Stack(children: [
                Container(height: 6, color: AppColors.mist),
                FractionallySizedBox(widthFactor: score / 100,
                  child: Container(height: 6, color: score >= 70 ? AppColors.blue : score >= 50 ? AppColors.amber : AppColors.red)),
              ]),
            ])),
            const SizedBox(width: 12),
            Container(width: 44, height: 44,
              decoration: BoxDecoration(color: bgColor, border: Border.all(color: accent, width: 1.5)),
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Text('$score', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: Colors.white)),
                Text(cv.afterScore.grade, style: TextStyle(fontSize: 8, color: accent)),
              ])),
          ])),
        const SizedBox(height: 10),
        // Stats strip
        Container(width: double.infinity, padding: const EdgeInsets.all(10), color: AppColors.cream,
          child: Row(children: [
            _previewStat('BEFORE', '${cv.beforeScore.score}', AppColors.red),
            Container(width: 1, height: 24, color: AppColors.mist),
            _previewStat('AFTER', '${cv.afterScore.score}', AppColors.blue),
            Container(width: 1, height: 24, color: AppColors.mist),
            _previewStat('GAIN', '${cv.improvement > 0 ? '+' : ''}${cv.improvement}',
              cv.improvement > 0 ? AppColors.blue : AppColors.dim),
            Container(width: 1, height: 24, color: AppColors.mist),
            _previewStat('LEFT',
              '${cv.retentionExpiry != null ? cv.retentionExpiry!.difference(DateTime.now()).inDays : 30}d',
              AppColors.amber),
          ])),
      ]));
  }
  Widget _previewStat(String label, String val, Color color) =>
    Expanded(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Text(val, style: AppText.title.copyWith(color: color, fontSize: 12),
        overflow: TextOverflow.ellipsis),
      Text(label, style: AppText.caption.copyWith(fontSize: 7, color: AppColors.dim),
        overflow: TextOverflow.ellipsis),
    ]));

  Widget _scoreBlock(String label, ATSScore s, Color color) =>
    Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.06),
        border: Border.all(color: color.withOpacity(0.3), width: 1)),
      child: Column(children: [
        Text(label, style: AppText.label.copyWith(
          fontSize: 8, color: color)),
        const SizedBox(height: 6),
        Text('${s.score}',
          style: AppText.display.copyWith(
            fontSize: 28, color: color)),
        Text(s.grade, style: AppText.caption.copyWith(
          fontSize: 9, color: color)),
      ]));

  Widget _pill(String text, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: color.withOpacity(0.08),
      border: Border.all(color: color.withOpacity(0.3), width: 1)),
    child: Text(text,
      style: AppText.caption.copyWith(
        color: color, fontSize: 9)));

  Widget _dlButton(String label, IconData icon, Color color,
      String cvId, CVFileType type) {
    final key   = '$cvId-${type.name}';
    final busy  = _downloading == key;
    return GestureDetector(
      onTap: busy ? null : () => _download(cvId, type),
      child: Container(
        height: 36,
        decoration: BoxDecoration(
          color: busy ? AppColors.dim : color,
          border: AppBorders.ink2),
        child: Center(child: busy
          ? const SizedBox(width: 14, height: 14,
              child: CircularProgressIndicator(
                color: Colors.white, strokeWidth: 2))
          : Row(mainAxisAlignment: MainAxisAlignment.center,
              children: [
              Icon(icon, color: Colors.white, size: 10),
              const SizedBox(width: 3),
              Flexible(child: Text(label, style: AppText.label.copyWith(
                color: Colors.white, fontSize: 7), overflow: TextOverflow.ellipsis)),
            ]))));
  }
}








