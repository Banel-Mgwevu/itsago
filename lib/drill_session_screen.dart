import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'app_theme.dart';
import 'app_config.dart';
import 'cloud_function_service.dart';

class DrillSessionScreen extends StatefulWidget {
  final Map<String, dynamic>? progressStats;
  const DrillSessionScreen({super.key, this.progressStats});
  @override
  State<DrillSessionScreen> createState() => _DrillSessionScreenState();
}

class _DrillSessionScreenState extends State<DrillSessionScreen>
    with TickerProviderStateMixin {

  final FlutterTts       _tts    = FlutterTts();
  final stt.SpeechToText _speech = stt.SpeechToText();

  _DrillPhase _phase        = _DrillPhase.loading;
  String      _weaknessLabel= '';
  List<_Drill> _drills      = [];
  int         _currentDrill = 0;

  // Voice state
  bool   _voiceReady    = false;
  bool   _ttsPlaying    = false;
  bool   _listening     = false;
  bool   _scoring       = false;
  bool   _canSpeak      = false;  // true after TTS question finishes
  String _liveTranscript= '';
  String _finalAnswer   = '';

  _DrillResult? _lastResult;
  final List<_DrillResult> _results = [];

  Timer? _recordingTimer;
  int    _recordSecs = 0;
  int    _maxSecs    = 60;

  late AnimationController _pulseCtrl = AnimationController(
    vsync: this, duration: const Duration(milliseconds: 900))
    ..repeat(reverse: true);

  @override
  void initState() {
    super.initState();
    _initVoice();
  }

  @override
  void dispose() {
    _recordingTimer?.cancel();
    _pulseCtrl.dispose();
    _tts.stop();
    _speech.stop();
    super.dispose();
  }

  // ── Voice init ───────────────────────────────────────────────

  Future<void> _initVoice() async {
    await _tts.setLanguage('en-ZA');
    await _tts.setSpeechRate(0.46);
    await _tts.setVolume(1.0);
    _tts.setStartHandler(() {
      if (mounted) setState(() => _ttsPlaying = true);
    });
    _tts.setCompletionHandler(() {
      if (mounted) setState(() { _ttsPlaying = false; _canSpeak = true; });
    });
    _voiceReady = await _speech.initialize(
      onStatus: (s) {
        if (s == 'done' || s == 'notListening') {
          if (mounted && _listening) _stopListening();
        }
      },
      onError: (_) {
        if (mounted && _listening) _stopListening();
      });
    if (mounted) setState(() {});
    _analyzePlanDrills();
  }

  Future<void> _speak(String text, {bool allowMicAfter = false}) async {
    setState(() { _ttsPlaying = true; _canSpeak = false; });
    await _tts.speak(text);
    // Completion handler sets _ttsPlaying = false and _canSpeak = true
  }

  Future<void> _startListening() async {
    if (!_voiceReady || _listening || _ttsPlaying) return;
    setState(() {
      _listening      = true;
      _liveTranscript = '';
      _finalAnswer    = '';
      _recordSecs     = 0;
    });
    _recordingTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!_listening) { t.cancel(); return; }
      setState(() => _recordSecs++);
      if (_recordSecs >= _maxSecs) _stopListening();
    });
    await _speech.listen(
      onResult: (r) {
        if (mounted) setState(() {
          _liveTranscript = r.recognizedWords;
          if (r.finalResult) _finalAnswer = r.recognizedWords;
        });
      },
      listenFor: Duration(seconds: _maxSecs),
      pauseFor: const Duration(seconds: 4),
      localeId: 'en_ZA');
  }

  void _stopListening() {
    _recordingTimer?.cancel();
    _speech.stop();
    if (mounted) {
      final answer = _finalAnswer.isNotEmpty ? _finalAnswer : _liveTranscript;
      setState(() { _listening = false; });
      if (answer.trim().isNotEmpty) {
        _submitAnswer(answer.trim());
      }
    }
  }

  // ── Analyse + plan ────────────────────────────────────────────

  Future<void> _analyzePlanDrills() async {
    setState(() => _phase = _DrillPhase.loading);
    final stats = widget.progressStats;
    final ctx = <String>[];
    if (stats != null && (stats['total'] as int) > 0) {
      ctx.add('Avg confidence: ${(stats["avgConf"] as double).round()}%');
      ctx.add('Avg fillers: ${(stats["avgFillers"] as double).toStringAsFixed(1)}/session');
      for (final s in (stats['sessions'] as List? ?? []).take(3)) {
        ctx.add('${s["company"]} — ${(s["overallConfidence"] as num).round()}%');
      }
    } else { ctx.add('Beginner — no previous sessions.'); }

    try {
      final res = await CloudFunctionService.callClaude(
        
          model: 'claude-haiku-4-5-20251001',
          maxTokens: 250,
          messages: [{'role': 'user', 'content':
            'Analyse this interview candidate and design 3 targeted voice drills.\n'
            'Data:\n${ctx.join("\n")}\n\n'
            'Return ONLY valid JSON — no markdown:\n'
            '{"weaknessLabel":"e.g. Filler Words",'
            '"drills":['
            '{"title":"Drill 1 — Warm-Up",'
            '"question":"a natural spoken question",'
            '"tip":"one short coaching tip shown during prep"},'
            '{"title":"Drill 2 — Challenge",...},'
            '{"title":"Drill 3 — Pressure",...}]}',
          }],
        );

        final raw  = CloudFunctionService.extractText(res);
        final data = jsonDecode(
          raw.replaceAll('```json','').replaceAll('```','').trim())
          as Map<String, dynamic>;
        _weaknessLabel = data['weaknessLabel'] as String? ?? 'Interview Skills';
        _drills = (data['drills'] as List).map((d) => _Drill(
          title:    d['title']    as String? ?? '',
          question: d['question'] as String? ?? '',
          tip:      d['tip']      as String? ?? '')).toList();
        if (mounted) setState(() => _phase = _DrillPhase.intro);
        return;
    } catch (_) {}
    _weaknessLabel = 'Interview Fundamentals';
    _drills = [
      _Drill(title: 'Drill 1 — Introduction',
        question: 'Tell me about yourself and your professional background.',
        tip: 'Structure your answer: past, present, future. Aim for 60 seconds.'),
      _Drill(title: 'Drill 2 — STAR Method',
        question: 'Tell me about a time you solved a challenging problem at work.',
        tip: 'Use STAR: Situation, Task, Action, Result.'),
      _Drill(title: 'Drill 3 — Pressure Question',
        question: 'What is your greatest weakness and how are you working on it?',
        tip: 'Be honest. Show self-awareness and growth.'),
    ];
    if (mounted) setState(() => _phase = _DrillPhase.intro);
  }

  // ── Drill flow ────────────────────────────────────────────────

  Future<void> _startDrill() async {
    setState(() {
      _phase = _DrillPhase.drilling;
      _currentDrill = 0;
      _lastResult   = null;
    });
    await _presentDrill();
  }

  Future<void> _presentDrill() async {
    setState(() {
      _canSpeak      = false;
      _liveTranscript= '';
      _finalAnswer   = '';
      _lastResult    = null;
      _recordSecs    = 0;
    });
    final drill = _drills[_currentDrill];
    // Announce drill number then ask question
    await _speak(
      'Drill ${_currentDrill + 1} of ${_drills.length}. '
      '${drill.question}',
      allowMicAfter: true);
    // _canSpeak set to true by TTS completion handler
  }

  Future<void> _submitAnswer(String answer) async {
    setState(() { _scoring = true; _canSpeak = false; });
    await _speak('Got it. Let me review your answer.');
    await _scoreAnswer(answer);
  }

  Future<void> _scoreAnswer(String answer) async {
    final drill = _drills[_currentDrill];
    try {
      final res = await CloudFunctionService.callClaude(
        
          model: 'claude-haiku-4-5-20251001',
          maxTokens: 250,
          messages: [{'role': 'user', 'content':
            'Score this spoken interview answer.\n'
            'Question: "${drill.question}"\n'
            'Answer: "$answer"\n\n'
            'Return ONLY valid JSON:\n'
            '{"score":<1-10>,"grade":"EXCELLENT|STRONG|GOOD|FAIR|WEAK",'
            '"highlight":"one strength in 10 words",'
            '"improvement":"one fix in 10 words",'
            '"spokenFeedback":"2 sentence spoken feedback for TTS"}',
          }],
        );

        final raw  = CloudFunctionService.extractText(res);
        final data = jsonDecode(
          raw.replaceAll('```json','').replaceAll('```','').trim())
          as Map<String, dynamic>;
        final result = _DrillResult(
          score:          (data['score'] as num).toInt(),
          grade:          data['grade']          as String? ?? 'GOOD',
          highlight:      data['highlight']      as String? ?? '',
          improvement:    data['improvement']    as String? ?? '',
          spokenFeedback: data['spokenFeedback'] as String? ?? '');
        _results.add(result);
        if (mounted) setState(() { _lastResult = result; _scoring = false; });
        // Speak the feedback
        await _speak('Score: ${result.score} out of 10. ${result.spokenFeedback}');
        return;
    } catch (_) {}
    final fallback = _DrillResult(score: 6, grade: 'GOOD',
      highlight: 'You attempted the question.',
      improvement: 'Add a specific example with a number or outcome.',
      spokenFeedback: 'Good effort. Next time add a specific example '
        'with a measurable outcome to make your answer stronger.');
    _results.add(fallback);
    if (mounted) setState(() { _lastResult = fallback; _scoring = false; });
    await _speak('Score: 6 out of 10. ${fallback.spokenFeedback}');
  }

  Future<void> _nextDrill() async {
    if (_currentDrill < _drills.length - 1) {
      setState(() { _currentDrill++; _lastResult = null; });
      await _presentDrill();
    } else {
      setState(() => _phase = _DrillPhase.results);
      final avg = _avgScore;
      final msg = avg >= 8 ? 'Excellent work — you are interview ready!'
        : avg >= 6 ? 'Solid session — keep practising.'
        : 'Keep going — you will improve with practice.';
      await _speak('Drill complete! Your average score was $avg out of 10. $msg');
    }
  }

  int get _avgScore => _results.isEmpty ? 0
    : _results.map((r) => r.score).reduce((a, b) => a + b) ~/ _results.length;

  Color _drillColor(int i) => i == 0 ? AppColors.amber
    : i == 1 ? AppColors.blue : AppColors.red;

  // ── Build ─────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.cream,
      body: SafeArea(child: Column(children: [

        // Header
        Container(color: AppColors.ink,
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          child: Row(children: [
            GestureDetector(onTap: () => Navigator.pop(context),
              child: Container(width: 38, height: 38,
                decoration: const BoxDecoration(
                  color: AppColors.white, border: AppBorders.ink2,
                  boxShadow: [AppShadows.hard3]),
                child: const Icon(Icons.close_rounded,
                  color: AppColors.ink, size: 18))),
            const SizedBox(width: 14),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                const Icon(Icons.mic_rounded,
                  color: AppColors.amber, size: 14),
                const SizedBox(width: 6),
                Text('VOICE DRILL MODE',
                  style: AppText.title.copyWith(
                    color: Colors.white, letterSpacing: 1.5)),
              ]),
              if (_weaknessLabel.isNotEmpty)
                Text('Focus: $_weaknessLabel',
                  style: AppText.caption.copyWith(color: AppColors.amber)),
            ])),
            // Drill progress dots
            if (_phase == _DrillPhase.drilling)
              Row(children: List.generate(_drills.length, (i) =>
                Container(margin: const EdgeInsets.only(left: 6),
                  width: 10, height: 10,
                  decoration: BoxDecoration(
                    color: i < _currentDrill   ? AppColors.amber
                      : i == _currentDrill ? Colors.white : AppColors.dim,
                    border: Border.all(
                      color: Colors.white.withOpacity(0.5), width: 1))))),
          ])),

        Expanded(child: _buildPhase()),
      ])));
  }

  Widget _buildPhase() {
    switch (_phase) {
      case _DrillPhase.loading:  return _buildLoading();
      case _DrillPhase.intro:    return _buildIntro();
      case _DrillPhase.drilling: return _buildDrilling();
      case _DrillPhase.results:  return _buildResults();
    }
  }

  // Loading
  Widget _buildLoading() => Center(child: Padding(
    padding: const EdgeInsets.all(32),
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      AnimatedBuilder(animation: _pulseCtrl, builder: (_, __) =>
        Container(
          width: 72 + _pulseCtrl.value * 8,
          height: 72 + _pulseCtrl.value * 8,
          decoration: BoxDecoration(shape: BoxShape.circle,
            color: AppColors.amber.withOpacity(0.1 + _pulseCtrl.value * 0.1),
            border: Border.all(color: AppColors.amber, width: 2)),
          child: const Icon(Icons.psychology_rounded,
            color: AppColors.amber, size: 32))),
      const SizedBox(height: 24),
      Text('ANALYSING YOUR PERFORMANCE',
        style: AppText.title.copyWith(letterSpacing: 1.5),
        textAlign: TextAlign.center),
      const SizedBox(height: 8),
      Text('Designing 3 targeted voice drills...',
        style: AppText.caption, textAlign: TextAlign.center),
    ])));

  // Intro
  Widget _buildIntro() => SingleChildScrollView(
    padding: const EdgeInsets.all(20),
    child: Column(children: [
      Container(decoration: AppDecorations.card, child: Column(children: [
        Container(width: double.infinity, color: AppColors.amber,
          padding: const EdgeInsets.all(14),
          child: Row(children: [
            const Icon(Icons.mic_rounded, color: AppColors.ink, size: 18),
            const SizedBox(width: 10),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('VOICE DRILL SESSION',
                style: AppText.title.copyWith(
                  color: AppColors.ink, letterSpacing: 1)),
              Text('Focus: $_weaknessLabel',
                style: AppText.caption.copyWith(color: AppColors.ink)),
            ])),
          ])),
        Padding(padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start,
            children: [

          // How it works
          Container(width: double.infinity,
            padding: const EdgeInsets.all(12),
            color: AppColors.blue.withOpacity(0.06),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start,
              children: [
              Text('HOW IT WORKS',
                style: AppText.label.copyWith(
                  fontSize: 9, color: AppColors.blue)),
              const SizedBox(height: 8),
              _howStep(Icons.volume_up_rounded,
                'Lizzy asks the question out loud'),
              _howStep(Icons.mic_rounded,
                'Tap the mic and speak your answer'),
              _howStep(Icons.star_rounded,
                'AI scores your answer and gives feedback'),
              _howStep(Icons.arrow_forward_rounded,
                'Move to the next drill'),
            ])),

          const SizedBox(height: 14),
          AppWidgets.sectionLabel('YOUR 3 DRILLS'),
          const SizedBox(height: 10),

          ..._drills.asMap().entries.map((e) =>
            Padding(padding: const EdgeInsets.only(bottom: 10),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                Container(width: 26, height: 26,
                  decoration: BoxDecoration(
                    color: _drillColor(e.key), border: AppBorders.ink2),
                  child: Center(child: Text('${e.key + 1}',
                    style: AppText.label.copyWith(
                      color: e.key == 0 ? AppColors.ink : Colors.white,
                      fontSize: 11)))),
                const SizedBox(width: 10),
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(e.value.title,
                    style: AppText.label.copyWith(fontSize: 10)),
                  const SizedBox(height: 3),
                  Text(e.value.tip,
                    style: AppText.caption.copyWith(height: 1.4)),
                ])),
              ]))),
        ])),
      ])),
      const SizedBox(height: 20),
      AppWidgets.primaryButton(
        label: 'START VOICE DRILLS',
        onTap: _startDrill,
        color: AppColors.red),
      const SizedBox(height: 12),
      Text('Make sure your microphone is on and you\'re in a quiet place.',
        style: AppText.caption.copyWith(
          color: AppColors.dim, fontStyle: FontStyle.italic),
        textAlign: TextAlign.center),
    ]));

  Widget _howStep(IconData icon, String text) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Row(children: [
      Icon(icon, size: 14, color: AppColors.blue),
      const SizedBox(width: 8),
      Text(text, style: AppText.caption.copyWith(height: 1.3)),
    ]));

  // Drilling
  Widget _buildDrilling() {
    final drill = _drills[_currentDrill];
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(children: [

        // Question card
        Container(decoration: AppDecorations.card, child: Column(children: [
          Container(width: double.infinity,
            color: _drillColor(_currentDrill),
            padding: const EdgeInsets.all(12),
            child: Row(children: [
              Container(width: 28, height: 28,
                color: Colors.white,
                child: Center(child: Text('${_currentDrill + 1}',
                  style: AppText.label.copyWith(
                    color: _drillColor(_currentDrill), fontSize: 13)))),
              const SizedBox(width: 10),
              Expanded(child: Text(drill.title,
                style: AppText.title.copyWith(
                  color: _currentDrill == 0 ? AppColors.ink : Colors.white,
                  letterSpacing: 1))),
              // Timer shown while listening
              if (_listening)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 4),
                  color: Colors.black26,
                  child: Text(
                    '${(_recordSecs ~/ 60).toString().padLeft(2,"0")}:'
                    '${(_recordSecs % 60).toString().padLeft(2,"0")}',
                    style: AppText.label.copyWith(
                      color: Colors.white, fontSize: 12))),
            ])),
          Padding(padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Question text
            Container(width: double.infinity,
              padding: const EdgeInsets.all(12),
              color: AppColors.ink.withOpacity(0.04),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                const Icon(Icons.volume_up_rounded,
                  size: 14, color: AppColors.dim),
                const SizedBox(width: 8),
                Expanded(child: Text(drill.question,
                  style: AppText.body.copyWith(
                    fontWeight: FontWeight.w700, height: 1.5))),
              ])),

            const SizedBox(height: 12),

            // Coaching tip
            Container(width: double.infinity,
              padding: const EdgeInsets.all(10),
              color: AppColors.amber.withOpacity(0.08),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                const Icon(Icons.tips_and_updates_rounded,
                  color: AppColors.amber, size: 14),
                const SizedBox(width: 8),
                Expanded(child: Text(drill.tip,
                  style: AppText.caption.copyWith(height: 1.4))),
              ])),
          ])),
        ])),

        const SizedBox(height: 20),

        // Voice UI
        if (!_scoring && _lastResult == null) ...[

          // TTS playing indicator
          if (_ttsPlaying)
            Padding(padding: const EdgeInsets.only(bottom: 16),
              child: Row(mainAxisAlignment: MainAxisAlignment.center,
                children: [
                AnimatedBuilder(animation: _pulseCtrl, builder: (_, __) =>
                  Container(width: 8, height: 8,
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.amber.withOpacity(
                        0.4 + _pulseCtrl.value * 0.6)))),
                const SizedBox(width: 8),
                Text('Lizzy is speaking...',
                  style: AppText.label.copyWith(
                    color: AppColors.amber, fontSize: 10)),
              ])),

          // Mic button
          Center(child: GestureDetector(
            onTap: () {
              if (_listening)        _stopListening();
              else if (_canSpeak)   _startListening();
            },
            child: AnimatedBuilder(animation: _pulseCtrl, builder: (_, __) {
              final active = _listening;
              return Container(
                width: active ? 88 + _pulseCtrl.value * 10 : 88,
                height: active ? 88 + _pulseCtrl.value * 10 : 88,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: active    ? AppColors.red
                    : _canSpeak   ? AppColors.ink
                    : AppColors.dim,
                  border: Border.all(
                    color: active
                      ? AppColors.red.withOpacity(
                          0.3 + _pulseCtrl.value * 0.4)
                      : AppColors.ink,
                    width: active ? 3 + _pulseCtrl.value * 4 : 2),
                  boxShadow: active
                    ? [BoxShadow(
                        color: AppColors.red.withOpacity(
                          0.25 + _pulseCtrl.value * 0.2),
                        blurRadius: 16 + _pulseCtrl.value * 8,
                        spreadRadius: 2)]
                    : const [AppShadows.hard4]),
                child: Icon(
                  active ? Icons.stop_rounded : Icons.mic_rounded,
                  color: Colors.white, size: 36));
            }))),

          const SizedBox(height: 12),

          Text(
            _ttsPlaying  ? 'Listen to the question...'
            : _listening ? 'Speaking... tap to submit'
            : _canSpeak  ? 'Tap to answer'
            : 'Preparing question...',
            style: AppText.label.copyWith(
              color: _listening ? AppColors.red : AppColors.dim,
              fontSize: 11),
            textAlign: TextAlign.center),

          // Live transcript
          if (_listening && _liveTranscript.isNotEmpty) ...[
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.white,
                border: Border.all(
                  color: AppColors.red.withOpacity(0.3), width: 1.5)),
              child: Text(_liveTranscript,
                style: AppText.caption.copyWith(
                  height: 1.5, color: AppColors.ink,
                  fontStyle: FontStyle.italic))),
          ],
        ],

        // Scoring
        if (_scoring)
          Padding(padding: const EdgeInsets.only(top: 16),
            child: Container(
              decoration: AppDecorations.cardSmall,
              padding: const EdgeInsets.all(18),
              child: Row(children: [
                AnimatedBuilder(animation: _pulseCtrl, builder: (_, __) =>
                  Container(width: 10, height: 10,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.blue.withOpacity(
                        0.4 + _pulseCtrl.value * 0.6)))),
                const SizedBox(width: 14),
                Text('AI coach is reviewing your answer...',
                  style: AppText.caption),
              ]))),

        // Score result
        if (_lastResult != null && !_scoring) ...[
          const SizedBox(height: 16),
          _scoreCard(_lastResult!),
          const SizedBox(height: 16),

          // Next drill button
          AppWidgets.primaryButton(
            label: _currentDrill < _drills.length - 1
              ? 'NEXT DRILL  →'
              : 'SEE RESULTS',
            onTap: _nextDrill,
            color: _currentDrill < _drills.length - 1
              ? AppColors.blue : AppColors.amber),
        ],

        const SizedBox(height: 32),
      ]));
  }

  Widget _scoreCard(_DrillResult r) {
    final color = r.score >= 8 ? AppColors.blue
      : r.score >= 6 ? AppColors.amber : AppColors.red;
    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        border: Border.all(color: color.withOpacity(0.4), width: 1.5),
        boxShadow: [AppShadows.colored(color, size: 3)]),
      child: Column(children: [
        Container(width: double.infinity, color: color,
          padding: const EdgeInsets.all(10),
          child: Row(children: [
            Text('${r.score}/10  ·  ${r.grade}',
              style: AppText.title.copyWith(
                color: Colors.white, letterSpacing: 1.5)),
          ])),
        Padding(padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Icon(Icons.check_circle_rounded,
              color: AppColors.blue, size: 14),
            const SizedBox(width: 8),
            Expanded(child: Text(r.highlight,
              style: AppText.caption.copyWith(height: 1.4))),
          ]),
          const SizedBox(height: 8),
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Icon(Icons.lightbulb_rounded,
              color: AppColors.amber, size: 14),
            const SizedBox(width: 8),
            Expanded(child: Text(r.improvement,
              style: AppText.caption.copyWith(height: 1.4))),
          ]),
        ])),
      ]));
  }

  // Results
  Widget _buildResults() {
    final avg   = _avgScore;
    final color = avg >= 8 ? AppColors.blue
      : avg >= 6 ? AppColors.amber : AppColors.red;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(children: [
        Container(decoration: AppDecorations.card, child: Column(children: [
          Container(width: double.infinity, color: AppColors.ink,
            padding: const EdgeInsets.all(16),
            child: Column(children: [
              Text('SESSION COMPLETE',
                style: AppText.display.copyWith(
                  color: Colors.white, fontSize: 20)),
              const SizedBox(height: 4),
              Text('Focus: $_weaknessLabel',
                style: AppText.caption.copyWith(color: AppColors.amber)),
            ])),
          Padding(padding: const EdgeInsets.all(16),
            child: Column(children: [
            Container(width: 90, height: 90,
              decoration: BoxDecoration(
                color: color, border: AppBorders.ink3,
                boxShadow: [AppShadows.colored(color, size: 5)]),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center, children: [
                Text('$avg', style: AppText.display.copyWith(
                  color: Colors.white, fontSize: 32)),
                Text('/10', style: AppText.label.copyWith(
                  color: Colors.white.withOpacity(0.7))),
              ])),
            const SizedBox(height: 10),
            Text(avg >= 8 ? 'EXCELLENT SESSION'
              : avg >= 6 ? 'SOLID SESSION' : 'KEEP PRACTISING',
              style: AppText.title.copyWith(letterSpacing: 1.5)),
            const SizedBox(height: 20),

            ..._results.asMap().entries.map((e) =>
              Container(margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.mist, width: 1)),
                child: Row(children: [
                  Container(width: 26, height: 26,
                    color: _drillColor(e.key),
                    child: Center(child: Text('${e.key + 1}',
                      style: AppText.label.copyWith(
                        color: e.key == 0 ? AppColors.ink : Colors.white,
                        fontSize: 11)))),
                  const SizedBox(width: 10),
                  Expanded(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                    Text(_drills[e.key].title,
                      style: AppText.label.copyWith(fontSize: 9)),
                    Text(e.value.improvement,
                      style: AppText.caption.copyWith(fontSize: 9),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  ])),
                  Text('${e.value.score}/10',
                    style: AppText.title.copyWith(
                      color: _drillColor(e.key), fontSize: 16)),
                ]))),

            const SizedBox(height: 16),
            AppWidgets.primaryButton(
              label: 'BACK TO COACH',
              onTap: () => Navigator.pop(context),
              color: AppColors.amber),
          ])),
        ])),
      ]));
  }
}

enum _DrillPhase { loading, intro, drilling, results }

class _Drill {
  final String title, question, tip;
  const _Drill({required this.title, required this.question, required this.tip});
}

class _DrillResult {
  final int    score;
  final String grade, highlight, improvement, spokenFeedback;
  const _DrillResult({required this.score, required this.grade,
    required this.highlight, required this.improvement,
    required this.spokenFeedback});
}
