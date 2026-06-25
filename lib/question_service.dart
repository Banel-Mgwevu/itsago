import 'dart:math';

class QuestionService {

  static const _behavioural = [
    'Tell me about a time you had to meet a tight deadline. How did you handle it?',
    'Describe a situation where you had to work with a difficult colleague. What did you do?',
    'Give me an example of a time you made a mistake at work. How did you recover?',
    'Tell me about your greatest professional achievement so far.',
    'Describe a time you had to learn something new quickly. How did you approach it?',
    'Tell me about a time you went above and beyond what was expected of you.',
    'Describe a situation where you had to change your approach because things were not working.',
    'Tell me about a time you received tough feedback. How did you respond?',
    'Give an example of a time you had to prioritise multiple tasks at once.',
    'Describe a time you had to persuade someone to see things your way.',
  ];

  static const _situational = [
    'If you were given three urgent tasks with the same deadline, how would you decide what to do first?',
    'Imagine a client is unhappy with your work. What steps would you take to resolve it?',
    'If your manager gave you an instruction you disagreed with, what would you do?',
    'You notice a colleague is struggling with their workload. How would you handle it?',
    'If you were unsure how to complete a task, what would you do?',
    'Imagine you joined {company} and noticed a process that could be improved. What would you do?',
    'If you had to deliver bad news to a client or colleague, how would you approach it?',
    'You are halfway through a project and realise the approach is wrong. What do you do?',
    'If two team members had a conflict that was affecting the team, how would you handle it?',
    'You are asked to do something outside your job description. How do you respond?',
  ];

  static const _values = [
    'Why do you want to work at {company} specifically?',
    'What do you know about {company} and what excites you about it?',
    'How do your personal values align with what {company} stands for?',
    'What does integrity in the workplace mean to you?',
    'Describe the kind of team culture where you do your best work.',
    'What motivates you to come to work every day?',
    'How do you handle working in a diverse team with different perspectives?',
    'What does customer service mean to you personally?',
    'Why do you want to work in this industry?',
    'What kind of impact do you want to have at {company}?',
  ];

  static const _strength = [
    'What would you say is your greatest professional strength?',
    'What sets you apart from other candidates applying for this position?',
    'What skills have you developed in your career that will benefit {company}?',
    'Describe a skill you are still working to improve and how you are doing it.',
    'What do colleagues say about working with you?',
    'What is something you are genuinely proud of from your career so far?',
    'How do you keep your skills up to date in a fast-changing industry?',
    'Where do you see yourself in three years and how does this role fit that goal?',
    'What is one thing that you do better than most people you have worked with?',
  ];

  static const _technical = [
    'Walk me through how you approach solving a problem you have never encountered before.',
    'Describe the tools and systems you use most in your day-to-day work.',
    'How do you ensure the quality of your work before submitting it?',
    'Tell me about a technical challenge you solved that you are proud of.',
    'How do you stay current with new developments and tools in your field?',
    'Describe a project where you had to use data to make a decision.',
    'What process do you follow when starting a new project or task?',
    'How do you handle situations where you do not have all the information you need?',
    'Describe your experience with reporting, documentation, or record keeping.',
    'Tell me about a time you had to explain a complex idea to a non-technical person.',
  ];

  static const _leadership = [
    'Tell me about a time you took the lead on a project or initiative.',
    'Describe a situation where you had to motivate a team that was losing momentum.',
    'How do you handle it when someone on your team is not performing well?',
    'Tell me about a time you had to make a difficult decision with limited information.',
    'Describe how you set goals for yourself and track your progress.',
    'Tell me about a time you mentored or helped develop someone else.',
    'How do you earn the trust and respect of the people you work with?',
    'Describe a situation where you had to manage conflict within a team.',
    'Tell me about a time your leadership led to a measurable positive outcome.',
    'How do you balance being decisive with being open to input from others?',
  ];

  static const _salary = [
    'What are your salary expectations for this role?',
    'How did you determine the salary range you are looking for?',
    'What is more important to you — the salary package or the opportunity to grow?',
    'Are you currently receiving any other offers that we should be aware of?',
    'What does your ideal total compensation package look like beyond just salary?',
  ];

  static const _map = {
    'behavioural': _behavioural,
    'situational':  _situational,
    'values':       _values,
    'strength':     _strength,
    'technical':    _technical,
    'leadership':   _leadership,
    'salary':       _salary,
  };

  static const _openers = [
    'Welcome! To start us off — please introduce yourself and tell us what brings you to {company}.',
    'Great to meet you. Tell us a little about your background and why you applied for this role.',
    'Thanks for coming in. Start by telling us about yourself and your journey to get here.',
    'Let us get started. Tell us who you are and what excites you about this opportunity at {company}.',
    'Glad you could join us. Walk us through your background and what led you to apply here.',
  ];

  static Future<List<String>> generate({
    required String company,
    required String jobTitle,
    required String jobDescription,
    String style = 'friendly',
    List<String> categories = const ['behavioural','situational','values','strength'],
  }) async {
    final rng      = Random();
    final selected = categories.where((c) => _map.containsKey(c)).toList();
    if (selected.isEmpty) selected.add('behavioural');

    final questions = <String>[];
    final used      = <String>{};

    // Q1: Random opener — different every session
    questions.add(_inject(_openers[rng.nextInt(_openers.length)], company));

    // Q2-Q5: Pick randomly from selected categories
    // Shuffle the categories so order is different each session
    final shuffled = List<String>.from(selected)..shuffle(rng);

    // Build a weighted pool — all questions from all selected categories
    final pool = <String>[];
    for (final cat in shuffled) {
      pool.addAll(_map[cat]!);
    }
    pool.shuffle(rng);

    // Pick 3 unique questions from the shuffled pool (Q2-Q4)
    // Q5 is always the closing question
    const closing = 'Is there anything else you would like us to know about you, or do you have any questions for us?';
    for (final q in pool) {
      if (questions.length >= 4) break;
      if (!used.contains(q) && q != closing) {
        used.add(q);
        questions.add(_inject(q, company));
      }
    }

    // Pad Q2-Q4 with fallback if needed
    while (questions.length < 4) {
      questions.add(_inject(_fallback[questions.length % _fallback.length], company));
    }

    // Q5 always closes the interview
    questions.add(closing);

    return questions;
  }

  static String _inject(String q, String company) =>
    q.replaceAll('{company}', company.isEmpty ? 'our company' : company);

  static const _fallback = [
    'Tell me about yourself and why you are interested in this role.',
    'What do you know about {company} and why do you want to work here?',
    'Describe a challenge you faced and how you overcame it.',
    'Where do you see yourself in three years?',
    'Do you have any questions for us?',
  ];
}
