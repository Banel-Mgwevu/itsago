import 'dart:convert';
import 'package:googleapis/calendar/v3.dart' as calendar;
import 'package:googleapis_auth/auth_io.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class CalendarEvent {
  final String id;
  final String title;
  final String description;
  final DateTime startTime;
  final DateTime endTime;
  final String location;
  final List<String> attendees;

  CalendarEvent({
    required this.id,
    required this.title,
    required this.description,
    required this.startTime,
    required this.endTime,
    required this.location,
    required this.attendees,
  });

  factory CalendarEvent.fromGoogleEvent(calendar.Event event) {
    return CalendarEvent(
      id: event.id ?? '',
      title: event.summary ?? 'No Title',
      description: event.description ?? '',
      startTime: event.start?.dateTime ?? DateTime.now(),
      endTime: event.end?.dateTime ?? DateTime.now(),
      location: event.location ?? '',
      attendees: event.attendees?.map((a) => a.email ?? '').toList() ?? [],
    );
  }

  bool get isInterview {
 final keywords = [
  'interview',
  'meeting',
  'call',
  'zoom',
  'teams',
  'discussion',
  'hire',
  'hiring',
  'job',
  'position',
  'role',
  'opening',
  'vacancy',
  'career',
  'opportunity',
  'candidate',
  'applicant',
  'application',
  'recruiter',
  'recruitment',
  'intern',
  'internship',
  'graduate',
  'entry',
  'junior',
  'mid',
  'midlevel',
  'midlevel',
  'senior',
  'lead',
  'manager',
  'director',
  'head',
  'principal',
  'consultant',
  'specialist',
  'coordinator',
  'analyst',
  'engineer',
  'developer',
  'designer',
  'architect',
  'administrator',
  'contractor',
  'freelance',
  'temporary',
  'parttime',
  'fulltime',
  'google',
  'meet',
  'link',
  'skype',
  'hangouts',
  'webex',
  'slack',
  'huddle',
  'online',
  'virtual',
  'screening',
  'assessment',
  'evaluation',
  'appointment',
  'chat',
  'schedule',
  'scheduled',
  'invite',
  'invitation',
  'panel',
  'hr',
  'talent',
  'acquisition',
  'video',
  'phone',
  'technical',
  'final',
  'first',
  'second','head','test',
  'third','marketing','director',
  'test','software','developer',
  'coding',
  'challenge',
  'assignment',
  'exam',
  'round',
  'stage',
  'slot',
  'confirm',
  'attendance',
  'confirmation',
  'join',
  'web',
  'calendar',
  'session',
  'briefing',
  'orientation',
  'walkthrough',
  'connection',
  'details',
  'login',
  'credentials',
  'passcode',
  'password',
  'access',
  'dial',
  'conference',
  'id',
  'number',
  'time',
  'availability',
  'request',
  'reschedule',
  'postpone',
  'code',
  'pre',
  'onboarding'
];
   
    
    final searchText = '${title.toLowerCase()} ${description.toLowerCase()}';
    return keywords.any((keyword) => searchText.contains(keyword));
  }

  bool get isUpcoming {
    return startTime.isAfter(DateTime.now());
  }

  bool get isToday {
    final now = DateTime.now();
    return startTime.year == now.year &&
           startTime.month == now.month &&
           startTime.day == now.day;
  }
}

