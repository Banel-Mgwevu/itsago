import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'question_service.dart';
import 'package:camera/camera.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'dart:math';
import 'app_theme.dart';
import 'app_config.dart';
import 'cloud_function_service.dart';
import 'interview_screen.dart';

class LoadingScreen extends StatefulWidget {
  final List<CameraDescription> cameras;
  final String jobDescription;
  final String interviewStyle;
  final List<String> questionCategories;
  final String company;
  final String apiKey;
  const LoadingScreen({
    super.key,
    this.interviewStyle = 'friendly',
    this.questionCategories = const ['behavioural','situational','values','strength'], required this.cameras, required this.jobDescription,
    required this.company, required this.apiKey});
  @override
  State<LoadingScreen> createState() => _LoadingScreenState();
}

class _LoadingScreenState extends State<LoadingScreen>
    with TickerProviderStateMixin {

  late final AnimationController _spinCtrl = AnimationController(
    vsync: this, duration: const Duration(seconds: 2))..repeat();
  late final AnimationController _pulseCtrl = AnimationController(
    vsync: this, duration: const Duration(milliseconds: 1200))..repeat(reverse: true);
  late final Animation<double> _pulse = Tween<double>(begin: 0.92, end: 1.0)
      .animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));

  String _status = 'GETTING READY...';
  int    _step   = 0; // 0,1,2

  @override
  void initState() { super.initState(); _run(); }

  @override
  void dispose() { _spinCtrl.dispose(); _pulseCtrl.dispose(); super.dispose(); }

  Future<void> _set(String s, int step, [int ms = 900]) async {
    if (!mounted) return;
    setState(() { _status = s; _step = step; });
    await Future.delayed(Duration(milliseconds: ms));
  }

  Future<void> _run() async {
    final isGeneric = widget.jobDescription.trim().isEmpty;
    await _set('GETTING READY...', 0, 800);
    await _set(isGeneric
      ? 'PREPARING QUESTIONS...' : 'ANALYSING JOB DESCRIPTION...', 1, 600);

    try {
      final questions = isGeneric
        ? await _generateGeneric(widget.company, widget.questionCategories)
        : await _generate(widget.jobDescription, widget.company, widget.apiKey);

      await _set('QUESTIONS READY - STARTING...', 2, 800);

      if (mounted) Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => InterviewScreen(interviewStyle: widget.interviewStyle,
          cameras: widget.cameras, questions: questions,
          company: widget.company, apiKey: widget.apiKey)));
    } catch (e) {
      _errorDialog(e.toString());
    }
  }

  /// General interview questions - AI-generated so they sound like a real
  /// interviewer, not a fixed rotation of the same 5 questions every time.
  /// Falls back to the curated static question bank (QuestionService) if
  /// the AI call fails, which is why that import stays even on failure -
  /// both paths correctly respect the categories the person selected on
  /// the setup screen.
  Future<List<String>> _generateGeneric(
      String company, List<String> categories) async {
    try {
      final catLabel = categories.isEmpty
          ? 'general workplace behavioural questions'
          : categories.map(_categoryLabel).join(', ');
      final res = await CloudFunctionService.callClaude(
          model: 'claude-haiku-4-5-20251001',
          maxTokens: 300,
          messages: [{'role': 'user', 'content':
            'You are a warm, experienced interviewer at $company running a '
            'friendly practice interview. Write exactly 5 interview '
            'questions covering these question types: $catLabel.\n\n'
            'Sound like a real person talking in a real conversation, not '
            'a form or a survey. Rules:\n'
            '- Plain, natural spoken English - contractions are fine '
            '("what\'s", "you\'ve", "isn\'t")\n'
            '- One simple sentence per question, max 14 words\n'
            '- No two questions may start with the same opening words\n'
            '- Use a templated opener like "Tell me about a time..." or '
            '"Describe a situation where..." AT MOST once across all 5 '
            'questions - vary the phrasing the rest of the time\n'
            '- Build up naturally like a real interview: Q1 is a warm, '
            'easy opener about the candidate; Q2-3 explore the selected '
            'question types; Q4 goes one level deeper; Q5 is a warm '
            'closing question\n'
            '- Mention $company naturally in at least one question\n\n'
            'Return ONLY a valid JSON array of 5 strings. No markdown, no numbering.',
          }],
        );

        final raw   = CloudFunctionService.extractText(res);
        final clean = raw.replaceAll(RegExp(r'```[a-z]*'), '').replaceAll('```', '').trim();
        final list  = jsonDecode(clean) as List;
        if (list.length >= 3) {
          return list.take(5).map((q) => q.toString()).toList();
        }
    } catch (e) {
      if (kDebugMode) print('General question generation failed: $e');
    }
    return QuestionService.generate(
        company: company, jobTitle: '', jobDescription: '',
        categories: categories);
  }

  String _categoryLabel(String c) => switch (c) {
    'behavioural' => 'behavioural (past experiences)',
    'situational' => 'situational (hypothetical scenarios)',
    'values'      => 'company values and culture fit',
    'strength'    => 'strengths and self-assessment',
    'technical'   => 'technical or role-specific skills',
    'leadership'  => 'leadership and teamwork',
    'salary'      => 'salary and compensation expectations',
    _             => c,
  };

  Future<List<String>> _generate(
      String jobDesc, String company, String apiKey) async {
    try {
      final res = await CloudFunctionService.callClaude(
          model: 'claude-haiku-4-5-20251001',
          maxTokens: 300,
          messages: [{'role': 'user', 'content':
            'You are a warm, experienced interviewer at $company '
            'interviewing a candidate for this role:\n'
            '${jobDesc.length > 500 ? jobDesc.substring(0, 500) : jobDesc}\n\n'
            'Write exactly 5 interview questions for a friendly practice '
            'session. Sound like a real person having a conversation, not '
            'a form or a template. Rules:\n'
            '- Plain, natural spoken English - contractions are fine '
            '("what\'s", "you\'ve", "isn\'t")\n'
            '- One simple sentence per question, max 14 words\n'
            '- No compound questions (no "and"/"or" joining two questions)\n'
            '- No two questions may start with the same opening words\n'
            '- Use a templated opener like "Tell me about a time..." or '
            '"Describe a situation where..." AT MOST once across all 5 '
            'questions - vary the phrasing the rest of the time, the way '
            'a real interviewer naturally would\n'
            '- Build up like a real interview conversation: Q1 is a warm, '
            'easy opener about the candidate; Q2 explores their interest '
            'in this specific role; Q3 probes a skill or experience '
            'directly relevant to the job description; Q4 goes one level '
            'deeper with a real workplace scenario tied to this role; Q5 '
            'is a warm closing question\n'
            '- Reference specific skills or responsibilities from the job '
            'description where natural, not just generic phrasing\n\n'
            'Return ONLY a valid JSON array of 5 strings. No markdown, no numbering.',
          }],
        );

      
        final raw   = CloudFunctionService.extractText(res);
        final clean = raw.replaceAll(RegExp(r'```[a-z]*'), '').replaceAll('```', '').trim();
        final list  = jsonDecode(clean) as List;
        if (list.length >= 3) {
          return list.take(5).map((q) => q.toString()).toList();
        }
    } catch (e) {
      if (kDebugMode) print('Question generation failed: $e');
    }
    return _fallback(company);
  }

  List<String> _fallback(String company) => [
    'Can you tell me a little about yourself?',
    'Why are you interested in working at $company?',
    'What would you say is your greatest strength?',
    'Tell me about a time you had to solve a difficult problem at work.',
    'Where do you see yourself in the next two to three years?',
  ];

  void _errorDialog(String msg) {
    showDialog(context: context, barrierDismissible: false,
      builder: (dlg) => Dialog(backgroundColor: Colors.transparent,
        child: Container(
          decoration: AppDecorations.dialog,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(width: double.infinity,
              padding: const EdgeInsets.all(16),
              color: AppColors.amber,
              child: Row(children: [
                const Icon(Icons.warning_rounded, color: AppColors.ink, size: 20),
                const SizedBox(width: 10),
                Text('API ISSUE', style: AppText.title.copyWith(
                  color: AppColors.ink, letterSpacing: 2)),
              ])),
            Padding(padding: const EdgeInsets.all(20),
              child: Column(children: [
                Text('$msg\n\nContinue with default questions?',
                  style: AppText.body, textAlign: TextAlign.center),
                const SizedBox(height: 20),
                Row(children: [
                  Expanded(child: GestureDetector(
                    onTap: () { Navigator.pop(dlg); Navigator.pop(context); },
                    child: Container(height: 46,
                      decoration: const BoxDecoration(
                        color: AppColors.white, border: AppBorders.ink2),
                      child: Center(child: Text('CANCEL',
                        style: AppText.button.copyWith(color: AppColors.ink)))))),
                  const SizedBox(width: 12),
                  Expanded(child: GestureDetector(
                    onTap: () {
                      Navigator.pop(dlg);
                      Navigator.of(context).pushReplacement(MaterialPageRoute(
                        builder: (_) => InterviewScreen(interviewStyle: widget.interviewStyle,
                          cameras: widget.cameras,
                          questions: _fallback(widget.company),
                          company: widget.company,
                          apiKey: widget.apiKey)));
                    },
                    child: Container(height: 46,
                      decoration: const BoxDecoration(
                        color: AppColors.red, border: AppBorders.ink2,
                        boxShadow: [AppShadows.hard3]),
                      child: Center(child: Text('CONTINUE',
                        style: AppText.button))))),
                ]),
              ])),
          ]))));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.cream,
      body: SafeArea(child: Stack(children: [
        // Geometric accents
        Positioned(top: -40, right: -40,
          child: Container(width: 130, height: 130,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.amber.withOpacity(0.12),
              border: Border.all(
                color: AppColors.amber.withOpacity(0.25), width: 1.5)))),
        Positioned(bottom: 80, left: -20,
          child: Container(width: 60, height: 14,
            color: AppColors.blue.withOpacity(0.15))),

        Center(child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            // Company label
            AppWidgets.badge(widget.company.toUpperCase(), bg: AppColors.ink, fg: Colors.white),
            const SizedBox(height: 40),

            // Spinning Bauhaus shape
            AnimatedBuilder(animation: _spinCtrl,
              builder: (_, __) => Transform.rotate(
                angle: _spinCtrl.value * 2 * pi,
                child: Container(width: 110, height: 110,
                  decoration: BoxDecoration(
                    color: AppColors.red,
                    border: AppBorders.ink3,
                    boxShadow: const [AppShadows.hard5]),
                  child: Stack(children: [
                    Positioned(top: 10, right: 10,
                      child: Container(width: 22, height: 22,
                        decoration: const BoxDecoration(
                          color: AppColors.amber, shape: BoxShape.circle))),
                    Center(child: Container(width: 36, height: 36,
                      color: AppColors.ink)),
                  ])))),

            const SizedBox(height: 48),

            // Status text
            AnimatedBuilder(animation: _pulseCtrl,
              builder: (_, __) => Transform.scale(
                scale: _pulse.value,
                child: Text(_status,
                  style: AppText.title.copyWith(letterSpacing: 2),
                  textAlign: TextAlign.center))),

            const SizedBox(height: 32),

            // Step progress
            Container(
              width: double.infinity,
              decoration: AppDecorations.cardSmall,
              child: Column(children: [
                Container(height: 4,
                  color: _step == 0 ? AppColors.amber
                       : _step == 1 ? AppColors.blue
                       : AppColors.red),
                Padding(padding: const EdgeInsets.all(16),
                  child: Row(children: List.generate(3, (i) {
                    final done  = i < _step;
                    final active = i == _step;
                    final labels = ['GET READY', 'GENERATE', 'START'];
                    final colors = [AppColors.amber, AppColors.blue, AppColors.red];
                    return Expanded(child: Row(children: [
                      if (i > 0) Expanded(child: Container(height: 1.5,
                        color: done ? colors[i] : AppColors.mist)),
                      Column(children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          width: 28, height: 28,
                          decoration: BoxDecoration(
                            color: done || active ? colors[i] : AppColors.mist,
                            border: Border.all(color: AppColors.ink, width: 1.5)),
                          child: Center(child: done
                            ? const Icon(Icons.check_rounded,
                                color: Colors.white, size: 14)
                            : Text('${i + 1}', style: AppText.label.copyWith(
                                color: active ? Colors.white : AppColors.dim)))),
                        const SizedBox(height: 4),
                        Text(labels[i], style: AppText.label.copyWith(
                          fontSize: 7,
                          color: active ? colors[i] : AppColors.dim)),
                      ]),
                      if (i == 2) const SizedBox.shrink(),
                    ]));
                  }))),
              ])),

            const SizedBox(height: 24),
            Text(
              widget.jobDescription.isEmpty
                ? 'LOADING STANDARD QUESTIONS'
                : 'AI IS ANALYSING YOUR JOB REQUIREMENTS',
              style: AppText.caption.copyWith(letterSpacing: 1.5),
              textAlign: TextAlign.center),
          ])),
        ),
      ])),
    );
  }
}



