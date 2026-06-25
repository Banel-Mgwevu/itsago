import 'package:http/http.dart' as http;
import 'dart:convert';
import 'app_config.dart';
import 'cloud_function_service.dart';

class ATSScoringService {

  static Future<ATSScore> score({
    required String cvText,
    required String jobDescription,
    required String jobTitle,
    required String company,
  }) async {
    final hasJD = jobDescription.trim().isNotEmpty;

    final prompt =
      'You are an expert ATS (Applicant Tracking System) analyst.\n\n'
      'Score this CV for the role of "$jobTitle" at "$company".\n'
      '${hasJD ? "Job Description:\n$jobDescription\n\n" : ""}'
      'CV Content:\n$cvText\n\n'
      'Evaluate and return ONLY valid JSON with no markdown:\n'
      '{\n'
      '  "score": <integer 0-100>,\n'
      '  "grade": "<EXCELLENT|STRONG|GOOD|FAIR|WEAK>",\n'
      '  "summary": "<2 sentence honest assessment>",\n'
      '  "keywordsFound": ["<keyword>"],\n'
      '  "keywordsMissing": ["<keyword>"],\n'
      '  "strengths": ["<specific strength>"],\n'
      '  "weaknesses": ["<specific weakness>"],\n'
      '  "quickWins": ["<one actionable fix>"]\n'
      '}\n\n'
      'Scoring criteria:\n'
      '- Keyword match with JD (30%)\n'
      '- Quantified achievements — numbers, percentages, impact (25%)\n'
      '- Relevant experience depth (20%)\n'
      '- CV structure and ATS parseability (15%)\n'
      '- Summary/objective quality (10%)\n'
      'Be honest. A weak CV should score 30-45, not 70.';

    try {
      final res = await CloudFunctionService.callClaude(
        model: 'claude-haiku-4-5-20251001',
        maxTokens: 600,
        messages: [{'role': 'user', 'content': prompt}],
      );
      final raw   = CloudFunctionService.extractText(res);
      final clean = raw.replaceAll('`json','').replaceAll('`','').trim();
      final data  = jsonDecode(clean) as Map<String, dynamic>;
      return ATSScore.fromJson(data);
    } catch (_) {}
    return ATSScore.failed();
  }
}

class ATSScore {
  final int          score;
  final String       grade;
  final String       summary;
  final List<String> keywordsFound;
  final List<String> keywordsMissing;
  final List<String> strengths;
  final List<String> weaknesses;
  final List<String> quickWins;
  final bool         failed;

  const ATSScore({
    required this.score,
    required this.grade,
    required this.summary,
    required this.keywordsFound,
    required this.keywordsMissing,
    required this.strengths,
    required this.weaknesses,
    required this.quickWins,
    this.failed = false,
  });

  factory ATSScore.fromJson(Map<String, dynamic> j) => ATSScore(
    score:           (j['score']   as num).toInt().clamp(0, 100),
    grade:           j['grade']    as String? ?? 'UNKNOWN',
    summary:         j['summary']  as String? ?? '',
    keywordsFound:   _list(j['keywordsFound']),
    keywordsMissing: _list(j['keywordsMissing']),
    strengths:       _list(j['strengths']),
    weaknesses:      _list(j['weaknesses']),
    quickWins:       _list(j['quickWins']),
  );

  factory ATSScore.failed() => const ATSScore(
    score: 0, grade: 'ERROR', summary: '',
    keywordsFound: [], keywordsMissing: [],
    strengths: [], weaknesses: [], quickWins: [],
    failed: true,
  );

  static List<String> _list(dynamic v) =>
    v == null ? [] : (v as List).map((e) => e.toString()).toList();

  Map<String, dynamic> toJson() => {
    'score':           score,
    'grade':           grade,
    'summary':         summary,
    'keywordsFound':   keywordsFound,
    'keywordsMissing': keywordsMissing,
    'strengths':       strengths,
    'weaknesses':      weaknesses,
    'quickWins':       quickWins,
  };
}
