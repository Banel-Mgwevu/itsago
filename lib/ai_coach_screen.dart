import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'main.dart';
import 'main_menu_screen.dart';
import 'about_screen.dart';
import 'upgrade_premium_screen.dart';
import 'setup_screen.dart';
import 'resources_screen.dart';
import 'calendar_service.dart';
import 'calendar_widget.dart';
import 'notification_service.dart';

class AiCoachScreen extends StatefulWidget {
  final List<CameraDescription> cameras;
  
  const AiCoachScreen({Key? key, required this.cameras}) : super(key: key);

  @override
  State<AiCoachScreen> createState() => _AiCoachScreenState();
}

class ChatMessage {
  final String text;
  final bool isUser;
  final DateTime timestamp;

  ChatMessage({
    required this.text,
    required this.isUser,
    required this.timestamp,
  });
}

class _AiCoachScreenState extends State<AiCoachScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<ChatMessage> _messages = [];
  bool _isTyping = false;
  late AnimationController _typingController;
  
  // Gemini API configuration
  static const String apiKey = 'AIzaSyBcK5CDUQhMY94FJEgGja6UiT4pKAcdWZw';//'AIzaSyBG9Ibtg3a0UTO5DZb4mfhmN7mtij_OMPU';
  static const String baseUrl = 'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent';
  
  // Chat history for context
  final List<Map<String, dynamic>> _chatHistory = [];

  // Calendar integration - Add local state tracking
  final GoogleCalendarService _calendarService = GoogleCalendarService();
  final NotificationService _notificationService = NotificationService();
  List<CalendarEvent> _upcomingInterviews = [];
  bool _isCalendarLoading = false;
  bool _isCalendarConnected = false; // ADD THIS: Local state tracking

  // Sample interview questions for quick start
  final List<String> _quickQuestions = [
    "Tell me about yourself",
    "What are your greatest strengths?",
    "Why do you want this job?",
    "Where do you see yourself in 5 years?",
    "What's your biggest weakness?",
    "Why are you leaving your current job?",
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _typingController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _addWelcomeMessage();
    _addSystemMessage();
    _initializeServices();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _messageController.dispose();
    _scrollController.dispose();
    _typingController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    
    if (state == AppLifecycleState.resumed) {
      // App came back to foreground, refresh calendar data
      _refreshCalendarData();
    }
  }

  // Initialize all services
  Future<void> _initializeServices() async {
    // Initialize notifications first
    await _initializeNotifications();
    
    // Initialize calendar service
    await _initializeCalendarService();
  }

  Future<void> _initializeNotifications() async {
    try {
      await _notificationService.initialize();
    } catch (error) {
      print('Error initializing notifications: $error');
    }
  }

  Future<void> _initializeCalendarService() async {
    if (mounted) {
      setState(() {
        _isCalendarLoading = true;
      });
    }

    try {
      print('Initializing calendar service...');
      
      // Initialize the calendar service (this will auto-sign in if previously signed in)
      final bool wasSignedIn = await _calendarService.initialize();
      
      // UPDATE: Always update local state after initialization
      if (mounted) {
        setState(() {
          _isCalendarConnected = _calendarService.isSignedIn;
        });
      }
      
      if (wasSignedIn) {
        print('Calendar service: User was already signed in, loading data...');
        await _loadCalendarData();
      } else {
        print('Calendar service: No previous sign-in found');
        _showCalendarSignInOption();
      }
    } catch (error) {
      print('Error initializing calendar service: $error');
      // UPDATE: Ensure state is updated even on error
      if (mounted) {
        setState(() {
          _isCalendarConnected = false;
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isCalendarLoading = false;
        });
      }
    }
  }

  Future<void> _loadCalendarData() async {
    try {
      // Ensure connection before loading data
      if (await _calendarService.ensureConnection()) {
        final interviews = await _calendarService.getInterviewEvents();
        if (mounted) {
          setState(() {
            _upcomingInterviews = interviews;
            _isCalendarConnected = _calendarService.isSignedIn; // UPDATE: Sync state
          });
        }
        
        if (interviews.isNotEmpty) {
          _updateAIContextWithCalendar();
          // Update notifications when calendar data loads
          await _notificationService.scheduleInterviewNotifications();
        }
        
        print('Calendar data loaded: ${interviews.length} interview events found');
      } else {
        print('Could not establish calendar connection');
        // UPDATE: Update connection state if connection failed
        if (mounted) {
          setState(() {
            _isCalendarConnected = false;
          });
        }
      }
    } catch (error) {
      print('Error loading calendar data: $error');
      // Handle the error gracefully - app should still work without calendar
      if (mounted) {
        setState(() {
          _isCalendarConnected = false;
        });
      }
    }
  }

  void _showCalendarSignInOption() {
    print('Calendar connection available - user can sign in for interview reminders');
  }

  Future<void> _connectCalendar() async {
    if (mounted) {
      setState(() {
        _isCalendarLoading = true;
      });
    }

    try {
      final bool success = await _calendarService.signIn();
      if (success) {
        // UPDATE: Update local state immediately after successful sign-in
        if (mounted) {
          setState(() {
            _isCalendarConnected = true;
          });
        }
        
        await _loadCalendarData();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Calendar connected successfully!'),
              backgroundColor: BauhausColors.blue,
            ),
          );
        }
      } else {
        // UPDATE: Update state on sign-in failure
        if (mounted) {
          setState(() {
            _isCalendarConnected = false;
          });
        }
      }
    } catch (error) {
      print('Error connecting calendar: $error');
      if (mounted) {
        setState(() {
          _isCalendarConnected = false; // UPDATE: Update state on error
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to connect calendar'),
            backgroundColor: BauhausColors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isCalendarLoading = false;
        });
      }
    }
  }

  Future<void> _disconnectCalendar() async {
    try {
      await _calendarService.signOut();
      if (mounted) {
        setState(() {
          _upcomingInterviews = [];
          _isCalendarConnected = false; // UPDATE: Update local state
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Calendar disconnected'),
            backgroundColor: BauhausColors.gray,
          ),
        );
      }
    } catch (error) {
      print('Error disconnecting calendar: $error');
    }
  }

  Future<void> _refreshCalendarData() async {
    // UPDATE: Check local state first, then service state
    if (_isCalendarConnected && _calendarService.isSignedIn) {
      try {
        // Ensure connection is still valid
        if (await _calendarService.ensureConnection()) {
          await _loadCalendarData();
        } else {
          print('Calendar connection lost, reinitializing...');
          await _initializeCalendarService();
        }
      } catch (error) {
        print('Error refreshing calendar data: $error');
        // UPDATE: Update state on refresh error
        if (mounted) {
          setState(() {
            _isCalendarConnected = false;
          });
        }
      }
    }
  }

  void _updateAIContextWithCalendar() {
    if (_upcomingInterviews.isNotEmpty && _isCalendarConnected) {
      final nextInterview = _upcomingInterviews.first;
      final contextMessage = "User has an upcoming interview: '${nextInterview.title}' on ${_formatEventTime(nextInterview)}. ${nextInterview.description.isNotEmpty ? 'Description: ${nextInterview.description}' : ''} Provide relevant preparation advice.";
      
      print('Calendar context: $contextMessage');
    }
  }

  void _addSystemMessage() {
    // Add system instructions to chat history
    _chatHistory.add({
      "role": "user",
      "parts": [{
        "text": """You are ITSAGO, an AI Interview Coach chatbot.

Keep responses medium length - 2-3 sentences with helpful details. Be chatbot-friendly but informative.

Rules:
- 2-3 sentences maximum
- Give practical, actionable advice
- Include key tips or examples when helpful
- Be conversational and encouraging
- Focus on one main point with brief explanation

Respond like a helpful chatbot that gives solid interview advice without being too wordy."""
      }]
    });
    
    _chatHistory.add({
      "role": "model",
      "parts": [{
        "text": "Hi! I'm ITSAGO, your AI Interview Coach. I'll help you with practical interview tips and advice. What would you like to practice today?"
      }]
    });
  }

  void _addWelcomeMessage() {
    setState(() {
      _messages.add(ChatMessage(
        text: "Hi! I'm ITSAGO, your AI Interview Coach. I'll help you prepare with practical tips and advice. What interview topic would you like to work on?",
        isUser: false,
        timestamp: DateTime.now(),
      ));
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BauhausColors.lightGray,
      drawer: _buildBauhausDrawer(),
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Container(
              width: double.infinity,
              height: 100,
              color: BauhausColors.yellow,
              child: Stack(
                children: [
                  // Geometric elements
                  Positioned(
                    top: -15,
                    right: -15,
                    child: Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        color: BauhausColors.red,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 8,
                    left: 30,
                    child: Container(
                      width: 25,
                      height: 12,
                      color: BauhausColors.blue,
                    ),
                  ),
                  // Back button
                  Positioned(
                    top: 15,
                    left: 15,
                    child: GestureDetector(
                      onTap: () => Navigator.of(context).pop(),
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: BauhausColors.white,
                          border: Border.all(
                            color: BauhausColors.black,
                            width: 2,
                          ),
                        ),
                        child: Icon(
                          Icons.arrow_back,
                          color: BauhausColors.black,
                          size: 20,
                        ),
                      ),
                    ),
                  ),
                  // Menu button
                  Positioned(
                    top: 15,
                    right: 15,
                    child: Builder(
                      builder: (context) => GestureDetector(
                        onTap: () => Scaffold.of(context).openDrawer(),
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: BauhausColors.white,
                            border: Border.all(
                              color: BauhausColors.black,
                              width: 2,
                            ),
                          ),
                          child: Icon(
                            Icons.menu,
                            color: BauhausColors.black,
                            size: 20,
                          ),
                        ),
                      ),
                    ),
                  ),
                  // Title
                  Center(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.psychology,
                          color: BauhausColors.black,
                          size: 24,
                        ),
                        const SizedBox(width: 10),
                        Text(
                          'AI COACH',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            color: BauhausColors.black,
                            letterSpacing: 3,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            
            // Main content area - Expandable
            Expanded(
              child: _messages.length <= 1 
                  ? SingleChildScrollView(
                      padding: const EdgeInsets.all(15),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Calendar Events Section - TOP
                          _buildCalendarEventsSection(),
                          
                          const SizedBox(height: 20),
                          
                          // Quick Questions Section - MIDDLE
                          Text(
                            'QUICK START',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                              color: BauhausColors.black,
                              letterSpacing: 2,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: _quickQuestions.map((question) {
                              return GestureDetector(
                                onTap: () => _sendMessage(question),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: BauhausColors.white,
                                    border: Border.all(
                                      color: BauhausColors.black,
                                      width: 2,
                                    ),
                                  ),
                                  child: Text(
                                    question,
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: BauhausColors.black,
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                          
                          const SizedBox(height: 20),
                          
                          // Welcome message - BOTTOM
                          if (_messages.isNotEmpty) 
                            _buildMessageBubble(_messages.first),
                          
                          // Add some bottom padding for better scrolling
                          const SizedBox(height: 100),
                        ],
                      ),
                    )
                  : ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.symmetric(horizontal: 15),
                      itemCount: _messages.length + (_isTyping ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (index == _messages.length && _isTyping) {
                          return _buildTypingIndicator();
                        }
                        return _buildMessageBubble(_messages[index]);
                      },
                    ),
            ),
            
            // Input area - Fixed at bottom
            Container(
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: BauhausColors.white,
                border: Border(
                  top: BorderSide(color: BauhausColors.black, width: 2),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: BauhausColors.black, width: 2),
                      ),
                      child: TextField(
                        controller: _messageController,
                        decoration: InputDecoration(
                          hintText: 'Ask any interview question...',
                          hintStyle: TextStyle(
                            color: BauhausColors.gray,
                            fontWeight: FontWeight.w600,
                          ),
                          contentPadding: const EdgeInsets.all(12),
                          border: InputBorder.none,
                          filled: true,
                          fillColor: BauhausColors.white,
                        ),
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: BauhausColors.black,
                        ),
                        maxLines: null,
                        onSubmitted: (text) {
                          if (text.trim().isNotEmpty) {
                            _sendMessage(text.trim());
                          }
                        },
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    width: 50,
                    height: 50,
                    color: BauhausColors.blue,
                    child: MaterialButton(
                      onPressed: _isTyping ? null : () {
                        final text = _messageController.text.trim();
                        if (text.isNotEmpty) {
                          _sendMessage(text);
                        }
                      },
                      child: Icon(
                        Icons.send,
                        color: BauhausColors.white,
                        size: 20,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Calendar events section - UPDATE: Use local state
  Widget _buildCalendarEventsSection() {
    return CalendarEventsWidget(
      events: _upcomingInterviews,
      isLoading: _isCalendarLoading,
      isConnected: _isCalendarConnected, // CHANGED: Use local state instead of service state
      onEventTap: (event) {
        // When user taps on an interview event, auto-generate coaching
        if (event.isInterview) {
          final message = "Help me prepare for my upcoming interview: ${event.title} scheduled for ${_formatEventTime(event)}. ${event.description.isNotEmpty ? 'Description: ${event.description}' : ''}";
          _sendMessage(message);
        }
      },
      onConnectTap: _connectCalendar,
      onRefreshTap: _refreshCalendarData,
    );
  }

  // ... rest of the methods remain the same ...
  
  Widget _buildMessageBubble(ChatMessage message) {
    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      child: Row(
        mainAxisAlignment: message.isUser 
            ? MainAxisAlignment.end 
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!message.isUser) ...[
            Container(
              width: 35,
              height: 35,
              decoration: BoxDecoration(
                color: BauhausColors.yellow,
                border: Border.all(color: BauhausColors.black, width: 2),
              ),
              child: Icon(
                Icons.psychology,
                color: BauhausColors.black,
                size: 18,
              ),
            ),
            const SizedBox(width: 10),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: message.isUser 
                    ? BauhausColors.blue 
                    : BauhausColors.white,
                border: Border.all(color: BauhausColors.black, width: 2),
              ),
              child: Text(
                message.text,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: message.isUser 
                      ? BauhausColors.white 
                      : BauhausColors.black,
                  height: 1.3,
                ),
              ),
            ),
          ),
          if (message.isUser) ...[
            const SizedBox(width: 10),
            Container(
              width: 35,
              height: 35,
              decoration: BoxDecoration(
                color: BauhausColors.red,
                border: Border.all(color: BauhausColors.black, width: 2),
              ),
              child: Icon(
                Icons.person,
                color: BauhausColors.white,
                size: 18,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      child: Row(
        children: [
          Container(
            width: 35,
            height: 35,
            decoration: BoxDecoration(
              color: BauhausColors.yellow,
              border: Border.all(color: BauhausColors.black, width: 2),
            ),
            child: Icon(
              Icons.psychology,
              color: BauhausColors.black,
              size: 18,
            ),
          ),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: BauhausColors.white,
              border: Border.all(color: BauhausColors.black, width: 2),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'AI Coach is thinking',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: BauhausColors.gray,
                    fontStyle: FontStyle.italic,
                  ),
                ),
                const SizedBox(width: 6),
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: BauhausColors.blue,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _sendMessage(String text) {
    setState(() {
      _messages.add(ChatMessage(
        text: text,
        isUser: true,
        timestamp: DateTime.now(),
      ));
      _isTyping = true;
    });
    
    _messageController.clear();
    _scrollToBottom();
    
    // Generate AI response using direct HTTP API
    _generateGeminiResponse(text);
  }

  Future<void> _generateGeminiResponse(String userMessage) async {
    try {
      // Add user message to chat history
      _chatHistory.add({
        "role": "user",
        "parts": [{"text": userMessage}]
      });

      // Include calendar context if available
      String contextualMessage = userMessage;
      if (_upcomingInterviews.isNotEmpty) {
        final nextInterview = _upcomingInterviews.first;
        contextualMessage += "\n\nContext: User has an upcoming interview - '${nextInterview.title}' on ${_formatEventTime(nextInterview)}.";
      }

      final response = await http.post(
        Uri.parse('$baseUrl?key=$apiKey'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          "contents": [
            ..._chatHistory,
            {
              "role": "user",
              "parts": [{"text": contextualMessage + "\n\nGive me 2-3 sentences with helpful details. Be chatbot-friendly but informative."}]
            }
          ],
          "generationConfig": {
            "temperature": 0.7,
            "topK": 40,
            "topP": 0.95,
            "maxOutputTokens": 120,
            "stopSequences": ["\n\n"],
          },
          "safetySettings": [
            {
              "category": "HARM_CATEGORY_HARASSMENT",
              "threshold": "BLOCK_MEDIUM_AND_ABOVE"
            },
            {
              "category": "HARM_CATEGORY_HATE_SPEECH",
              "threshold": "BLOCK_MEDIUM_AND_ABOVE"
            },
            {
              "category": "HARM_CATEGORY_SEXUALLY_EXPLICIT",
              "threshold": "BLOCK_MEDIUM_AND_ABOVE"
            },
            {
              "category": "HARM_CATEGORY_DANGEROUS_CONTENT",
              "threshold": "BLOCK_MEDIUM_AND_ABOVE"
            }
          ]
        }),
      );

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        
        if (responseData['candidates'] != null && 
            responseData['candidates'].isNotEmpty &&
            responseData['candidates'][0]['content'] != null &&
            responseData['candidates'][0]['content']['parts'] != null &&
            responseData['candidates'][0]['content']['parts'].isNotEmpty) {
          
          String aiResponse = responseData['candidates'][0]['content']['parts'][0]['text'];
          
          // Trim response to ensure it's concise
          aiResponse = _trimResponse(aiResponse);
          
          // Add AI response to chat history
          _chatHistory.add({
            "role": "model",
            "parts": [{"text": aiResponse}]
          });

          setState(() {
            _isTyping = false;
            _messages.add(ChatMessage(
              text: aiResponse,
              isUser: false,
              timestamp: DateTime.now(),
            ));
          });
        } else {
          _handleAIError('Sorry, I couldn\'t generate a response. Could you try rephrasing your question?');
        }
      } else {
        print('API Error: ${response.statusCode} - ${response.body}');
        _handleAIError('I\'m having trouble connecting right now. Please check your connection and try again.');
      }
    } catch (e) {
      print('Error generating AI response: $e');
      _handleAIError('Network connection issue. Please check your internet and try again.');
    }
    
    _scrollToBottom();
  }

  String _trimResponse(String response) {
    response = response.trim().replaceAll(RegExp(r'\n+'), ' ');
    
    List<String> sentences = response.split(RegExp(r'[.!?]+'));
    sentences = sentences.where((s) => s.trim().isNotEmpty).toList();
    
    if (sentences.length <= 3) {
      return response.trim();
    }
    
    String trimmed = sentences.take(3).join('. ').trim();
    
    if (!trimmed.endsWith('.') && !trimmed.endsWith('!') && !trimmed.endsWith('?')) {
      trimmed += '.';
    }
    
    return trimmed;
  }

  void _handleAIError(String errorMessage) {
    setState(() {
      _isTyping = false;
      _messages.add(ChatMessage(
        text: errorMessage,
        isUser: false,
        timestamp: DateTime.now(),
      ));
    });
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // Helper methods for calendar integration
  String _formatEventTime(CalendarEvent event) {
    final now = DateTime.now();
    final eventDate = event.startTime;
    
    if (eventDate.year == now.year && eventDate.month == now.month && eventDate.day == now.day) {
      return 'Today ${_formatTime(eventDate)}';
    } else if (eventDate.difference(now).inDays == 1) {
      return 'Tomorrow ${_formatTime(eventDate)}';
    } else if (eventDate.difference(now).inDays < 7) {
      return '${_getDayName(eventDate.weekday)} ${_formatTime(eventDate)}';
    } else {
      return '${eventDate.day}/${eventDate.month} ${_formatTime(eventDate)}';
    }
  }

  String _formatTime(DateTime dateTime) {
    final hour = dateTime.hour;
    final minute = dateTime.minute.toString().padLeft(2, '0');
    final amPm = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
    return '$displayHour:$minute $amPm';
  }

  String _getDayName(int weekday) {
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return days[weekday - 1];
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
                        'ITSAGO',
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
                
                // Main Menu item
                _buildDrawerItem(
                  icon: Icons.home,
                  title: 'MAIN MENU',
                  subtitle: 'Return to home screen',
                  color: BauhausColors.yellow,
                  onTap: () {
                    Navigator.of(context).pop();
                    Navigator.of(context).pushReplacement(
                      PageRouteBuilder(
                        pageBuilder: (context, animation, secondaryAnimation) =>
                            MainMenuScreen(cameras: widget.cameras),
                        transitionsBuilder: (context, animation, secondaryAnimation, child) {
                          return SlideTransition(
                            position: Tween<Offset>(
                              begin: const Offset(-1.0, 0.0),
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
                
                // Resources menu item
                _buildDrawerItem(
                  icon: Icons.library_books,
                  title: 'INTERVIEW RESOURCES',
                  subtitle: 'Guides and study materials',
                  color: BauhausColors.blue,
                  onTap: () {
                    Navigator.of(context).pop();
                    Navigator.of(context).push(
                      PageRouteBuilder(
                        pageBuilder: (context, animation, secondaryAnimation) =>
                            ResourcesScreen(cameras: widget.cameras),
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
                  subtitle: 'Learn more about ISTAGO',
                  color: BauhausColors.gray,
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