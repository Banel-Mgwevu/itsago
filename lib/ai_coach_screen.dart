import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:http/http.dart' as http;
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:interviewai/cloud_function_service.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'dart:convert';
import 'app_theme.dart';
import 'app_config.dart';
import 'calendar_service.dart';
import 'progress_service.dart';
import 'drill_session_screen.dart';

class AiCoachScreen extends StatefulWidget {
  final List<CameraDescription> cameras;
  const AiCoachScreen({super.key, required this.cameras});
  @override
  State<AiCoachScreen> createState() => _AiCoachScreenState();
}

class _AiCoachScreenState extends State<AiCoachScreen>
    with TickerProviderStateMixin {

  final _inputCtrl  = TextEditingController();
  final _scrollCtrl = ScrollController();
  final List<_Msg>  _messages = [];

  // State
  bool _thinking    = false;
  bool _loadingCtx  = true;
  bool _voiceMode   = false;
  bool _listening   = false;
  bool _ttsPlaying  = false;
  bool _voiceReady  = false;

  // Voice
  final FlutterTts        _tts    = FlutterTts();
  final stt.SpeechToText  _speech = stt.SpeechToText();

  // Context
  List<CalendarEvent>     _upcomingInterviews = [];
  Map<String, dynamic>?   _progressStats;
  String                  _userName = '';

  // Pulse animation for mic
  late AnimationController _micPulse = AnimationController(
    vsync: this, duration: const Duration(milliseconds: 800))
    ..repeat(reverse: true);

  static const _kModel = 'claude-haiku-4-5-20251001';

  @override
  void initState() {
    super.initState();
    _initVoice();
    _loadContext();
  }

  @override
  void dispose() {
    _inputCtrl.dispose();
    _scrollCtrl.dispose();
    _micPulse.dispose();
    _tts.stop();
    _speech.stop();
    super.dispose();
  }

  // - Voice init -

  Future<void> _initVoice() async {
    await _tts.setLanguage('en-ZA');
    await _tts.setSpeechRate(0.48);
    await _tts.setVolume(1.0);
    _tts.setCompletionHandler(() {
      if (mounted) setState(() => _ttsPlaying = false);
    });
    _voiceReady = await _speech.initialize(
      onStatus: (s) {
        if (s == 'done' || s == 'notListening') {
          if (mounted) setState(() => _listening = false);
        }
      },
      onError: (_) {
        if (mounted) setState(() => _listening = false);
      });
    if (mounted) setState(() {});
  }

  Future<void> _speak(String text) async {
    if (!_voiceMode) return;
    setState(() => _ttsPlaying = true);
    await _tts.speak(text);
  }

  Future<void> _toggleListen() async {
    if (!_voiceReady) return;
    if (_listening) {
      await _speech.stop();
      setState(() => _listening = false);
      return;
    }
    setState(() => _listening = true);
    await _speech.listen(
      onResult: (r) {
        if (r.finalResult && r.recognizedWords.isNotEmpty) {
          setState(() => _listening = false);
          _sendText(r.recognizedWords);
        }
      },
      listenFor: const Duration(seconds: 30),
      pauseFor: const Duration(seconds: 3),
      localeId: 'en_ZA');
  }

  void _stopTTS() {
    _tts.stop();
    setState(() => _ttsPlaying = false);
  }

  // - Load context -

  Future<void> _loadContext() async {
    setState(() => _loadingCtx = true);
    final user = FirebaseAuth.instance.currentUser;
    _userName = user?.displayName?.split(' ').first ?? '';
    final results = await Future.wait([
      _loadCalendar(), ProgressService.getStats()]);
    _upcomingInterviews = results[0] as List<CalendarEvent>;
    _progressStats      = results[1] as Map<String, dynamic>?;
    if (mounted) {
      setState(() => _loadingCtx = false);
      _addGreeting();
    }
  }

  Future<List<CalendarEvent>> _loadCalendar() async {
    try {
      final svc = GoogleCalendarService();
      await svc.initialize();
      if (!svc.isSignedIn) return [];
      return await svc.getInterviewEvents();
    } catch (_) { return []; }
  }

  void _addGreeting() {
    final name     = _userName.isNotEmpty ? ', $_userName' : '';
    final total    = _progressStats?['total'] as int? ?? 0;
    final avgConf  = (_progressStats?['avgConf'] as double? ?? 0).round();
    final hasCalendar = _upcomingInterviews.isNotEmpty;

    String greeting;
    if (hasCalendar) {
      final next  = _upcomingInterviews.first;
      final days  = next.startTime.difference(DateTime.now()).inDays;
      final when  = days == 0 ? 'TODAY' : days == 1 ? 'TOMORROW' : 'in $days days';
      greeting =
        'Hi$name! I can see you have an interview $when - ${next.title}.\n\n'
        'I have loaded your calendar and performance data. '
        'Tap PREP NOW on the banner above, or start a Drill Session '
        'to practise targeted questions. What would you like to do?';
    } else if (total > 0) {
      greeting =
        'Hi$name! I have loaded your performance data - '
        '$total session${total == 1 ? "" : "s"}, '
        'average confidence $avgConf%.\n\n'
        '${avgConf < 60
          ? "There is room to build that confidence. Try a Drill Session."
          : avgConf < 75
          ? "Good progress. Let\'s push further - try a targeted drill."
          : "Strong numbers. Let\'s keep the momentum going."}\n\n'
        'What would you like to work on?';
    } else {
      greeting =
        'Hi$name! I am your ITSAGO AI Coach.\n\n'
        'I am here to help you prepare for interviews, practise answers, '
        'and build your confidence.\n\n'
        'You can chat with me, run a structured Drill Session, '
        'or use voice mode to practise speaking out loud. '
        'What would you like to do?';
    }
    setState(() => _messages.add(_Msg(role: 'assistant', text: greeting)));
  }

  String _systemPrompt() {
    final sb = StringBuffer();
    sb.writeln(
      'You are ITSAGO AI, a career and interview preparation assistant for South African job seekers. Be concise, practical and direct. Use South African context where relevant.\n'
      'IDENTITY RULE: You are ITSAGO AI. If anyone asks what AI you are, what model powers you, who made you, or what technology you use, always say: I am ITSAGO AI, your personal career coach. Never mention Claude, Anthropic, Gemini, Google or any other company or model.\n'
      'SCOPE RULE: Only answer questions about interviews, careers, CVs, job applications, salary negotiation, workplace skills and professional development. For anything else respond: I am only able to help with career and interview preparation. Try asking me about interviews, CVs or job applications!');
    if (_userName.isNotEmpty) sb.writeln('\nUser: $_userName');
    final stats = _progressStats;
    if (stats != null && (stats['total'] as int) > 0) {
      final avg  = (stats['avgConf']    as double).round();
      final best = (stats['best']       as double).round();
      final fill = (stats['avgFillers'] as double).toStringAsFixed(1);
      sb.writeln('\n=== PERFORMANCE DATA ===');
      sb.writeln('Sessions: ${stats["total"]}  Avg: $avg%  Best: $best%  Fillers: $fill/session');
      for (final s in (stats['sessions'] as List? ?? []).take(3)) {
        sb.writeln('  ${s["company"]} | ${s["jobTitle"]} | ${(s["overallConfidence"] as num).round()}%');
      }
    }
    if (_upcomingInterviews.isNotEmpty) {
      sb.writeln('\n=== UPCOMING INTERVIEWS ===');
      for (final e in _upcomingInterviews.take(3)) {
        final d = e.startTime.difference(DateTime.now()).inDays;
        sb.writeln('${e.title} - in $d day${d == 1 ? "" : "s"}');
      }
    }
    if (_voiceMode) {
      sb.writeln('\nUSER IS IN VOICE MODE - keep replies under 3 sentences. '
        'Be conversational, no bullet lists, no markdown.');
    }
    return sb.toString();
  }

  // - Send -

  Future<void> _send() async {
    final text = _inputCtrl.text.trim();
    if (text.isEmpty || _thinking) return;
    _inputCtrl.clear();
    _sendText(text);
  }

  Future<void> _sendText(String text) async {
    if (_thinking) return;
    if (_ttsPlaying) _stopTTS();
    setState(() {
      _messages.add(_Msg(role: 'user', text: text));
      _thinking = true;
    });
    _scrollDown();
    try {
      // Claude API requires history to start with user role.
      // The local greeting is assistant-generated and must be excluded.
      // Also trim to last 20 messages to avoid token limits.
      final allMsgs = _messages
        .map((m) => {'role': m.role, 'content': m.text})
        .toList();
      final firstUser = allMsgs.indexWhere((m) => m['role'] == 'user');
      final trimmed   = firstUser >= 0 ? allMsgs.sublist(firstUser) : allMsgs;
      final history   = trimmed.length > 20
        ? trimmed.sublist(trimmed.length - 20)
        : trimmed;
      final res = await CloudFunctionService.callClaude(
        
          model: 'claude-haiku-4-5-20251001',
          maxTokens: _voiceMode ? 200 : 600,
          system: _systemPrompt(),
          messages: history,
        );
      
        final raw = CloudFunctionService.extractText(res);
        final reply = raw.replaceAll(RegExp(r'\*\*'), '').replaceAll(RegExp(r'\*'), '').replaceAll(RegExp(r'#{1,6} '), '').trim();
        if (mounted) {
          setState(() {
            _messages.add(_Msg(role: 'assistant', text: reply));
            _thinking = false;
          });
          if (_voiceMode) await _speak(reply);
        }
    } catch (_) {
      if (mounted) setState(() {
        _messages.add(_Msg(role: 'assistant',
          text: 'Sorry - connection issue. Please try again.'));
        _thinking = false;
      });
    }
    _scrollDown();
  }

  void _scrollDown() => Future.delayed(const Duration(milliseconds: 120), () {
    if (_scrollCtrl.hasClients) _scrollCtrl.animateTo(
      _scrollCtrl.position.maxScrollExtent,
      duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
  });

  // - Context-aware quick prompts -

  List<Map<String, dynamic>> get _contextPrompts {
    final list = <Map<String, dynamic>>[];
    if (_upcomingInterviews.isNotEmpty) {
      final next = _upcomingInterviews.first;
      final days = next.startTime.difference(DateTime.now()).inDays;
      list.add({
        'label':  days == 0 ? 'Prep Today' : days == 1 ? 'Prep Tomorrow' : 'Prep Interview',
        'prompt': 'I have an interview for ${next.title} '
          '${days == 0 ? "today" : days == 1 ? "tomorrow" : "in $days days"}. '
          'Give me the top 5 questions and a prep plan.',
        'icon': Icons.event_rounded, 'color': AppColors.red,
      });
    }
    final avg = _progressStats?['avgConf'] as double? ?? 0;
    if (avg > 0 && avg < 65) {
      list.add({
        'label':  'Confidence',
        'prompt': 'My average confidence is ${avg.round()}%. '
          'Give me a 5-minute confidence building drill.',
        'icon': Icons.psychology_rounded, 'color': AppColors.amber,
      });
    }
    list.addAll([
      {'label': 'STAR Method',  'prompt': 'Teach me STAR with 2 worked examples.',
       'icon': Icons.star_rounded, 'color': AppColors.amber},
      {'label': 'Mock Q&A',     'prompt': 'Ask me 3 interview questions and give feedback on my answers.',
       'icon': Icons.mic_rounded, 'color': AppColors.red},
      {'label': 'Salary Nego',  'prompt': 'How do I negotiate salary in South Africa without losing the offer?',
       'icon': Icons.attach_money_rounded, 'color': AppColors.blue},
      {'label': 'Weakness Q',   'prompt': 'How do I answer "What is your greatest weakness?" impressively?',
       'icon': Icons.shield_rounded, 'color': AppColors.ink},
      {'label': 'Body Language','prompt': 'Give me 5 video interview body language tips.',
       'icon': Icons.accessibility_new_rounded, 'color': AppColors.blue},
    ]);
    return list.take(6).toList();
  }

  // - Build -

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.cream,
      body: SafeArea(child: Column(children: [

        AppWidgets.header(
          title:       'AI COACH',
          context:     context,
          leading:     AppWidgets.backButton(context),
          accentColor: AppColors.amber),

        // Interview banner
        if (_upcomingInterviews.isNotEmpty)
          _interviewBanner(_upcomingInterviews.first),

        // Context loading
        if (_loadingCtx)
          Container(
            color: AppColors.blue.withOpacity(0.06),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            child: Row(children: [
              const SizedBox(width: 12, height: 12,
                child: CircularProgressIndicator(
                  color: AppColors.blue, strokeWidth: 2)),
              const SizedBox(width: 10),
              Text('Loading your performance data...',
                style: AppText.caption.copyWith(color: AppColors.blue)),
            ])),

        // Toolbar: voice mode + drill mode
        _toolbar(),

        // Quick prompts
        Container(
          color: AppColors.white, height: 42,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            children: _contextPrompts.map((p) => GestureDetector(
              onTap: () {
                _inputCtrl.text = p['prompt'] as String;
                _send();
              },
              child: Container(
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: (p['color'] as Color).withOpacity(0.08),
                  border: Border.all(
                    color: (p['color'] as Color).withOpacity(0.3), width: 1.5)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(p['icon'] as IconData,
                    size: 12, color: p['color'] as Color),
                  const SizedBox(width: 5),
                  Text((p['label'] as String).toUpperCase(),
                    style: AppText.label.copyWith(
                      color: p['color'] as Color, fontSize: 8)),
                ])))).toList())),

        AppWidgets.divider(),

        // Messages
        Expanded(child: ListView.builder(
          controller: _scrollCtrl,
          padding: const EdgeInsets.all(14),
          itemCount: _messages.length + (_thinking ? 1 : 0),
          itemBuilder: (_, i) {
            if (i == _messages.length) return _thinkingBubble();
            return _bubble(_messages[i]);
          })),

        AppWidgets.divider(),

        // Context strip
        if (!_loadingCtx && (_progressStats?['total'] as int? ?? 0) > 0)
          _contextStrip(),

        // Input area
        _voiceMode ? _voiceInput() : _textInput(),

      ])));
  }

  // - Toolbar -

  Widget _toolbar() => Container(
    color: AppColors.white,
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    child: Row(children: [

      // Voice mode toggle
      GestureDetector(
        onTap: () => setState(() { _voiceMode = !_voiceMode; if (!_voiceMode) { _speech.stop(); _tts.stop(); }}),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: _voiceMode ? AppColors.red : Colors.transparent,
            border: Border.all(
              color: _voiceMode ? AppColors.red : AppColors.mist,
              width: 1.5)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.mic_rounded,
              size: 13,
              color: _voiceMode ? Colors.white : AppColors.dim),
            const SizedBox(width: 6),
            Text('VOICE${_voiceMode ? " ON" : ""}',
              style: AppText.label.copyWith(
                fontSize: 8,
                color: _voiceMode ? Colors.white : AppColors.dim)),
          ]))),

      const SizedBox(width: 8),

      // TTS stop button (when playing)
      if (_ttsPlaying)
        GestureDetector(
          onTap: _stopTTS,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.amber,
              border: Border.all(color: AppColors.ink, width: 1.5)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.stop_rounded, size: 13, color: AppColors.ink),
              const SizedBox(width: 6),
              Text('STOP', style: AppText.label.copyWith(
                fontSize: 8, color: AppColors.ink)),
            ]))),

      const Spacer(),

      // Drill mode button
      GestureDetector(
        onTap: () => Navigator.push(context, MaterialPageRoute(
          builder: (_) => DrillSessionScreen(
            progressStats: _progressStats))),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: const BoxDecoration(
            color: AppColors.ink, border: AppBorders.ink2,
            boxShadow: [AppShadows.hard3]),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.fitness_center_rounded,
              size: 13, color: AppColors.amber),
            const SizedBox(width: 6),
            Text('DRILL MODE',
              style: AppText.label.copyWith(
                fontSize: 8, color: Colors.white)),
          ]))),
    ]));

  // - Voice input -

  Widget _voiceInput() => Container(
    color: AppColors.white,
    padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
    child: Column(children: [
      if (_listening)
        Padding(padding: const EdgeInsets.only(bottom: 10),
          child: Text('Listening...',
            style: AppText.label.copyWith(
              color: AppColors.red, fontSize: 10))),
      AnimatedBuilder(animation: _micPulse, builder: (_, __) =>
        GestureDetector(
          onTap: _listening ? _toggleListen : _toggleListen,
          child: Container(
            width: 72 + (_listening ? _micPulse.value * 8 : 0),
            height: 72 + (_listening ? _micPulse.value * 8 : 0),
            decoration: BoxDecoration(
              color: _listening ? AppColors.red : AppColors.ink,
              shape: BoxShape.circle,
              border: Border.all(
                color: _listening
                  ? AppColors.red.withOpacity(0.3 + _micPulse.value * 0.4)
                  : AppColors.ink,
                width: _listening ? 3 + _micPulse.value * 4 : 2),
              boxShadow: _listening
                ? [BoxShadow(
                    color: AppColors.red.withOpacity(0.3 + _micPulse.value * 0.2),
                    blurRadius: 12 + _micPulse.value * 8,
                    spreadRadius: 2)]
                : const [AppShadows.hard4]),
            child: Icon(
              _listening ? Icons.stop_rounded : Icons.mic_rounded,
              color: Colors.white,
              size: 30)))),
      const SizedBox(height: 10),
      Text(
        _thinking ? 'Coach is thinking...'
        : _ttsPlaying ? 'Coach is speaking...'
        : _listening ? 'Tap to stop'
        : 'Tap to speak',
        style: AppText.caption.copyWith(color: AppColors.dim)),
    ]));

  // - Text input -

  Widget _textInput() => Container(
    color: AppColors.white,
    padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
    child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
      Expanded(child: Container(
        decoration: const BoxDecoration(
          color: AppColors.cream, border: AppBorders.ink2),
        child: TextField(
          controller: _inputCtrl,
          maxLines: 4, minLines: 1,
          style: AppText.body,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(
            hintText: 'Ask your AI coach anything...',
            hintStyle: AppText.caption,
            contentPadding: const EdgeInsets.all(12),
            border: InputBorder.none),
          onSubmitted: (_) => _send()))),
      const SizedBox(width: 10),
      GestureDetector(
        onTap: _send,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 48, height: 48,
          decoration: BoxDecoration(
            color: _thinking ? AppColors.dim : AppColors.ink,
            border: AppBorders.ink2,
            boxShadow: _thinking ? null : const [AppShadows.hard3]),
          child: _thinking
            ? const Center(child: SizedBox(width: 18, height: 18,
                child: CircularProgressIndicator(
                  color: Colors.white, strokeWidth: 2)))
            : const Icon(Icons.send_rounded, color: Colors.white, size: 20))),
    ]));

  // - Widgets -

  Widget _interviewBanner(CalendarEvent event) {
    final days = event.startTime.difference(DateTime.now()).inDays;
    final when = days == 0 ? 'TODAY' : days == 1 ? 'TOMORROW' : 'IN $days DAYS';
    return Container(
      width: double.infinity, color: AppColors.red,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: Row(children: [
        Container(width: 4, height: 32, color: Colors.white),
        const SizedBox(width: 10),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('INTERVIEW $when',
            style: AppText.label.copyWith(
              color: Colors.white, fontSize: 8, letterSpacing: 1.5)),
          Text(event.title,
            style: AppText.label.copyWith(color: Colors.white),
            maxLines: 1, overflow: TextOverflow.ellipsis),
        ])),
        GestureDetector(
          onTap: () {
            _inputCtrl.text =
              'I have an interview for ${event.title} $when. '
              'Give me the top 5 questions and a full prep plan.';
            _send();
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: AppColors.red, width: 1.5)),
            child: Text('PREP NOW', style: AppText.label.copyWith(
              color: AppColors.red, fontSize: 8)))),
      ]));
  }

  Widget _contextStrip() {
    final total = _progressStats!['total'] as int;
    final avg   = (_progressStats!['avgConf'] as double).round();
    final best  = (_progressStats!['best']    as double).round();
    return Container(
      color: AppColors.ink.withOpacity(0.03),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
      child: Row(children: [
        const Icon(Icons.insights_rounded, size: 11, color: AppColors.dim),
        const SizedBox(width: 8),
        Text('Context: $total sessions  -.  avg $avg%  -.  best $best%',
          style: AppText.caption.copyWith(fontSize: 9, color: AppColors.dim)),
      ]));
  }

  Widget _bubble(_Msg msg) {
    final isUser = msg.role == 'user';
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: isUser
          ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
        if (!isUser) ...[
          Container(width: 34, height: 34,
            decoration: const BoxDecoration(
              color: AppColors.amber, border: AppBorders.ink2,
              boxShadow: [AppShadows.hard3]),
            child: Center(child: Text('AI',
              style: AppText.label.copyWith(
                color: AppColors.ink, fontSize: 9)))),
          const SizedBox(width: 10),
        ],
        Flexible(child: GestureDetector(
          onTap: (!isUser && _voiceMode)
            ? () => _speak(msg.text) : null,
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isUser ? AppColors.ink : AppColors.white,
              border: Border.all(
                color: isUser ? AppColors.ink : AppColors.mist,
                width: isUser ? 2 : 1.5),
              boxShadow: isUser
                ? const [AppShadows.hard3]
                : [BoxShadow(
                    color: AppColors.inkAt(0.05),
                    offset: const Offset(2, 2))]),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
              Text(msg.text,
                style: AppText.body.copyWith(
                  color: isUser ? Colors.white : AppColors.ink,
                  height: 1.5)),
              if (!isUser && _voiceMode) ...[
                const SizedBox(height: 6),
                Row(children: [
                  const Icon(Icons.volume_up_rounded,
                    size: 11, color: AppColors.dim),
                  const SizedBox(width: 4),
                  Text('Tap to replay',
                    style: AppText.caption.copyWith(
                      fontSize: 9, color: AppColors.dim)),
                ]),
              ],
            ])),
        )),
        if (isUser) ...[
          const SizedBox(width: 10),
          Container(width: 34, height: 34,
            decoration: const BoxDecoration(
              color: AppColors.red, border: AppBorders.ink2,
              boxShadow: [AppShadows.hard3]),
            child: const Center(child: Icon(Icons.person_rounded,
              color: Colors.white, size: 16))),
        ],
      ]));
  }

  Widget _thinkingBubble() => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(width: 34, height: 34,
        decoration: const BoxDecoration(
          color: AppColors.amber, border: AppBorders.ink2,
          boxShadow: [AppShadows.hard3]),
        child: Center(child: Text('AI',
          style: AppText.label.copyWith(
            color: AppColors.ink, fontSize: 9)))),
      const SizedBox(width: 10),
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.white,
          border: Border.all(color: AppColors.mist, width: 1.5)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          _dot(0), const SizedBox(width: 5),
          _dot(200), const SizedBox(width: 5),
          _dot(400),
        ])),
    ]));

  Widget _dot(int ms) => TweenAnimationBuilder<double>(
    tween: Tween(begin: 0.2, end: 1.0),
    duration: Duration(milliseconds: 600 + ms),
    builder: (_, v, __) => Container(
      width: 7, height: 7,
      decoration: BoxDecoration(
        color: AppColors.inkAt(v), shape: BoxShape.circle)));
}

class _Msg {
  final String role, text;
  const _Msg({required this.role, required this.text});
}

