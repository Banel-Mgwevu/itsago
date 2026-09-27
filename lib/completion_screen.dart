import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'app_config.dart';
import 'progress_service.dart';
import 'app_theme.dart';
import 'main_menu_screen.dart';
import 'notification_service.dart';
import 'cloud_function_service.dart';

class CompletionScreen extends StatefulWidget {
  final List<Map<String, dynamic>> allResults;
  final String company;
  const CompletionScreen({
    super.key, required this.allResults, required this.company});
  @override
  State<CompletionScreen> createState() => _CompletionScreenState();
}

class _CompletionScreenState extends State<CompletionScreen>
    with TickerProviderStateMixin {

  @override
  void initState() { super.initState(); _fetchFeedback(); }

  late final AnimationController _entryCtrl = AnimationController(
    vsync: this, duration: const Duration(milliseconds: 800))..forward();
  int _expandedQ = -1;
  Map<String, dynamic>? _aiFeedback;
  bool _loadingFeedback = true;

  Animation<double> _fade(double a, double b) => Tween<double>(begin: 0, end: 1)
      .animate(CurvedAnimation(parent: _entryCtrl,
          curve: Interval(a, b, curve: Curves.easeOut)));
  Animation<Offset> _slide(double a, double b) =>
      Tween<Offset>(begin: const Offset(0, 0.04), end: Offset.zero)
          .animate(CurvedAnimation(parent: _entryCtrl,
              curve: Interval(a, b, curve: Curves.easeOut)));

  @override
  void dispose() { _entryCtrl.dispose(); super.dispose(); }

  // - AI Feedback -
  Future<void> _fetchFeedback() async {
    if (widget.allResults.isEmpty) {
      if (mounted) setState(() => _loadingFeedback = false);
      return;
    }
    try {
      final sb = StringBuffer();
      sb.write('Mock interview for ${widget.company}. Analyse these responses:\n\n');
      for (final r in widget.allResults) {
        final wps = ((r['wordsPerSecond'] ?? 0) as num).toStringAsFixed(1);
        final fr  = (((r['fillerRatio']   ?? 0) as num) * 100).toStringAsFixed(0);
        sb.write('Q${r["questionNumber"]}: ${r["question"]}\n');
        sb.write('Answer: ${r["transcript"]}\n');
        if (r['scored'] == false) {
          sb.write('Stats: this answer could not be scored (technical issue) - do not judge it.\n\n');
          continue;
        }
        sb.write('Stats: ${(r["confidence"] as num).round()}% score, '
            '${(r["fillerWords"] as List).length} fillers, '
            '${r["wordCount"]} words, $wps words/sec, $fr% filler ratio\n\n');
      }
      sb.write('Each answer could be up to 2 minutes long.\n'
      'Focus primarily on CONTENT - did they answer the question with a specific point?\n'
      'Delivery (pace, fillers) is secondary. Be encouraging - they are practising.\n'
      'Return ONLY valid JSON, no markdown:\n');
      sb.write('{"overallSummary":"2-3 sentence honest assessment",');
      sb.write('"topStrength":"single biggest strength",');
      sb.write('"topImprovement":"single most important thing to work on",');
      sb.write('"starUsage":"1-2 sentences: did their behavioural answers follow a clear Situation-Task-Action-Result structure? If they told stories with a situation and outcome, say so. If answers were vague with no clear example or result, say that and tell them to use STAR.",');
      sb.write('"questions":[{"qNum":1,"rating":"STRONG","strength":"specific strength","tip":"actionable tip"}]}');

      final res = await CloudFunctionService.callClaude(
        
          model: 'claude-haiku-4-5-20251001',
          maxTokens: 700,
          messages: [{'role': 'user', 'content': sb.toString()}],
        );
      
        final raw   = CloudFunctionService.extractText(res);
        final clean = raw.replaceAll('```json','').replaceAll('```','').trim();
        final data  = jsonDecode(clean) as Map<String, dynamic>;
        if (mounted) setState(() { _aiFeedback = data; _loadingFeedback = false; });
        // Trigger score-based notification
        final avgConfidence = _avgConfidence;
        await NotificationService().onInterviewCompleted(
            avgScore:      avgConfidence,
            company:       widget.company,
            questionCount: widget.allResults.length);
        // Save session to Firestore
        await ProgressService.saveSession(
          company:    widget.company,
          jobTitle:   '',
          results:    widget.allResults,
          aiFeedback: data);
        return;
    } catch (_) {
      try {
        final avgConf = _avgConfidence;
        await NotificationService().onInterviewCompleted(
            avgScore: avgConf, company: widget.company, questionCount: widget.allResults.length);
        await ProgressService.saveSession(
          company: widget.company, jobTitle: '', results: widget.allResults, aiFeedback: null);
      } catch (_) {}
    }
    if (mounted) setState(() => _loadingFeedback = false);
  }

  Widget _aiFeedbackCard() {
    if (_loadingFeedback) {
      return Container(
        decoration: AppDecorations.cardSmall,
        padding: const EdgeInsets.all(18),
        child: Row(children: [
          const SizedBox(width: 18, height: 18,
            child: CircularProgressIndicator(
              color: AppColors.blue, strokeWidth: 2)),
          const SizedBox(width: 14),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('ITSAGO AI IS REVIEWING YOUR ANSWERS...',
              style: AppText.label.copyWith(color: AppColors.ink)),
            const SizedBox(height: 3),
            Text('Generating personalised feedback', style: AppText.caption),
          ])),
        ]));
    }
    if (_aiFeedback == null) return const SizedBox.shrink();
    return Container(
      decoration: AppDecorations.card,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: double.infinity, color: AppColors.ink,
          padding: const EdgeInsets.all(14),
          child: Row(children: [
            Container(width: 36, height: 36,
              decoration: const BoxDecoration(
                color: AppColors.amber, border: AppBorders.ink2),
              child: const Icon(Icons.smart_toy_rounded,
                color: AppColors.ink, size: 18)),
            const SizedBox(width: 12),
            Text('AI COACH FEEDBACK',
              style: AppText.title.copyWith(
                color: Colors.white, letterSpacing: 1.5)),
          ])),
        Padding(padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start,
            children: [
            Text(_aiFeedback!['overallSummary'] as String? ?? '',
              style: AppText.body.copyWith(height: 1.5)),
            const SizedBox(height: 14),
            Row(children: [
              Expanded(child: _feedbackTile(
                icon:  Icons.thumb_up_rounded,
                label: 'TOP STRENGTH',
                text:  _aiFeedback!['topStrength'] as String? ?? '',
                color: AppColors.blue)),
              const SizedBox(width: 10),
              Expanded(child: _feedbackTile(
                icon:  Icons.trending_up_rounded,
                label: 'FOCUS ON',
                text:  _aiFeedback!['topImprovement'] as String? ?? '',
                color: AppColors.amber)),
            ]),
          ])),
      ]));
  }

  Widget _feedbackTile({
    required IconData icon, required String label,
    required String text, required Color color}) =>
    Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.07),
        border: Border.all(color: color.withOpacity(0.3), width: 1)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(icon, color: color, size: 13),
          const SizedBox(width: 6),
          Text(label, style: AppText.label.copyWith(color: color, fontSize: 8)),
        ]),
        const SizedBox(height: 5),
        Text(text, style: AppText.caption.copyWith(height: 1.4)),
      ]));

  Map<String, dynamic>? _qAIData(int qNum) {
    if (_aiFeedback == null) return null;
    final qs = _aiFeedback!['questions'] as List?;
    if (qs == null) return null;
    try {
      return qs.firstWhere((q) => q['qNum'] == qNum)
          as Map<String, dynamic>;
    } catch (_) { return null; }
  }

  // - Computed stats -
  /// Answers that actually got a score. Answers we couldn't score
  /// (network/transcription failure) are left out of every average.
  List<Map<String, dynamic>> get _scored =>
      widget.allResults.where((r) => r['scored'] != false).toList();

  double get _avgConfidence {
    final s = _scored;
    if (s.isEmpty) return 0;
    final sum = s.fold<double>(0, (v, r) => v + (r['confidence'] as num).toDouble());
    return sum / s.length;
  }

  double get _avgEyeContact {
    if (widget.allResults.isEmpty) return 0;
    final total = widget.allResults
      .fold<double>(0, (v, r) => v + ((r['eyeContactScore'] as num?)?.toDouble() ?? 0));
    return total / widget.allResults.length;
  }

  // - Metric 1: Speaking pace -
  String get _paceLabel {
    if (widget.allResults.isEmpty) return '-';
    final avgWps = widget.allResults
      .fold<double>(0, (v, r) => v + ((r['wordsPerSecond'] as num?)?.toDouble() ?? 0))
      / widget.allResults.length;
    if (avgWps < 1.0) return 'TOO SLOW';
    if (avgWps < 1.5) return 'SLOW';
    if (avgWps <= 2.8) return 'PERFECT';
    if (avgWps <= 3.5) return 'FAST';
    return 'TOO FAST';
  }

  Color get _paceColor {
    final p = _paceLabel;
    if (p == 'PERFECT') return AppColors.blue;
    if (p == 'SLOW' || p == 'FAST') return AppColors.amber;
    return AppColors.red;
  }

  String get _paceTip {
    final p = _paceLabel;
    if (p == 'PERFECT') return 'Your speaking pace is ideal for interviews - clear and composed.';
    if (p == 'TOO SLOW') return 'You spoke quite slowly. Aim for a natural conversational pace - it shows confidence.';
    if (p == 'SLOW') return 'Slightly slow. A slightly faster pace sounds more energetic and engaged.';
    if (p == 'FAST') return 'Slightly fast. Slow down a little - interviewers need time to absorb your answers.';
    return 'You spoke very fast. Slow down significantly - rushing sounds nervous and is hard to follow.';
  }

  double get _avgWps => widget.allResults.isEmpty ? 0 :
    widget.allResults.fold<double>(0, (v, r) =>
      v + ((r['wordsPerSecond'] as num?)?.toDouble() ?? 0))
    / widget.allResults.length;

  // - Metric: Eye contact -
  String get _eyeContactLabel {
    final e = _avgEyeContact;
    if (e >= 80) return 'STRONG';
    if (e >= 60) return 'GOOD';
    if (e >= 40) return 'INCONSISTENT';
    return 'LOOKING AWAY';
  }

  Color get _eyeContactColor {
    final e = _avgEyeContact;
    if (e >= 80) return AppColors.blue;
    if (e >= 60) return AppColors.blue;
    if (e >= 40) return AppColors.amber;
    return AppColors.red;
  }

  String get _eyeContactTip {
    final e = _avgEyeContact;
    if (e >= 80) return 'Strong eye contact throughout - you looked engaged and confident on camera.';
    if (e >= 60) return 'Good eye contact overall. Try to hold the camera a little more steadily during longer answers.';
    if (e >= 40) return 'Your eye contact came and went. Interviewers read looking away as nerves or dishonesty, even when neither is true.';
    return 'You looked away from the camera a lot. Practice keeping your eyes on the lens, it is the single fastest way to look more confident on video.';
  }

  double get _avgHesitation {
    if (widget.allResults.isEmpty) return 0;
    final vals = widget.allResults.map((r) => (r['hesitationSeconds'] as num?)?.toDouble() ?? 0.0).where((v) => v > 0).toList();
    if (vals.isEmpty) return 0;
    return vals.fold<double>(0, (a, b) => a + b) / vals.length;
  }

  String get _hesitationLabel {
    final h = _avgHesitation;
    if (h <= 0) return 'NOT MEASURED';
    if (h <= 2.0) return 'QUICK';
    if (h <= 4.0) return 'STEADY';
    if (h <= 6.0) return 'SLOW START';
    return 'LONG PAUSES';
  }

  Color get _hesitationColor {
    final h = _avgHesitation;
    if (h <= 0) return AppColors.dim;
    if (h <= 4.0) return AppColors.blue;
    if (h <= 6.0) return AppColors.amber;
    return AppColors.red;
  }

  String get _hesitationTip {
    final h = _avgHesitation;
    if (h <= 0) return 'We could not measure your response time this session.';
    if (h <= 2.0) return 'You started answering quickly and confidently. Just make sure you are not rushing before you have thought it through.';
    if (h <= 4.0) return 'Healthy pause before answering. A short beat to gather your thoughts reads as composed, not slow.';
    if (h <= 6.0) return 'You took a while to start on average. A little silence is fine, but long pauses can read as being caught off guard.';
    return 'Long pauses before answering. Practise a go-to opening line to buy yourself a second while you gather your thoughts.';
  }

  // - Metric: Answer length -
  String get _lengthLabel {
    if (widget.allResults.isEmpty) return '-';
    final avgWords = _totalWords / widget.allResults.length;
    if (avgWords < 15) return 'TOO SHORT';
    if (avgWords < 25) return 'A BIT SHORT';
    if (avgWords <= 55) return 'JUST RIGHT';
    return 'A BIT LONG';
  }

  Color get _lengthColor {
    final l = _lengthLabel;
    if (l == 'JUST RIGHT') return AppColors.blue;
    if (l == 'A BIT SHORT' || l == 'A BIT LONG') return AppColors.amber;
    return AppColors.red;
  }

  String get _lengthTip {
    final l = _lengthLabel;
    if (l == 'JUST RIGHT') return 'Your answers were a good length - enough to make a point without rambling.';
    if (l == 'TOO SHORT') return 'Your answers were very short. Employers want at least one full example. Aim to back up every answer with a specific detail.';
    if (l == 'A BIT SHORT') return 'A little short. Add one concrete example or number to each answer to make it land harder.';
    return 'Your answers ran a bit long. Get to the point faster - lead with your main answer, then one supporting detail.';
  }

  // - Metric: STAR structure -
  String? get _starTip {
    if (_aiFeedback == null) return null;
    final star = _aiFeedback!['starUsage'];
    if (star == null) return null;
    return star.toString();
  }

  // - Metric 2: Filler word breakdown -
  Map<String, int> get _fillerBreakdown {
    final counts = <String, int>{};
    for (final r in widget.allResults) {
      for (final w in (r['fillerWords'] as List? ?? [])) {
        final word = w.toString().toLowerCase();
        counts[word] = (counts[word] ?? 0) + 1;
      }
    }
    final sorted = Map.fromEntries(
      counts.entries.toList()..sort((a, b) => b.value.compareTo(a.value)));
    return sorted;
  }

  // - Metric 3: Consistency score -
  double get _consistencyScore {
    if (_scored.length < 2) return 100;
    final scores = _scored
      .map((r) => (r['confidence'] as num).toDouble()).toList();
    final avg  = scores.fold<double>(0, (a, b) => a + b) / scores.length;
    final variance = scores.fold<double>(0, (a, b) => a + (b - avg) * (b - avg))
      / scores.length;
    final stdDev = variance > 0 ? variance / variance.ceil() * (variance.ceil().toDouble()) : 0;
    // Simple: max - min gives spread. Under 20 = consistent
    final spread = scores.reduce((a, b) => a > b ? a : b) -
                   scores.reduce((a, b) => a < b ? a : b);
    if (spread <= 15) return 100;
    if (spread <= 25) return 80;
    if (spread <= 35) return 60;
    if (spread <= 50) return 40;
    return 20;
  }

  String get _consistencyLabel {
    final s = _consistencyScore;
    if (s >= 90) return 'VERY CONSISTENT';
    if (s >= 75) return 'CONSISTENT';
    if (s >= 55) return 'MODERATE';
    if (s >= 35) return 'INCONSISTENT';
    return 'VERY INCONSISTENT';
  }

  String get _consistencyTip {
    final s = _consistencyScore;
    if (s >= 90) return 'Excellent consistency across all questions. You performed at a similar level throughout - a sign of real preparation.';
    if (s >= 75) return 'Good consistency. Minor variance across questions is normal. Keep practising weaker question types.';
    if (s >= 55) return 'Moderate consistency. Some questions scored much higher than others. Identify your weak question types and practise them.';
    return 'Wide variance across questions. You have strong moments but also very weak ones. Focus on maintaining energy and structure across all 5 answers.';
  }

  // - Metric 4: Most improved / best question -
  Map<String, dynamic>? get _bestQuestion {
    if (_scored.isEmpty) return null;
    Map<String, dynamic>? best;
    double bestScore = -1;
    for (final r in _scored) {
      final s = (r['confidence'] as num).toDouble();
      if (s > bestScore) { bestScore = s; best = r; }
    }
    return best;
  }

  Map<String, dynamic>? get _mostImproved {
    final list = _scored;
    if (list.length < 2) return null;
    Map<String, dynamic>? improved;
    double bestGain = -double.infinity;
    for (int i = 1; i < list.length; i++) {
      final prev = (list[i-1]['confidence'] as num).toDouble();
      final curr = (list[i]['confidence'] as num).toDouble();
      final gain = curr - prev;
      if (gain > bestGain) { bestGain = gain; improved = list[i]; }
    }
    return bestGain > 5 ? improved : null;
  }

  int get _totalFillers => widget.allResults
      .fold<int>(0, (v, r) => v + (r['fillerWords'] as List).length);

  int get _totalWords => widget.allResults
      .fold<int>(0, (v, r) => v + (r['wordCount'] as int? ?? 0));

  int get _totalDuration => widget.allResults
      .fold<int>(0, (v, r) => v + (r['recordingDuration'] as int? ?? 0));

  String get _grade {
    final c = _avgConfidence;
    if (c >= 80) return 'A';
    if (c >= 68) return 'B';
    if (c >= 55) return 'C';
    if (c >= 42) return 'D';
    return 'F';
  }

  Color get _gradeColor {
    final c = _avgConfidence;
    if (c >= 75) return AppColors.blue;
    if (c >= 60) return AppColors.amber;
    return AppColors.red;
  }

  String get _gradeLabel {
    final c = _avgConfidence;
    if (c >= 80) return 'EXCELLENT';
    if (c >= 68) return 'GREAT';
    if (c >= 55) return 'GOOD';
    if (c >= 42) return 'FAIR';
    return 'KEEP PRACTISING';
  }

  String _fmt(int s) =>
    '${s ~/ 60}m ${s % 60}s';

  Color _confColor(double c) =>
    c >= 75 ? AppColors.blue : c >= 60 ? AppColors.amber : AppColors.red;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        backgroundColor: AppColors.cream,
        body: SafeArea(child: Column(children: [

          // - Poster header -
          Container(
            width: double.infinity, color: AppColors.ink,
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
            child: Stack(children: [
              // Amber circle bleed
              Positioned(top: -20, right: -20,
                child: Container(width: 80, height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.amber.withOpacity(0.15),
                    border: Border.all(
                      color: AppColors.amber.withOpacity(0.3), width: 1.5)))),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                AppWidgets.badge('RESULTS', bg: AppColors.red, fg: Colors.white),
                const SizedBox(height: 8),
                Text('INTERVIEW\nCOMPLETE',
                  style: AppText.poster.copyWith(fontSize: 30, height: 1.0)),
                const SizedBox(height: 6),
                Text(widget.company.toUpperCase(),
                  style: AppText.label.copyWith(
                    color: AppColors.amber, letterSpacing: 2)),
              ]),
            ])),

          Expanded(child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
            child: AnimatedBuilder(
              animation: _entryCtrl,
              builder: (_, __) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [

                // - Grade card -
                FadeTransition(opacity: _fade(0.0, 0.5),
                  child: SlideTransition(position: _slide(0.0, 0.5),
                    child: Container(
                      decoration: AppDecorations.card,
                      child: Column(children: [
                        Container(height: 5, color: _gradeColor),
                        Padding(padding: const EdgeInsets.all(20),
                          child: Row(children: [
                          // Grade badge
                          Container(width: 80, height: 80,
                            decoration: BoxDecoration(
                              color: _gradeColor,
                              border: AppBorders.ink2,
                              boxShadow: [AppShadows.colored(_gradeColor)]),
                            child: Center(child: Text(_grade,
                              style: AppText.display.copyWith(
                                color: Colors.white, fontSize: 44)))),
                          const SizedBox(width: 20),
                          Expanded(child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                            Text(_gradeLabel,
                              style: AppText.headline.copyWith(
                                color: _gradeColor)),
                            const SizedBox(height: 6),
                            Text('${_avgConfidence.round()}% OVERALL SCORE',
                              style: AppText.title.copyWith(
                                color: AppColors.ink)),
                            const SizedBox(height: 8),
                            // Mini bar
                            Container(height: 8,
                              decoration: const BoxDecoration(
                                color: AppColors.mist,
                                border: AppBorders.ink2),
                              child: FractionallySizedBox(
                                widthFactor: _avgConfidence / 100,
                                alignment: Alignment.centerLeft,
                                child: Container(color: _gradeColor))),
                          ])),
                        ])),
                      ])))),

                const SizedBox(height: 16),

                // - Stats row -
                FadeTransition(opacity: _fade(0.1, 0.55),
                  child: SlideTransition(position: _slide(0.1, 0.55),
                    child: Row(children: [
                      _statTile('${widget.allResults.length}',
                        'QUESTIONS', AppColors.ink),
                      const SizedBox(width: 10),
                      _statTile('$_totalWords', 'WORDS', AppColors.blue),
                      const SizedBox(width: 10),
                      _statTile('$_totalFillers', 'FILLERS', AppColors.red),
                      const SizedBox(width: 10),
                      _statTile(_fmt(_totalDuration),
                        'DURATION', AppColors.amber),
                    ]))),

                const SizedBox(height: 24),

                // - Per-question results -
                FadeTransition(opacity: _fade(0.2, 0.65),
                  child: AppWidgets.sectionLabel('QUESTION BREAKDOWN')),
                const SizedBox(height: 12),

                ...widget.allResults.asMap().entries.map((e) {
                  final i = e.key; final r = e.value;
                  final conf = (r['confidence'] as num).toDouble();
                  final isScored = r['scored'] != false;
                  final rowColor = isScored ? _confColor(conf) : AppColors.dim;
                  final expanded = _expandedQ == i;
                  return Padding(
                  padding: EdgeInsets.zero,
                  child: FadeTransition(
                    opacity: _fade(0.25 + i * 0.05, 0.75 + i * 0.03),
                    child: GestureDetector(
                      onTap: () => setState(() =>
                        _expandedQ = expanded ? -1 : i),
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: AppColors.white,
                          border: Border.all(
                            color: expanded
                              ? rowColor : AppColors.mist,
                            width: expanded ? 2 : 1.5),
                          boxShadow: expanded
                            ? [AppShadows.colored(rowColor)]
                            : const [AppShadows.hard3]),
                        child: Column(children: [
                          // Colour top strip
                          Container(height: 3, color: rowColor),
                          Padding(
                            padding: const EdgeInsets.all(14),
                            child: Row(children: [
                              Container(width: 36, height: 36,
                                decoration: BoxDecoration(
                                  color: rowColor,
                                  border: AppBorders.ink2),
                                child: Center(child: Text('${i + 1}',
                                  style: AppText.label.copyWith(
                                    color: Colors.white, fontSize: 14)))),
                              const SizedBox(width: 12),
                              Expanded(child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                Text(r['question'] as String,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppText.caption.copyWith(
                                    color: AppColors.ink,
                                    fontSize: 11, height: 1.3)),
                                const SizedBox(height: 4),
                                Row(children: [
                                  Text(isScored
                                      ? '${conf.round()}% score'
                                      : "Couldn't score this answer",
                                    style: AppText.caption.copyWith(
                                      color: rowColor)),
                                  const SizedBox(width: 8),
                                  Text('. ${r['wordCount'] ?? 0} words',
                                    style: AppText.caption),
                                ]),
                              ])),
                              Icon(
                                expanded
                                  ? Icons.expand_less_rounded
                                  : Icons.expand_more_rounded,
                                color: AppColors.dim, size: 20),
                            ])),
                          // Expanded detail
                          AnimatedSize(
                            duration: const Duration(milliseconds: 280),
                            curve: Curves.easeOut,
                            child: expanded
                              ? Container(
                                width: double.infinity,
                                padding: const EdgeInsets.fromLTRB(14,0,14,14),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                  AppWidgets.divider(),
                                  const SizedBox(height: 12),
                                  // Transcript
                                  if ((r['transcript'] as String).isNotEmpty &&
                                      r['transcript'] != '[NO RESPONSE - SILENT]' &&
                                      r['transcript'] != '[SKIPPED - NO RESPONSE PROVIDED]') ...[
                                    AppWidgets.sectionLabel('YOUR ANSWER',
                                      accent: AppColors.blue),
                                    const SizedBox(height: 8),
                                    Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.all(12),
                                      color: AppColors.cream,
                                      child: Text(r['transcript'] as String,
                                        style: AppText.body.copyWith(
                                          fontSize: 12, height: 1.5))),
                                    const SizedBox(height: 12),
                                  ],
                                  if (_qAIData(i + 1) != null)
                                    _qAITile(_qAIData(i + 1)!),
                                  // Stats row
                                  Row(children: [
                                    _miniStat('SCORE',
                                      isScored ? '${conf.round()}%' : '-',
                                      AppColors.blue),
                                    const SizedBox(width: 8),
                                    _miniStat('FILLERS',
                                      '${(r['fillerWords'] as List).length}',
                                      AppColors.red),
                                    const SizedBox(width: 8),
                                    _miniStat('DURATION',
                                      '${r['recordingDuration'] ?? 0}s',
                                      AppColors.amber),
                                  ]),
                                ]))
                              : const SizedBox.shrink()),
                        ])))));;
                }),

                const SizedBox(height: 24),


                // - Performance Metrics -
                FadeTransition(opacity: _fade(0.5, 0.88),
                  child: SlideTransition(position: _slide(0.5, 0.88),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                      AppWidgets.sectionLabel('PERFORMANCE METRICS',
                        accent: AppColors.blue),
                      const SizedBox(height: 12),
                      _metricCard(
                        icon: Icons.speed_rounded,
                        title: 'SPEAKING PACE',
                        value: '${_avgWps.toStringAsFixed(1)} words/sec',
                        badge: _paceLabel,
                        badgeColor: _paceColor,
                        body: _paceTip,
                      ),
                      const SizedBox(height: 10),
                      _metricCard(
                        icon: Icons.remove_red_eye_rounded,
                        title: 'EYE CONTACT',
                        value: '${_avgEyeContact.round()}% on camera',
                        badge: _eyeContactLabel,
                        badgeColor: _eyeContactColor,
                        body: _eyeContactTip,
                      ),
                      const SizedBox(height: 10),
                      _metricCard(icon: Icons.timer_outlined, title: 'RESPONSE TIME', value: _avgHesitation <= 0 ? 'Not measured' : '${_avgHesitation.toStringAsFixed(1)}s before answering', badge: _hesitationLabel, badgeColor: _hesitationColor, body: _hesitationTip),
                      const SizedBox(height: 10),
                      _metricCard(icon: Icons.notes_rounded, title: 'ANSWER LENGTH', value: '${widget.allResults.isEmpty ? 0 : (_totalWords / widget.allResults.length).round()} words per answer', badge: _lengthLabel, badgeColor: _lengthColor, body: _lengthTip),
                      if (_starTip != null) ...[
                        const SizedBox(height: 10),
                        _metricCard(icon: Icons.auto_stories_rounded, title: 'STAR STRUCTURE', value: 'Story structure', badge: 'STAR', badgeColor: AppColors.blue, body: _starTip!),
                      ],
                      const SizedBox(height: 10),
                      _fillerBreakdownCard(),
                      const SizedBox(height: 10),
                      _metricCard(
                        icon: Icons.show_chart_rounded,
                        title: 'ANSWER CONSISTENCY',
                        value: _consistencyLabel,
                        badge: _consistencyScore.round().toString() + '%',
                        badgeColor: _consistencyScore >= 75 ? AppColors.blue : _consistencyScore >= 50 ? AppColors.amber : AppColors.red,
                        body: _consistencyTip,
                      ),
                      const SizedBox(height: 10),
                      if (_bestQuestion != null)
                        _metricCard(
                          icon: Icons.emoji_events_rounded,
                          title: 'BEST ANSWER',
                          value: 'Question ' + (_bestQuestion!['questionNumber']).toString(),
                          badge: (_bestQuestion!['confidence'] as num).round().toString() + '%',
                          badgeColor: AppColors.blue,
                          body: 'Your strongest answer. Bring this energy to every question.',
                        ),
                    ]))),

                const SizedBox(height: 24),

                // - Tips -
                FadeTransition(opacity: _fade(0.55, 0.95),
                  child: SlideTransition(position: _slide(0.55, 0.95),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                      AppWidgets.sectionLabel('IMPROVEMENT TIPS',
                        accent: AppColors.amber),
                      const SizedBox(height: 12),
                      AppWidgets.infoCard(
                        accent: AppColors.amber,
                        icon: Icons.lightbulb_rounded,
                        title: 'REDUCE FILLER WORDS',
                        body: _totalFillers > 5
                          ? 'You used $_totalFillers filler words. Practice pausing instead of saying "um" or "like" - silence sounds more confident than filler.'
                          : 'Good job keeping fillers low! Keep practising to maintain this.',
                      ),
                      const SizedBox(height: 12),
                      AppWidgets.infoCard(
                        accent: _avgConfidence >= 70 ? AppColors.blue : AppColors.red,
                        icon: Icons.psychology_rounded,
                        title: 'CONFIDENCE SCORE',
                        body: _avgConfidence >= 70
                          ? 'Strong overall score of ${_avgConfidence.round()}%. Keep up structured, clear answers.'
                          : 'Confidence at ${_avgConfidence.round()}%. Try the STAR method: Situation - Task - Action - Result.',
                      ),
                    ]))),

                const SizedBox(height: 32),

                // - Actions -
                FadeTransition(opacity: _fade(0.7, 1.0),
                  child: Column(children: [
                  GestureDetector(
                    onTap: () => Navigator.of(context).pushAndRemoveUntil(
                      PageRouteBuilder(
                        pageBuilder: (ctx, _, __) {
                          final cameras = ModalRoute.of(ctx)?.settings.arguments;
                          return MainMenuScreen(cameras: const []);
                        },
                        transitionsBuilder: (_, a, __, child) =>
                            FadeTransition(opacity: a, child: child)),
                      (r) => false),
                    child: Container(
                      width: double.infinity, height: 56,
                      decoration: const BoxDecoration(
                        color: AppColors.ink,
                        border: AppBorders.ink2,
                        boxShadow: [AppShadows.hard5]),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                        const Icon(Icons.home_rounded,
                          color: Colors.white, size: 20),
                        const SizedBox(width: 10),
                        Text('BACK TO MENU',
                          style: AppText.button.copyWith(letterSpacing: 2)),
                      ]))),
                  const SizedBox(height: 12),
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: Container(
                      width: double.infinity, height: 46,
                      decoration: BoxDecoration(
                        color: AppColors.cream,
                        border: Border.all(
                          color: AppColors.mist, width: 1.5)),
                      child: Center(child: Text('TRY AGAIN',
                        style: AppText.button.copyWith(
                          color: AppColors.dim, letterSpacing: 1))))),
                ])),
              ])))),
        ])));
  }

  Widget _qAITile(Map<String, dynamic> d) {
    final rating = d['rating'] as String? ?? '';
    final color  = rating == 'STRONG' || rating == 'GOOD'
      ? AppColors.blue : rating == 'FAIR' ? AppColors.amber : AppColors.red;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.06),
        border: Border.all(color: color.withOpacity(0.25), width: 1)),
      child: Column(children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          color: color,
          child: Row(children: [
            const Icon(Icons.smart_toy_rounded, color: Colors.white, size: 11),
            const SizedBox(width: 5),
            Text('AI  .  ',
              style: AppText.label.copyWith(color: Colors.white, fontSize: 7.5)),
          ])),
        Padding(padding: const EdgeInsets.all(10),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(Icons.check_circle_rounded, color: AppColors.blue, size: 12),
            const SizedBox(width: 5),
            Expanded(child: Text(d['strength'] as String? ?? '',
              style: AppText.caption.copyWith(height: 1.4, fontSize: 10.5))),
          ]),
          const SizedBox(height: 5),
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(Icons.lightbulb_rounded, color: AppColors.amber, size: 12),
            const SizedBox(width: 5),
            Expanded(child: Text(d['tip'] as String? ?? '',
              style: AppText.caption.copyWith(height: 1.4, fontSize: 10.5))),
          ]),
        ])),
      ]));
  }

  Widget _statTile(String val, String lbl, Color accent) =>
    Expanded(child: Container(
      height: 68,
      decoration: BoxDecoration(
        color: AppColors.white,
        border: AppBorders.ink2,
        boxShadow: const [AppShadows.hard3]),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(width: double.infinity, height: 3, color: accent),
        const SizedBox(height: 8),
        Text(val, style: AppText.title.copyWith(
          color: accent, fontSize: 14), textAlign: TextAlign.center),
        Text(lbl, style: AppText.label.copyWith(
          color: AppColors.dim, fontSize: 7)),
        const SizedBox(height: 6),
      ])));

  Widget _metricCard({
    required IconData icon,
    required String title,
    required String value,
    required String badge,
    required Color badgeColor,
    required String body,
  }) => Container(
    width: double.infinity,
    decoration: BoxDecoration(
      color: AppColors.white,
      border: AppBorders.ink2,
      boxShadow: const [AppShadows.hard3]),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(height: 3, color: badgeColor),
      Padding(padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(icon, size: 14, color: badgeColor),
          const SizedBox(width: 6),
          Text(title, style: AppText.label.copyWith(
            color: AppColors.ink, fontSize: 9, letterSpacing: 1)),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            color: badgeColor,
            child: Text(badge, style: AppText.label.copyWith(
              color: Colors.white, fontSize: 8))),
        ]),
        const SizedBox(height: 6),
        Text(value, style: AppText.title.copyWith(
          color: badgeColor, fontSize: 13)),
        const SizedBox(height: 5),
        Text(body, style: AppText.caption.copyWith(height: 1.4)),
      ])),
    ]));

  Widget _fillerBreakdownCard() {
    final breakdown = _fillerBreakdown;
    if (breakdown.isEmpty) {
      return _metricCard(
        icon: Icons.record_voice_over_rounded,
        title: 'FILLER WORDS',
        value: 'None detected',
        badge: '0',
        badgeColor: AppColors.blue,
        body: 'No filler words detected. Excellent vocal control.',
      );
    }
    final top = breakdown.entries.take(4).toList();
    final topNames = top.take(2).map((e) => e.key).join(' and ');
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.white,
        border: AppBorders.ink2,
        boxShadow: const [AppShadows.hard3]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(height: 3, color: AppColors.red),
        Padding(padding: const EdgeInsets.all(12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.record_voice_over_rounded, size: 14, color: AppColors.red),
            const SizedBox(width: 6),
            Text('FILLER WORDS BREAKDOWN', style: AppText.label.copyWith(
              color: AppColors.ink, fontSize: 9, letterSpacing: 1)),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              color: AppColors.red,
              child: Text('$_totalFillers TOTAL', style: AppText.label.copyWith(
                color: Colors.white, fontSize: 8))),
          ]),
          const SizedBox(height: 10),
          Wrap(spacing: 8, runSpacing: 6,
            children: top.map((e) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: AppColors.red.withOpacity(0.07),
                border: Border.all(color: AppColors.red.withOpacity(0.3))),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Text(e.key, style: AppText.label.copyWith(
                  color: AppColors.red, fontSize: 10)),
                const SizedBox(width: 5),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  color: AppColors.red,
                  child: Text('x' + e.value.toString(), style: AppText.label.copyWith(
                    color: Colors.white, fontSize: 8))),
              ]))).toList()),
          const SizedBox(height: 8),
          Text(
            breakdown.length == 1
              ? 'You relied on ' + breakdown.keys.first + ' as a filler. Replace it with a pause.'
              : 'Your top fillers are ' + topNames + ' - practise pausing instead.',
            style: AppText.caption.copyWith(height: 1.4)),
        ])),
      ]));
  }

  Widget _miniStat(String lbl, String val, Color accent) =>
    Expanded(child: Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: accent.withOpacity(0.07),
        border: Border.all(color: accent.withOpacity(0.3), width: 1)),
      child: Column(children: [
        Text(val, style: AppText.title.copyWith(
          color: accent, fontSize: 12)),
        Text(lbl, style: AppText.label.copyWith(
          color: AppColors.dim, fontSize: 7)),
      ])));
}












