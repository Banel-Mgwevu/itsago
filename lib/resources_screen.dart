import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'main.dart';
import 'about_screen.dart';
import 'upgrade_premium_screen.dart';
import 'setup_screen.dart';

class ResourcesScreen extends StatefulWidget {
  final List<CameraDescription> cameras;
  
  const ResourcesScreen({super.key, required this.cameras});

  @override
  State<ResourcesScreen> createState() => _ResourcesScreenState();
}

class _ResourcesScreenState extends State<ResourcesScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BauhausColors.lightGray,
      drawer: _buildBauhausDrawer(),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              // Header with Bauhaus geometric design
              Container(
                width: double.infinity,
                height: 200,
                color: BauhausColors.blue,
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
                    // Red rectangles
                    Positioned(
                      bottom: 30,
                      left: 30,
                      child: Container(
                        width: 60,
                        height: 20,
                        color: BauhausColors.red,
                      ),
                    ),
                    Positioned(
                      top: 40,
                      left: 80,
                      child: Container(
                        width: 25,
                        height: 25,
                        color: BauhausColors.white,
                      ),
                    ),
                    // Back button
                    Positioned(
                      top: 20,
                      left: 20,
                      child: GestureDetector(
                        onTap: () => Navigator.of(context).pop(),
                        child: Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            color: BauhausColors.white,
                            border: Border.all(
                              color: BauhausColors.black,
                              width: 3,
                            ),
                          ),
                          child: Icon(
                            Icons.arrow_back,
                            color: BauhausColors.black,
                            size: 24,
                          ),
                        ),
                      ),
                    ),
                    // Menu button
                    Positioned(
                      top: 20,
                      right: 20,
                      child: Builder(
                        builder: (context) => GestureDetector(
                          onTap: () => Scaffold.of(context).openDrawer(),
                          child: Container(
                            width: 50,
                            height: 50,
                            decoration: BoxDecoration(
                              color: BauhausColors.white,
                              border: Border.all(
                                color: BauhausColors.black,
                                width: 3,
                              ),
                            ),
                            child: Icon(
                              Icons.menu,
                              color: BauhausColors.black,
                              size: 24,
                            ),
                          ),
                        ),
                      ),
                    ),
                    // Title
                    Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'INTERVIEW',
                            style: TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.w900,
                              color: BauhausColors.white,
                              letterSpacing: 6,
                              height: 0.9,
                            ),
                          ),
                          Text(
                            'RESOURCES',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w900,
                              color: BauhausColors.yellow,
                              letterSpacing: 4,
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
                    // Introduction section
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: BauhausColors.white,
                        border: Border.all(color: BauhausColors.black, width: 3),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 50,
                                height: 50,
                                color: BauhausColors.yellow,
                                child: Icon(
                                  Icons.lightbulb_outline,
                                  color: BauhausColors.black,
                                  size: 24,
                                ),
                              ),
                              const SizedBox(width: 15),
                              Expanded(
                                child: Text(
                                  'MASTER YOUR INTERVIEW',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w900,
                                    color: BauhausColors.black,
                                    letterSpacing: 2,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 15),
                          Text(
                            'Access our curated collection of premium interview preparation materials, expert tips, and proven strategies to boost your confidence and ace your next interview.',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: BauhausColors.gray,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 30),
                    
                    // Resource categories
                    _buildResourceCategory(
                      title: 'BEHAVIORAL QUESTIONS',
                      subtitle: 'STAR METHOD & EXAMPLES',
                      icon: Icons.psychology,
                      color: BauhausColors.red,
                      isPremium: true,
                      description: 'Master the STAR method with 50+ behavioral question examples and detailed sample answers.',
                    ),
                    
                    const SizedBox(height: 20),
                    
                    _buildResourceCategory(
                      title: 'TECHNICAL INTERVIEWS',
                      subtitle: 'CODING & SYSTEM DESIGN',
                      icon: Icons.code,
                      color: BauhausColors.blue,
                      isPremium: true,
                      description: 'Comprehensive guide to technical interviews including coding challenges and system design principles.',
                    ),
                    
                    const SizedBox(height: 20),
                    
                    _buildResourceCategory(
                      title: 'SALARY NEGOTIATION',
                      subtitle: 'STRATEGIES & SCRIPTS',
                      icon: Icons.attach_money,
                      color: BauhausColors.yellow,
                      isPremium: true,
                      description: 'Learn proven negotiation tactics and get access to salary benchmarking data.',
                    ),
                    
                    const SizedBox(height: 20),
                    
                    _buildResourceCategory(
                      title: 'COMPANY RESEARCH',
                      subtitle: 'PREPARATION TEMPLATES',
                      icon: Icons.business,
                      color: BauhausColors.red,
                      isPremium: true,
                      description: 'Templates and frameworks for researching companies and understanding their culture.',
                    ),
                    
                    const SizedBox(height: 20),
                    
                    _buildResourceCategory(
                      title: 'FOLLOW-UP EMAILS',
                      subtitle: 'TEMPLATES & EXAMPLES',
                      icon: Icons.email,
                      color: BauhausColors.blue,
                      isPremium: true,
                      description: 'Professional email templates for follow-ups, thank you notes, and status inquiries.',
                    ),
                    
                    const SizedBox(height: 40),
                    
                    // Premium upgrade CTA
                    Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        border: Border.all(color: BauhausColors.black, width: 4),
                      ),
                      child: Column(
                        children: [
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(20),
                            color: BauhausColors.red,
                            child: Row(
                              children: [
                                Container(
                                  width: 50,
                                  height: 50,
                                  decoration: BoxDecoration(
                                    color: BauhausColors.white,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    Icons.star,
                                    color: BauhausColors.red,
                                    size: 24,
                                  ),
                                ),
                                const SizedBox(width: 15),
                                Expanded(
                                  child: Text(
                                    'UNLOCK ALL RESOURCES',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w900,
                                      color: BauhausColors.white,
                                      letterSpacing: 2,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(20),
                            color: BauhausColors.white,
                            child: Column(
                              children: [
                                Text(
                                  'Get unlimited access to all premium interview resources, including technical guides, salary negotiation strategies, and exclusive templates.',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: BauhausColors.black,
                                    height: 1.4,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 20),
                                Container(
                                  width: double.infinity,
                                  height: 50,
                                  color: BauhausColors.yellow,
                                  child: MaterialButton(
                                    onPressed: () {
                                      Navigator.of(context).push(
                                        PageRouteBuilder(
                                          pageBuilder: (context, animation, secondaryAnimation) =>
                                              UpgradePremiumScreen(cameras: widget.cameras),
                                          transitionsBuilder: (context, animation, secondaryAnimation, child) {
                                            return SlideTransition(
                                              position: Tween<Offset>(
                                                begin: const Offset(1.0, 0.0),
                                                end: Offset.zero,
                                              ).animate(CurvedAnimation(
                                                parent: animation,
                                                curve: Curves.easeOut,
                                              )),
                                              child: child,
                                            );
                                          },
                                          transitionDuration: const Duration(milliseconds: 600),
                                        ),
                                      );
                                    },
                                    child: Text(
                                      'UPGRADE TO PREMIUM',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w900,
                                        color: BauhausColors.black,
                                        letterSpacing: 2,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
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

  Widget _buildResourceCategory({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required bool isPremium,
    required String description,
  }) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        border: Border.all(color: BauhausColors.black, width: 3),
      ),
      child: Column(
        children: [
          // Header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(15),
            color: color,
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 24,
                  color: color == BauhausColors.yellow 
                      ? BauhausColors.black 
                      : BauhausColors.white,
                ),
                const SizedBox(width: 15),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: color == BauhausColors.yellow 
                              ? BauhausColors.black 
                              : BauhausColors.white,
                          letterSpacing: 1,
                        ),
                      ),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: color == BauhausColors.yellow 
                              ? BauhausColors.black 
                              : BauhausColors.white,
                          letterSpacing: 1,
                        ),
                      ),
                    ],
                  ),
                ),
                if (isPremium)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: BauhausColors.white,
                      border: Border.all(color: BauhausColors.black, width: 2),
                    ),
                    child: Text(
                      'PREMIUM',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        color: BauhausColors.black,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          
          // Content
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(15),
            color: BauhausColors.white,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: BauhausColors.black,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 15),
                Container(
                  width: isPremium ? 120 : 100,
                  height: 40,
                  color: isPremium ? BauhausColors.red : color,
                  child: MaterialButton(
                    onPressed: () {
                      if (isPremium) {
                        Navigator.of(context).push(
                          PageRouteBuilder(
                            pageBuilder: (context, animation, secondaryAnimation) =>
                                UpgradePremiumScreen(cameras: widget.cameras),
                            transitionsBuilder: (context, animation, secondaryAnimation, child) {
                              return SlideTransition(
                                position: Tween<Offset>(
                                  begin: const Offset(1.0, 0.0),
                                  end: Offset.zero,
                                ).animate(CurvedAnimation(
                                  parent: animation,
                                  curve: Curves.easeOut,
                                )),
                                child: child,
                              );
                            },
                            transitionDuration: const Duration(milliseconds: 600),
                          ),
                        );
                      } else {
                        _showResourceContent(title);
                      }
                    },
                    child: Text(
                      isPremium ? 'UPGRADE' : 'VIEW',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        color: (isPremium || color == BauhausColors.yellow) 
                            ? (isPremium ? BauhausColors.white : BauhausColors.black)
                            : BauhausColors.white,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showResourceContent(String title) {
    String content = '';
    List<String> sections = [];
    
    if (title == 'BEHAVIORAL QUESTIONS') {
      sections = [
        'THE STAR METHOD',
        'Situation: Set the scene and give context\nTask: Describe what you were responsible for\nAction: Explain what steps you took\nResult: Share what outcomes you achieved',
        '',
        'COMMON BEHAVIORAL QUESTIONS',
        '',
        '1. Tell me about a time you faced a challenge',
        'STAR Example:\nS: Working on a tight deadline project with limited resources\nT: Had to deliver a marketing campaign in 2 weeks instead of 4\nA: Prioritized tasks, delegated effectively, worked extra hours\nR: Delivered on time and campaign exceeded KPIs by 25%',
        '',
        '2. Describe a time you showed leadership',
        'Focus on: Taking initiative, motivating others, making decisions, taking responsibility for outcomes',
        '',
        '3. Tell me about a mistake you made',
        'Focus on: Taking ownership, learning from it, implementing changes to prevent future mistakes',
        '',
        '4. Describe a time you worked with a difficult person',
        'Focus on: Communication, empathy, finding common ground, maintaining professionalism',
        '',
        '5. Tell me about a time you exceeded expectations',
        'Focus on: Going above and beyond, proactive behavior, delivering exceptional results',
        '',
        'PREPARATION TIPS',
        '• Prepare 5-7 STAR stories covering different competencies\n• Practice out loud to sound natural\n• Keep answers 1-3 minutes long\n• Focus on YOUR actions, not team actions\n• Quantify results when possible'
      ];
    } else if (title == 'COMPANY RESEARCH') {
      sections = [
        'RESEARCH FRAMEWORK',
        '',
        '1. COMPANY BASICS',
        '• Mission, vision, and values\n• Business model and revenue streams\n• Key products/services\n• Target market and customers\n• Company size and locations',
        '',
        '2. RECENT NEWS & DEVELOPMENTS',
        '• Press releases (last 6 months)\n• Product launches\n• Acquisitions or partnerships\n• Leadership changes\n• Financial performance',
        '',
        '3. COMPANY CULTURE',
        '• Employee reviews on Glassdoor\n• Social media presence\n• Diversity and inclusion initiatives\n• Work-life balance policies\n• Career development opportunities',
        '',
        '4. INDUSTRY LANDSCAPE',
        '• Market trends and challenges\n• Key competitors\n• Industry growth projections\n• Regulatory environment\n• Technological disruptions',
        '',
        '5. ROLE-SPECIFIC RESEARCH',
        '• Department structure\n• Team you\'ll be joining\n• Key challenges they\'re facing\n• Skills they\'re prioritizing\n• Career progression paths',
        '',
        'RESEARCH SOURCES',
        '• Company website and blog\n• LinkedIn company page\n• Glassdoor reviews\n• Industry publications\n• Google News alerts\n• Annual reports (public companies)\n• Crunchbase (startups)',
        '',
        'PREPARATION QUESTIONS',
        '• Why do you want to work here?\n• What attracts you to this industry?\n• How do you see yourself contributing?\n• What questions do you have about the role?\n• How does this align with your career goals?'
      ];
    } else if (title == 'TECHNICAL INTERVIEWS') {
      sections = [
        'CODING INTERVIEW PREPARATION',
        '',
        '1. DATA STRUCTURES & ALGORITHMS',
        '• Arrays and Strings\n• Linked Lists\n• Stacks and Queues\n• Trees and Graphs\n• Hash Tables\n• Sorting and Searching\n• Dynamic Programming\n• Recursion and Backtracking',
        '',
        '2. CODING BEST PRACTICES',
        '• Write clean, readable code\n• Start with brute force, then optimize\n• Test with edge cases\n• Communicate your thought process\n• Ask clarifying questions\n• Consider time and space complexity',
        '',
        '3. COMMON CODING PATTERNS',
        '• Two Pointers\n• Sliding Window\n• Fast & Slow Pointers\n• Merge Intervals\n• Cyclic Sort\n• Tree Traversal (BFS/DFS)\n• Binary Search\n• Topological Sort',
        '',
        'SYSTEM DESIGN FUNDAMENTALS',
        '',
        '1. SCALABILITY CONCEPTS',
        '• Load Balancing\n• Database Sharding\n• Caching Strategies\n• CDN (Content Delivery Networks)\n• Microservices vs Monolith\n• Horizontal vs Vertical Scaling',
        '',
        '2. DATABASE DESIGN',
        '• SQL vs NoSQL\n• ACID Properties\n• Database Normalization\n• Indexing Strategies\n• Replication and Partitioning\n• CAP Theorem',
        '',
        '3. SYSTEM DESIGN APPROACH',
        '• Clarify requirements\n• Estimate scale (users, data, requests)\n• Design high-level architecture\n• Deep dive into core components\n• Address scalability and bottlenecks\n• Consider monitoring and alerting',
        '',
        'INTERVIEW TIPS',
        '• Practice coding without an IDE\n• Use whiteboarding or paper\n• Think out loud during problem solving\n• Start with simple examples\n• Don\'t memorize solutions, understand patterns\n• Practice system design discussions\n• Review your past projects for technical depth'
      ];
    } else if (title == 'SALARY NEGOTIATION') {
      sections = [
        'SALARY NEGOTIATION STRATEGY',
        '',
        '1. RESEARCH & PREPARATION',
        '• Use Glassdoor, PayScale, Levels.fyi\n• Consider geographic location\n• Factor in company size and industry\n• Include total compensation (salary, bonus, equity, benefits)\n• Know your worth and minimum acceptable offer',
        '',
        '2. NEGOTIATION FRAMEWORK',
        'Step 1: Express enthusiasm for the role\nStep 2: Present your research and rationale\nStep 3: Make your counteroffer\nStep 4: Negotiate other benefits if salary is fixed\nStep 5: Get everything in writing',
        '',
        '3. NEGOTIATION SCRIPTS',
        '',
        'INITIAL RESPONSE:',
        '"I\'m very excited about this opportunity and I believe I can add significant value to your team. Based on my research and experience, I was expecting a range of \$X to \$Y. Would there be flexibility in the compensation package?"',
        '',
        'COUNTEROFFER:',
        '"Thank you for the offer. I\'m very interested in joining the team. Based on my experience with [specific skills/achievements] and the market rate for this role, I was hoping for \$X. Is there room for adjustment?"',
        '',
        'NEGOTIATING BENEFITS:',
        '"If the salary range is fixed, I\'d be interested in discussing other aspects of the compensation package such as additional vacation days, flexible work arrangements, or professional development budget."',
        '',
        '4. WHAT TO NEGOTIATE',
        '• Base salary\n• Signing bonus\n• Annual bonus structure\n• Stock options/equity\n• Vacation time\n• Flexible work arrangements\n• Professional development budget\n• Start date\n• Job title\n• Performance review timeline',
        '',
        '5. NEGOTIATION DO\'S AND DON\'TS',
        '',
        'DO:',
        '• Be professional and positive\n• Have multiple offers if possible\n• Focus on value you bring\n• Be prepared to walk away\n• Get final offer in writing',
        '',
        'DON\'T:',
        '• Make ultimatums\n• Lie about other offers\n• Negotiate before receiving an offer\n• Accept immediately (ask for time to consider)\n• Burn bridges if they can\'t meet your requirements',
        '',
        'SALARY RANGES BY EXPERIENCE',
        'Entry Level (0-2 years): Research junior roles\nMid Level (3-5 years): 20-40% above entry level\nSenior Level (5+ years): Market rate + premium for expertise\nLeadership Roles: Significant increase + equity consideration'
      ];
    } else if (title == 'FOLLOW-UP EMAILS') {
      sections = [
        'EMAIL TEMPLATES & BEST PRACTICES',
        '',
        '1. THANK YOU EMAIL (AFTER INTERVIEW)',
        '',
        'Subject: Thank you for today\'s interview - [Your Name]',
        '',
        'Dear [Interviewer\'s Name],',
        '',
        'Thank you for taking the time to interview me today for the [Position Title] role. I enjoyed our conversation about [specific topic discussed] and learning more about [company\'s project/initiative].',
        '',
        'Our discussion reinforced my enthusiasm for this opportunity, particularly [mention specific aspect that excites you]. I believe my experience in [relevant skill/experience] would enable me to contribute effectively to [specific team goal or challenge discussed].',
        '',
        'Please let me know if you need any additional information from me. I look forward to hearing about the next steps.',
        '',
        'Best regards,\n[Your Name]',
        '',
        '2. FOLLOW-UP EMAIL (AFTER NO RESPONSE)',
        '',
        'Subject: Following up on [Position Title] application',
        '',
        'Dear [Hiring Manager\'s Name],',
        '',
        'I wanted to follow up on my application for the [Position Title] role that I submitted on [date]. I remain very interested in this opportunity and would welcome the chance to discuss how my background in [relevant experience] could benefit your team.',
        '',
        'I\'ve attached my resume again for your convenience. Please let me know if you need any additional information.',
        '',
        'Thank you for your consideration.',
        '',
        'Best regards,\n[Your Name]',
        '',
        '3. STATUS INQUIRY EMAIL',
        '',
        'Subject: Checking in on [Position Title] application status',
        '',
        'Dear [Hiring Manager\'s Name],',
        '',
        'I hope this email finds you well. I wanted to check in regarding the status of my application for the [Position Title] position.',
        '',
        'I interviewed with [interviewer names] on [date] and remain very excited about the possibility of joining your team. If there\'s any additional information I can provide to assist with your decision, please let me know.',
        '',
        'Thank you for your time and consideration.',
        '',
        'Best regards,\n[Your Name]',
        '',
        '4. SALARY NEGOTIATION EMAIL',
        '',
        'Subject: Re: Job Offer - [Position Title]',
        '',
        'Dear [Hiring Manager\'s Name],',
        '',
        'Thank you for extending the offer for the [Position Title] role. I\'m excited about the opportunity to contribute to [Company Name] and [specific project/goal].',
        '',
        'After careful consideration of the offer and researching market rates for this position, I was hoping we could discuss the compensation package. Based on my [years] years of experience and [specific achievements], I was expecting a salary in the range of \$[X] to \$[Y].',
        '',
        'I\'m confident that I can deliver significant value to your team, and I\'m hoping we can find a mutually beneficial arrangement.',
        '',
        'I look forward to your response.',
        '',
        'Best regards,\n[Your Name]',
        '',
        'EMAIL BEST PRACTICES',
        '',
        'TIMING:',
        '• Thank you emails: Within 24 hours\n• Follow-up emails: After 1-2 weeks of silence\n• Status inquiries: After the timeframe they mentioned\n• Avoid Mondays and Fridays when possible',
        '',
        'FORMAT:',
        '• Use professional email address\n• Clear, specific subject lines\n• Keep it concise (under 200 words)\n• Professional greeting and closing\n• Proofread for typos and grammar\n• Include your phone number in signature',
        '',
        'TONE:',
        '• Professional but warm\n• Enthusiastic about the opportunity\n• Grateful for their time\n• Confident but not pushy\n• Personalized, not generic'
      ];
    }
    
    content = sections.join('\n');
    
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          width: MediaQuery.of(context).size.width * 0.9,
          height: MediaQuery.of(context).size.height * 0.8,
          decoration: BoxDecoration(
            border: Border.all(color: BauhausColors.black, width: 4),
          ),
          child: Column(
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                color: BauhausColors.blue,
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: BauhausColors.white,
                          letterSpacing: 2,
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: () => Navigator.of(context).pop(),
                      child: Container(
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                          color: BauhausColors.white,
                          border: Border.all(color: BauhausColors.black, width: 2),
                        ),
                        child: Icon(
                          Icons.close,
                          color: BauhausColors.black,
                          size: 20,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  color: BauhausColors.white,
                  child: SingleChildScrollView(
                    child: Text(
                      content,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: BauhausColors.black,
                        height: 1.5,
                      ),
                    ),
                  ),
                ),
              ),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: BauhausColors.lightGray,
                  border: Border(
                    top: BorderSide(color: BauhausColors.black, width: 2),
                  ),
                ),
                child: Container(
                  width: 100,
                  height: 40,
                  color: BauhausColors.blue,
                  child: MaterialButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(
                      'CLOSE',
                      style: TextStyle(
                        fontSize: 14,
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
        ),
      ),
    );
  }

  Widget _buildBauhausDrawer() {
    return Drawer(
      backgroundColor: BauhausColors.white,
      child: Column(
        children: [
          // Drawer Header
          Container(
            width: double.infinity,
            height: 200,
            color: BauhausColors.blue,
            child: Stack(
              children: [
                // Geometric elements
                Positioned(
                  top: -30,
                  right: -30,
                  child: Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      color: BauhausColors.yellow,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                Positioned(
                  bottom: 10,
                  left: 10,
                  child: Container(
                    width: 60,
                    height: 30,
                    color: BauhausColors.red,
                  ),
                ),
                
                // Header content
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          color: BauhausColors.white,
                          border: Border.all(
                            color: BauhausColors.black,
                            width: 3,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            'I',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w900,
                              color: BauhausColors.black,
                              letterSpacing: 1,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 15),
                      Text(
                        'ITAGO',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          color: BauhausColors.white,
                          letterSpacing: 3,
                        ),
                      ),
                      Text(
                        'AI INTERVIEW PREP',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: BauhausColors.yellow,
                          letterSpacing: 1,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          // Menu Items
          Expanded(
            child: Column(
              children: [
                const SizedBox(height: 20),
                
                // Practice Interview menu item
                _buildDrawerItem(
                  icon: Icons.video_camera_front,
                  title: 'PRACTICE INTERVIEW',
                  subtitle: 'Start your interview prep',
                  color: BauhausColors.red,
                  onTap: () {
                    Navigator.of(context).pop();
                    Navigator.of(context).push(
                      PageRouteBuilder(
                        pageBuilder: (context, animation, secondaryAnimation) =>
                            SetupScreen(cameras: widget.cameras),
                        transitionsBuilder: (context, animation, secondaryAnimation, child) {
                          return SlideTransition(
                            position: Tween<Offset>(
                              begin: const Offset(1.0, 0.0),
                              end: Offset.zero,
                            ).animate(CurvedAnimation(
                              parent: animation,
                              curve: Curves.easeOut,
                            )),
                            child: child,
                          );
                        },
                        transitionDuration: const Duration(milliseconds: 600),
                      ),
                    );
                  },
                ),
                
                const SizedBox(height: 15),
                
                // About menu item
                _buildDrawerItem(
                  icon: Icons.info_outline,
                  title: 'ABOUT',
                  subtitle: 'Learn more about ITAGO',
                  color: BauhausColors.yellow,
                  onTap: () {
                    Navigator.of(context).pop();
                    Navigator.of(context).push(
                      PageRouteBuilder(
                        pageBuilder: (context, animation, secondaryAnimation) =>
                            AboutScreen(cameras: widget.cameras),
                        transitionsBuilder: (context, animation, secondaryAnimation, child) {
                          return SlideTransition(
                            position: Tween<Offset>(
                              begin: const Offset(1.0, 0.0),
                              end: Offset.zero,
                            ).animate(CurvedAnimation(
                              parent: animation,
                              curve: Curves.easeOut,
                            )),
                            child: child,
                          );
                        },
                        transitionDuration: const Duration(milliseconds: 600),
                      ),
                    );
                  },
                ),
                
                const SizedBox(height: 15),
                
                // Upgrade to Premium menu item
                _buildDrawerItem(
                  icon: Icons.star_outline,
                  title: 'UPGRADE TO PREMIUM',
                  subtitle: 'Unlock advanced features',
                  color: BauhausColors.red,
                  onTap: () {
                    Navigator.of(context).pop();
                    Navigator.of(context).push(
                      PageRouteBuilder(
                        pageBuilder: (context, animation, secondaryAnimation) =>
                            UpgradePremiumScreen(cameras: widget.cameras),
                        transitionsBuilder: (context, animation, secondaryAnimation, child) {
                          return SlideTransition(
                            position: Tween<Offset>(
                              begin: const Offset(1.0, 0.0),
                              end: Offset.zero,
                            ).animate(CurvedAnimation(
                              parent: animation,
                              curve: Curves.easeOut,
                            )),
                            child: child,
                          );
                        },
                        transitionDuration: const Duration(milliseconds: 600),
                      ),
                    );
                  },
                ),
                
                const Spacer(),
                
                // Footer
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    border: Border(
                      top: BorderSide(
                        color: BauhausColors.gray,
                        width: 1,
                      ),
                    ),
                  ),
                  child: Column(
                    children: [
                      Container(
                        width: 40,
                        height: 3,
                        color: BauhausColors.red,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'VERSION 1.0.0',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: BauhausColors.gray,
                          letterSpacing: 1,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawerItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 15),
      decoration: BoxDecoration(
        border: Border.all(
          color: BauhausColors.black,
          width: 2,
        ),
      ),
      child: Material(
        color: BauhausColors.white,
        child: InkWell(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(0),
            child: Row(
              children: [
                Container(
                  width: 70,
                  height: 70,
                  color: color,
                  child: Icon(
                    icon,
                    size: 24,
                    color: color == BauhausColors.yellow 
                        ? BauhausColors.black 
                        : BauhausColors.white,
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 15),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                            color: BauhausColors.black,
                            letterSpacing: 1,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          subtitle,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: BauhausColors.gray,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Container(
                  width: 30,
                  height: 70,
                  color: BauhausColors.lightGray,
                  child: Icon(
                    Icons.arrow_forward_ios,
                    size: 16,
                    color: BauhausColors.gray,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}