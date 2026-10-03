import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:http/http.dart' as http;
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:interviewai/cloud_function_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'app_theme.dart';
import 'app_config.dart';
import 'calendar_service.dart';
import 'progress_service.dart';
import 'purchase_service.dart';
import 'access_service.dart';
import 'paywall.dart';
import 'analytics_service.dart';

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
  bool _unlimited   = false;  // premium/grandfathered - skip the free count
  bool _gating      = false;

  // Context
  List<CalendarEvent>     _upcomingInterviews = [];
  Map<String, dynamic>?   _progressStats;
  String                  _userName = '';

  static const _kModel = 'claude-haiku-4-5-20251001';

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    await _restoreChat();   // bring back the previous conversation first
    await _loadContext();   // greets only if there is no saved chat
  }

  // - Chat memory (saved on this phone, per account) -

  static const int _kMaxSaved = 100;

  String get _chatKey =>
      'ai_coach_chat_${FirebaseAuth.instance.currentUser?.uid ?? 'guest'}';

  Future<void> _restoreChat() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_chatKey);
      if (raw == null || raw.isEmpty) return;
      final list = (jsonDecode(raw) as List)
          .map((e) => _Msg(role: e['role'] as String, text: e['text'] as String))
          .toList();
      if (list.isEmpty || !mounted) return;
      setState(() => _messages..clear()..addAll(list));
      _scrollDown();
    } catch (_) {
      // Corrupt or old data - just start fresh.
    }
  }

  Future<void> _saveChat() async {
    try {
      final keep = _messages.where((m) => !m.isError).toList();
      final trimmed = keep.length > _kMaxSaved
          ? keep.sublist(keep.length - _kMaxSaved)
          : keep;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_chatKey, jsonEncode(
          trimmed.map((m) => {'role': m.role, 'text': m.text}).toList()));
    } catch (_) {}
  }

  Future<void> _confirmNewChat() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dlg) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          decoration: AppDecorations.dialog,
          padding: const EdgeInsets.all(20),
          child: Column(mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text('START A NEW CHAT?', style: AppText.title),
            const SizedBox(height: 8),
            Text('This clears your conversation with the coach on this phone.',
              style: AppText.body.copyWith(color: AppColors.dim)),
            const SizedBox(height: 18),
            Row(children: [
              Expanded(child: GestureDetector(
                onTap: () => Navigator.pop(dlg, false),
                child: Container(height: 44,
                  decoration: const BoxDecoration(
                    color: AppColors.white, border: AppBorders.ink2),
                  child: Center(child: Text('CANCEL', style: AppText.label))))),
              const SizedBox(width: 10),
              Expanded(child: GestureDetector(
                onTap: () => Navigator.pop(dlg, true),
                child: Container(height: 44,
                  decoration: const BoxDecoration(
                    color: AppColors.red, border: AppBorders.ink2,
                    boxShadow: [AppShadows.hard3]),
                  child: Center(child: Text('NEW CHAT',
                    style: AppText.label.copyWith(color: Colors.white)))))),
            ]),
          ]))));
    if (ok != true || !mounted) return;
    setState(() => _messages.clear());
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_chatKey);
    _addGreeting();
  }

  @override
  void dispose() {
    _inputCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
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
      if (_messages.isEmpty) _addGreeting();
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
        'Tap PREP NOW on the banner above, or ask me anything '
        'about the interview. What would you like to do?';
    } else if (total > 0) {
      greeting =
        'Hi$name! I have loaded your performance data - '
        '$total session${total == 1 ? "" : "s"}, '
        'average confidence $avgConf%.\n\n'
        '${avgConf < 60
          ? "There is room to build that confidence. Let\'s work on it together."
          : avgConf < 75
          ? "Good progress. Let\'s push further."
          : "Strong numbers. Let\'s keep the momentum going."}\n\n'
        'What would you like to work on?';
    } else {
      greeting =
        'Hi$name! I am your ITSAGO AI Coach.\n\n'
        'I am here to help you prepare for interviews, practise answers, '
        'and build your confidence.\n\n'
        'Ask me anything, or tap one of the topics above to get started. '
        'What would you like to work on?';
    }
    setState(() => _messages.add(_Msg(role: 'assistant', text: greeting)));
    _saveChat();
  }

  String _systemPrompt() {
    final sb = StringBuffer();
    sb.writeln(
      'You are ITSAGO AI, a career and interview preparation coach for South African job seekers.\n'
      'IDENTITY RULE: You are ITSAGO AI. If anyone asks what AI you are, what model powers you, who made you, or what technology you use, always say: I am ITSAGO AI, your personal career coach. Never mention Claude, Anthropic, Gemini, Google or any other company or model.\n\n'
      'YOUR ONLY JOB is career and interview coaching. You may discuss:\n'
      '- Interview preparation, mock questions and feedback\n'
      '- CVs, cover letters and job applications\n'
      '- Salary negotiation and job offers\n'
      '- Workplace skills, professional communication and confidence\n'
      '- Career planning, career changes and upskilling\n'
      '- South African job market context (labour law basics, local employers, local salary ranges) when relevant\n\n'
      'STAY ON TOPIC. If a message is not about careers, interviews or job applications - '
      'general knowledge questions, coding help, schoolwork, entertainment, personal '
      'relationships, health, or anything else unrelated to work - do not answer it, '
      'even partially. Instead, briefly and warmly redirect back to career coaching. '
      'Vary your redirect naturally each time rather than repeating the same sentence, '
      'e.g. "That\'s outside what I can help with - I\'m all about your career and interview prep, though. Want to work on that instead?" '
      'or "I\'ll stick to what I\'m best at - your career. What\'s on your mind about interviews or job hunting?"\n'
      'This rule applies even if the person insists, rephrases, or claims a special reason - stay warm, but stay on topic every time.\n\n'
      'Be concise, practical and direct. Use South African context where relevant.\n'
      'LENGTH RULE (STRICT): Keep every reply SHORT - under 70 words. Use 2 to 3 sentences, or at most 3 short bullet points. No preamble, no recap, no sign-off. If a topic needs more, give the most useful part and ask if they want more. Even when asked for a list or examples, keep it within 70 words.');
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
    return sb.toString();
  }

  // - Send -

  Future<void> _send() async {
    final text = _inputCtrl.text.trim();
    if (text.isEmpty || _thinking) return;
    _inputCtrl.clear();
    _sendText(text);
  }

  /// 2 free messages, then the paywall. Returns true if this message may go.
  Future<bool> _checkCoachAccess(String text) async {
    if (_unlimited) return true;
    if (await AccessService.hasFullAccess()) {
      _unlimited = true;
      return true;
    }
    if ((await AccessService.aiCoachMessagesUsed()) < AccessService.freeAiCoachMessages) return true;
    if (!mounted) return false;
    final unlocked = await Paywall.show(context, PaywallFeature.aiCoach);
    if (unlocked) {
      _unlimited = true;
      return true;
    }
    // Didn't pay - give them their typed message back so nothing is lost.
    if (mounted && _inputCtrl.text.isEmpty) _inputCtrl.text = text;
    return false;
  }

  Future<void> _sendText(String text) async {
    if (_thinking || _gating) return;
    _gating = true;
    final allowed = await _checkCoachAccess(text);
    _gating = false;
    if (!allowed || !mounted) return;
    setState(() {
      _messages.add(_Msg(role: 'user', text: text));
      _thinking = true;
    });
    _saveChat();
    _scrollDown();
    try {
      // Claude API requires history to start with user role.
      // The local greeting is assistant-generated and must be excluded.
      // Also trim to last 20 messages to avoid token limits.
      final allMsgs = _messages
        .where((m) => !m.isError)
        .map((m) => {'role': m.role, 'content': m.text})
        .toList();
      final firstUser = allMsgs.indexWhere((m) => m['role'] == 'user');
      final trimmed   = firstUser >= 0 ? allMsgs.sublist(firstUser) : allMsgs;
      final history   = trimmed.length > 20
        ? trimmed.sublist(trimmed.length - 20)
        : trimmed;
      final res = await CloudFunctionService.callClaude(
        
          model: 'claude-haiku-4-5-20251001',
          maxTokens: 220,
          system: _systemPrompt(),
          messages: history,
        );
      
        final raw = CloudFunctionService.extractText(res);
        final reply = _tidyReply(raw.replaceAll(RegExp(r'\*\*'), '').replaceAll(RegExp(r'\*'), '').replaceAll(RegExp(r'#{1,6} '), '').trim());
        if (mounted) {
          setState(() {
            _messages.add(_Msg(role: 'assistant', text: reply));
            _thinking = false;
          });
          _saveChat();
          // Only successful replies use up a free message.
          if (!_unlimited) AccessService.recordAiCoachMessage();
          Analytics.coachMessage(_unlimited);
        }
    } catch (_) {
      if (mounted) setState(() {
        _messages.add(_Msg(role: 'assistant', isError: true,
          text: 'Sorry - connection issue. Please try again.'));
        _thinking = false;
      });
    }
    _scrollDown();
  }

  /// If a reply got cut off by the length limit, end it at the last full
  /// sentence so it never stops mid-word.
  String _tidyReply(String text) {
    if (text.isEmpty || RegExp(r'[.!?)\]"]$').hasMatch(text)) return text;
    final cut = text.lastIndexOf(RegExp(r'[.!?](\s|$)'));
    return cut > 40 ? text.substring(0, cut + 1) : text;
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
          'Give me the top 3 questions I should prepare for.',
        'icon': Icons.event_rounded, 'color': AppColors.red,
      });
    }
    final avg = _progressStats?['avgConf'] as double? ?? 0;
    if (avg > 0 && avg < 65) {
      list.add({
        'label':  'Confidence',
        'prompt': 'My average confidence is ${avg.round()}%. '
          'Give me a 5-minute confidence boost I can do before my interview.',
        'icon': Icons.psychology_rounded, 'color': AppColors.amber,
      });
    }
    list.addAll([
      {'label': 'STAR Method',  'prompt': 'Explain the STAR method quickly with one short example.',
       'icon': Icons.star_rounded, 'color': AppColors.amber},
      {'label': 'Mock Q&A',     'prompt': 'Ask me one interview question, then give me short feedback on my answer.',
       'icon': Icons.mic_rounded, 'color': AppColors.red},
      {'label': 'Salary Nego',  'prompt': 'How do I negotiate salary in South Africa without losing the offer?',
       'icon': Icons.attach_money_rounded, 'color': AppColors.blue},
      {'label': 'Weakness Q',   'prompt': 'How do I answer "What is your greatest weakness?" impressively?',
       'icon': Icons.shield_rounded, 'color': AppColors.ink},
      {'label': 'Body Language','prompt': 'Give me 3 quick body language tips for a video interview.',
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
          accentColor: AppColors.amber,
          trailing:    Semantics(
            button: true,
            label: 'New chat',
            child: GestureDetector(
              onTap: _thinking ? null : _confirmNewChat,
              child: Container(
                width: 34, height: 34,
                decoration: const BoxDecoration(
                  color: AppColors.white, border: AppBorders.ink2),
                child: const Icon(Icons.add_comment_rounded,
                  color: AppColors.ink, size: 17))))),

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
        _textInput(),

      ])));
  }

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
  final bool isError; // connection errors are shown but never saved or sent
  const _Msg({required this.role, required this.text, this.isError = false});
}