class GoogleCalendarService {
  static final GoogleCalendarService _instance = GoogleCalendarService._internal();
  factory GoogleCalendarService() => _instance;
  GoogleCalendarService._internal();

  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: [
      'email',
      'https://www.googleapis.com/auth/calendar.readonly',
    ],
  );

  GoogleSignInAccount? _currentUser;
  calendar.CalendarApi? _calendarApi;
  bool _isInitialized = false;

  bool get isSignedIn => _currentUser != null;
  bool get isInitialized => _isInitialized;
  GoogleSignInAccount? get currentUser => _currentUser;

  // Initialize the service - call this when app starts
  Future<bool> initialize() async {
    if (_isInitialized) return isSignedIn;

    try {
      // Check if user is already signed in
      _currentUser = await _googleSignIn.signInSilently();
      
      if (_currentUser != null) {
        await _initializeCalendarApi();
        print('Calendar service: User already signed in - ${_currentUser!.email}');
      } else {
        print('Calendar service: No previous sign-in found');
      }
      
      _isInitialized = true;
      return isSignedIn;
    } catch (error) {
      print('Error initializing calendar service: $error');
      _isInitialized = true;
      return false;
    }
  }

  // Sign in with user interaction
  Future<bool> signIn() async {
    try {
      final GoogleSignInAccount? account = await _googleSignIn.signIn();
      if (account != null) {
        _currentUser = account;
        await _initializeCalendarApi();
        await _saveAuthState();
        print('Calendar service: User signed in - ${account.email}');
        return true;
      }
      return false;
    } catch (error) {
      print('Error signing in: $error');
      return false;
    }
  }

  // Sign out
  Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
      _currentUser = null;
      _calendarApi = null;
      await _clearAuthState();
      print('Calendar service: User signed out');
    } catch (error) {
      print('Error signing out: $error');
    }
  }

  // Save authentication state
  Future<void> _saveAuthState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('calendar_signed_in', true);
      if (_currentUser != null) {
        await prefs.setString('calendar_user_email', _currentUser!.email);
      }
    } catch (error) {
      print('Error saving auth state: $error');
    }
  }

  // Clear authentication state
  Future<void> _clearAuthState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('calendar_signed_in');
      await prefs.remove('calendar_user_email');
    } catch (error) {
      print('Error clearing auth state: $error');
    }
  }

  // Initialize Calendar API with token refresh handling
  Future<void> _initializeCalendarApi() async {
    if (_currentUser == null) return;

    try {
      final GoogleSignInAuthentication auth = await _currentUser!.authentication;
      
      // Create a client that automatically refreshes tokens
      final AuthClient authClient = authenticatedClient(
        http.Client(),
        AccessCredentials(
          AccessToken(
            'Bearer', 
            auth.accessToken!, 
            DateTime.now().toUtc().add(Duration(hours: 1))
          ),
          auth.idToken,
          ['https://www.googleapis.com/auth/calendar.readonly'],
        ),
      );

      _calendarApi = calendar.CalendarApi(authClient);
      print('Calendar API initialized successfully');
    } catch (error) {
      print('Error initializing Calendar API: $error');
      // Try to refresh authentication
      await _refreshAuthentication();
    }
  }

  // Refresh authentication if tokens are expired
  Future<bool> _refreshAuthentication() async {
    try {
      if (_currentUser == null) return false;

      // Try to refresh the authentication
      final GoogleSignInAuthentication auth = await _currentUser!.authentication;
      
      if (auth.accessToken != null) {
        await _initializeCalendarApi();
        return true;
      } else {
        // Token is invalid, need to sign in again
        return await signIn();
      }
    } catch (error) {
      print('Error refreshing authentication: $error');
      return false;
    }
  }

  // Enhanced API call with automatic retry and refresh
  Future<T> _executeWithRetry<T>(Future<T> Function() apiCall) async {
    try {
      return await apiCall();
    } catch (error) {
      print('API call failed, attempting to refresh auth: $error');
      
      // Try to refresh authentication
      if (await _refreshAuthentication()) {
        try {
          return await apiCall();
        } catch (retryError) {
          print('API call failed after auth refresh: $retryError');
          throw Exception('Calendar API unavailable: $retryError');
        }
      } else {
        throw Exception('Authentication failed: $error');
      }
    }
  }

  // Get upcoming events with retry logic
  Future<List<CalendarEvent>> getUpcomingEvents({int maxResults = 10}) async {
    if (!_isInitialized) {
      await initialize();
    }

    if (_calendarApi == null) {
      throw Exception('Calendar not connected. Please sign in first.');
    }

    return await _executeWithRetry(() async {
      final now = DateTime.now();
      final events = await _calendarApi!.events.list(
        'primary',
        timeMin: now,
        timeMax: now.add(Duration(days: 30)),
        maxResults: maxResults,
        singleEvents: true,
        orderBy: 'startTime',
      );

      return events.items?.map((event) => CalendarEvent.fromGoogleEvent(event)).toList() ?? [];
    });
  }

  // Get today's events with retry logic
  Future<List<CalendarEvent>> getTodaysEvents() async {
    if (!_isInitialized) {
      await initialize();
    }

    if (_calendarApi == null) {
      throw Exception('Calendar not connected. Please sign in first.');
    }

    return await _executeWithRetry(() async {
      final now = DateTime.now();
      final startOfDay = DateTime(now.year, now.month, now.day);
      final endOfDay = startOfDay.add(Duration(days: 1));

      final events = await _calendarApi!.events.list(
        'primary',
        timeMin: startOfDay,
        timeMax: endOfDay,
        maxResults: 20,
        singleEvents: true,
        orderBy: 'startTime',
      );

      return events.items?.map((event) => CalendarEvent.fromGoogleEvent(event)).toList() ?? [];
    });
  }

  // Get interview-related events
  Future<List<CalendarEvent>> getInterviewEvents() async {
    try {
      final upcomingEvents = await getUpcomingEvents();
      return upcomingEvents.where((event) => event.isInterview).toList();
    } catch (error) {
      print('Error getting interview events: $error');
      return [];
    }
  }

  // Get next interview
  Future<CalendarEvent?> getNextInterview() async {
    try {
      final interviewEvents = await getInterviewEvents();
      if (interviewEvents.isEmpty) return null;
      
      interviewEvents.sort((a, b) => a.startTime.compareTo(b.startTime));
      return interviewEvents.first;
    } catch (error) {
      print('Error getting next interview: $error');
      return null;
    }
  }

  // Check connection status
  Future<bool> checkConnection() async {
    try {
      if (!isSignedIn) return false;
      
      // Try a simple API call to verify connection
      await _executeWithRetry(() async {
        await _calendarApi!.calendarList.list(maxResults: 1);
      });
      
      return true;
    } catch (error) {
      print('Connection check failed: $error');
      return false;
    }
  }

  // Reconnect if needed
  Future<bool> ensureConnection() async {
    if (!_isInitialized) {
      return await initialize();
    }

    if (!isSignedIn) {
      return await initialize();
    }

    if (!(await checkConnection())) {
      return await _refreshAuthentication();
    }

    return true;
  }
}