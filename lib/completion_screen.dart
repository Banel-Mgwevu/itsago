import 'package:flutter/material.dart';
import 'main.dart';
import 'splash_screen.dart';

class CompletionScreen extends StatelessWidget {
  final List<Map<String, dynamic>> allResults;
  final String company;

  const CompletionScreen({
    Key? key,
    required this.allResults,
    required this.company,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    double overallConfidence = _calculateOverallConfidence();
    int totalFillerWords = _calculateTotalFillerWords();
    int totalWords = _calculateTotalWords();
    String overallSentiment = _calculateOverallSentiment();
    Duration totalTime = _calculateTotalTime();

    return Scaffold(
      backgroundColor: BauhausColors.lightGray,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              // Bauhaus celebration header
              Container(
                width: double.infinity,
                height: 200,
                color: BauhausColors.red,
                child: Stack(
                  children: [
                    // Yellow circle
                    Positioned(
                      top: -30,
                      right: -30,
                      child: Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          color: BauhausColors.yellow,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                    // Blue rectangle
                    Positioned(
                      bottom: 20,
                      left: 20,
                      child: Container(
                        width: 60,
                        height: 30,
                        color: BauhausColors.blue,
                      ),
                    ),
                    // Main title
                    Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            _getCompletionEmoji(overallConfidence),
                            style: TextStyle(fontSize: 48),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'INTERVIEW',
                            style: TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.w900,
                              color: BauhausColors.white,
                              letterSpacing: 4,
                            ),
                          ),
                          Text(
                            'COMPLETED!',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w900,
                              color: BauhausColors.yellow,
                              letterSpacing: 3,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            company.toUpperCase(),
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: BauhausColors.white,
                              letterSpacing: 2,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 30),
              
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  children: [
                    // Overall Performance with Bauhaus styling
                    Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        border: Border.all(color: BauhausColors.black, width: 4),
                      ),
                      child: Column(
                        children: [
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            color: BauhausColors.blue,
                            child: Text(
                              'OVERALL PERFORMANCE',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                                color: BauhausColors.white,
                                letterSpacing: 2,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(30),
                            color: BauhausColors.white,
                            child: Column(
                              children: [
                                Container(
                                  width: 100,
                                  height: 100,
                                  decoration: BoxDecoration(
                                    border: Border.all(color: _getScoreColor(overallConfidence), width: 6),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Center(
                                    child: Text(
                                      '${overallConfidence.round()}%',
                                      style: TextStyle(
                                        fontSize: 24,
                                        fontWeight: FontWeight.w900,
                                        color: _getScoreColor(overallConfidence),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  _getScoreText(overallConfidence).toUpperCase(),
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w900,
                                    color: BauhausColors.black,
                                    letterSpacing: 2,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 20),
                    
                    // Summary Statistics Grid
                    Row(
                      children: [
                        Expanded(
                          child: _buildBauhausStatCard(
                            'QUESTIONS',
                            '${allResults.length}',
                            BauhausColors.blue,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildBauhausStatCard(
                            'TOTAL WORDS',
                            '$totalWords',
                            _getWordCountColor(totalWords),
                          ),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 12),
                    
                    Row(
                      children: [
                        Expanded(
                          child: _buildBauhausStatCard(
                            'FILLER WORDS',
                            '$totalFillerWords',
                            _getFillerColor(totalFillerWords),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildBauhausStatCard(
                            'TOTAL TIME',
                            '${totalTime.inMinutes}:${(totalTime.inSeconds % 60).toString().padLeft(2, '0')}',
                            BauhausColors.red,
                          ),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 20),
                    
                    // Question Results
                    Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        border: Border.all(color: BauhausColors.black, width: 4),
                      ),
                      child: Column(
                        children: [
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            color: BauhausColors.yellow,
                            child: Text(
                              'QUESTION ANALYSIS',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                                color: BauhausColors.black,
                                letterSpacing: 2,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            color: BauhausColors.white,
                            child: Column(
                              children: allResults.asMap().entries.map((entry) {
                                return _buildBauhausQuestionResult(entry.value, entry.key);
                              }).toList(),
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 20),
                    
                    // Feedback
                    Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        border: Border.all(color: BauhausColors.black, width: 4),
                      ),
                      child: Column(
                        children: [
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            color: BauhausColors.red,
                            child: Text(
                              'FEEDBACK & RECOMMENDATIONS',
                              style: TextStyle(
                                fontSize: 16,
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
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: _buildBauhausFeedback(overallConfidence, totalFillerWords, overallSentiment, totalWords),
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 30),
                    
                    // Action Button
                    Container(
                      width: double.infinity,
                      height: 80,
                      color: BauhausColors.blue,
                      child: MaterialButton(
                        onPressed: () {
                          Navigator.of(context).pushAndRemoveUntil(
                            MaterialPageRoute(builder: (context) => SplashScreen()),
                            (route) => false,
                          );
                        },
                        child: Text(
                          'PRACTICE AGAIN',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            color: BauhausColors.white,
                            letterSpacing: 3,
                          ),
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 20),
                    
                    Text(
                      _getMotivationalMessage(overallConfidence),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: BauhausColors.black,
                        letterSpacing: 1,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBauhausStatCard(String title, String value, Color color) {
    return Container(
      height: 120,
      decoration: BoxDecoration(
        border: Border.all(color: BauhausColors.black, width: 3),
      ),
      child: Column(
        children: [
          Container(
            height: 60,
            width: double.infinity,
            color: color,
            child: Center(
              child: Text(
                value,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: BauhausColors.white,
                ),
              ),
            ),
          ),
          Expanded(
            child: Container(
              width: double.infinity,
              color: BauhausColors.white,
              child: Center(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    color: BauhausColors.black,
                    letterSpacing: 1,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBauhausQuestionResult(Map<String, dynamic> result, int index) {
    double confidence = (result['confidence'] as num?)?.toDouble() ?? 70.0;
    Color confidenceColor = _getScoreColor(confidence); // Use same strict color coding
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        border: Border.all(color: BauhausColors.black, width: 2),
      ),
      child: Row(
        children: [
          Container(
            width: 60,
            height: 60,
            color: confidenceColor,
            child: Center(
              child: Text(
                '${index + 1}',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: BauhausColors.white,
                ),
              ),
            ),
          ),
          Expanded(
            child: Container(
              height: 60,
              padding: const EdgeInsets.all(8),
              color: BauhausColors.white,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(
                    children: [
                      Text(
                        'Q${index + 1}: ',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                          color: BauhausColors.black,
                        ),
                      ),
                      Text(
                        '${confidence.round()}%',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                          color: confidenceColor,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      Text(
                        'WORDS: ${result['wordCount'] ?? 0} | ',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: BauhausColors.black,
                        ),
                      ),
                      Text(
                        'FILLERS: ${(result['fillerWords'] as List<String>?)?.length ?? 0} | ',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: BauhausColors.black,
                        ),
                      ),
                      Text(
                        '${result['emotion'] ?? 'NEUTRAL'}',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: BauhausColors.black,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildBauhausFeedback(double confidence, int totalFillers, String sentiment, int totalWords) {
    final items = <Widget>[];
    
    // MUCH HARSHER: Brutally honest confidence feedback
    if (confidence >= 80) {
      items.add(_buildBauhausFeedbackItem('EXCELLENT PERFORMANCE! You demonstrated strong interview skills.', BauhausColors.blue));
    } else if (confidence >= 65) {
      items.add(_buildBauhausFeedbackItem('MEDIOCRE PERFORMANCE. You barely passed basic expectations.', BauhausColors.yellow));
    } else if (confidence >= 45) {
      items.add(_buildBauhausFeedbackItem('POOR PERFORMANCE. Employers would not be impressed with this level.', BauhausColors.red));
    } else if (confidence >= 30) {
      items.add(_buildBauhausFeedbackItem('VERY POOR PERFORMANCE. This interview would result in immediate rejection.', BauhausColors.red));
    } else {
      items.add(_buildBauhausFeedbackItem('UNACCEPTABLE PERFORMANCE. You are not ready for real interviews.', BauhausColors.red));
    }
    
    // HARSHER: No mercy on filler words
    if (totalFillers == 0) {
      items.add(_buildBauhausFeedbackItem('PERFECT SPEECH CLARITY! No filler words detected.', BauhausColors.blue));
    } else if (totalFillers <= 2) {
      items.add(_buildBauhausFeedbackItem('GOOD SPEECH CONTROL with minimal filler words.', BauhausColors.blue));
    } else if (totalFillers <= 5) {
      items.add(_buildBauhausFeedbackItem('ACCEPTABLE SPEECH but you need to eliminate remaining filler words.', BauhausColors.yellow));
    } else if (totalFillers <= 10) {
      items.add(_buildBauhausFeedbackItem('TOO MANY FILLER WORDS. This shows lack of preparation and confidence.', BauhausColors.red));
    } else if (totalFillers <= 20) {
      items.add(_buildBauhausFeedbackItem('EXCESSIVE FILLER WORDS. Interviewers would notice this weakness immediately.', BauhausColors.red));
    } else {
      items.add(_buildBauhausFeedbackItem('UNACCEPTABLE FILLER WORD COUNT. This would embarrass you in real interviews.', BauhausColors.red));
    }
    
    // HARSHER: Word count feedback with no sympathy
    int averageWordsPerQuestion = allResults.isNotEmpty ? (totalWords / allResults.length).round() : 0;
    if (averageWordsPerQuestion < 10) {
      items.add(_buildBauhausFeedbackItem('PATHETIC RESPONSE LENGTH. You essentially said nothing meaningful.', BauhausColors.red));
    } else if (averageWordsPerQuestion < 20) {
      items.add(_buildBauhausFeedbackItem('INADEQUATE RESPONSES. Employers expect substantial answers, not one-liners.', BauhausColors.red));
    } else if (averageWordsPerQuestion < 30) {
      items.add(_buildBauhausFeedbackItem('BARE MINIMUM EFFORT. Your responses lack depth and detail.', BauhausColors.yellow));
    } else {
      items.add(_buildBauhausFeedbackItem('ADEQUATE RESPONSE LENGTH with reasonable detail.', BauhausColors.blue));
    }
    
    // HARSHER: Sentiment feedback with reality check
    if (sentiment == 'Positive') {
      items.add(_buildBauhausFeedbackItem('POSITIVE ATTITUDE maintained throughout the interview.', BauhausColors.blue));
    } else if (sentiment == 'Negative') {
      items.add(_buildBauhausFeedbackItem('NEGATIVE ATTITUDE DETECTED. Employers will not hire pessimistic candidates.', BauhausColors.red));
    } else {
      items.add(_buildBauhausFeedbackItem('FLAT TONE. You sound disinterested and unmotivated.', BauhausColors.yellow));
    }
    
    // BRUTAL: Performance-based recommendations with harsh reality
    if (confidence < 40) {
      items.add(_buildBauhausFeedbackItem('CRITICAL FAILURE: Do not apply to jobs until you significantly improve.', BauhausColors.red));
      items.add(_buildBauhausFeedbackItem('REALITY CHECK: Companies have better candidates to choose from.', BauhausColors.red));
      items.add(_buildBauhausFeedbackItem('URGENT ACTION NEEDED: Your current skill level guarantees rejection.', BauhausColors.red));
    } else if (confidence < 55) {
      items.add(_buildBauhausFeedbackItem('SIGNIFICANT WEAKNESSES: You would struggle in competitive job markets.', BauhausColors.red));
      items.add(_buildBauhausFeedbackItem('WAKE-UP CALL: Other candidates are likely better prepared than you.', BauhausColors.red));
    } else if (confidence < 70) {
      items.add(_buildBauhausFeedbackItem('BELOW EXPECTATIONS: You need major improvements to compete effectively.', BauhausColors.yellow));
      items.add(_buildBauhausFeedbackItem('HONEST ASSESSMENT: Employers expect better performance than this.', BauhausColors.yellow));
    }
    
    // HARSH but constructive action items
    if (totalFillers > 10) {
      items.add(_buildBauhausFeedbackItem('MANDATORY: Record yourself speaking to hear how often you use fillers.', BauhausColors.red));
    }
    
    if (averageWordsPerQuestion < 20) {
      items.add(_buildBauhausFeedbackItem('REQUIRED: Practice giving 60-second responses to common questions.', BauhausColors.red));
    }
    
    if (confidence < 60) {
      items.add(_buildBauhausFeedbackItem('ESSENTIAL: Seek professional interview coaching before applying anywhere.', BauhausColors.red));
    }
    
    // Standard recommendations but with edge
    items.add(_buildBauhausFeedbackItem('REMINDER: Other candidates are practicing too - you must outwork them.', BauhausColors.yellow));
    items.add(_buildBauhausFeedbackItem('FACT: Companies can afford to be picky in today\'s market.', BauhausColors.yellow));
    
    return items;
  }

  Widget _buildBauhausFeedbackItem(String text, Color color) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 6,
            height: 20,
            color: color,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: BauhausColors.black,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  double _calculateOverallConfidence() {
    if (allResults.isEmpty) return 70.0;
    double total = allResults.fold(0.0, (sum, result) {
      double confidence = (result['confidence'] as num?)?.toDouble() ?? 70.0;
      return sum + confidence;
    });
    return total / allResults.length;
  }

  int _calculateTotalFillerWords() {
    return allResults.fold(0, (sum, result) {
      List<String> fillers = result['fillerWords'] ?? [];
      return sum + fillers.length;
    });
  }

  int _calculateTotalWords() {
    return allResults.fold(0, (sum, result) {
      int wordCount = (result['wordCount'] as num?)?.toInt() ?? 0;
      return sum + wordCount;
    });
  }

  String _calculateOverallSentiment() {
    if (allResults.isEmpty) return 'Neutral';
    
    Map<String, int> sentimentCounts = {'Positive': 0, 'Neutral': 0, 'Negative': 0};
    for (var result in allResults) {
      String sentiment = result['sentiment'] ?? 'Neutral';
      sentimentCounts[sentiment] = (sentimentCounts[sentiment] ?? 0) + 1;
    }
    
    return sentimentCounts.entries.reduce((a, b) => a.value > b.value ? a : b).key;
  }

  Duration _calculateTotalTime() {
    int totalSeconds = allResults.fold(0, (sum, result) {
      int duration = (result['recordingDuration'] as num?)?.toInt() ?? 0;
      return sum + duration;
    });
    return Duration(seconds: totalSeconds);
  }

  // FIXED: Much stricter color coding
  Color _getScoreColor(double score) {
    if (score >= 80) return BauhausColors.blue;    // Only excellent performance gets blue
    if (score >= 65) return BauhausColors.yellow;  // Good performance gets yellow
    return BauhausColors.red;                      // Everything else is red (poor)
  }

  // FIXED: Realistic score descriptions
  String _getScoreText(double score) {
    if (score >= 80) return 'EXCELLENT PERFORMANCE';
    if (score >= 65) return 'GOOD PERFORMANCE';
    if (score >= 45) return 'BELOW AVERAGE';
    if (score >= 30) return 'POOR PERFORMANCE';
    return 'VERY POOR PERFORMANCE';
  }

  // Helper methods for accurate color coding
  Color _getFillerColor(int fillers) {
    if (fillers <= 2) return BauhausColors.blue;
    if (fillers <= 5) return BauhausColors.yellow;
    return BauhausColors.red;
  }

  Color _getWordCountColor(int totalWords) {
    int averagePerQuestion = allResults.isNotEmpty ? (totalWords / allResults.length).round() : 0;
    if (averagePerQuestion >= 30) return BauhausColors.blue;
    if (averagePerQuestion >= 20) return BauhausColors.yellow;
    return BauhausColors.red;
  }

  String _getCompletionEmoji(double score) {
    if (score >= 80) return '🎉';
    if (score >= 65) return '👍';
    if (score >= 45) return '⚠️';
    return '📚';
  }

  String _getMotivationalMessage(double score) {
    if (score >= 80) {
      return 'EXCELLENT WORK! You have strong interview skills. Keep practicing to maintain this level.';
    } else if (score >= 65) {
      return 'GOOD EFFORT! Work on identified areas to reach excellent performance.';
    } else if (score >= 45) {
      return 'SIGNIFICANT IMPROVEMENT NEEDED. Focus on the feedback areas before real interviews.';
    } else {
      return 'EXTENSIVE PRACTICE REQUIRED. Consider professional interview coaching before applying.';
    }
  }
}