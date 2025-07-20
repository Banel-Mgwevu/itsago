import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'dart:math';
import 'main.dart';
import 'interview_screen.dart';

class LoadingScreen extends StatefulWidget {
  final List<CameraDescription> cameras;
  final String jobDescription;
  final String company;
  final String apiKey;

  const LoadingScreen({
    Key? key,
    required this.cameras,
    required this.jobDescription,
    required this.company,
    required this.apiKey,
  }) : super(key: key);

  @override
  State<LoadingScreen> createState() => _LoadingScreenState();
}

class _LoadingScreenState extends State<LoadingScreen>
    with TickerProviderStateMixin {
  late AnimationController _rotationController;
  late Animation<double> _rotationAnimation;
  String _loadingText = 'GET READY...';
  
  @override
  void initState() {
    super.initState();
    
    // Initialize rotation animation
    _rotationController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
    
    _rotationAnimation = Tween<double>(
      begin: 0,
      end: 2 * pi,
    ).animate(CurvedAnimation(
      parent: _rotationController,
      curve: Curves.linear,
    ));
    
    _rotationController.repeat();
    
    // Start the loading process
    _startLoadingProcess();
  }

  @override
  void dispose() {
    _rotationController.dispose();
    super.dispose();
  }

  void _startLoadingProcess() async {
    // Check if this is a normal interview (empty job description)
    bool isNormalInterview = widget.jobDescription.trim().isEmpty;
    
    if (isNormalInterview) {
      // Normal Interview Flow - No API call needed
      await _updateLoadingText('GET READY...', 1000);
      await _updateLoadingText('INTERVIEW STARTING\nPREPARING QUESTIONS...', 1000);
      await _updateLoadingText('QUESTIONS READY!\nSTARTING INTERVIEW...', 1000);
      
      // Get default questions and start interview
      final questions = _getFallbackQuestions(widget.company);
      
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => InterviewScreen(
              cameras: widget.cameras,
              questions: questions,
              company: widget.company,
              apiKey: widget.apiKey,
            ),
          ),
        );
      }
      return;
    }

    // AI Powered Interview Flow
    await _updateLoadingText('GET READY...', 1000);
    await _updateLoadingText('INTERVIEW STARTING\nGENERATING QUESTIONS...', 500);
    
    try {
      final questions = await _generateQuestions(
        widget.jobDescription,
        widget.company,
        widget.apiKey,
      );

      if (questions.isNotEmpty) {
        await _updateLoadingText('QUESTIONS READY!\nSTARTING INTERVIEW...', 1000);
        
        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (context) => InterviewScreen(
                cameras: widget.cameras,
                questions: questions,
                company: widget.company,
                apiKey: widget.apiKey,
              ),
            ),
          );
        }
      } else {
        _showApiErrorDialog('Using default questions');
      }
    } catch (e) {
      String errorMessage = 'ERROR: ${e.toString()}';
      
      if (e.toString().contains('QUOTA_EXCEEDED')) {
        errorMessage = 'API QUOTA EXCEEDED\nWAIT OR USE DEFAULTS';
      } else if (e.toString().contains('API_KEY_INVALID')) {
        errorMessage = 'INVALID API KEY\nCHECK CONFIGURATION';
      } else if (e.toString().contains('PERMISSION_DENIED')) {
        errorMessage = 'API ACCESS DENIED\nCHECK ACCOUNT STATUS';
      } else if (e.toString().contains('timeout')) {
        errorMessage = 'CONNECTION TIMEOUT\nCHECK INTERNET';
      }
      
      _showApiErrorDialog(errorMessage);
    }
  }

  Future<void> _updateLoadingText(String text, int delayMs) async {
    setState(() {
      _loadingText = text;
    });
    await Future.delayed(Duration(milliseconds: delayMs));
  }

  Future<List<String>> _generateQuestions(String jobDesc, String company, String apiKey) async {
    for (int attempt = 1; attempt <= 3; attempt++) {
      try {
        print('Attempting to generate questions with Gemini API (attempt $attempt/3)...');
        
        // Updated to use Gemini 2.0 Flash model
        final String baseUrl = 'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent';
        
        final response = await http.post(
          Uri.parse('$baseUrl?key=$apiKey'),
          headers: {
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            'contents': [
              {
                'parts': [
                  {
                    'text': '''Create 8 interview questions for $company. Job: ${jobDesc.length > 500 ? jobDesc.substring(0, 500) + "..." : jobDesc}

Return 8 numbered questions covering technical skills, behavioral scenarios, company fit, and problem-solving. Each question should be on a separate line starting with a number.''',
                  }
                ]
              }
            ],
            'generationConfig': {
              'temperature': 0.7,
              'topK': 40,
              'topP': 0.95,
              'maxOutputTokens': 600,
            },
            'safetySettings': [
              {
                'category': 'HARM_CATEGORY_HARASSMENT',
                'threshold': 'BLOCK_MEDIUM_AND_ABOVE'
              },
              {
                'category': 'HARM_CATEGORY_HATE_SPEECH',
                'threshold': 'BLOCK_MEDIUM_AND_ABOVE'
              },
              {
                'category': 'HARM_CATEGORY_SEXUALLY_EXPLICIT',
                'threshold': 'BLOCK_MEDIUM_AND_ABOVE'
              },
              {
                'category': 'HARM_CATEGORY_DANGEROUS_CONTENT',
                'threshold': 'BLOCK_MEDIUM_AND_ABOVE'
              }
            ]
          }),
        ).timeout(const Duration(seconds: 30));

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          
          // Parse Gemini API response
          if (data['candidates'] != null && 
              data['candidates'].isNotEmpty && 
              data['candidates'][0]['content'] != null &&
              data['candidates'][0]['content']['parts'] != null &&
              data['candidates'][0]['content']['parts'].isNotEmpty) {
            
            final content = data['candidates'][0]['content']['parts'][0]['text'];
            
            final lines = content.split('\n');
            final questions = <String>[];
            
            for (final line in lines) {
              final trimmed = line.trim();
              if (trimmed.isNotEmpty && RegExp(r'^\d+\.').hasMatch(trimmed)) {
                final question = trimmed.replaceFirst(RegExp(r'^\d+\.\s*'), '');
                if (question.isNotEmpty) {
                  questions.add(question);
                }
              }
            }
            
            if (questions.isNotEmpty) {
              print('Successfully generated ${questions.length} questions via Gemini API');
              return questions.take(8).toList();
            }
          }
        } else if (response.statusCode == 429) {
          print('Quota exceeded (429). Waiting before retry...');
          if (attempt < 3) {
            await Future.delayed(Duration(seconds: attempt * 2));
            continue;
          }
          throw Exception('QUOTA_EXCEEDED');
        } else if (response.statusCode == 400) {
          final errorData = jsonDecode(response.body);
          if (errorData['error'] != null && errorData['error']['message'] != null) {
            final errorMsg = errorData['error']['message'].toString();
            if (errorMsg.contains('API_KEY_INVALID') || errorMsg.contains('API key')) {
              throw Exception('API_KEY_INVALID');
            }
          }
          throw Exception('Bad request: ${response.body}');
        } else if (response.statusCode == 403) {
          throw Exception('PERMISSION_DENIED');
        } else {
          throw Exception('Gemini API error: ${response.statusCode} - ${response.body}');
        }
      } on TimeoutException {
        print('Request timeout on attempt $attempt');
        if (attempt == 3) {
          throw Exception('Request timeout. Please check your internet connection.');
        }
      } catch (e) {
        print('Gemini API attempt $attempt failed: $e');
        if (attempt == 3) {
          rethrow;
        }
        await Future.delayed(Duration(seconds: attempt));
      }
    }

    print('Gemini API failed, using fallback questions...');
    return _getFallbackQuestions(company);
  }

  List<String> _getFallbackQuestions(String company) {
    return [
      'Tell me about yourself and your professional background.',
      'Why are you interested in working at $company?',
      'What are your greatest strengths and how do they apply to this role?',
      'Describe a challenging project you worked on and how you overcame obstacles.',
      'How do you handle working under pressure and tight deadlines?',
      'Where do you see yourself professionally in the next 5 years?',
      'What do you know about our company culture and values?',
      'Do you have any questions about the role or our team?',
    ];
  }

  void _showApiErrorDialog(String errorMessage) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          width: 320,
          decoration: BoxDecoration(
            border: Border.all(color: BauhausColors.black, width: 4),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                color: BauhausColors.yellow,
                child: Text(
                  'API ISSUE',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: BauhausColors.black,
                    letterSpacing: 2,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                color: BauhausColors.white,
                child: Column(
                  children: [
                    Text(
                      errorMessage + '\n\nCONTINUE WITH DEFAULTS?',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: BauhausColors.black,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            height: 40,
                            color: BauhausColors.gray,
                            child: MaterialButton(
                              onPressed: () {
                                Navigator.of(context).pop();
                                Navigator.of(context).pop();
                              },
                              child: Text(
                                'CANCEL',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w900,
                                  color: BauhausColors.white,
                                  letterSpacing: 1,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Container(
                            height: 40,
                            color: BauhausColors.red,
                            child: MaterialButton(
                              onPressed: () {
                                Navigator.of(context).pop();
                                final fallbackQuestions = _getFallbackQuestions(widget.company);
                                Navigator.of(context).pushReplacement(
                                  MaterialPageRoute(
                                    builder: (context) => InterviewScreen(
                                      cameras: widget.cameras,
                                      questions: fallbackQuestions,
                                      company: widget.company,
                                      apiKey: widget.apiKey,
                                    ),
                                  ),
                                );
                              },
                              child: Text(
                                'CONTINUE',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w900,
                                  color: BauhausColors.white,
                                  letterSpacing: 1,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BauhausColors.lightGray,
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Company name at top
              Text(
                widget.company.toUpperCase(),
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: BauhausColors.black,
                  letterSpacing: 4,
                ),
                textAlign: TextAlign.center,
              ),
              
              const SizedBox(height: 60),
              
              // Spinning red geometric shape
              AnimatedBuilder(
                animation: _rotationAnimation,
                builder: (context, child) {
                  return Transform.rotate(
                    angle: _rotationAnimation.value,
                    child: Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        color: BauhausColors.red,
                        border: Border.all(color: BauhausColors.black, width: 4),
                        // Using rectangle instead of circle for Bauhaus geometric style
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Stack(
                        children: [
                          // Inner yellow triangle
                          Positioned.fill(
                            child: Center(
                              child: CustomPaint(
                                size: Size(40, 40),
                                painter: TrianglePainter(BauhausColors.yellow),
                              ),
                            ),
                          ),
                          // Blue circle in corner
                          Positioned(
                            top: 8,
                            right: 8,
                            child: Container(
                              width: 20,
                              height: 20,
                              decoration: BoxDecoration(
                                color: BauhausColors.blue,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
              
              const SizedBox(height: 60),
              
              // Loading text
              Text(
                _loadingText,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: BauhausColors.black,
                  letterSpacing: 3,
                ),
                textAlign: TextAlign.center,
              ),
              
              const SizedBox(height: 20),
              
              // Additional info text
              Container(
                width: 300,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border.all(color: BauhausColors.black, width: 3),
                ),
                child: Column(
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      color: BauhausColors.blue,
                      child: Text(
                        widget.jobDescription.trim().isEmpty ? 'PREPARING QUESTIONS' : 'AI PROCESSING',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                          color: BauhausColors.white,
                          letterSpacing: 2,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      color: BauhausColors.white,
                      child: Text(
                        widget.jobDescription.trim().isEmpty 
                            ? 'LOADING STANDARD INTERVIEW QUESTIONS\nOPTIMIZED FOR ${widget.company.toUpperCase()}'
                            : 'ANALYZING YOUR JOB REQUIREMENTS\nAND CREATING PERSONALIZED QUESTIONS',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: BauhausColors.black,
                          letterSpacing: 1,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Custom painter for triangle
class TrianglePainter extends CustomPainter {
  final Color color;
  
  TrianglePainter(this.color);
  
  @override
  void paint(Canvas canvas, Size size) {
    Paint paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    
    Path path = Path();
    path.moveTo(size.width / 2, 0);
    path.lineTo(0, size.height);
    path.lineTo(size.width, size.height);
    path.close();
    
    canvas.drawPath(path, paint);
  }
  
  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}