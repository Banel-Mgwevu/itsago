import 'package:flutter/material.dart';
import 'calendar_service.dart';
import 'main.dart'; // For BauhausColors

class CalendarEventsWidget extends StatelessWidget {
  final List<CalendarEvent> events;
  final bool isLoading;
  final bool isConnected;
  final Function(CalendarEvent)? onEventTap;
  final VoidCallback? onConnectTap;
  final VoidCallback? onRefreshTap;
  
  const CalendarEventsWidget({
    super.key,
    required this.events,
    required this.isLoading,
    required this.isConnected,
    this.onEventTap,
    this.onConnectTap,
    this.onRefreshTap,
  });

  @override
  Widget build(BuildContext context) {
    if (!isConnected) {
      return _buildSignInPrompt();
    }

    if (isLoading) {
      return _buildLoadingWidget();
    }

    if (events.isEmpty) {
      return _buildNoEventsWidget();
    }

    return _buildEventsList();
  }

  Widget _buildSignInPrompt() {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: BauhausColors.white,
        border: Border.all(color: BauhausColors.black, width: 2),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.calendar_today,
            size: 40,
            color: BauhausColors.blue,
          ),
          const SizedBox(height: 10),
          Text(
            'CONNECT CALENDAR',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: BauhausColors.black,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Connect your Google Calendar to get personalized interview prep and automatic reminders for upcoming interviews.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: BauhausColors.gray,
            ),
          ),
          const SizedBox(height: 15),
          Container(
            width: double.infinity,
            height: 45,
            decoration: BoxDecoration(
              color: BauhausColors.blue,
              border: Border.all(color: BauhausColors.black, width: 2),
            ),
            child: MaterialButton(
              onPressed: onConnectTap,
              child: Text(
                'CONNECT GOOGLE CALENDAR',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  color: BauhausColors.white,
                  letterSpacing: 1,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingWidget() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: BauhausColors.white,
        border: Border.all(color: BauhausColors.black, width: 2),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(
            color: BauhausColors.blue,
            strokeWidth: 3,
          ),
          const SizedBox(height: 15),
          Text(
            'LOADING CALENDAR...',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w900,
              color: BauhausColors.black,
              letterSpacing: 1,
            ),
          ),
          Text(
            'Fetching your upcoming events',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: BauhausColors.gray,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoEventsWidget() {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: BauhausColors.white,
        border: Border.all(color: BauhausColors.black, width: 2),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(
                Icons.work_off,
                size: 30,
                color: BauhausColors.gray,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'NO UPCOMING INTERVIEWS',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        color: BauhausColors.black,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'No interview events found. Practice with general questions!',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: BauhausColors.gray,
                      ),
                    ),
                  ],
                ),
              ),
              if (onRefreshTap != null)
                GestureDetector(
                  onTap: onRefreshTap,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: BauhausColors.blue,
                      border: Border.all(color: BauhausColors.black, width: 1),
                    ),
                    child: Icon(
                      Icons.refresh,
                      color: BauhausColors.white,
                      size: 16,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEventsList() {
    final interviewEvents = events.where((e) => e.isInterview).toList();

    if (interviewEvents.isEmpty) {
      return _buildNoInterviewsWidget();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'UPCOMING INTERVIEWS',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  color: BauhausColors.black,
                  letterSpacing: 2,
                ),
              ),
            ),
            if (onRefreshTap != null)
              GestureDetector(
                onTap: onRefreshTap,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: BauhausColors.blue,
                    border: Border.all(color: BauhausColors.black, width: 1),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.refresh,
                        color: BauhausColors.white,
                        size: 12,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'REFRESH',
                        style: TextStyle(
                          fontSize: 8,
                          fontWeight: FontWeight.w900,
                          color: BauhausColors.white,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 10),
        ...interviewEvents.take(3).map((event) => _buildEventCard(event, isInterview: true)),
        if (interviewEvents.length > 3)
          Container(
            margin: const EdgeInsets.only(top: 8),
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: BauhausColors.lightGray,
              border: Border.all(color: BauhausColors.gray, width: 1),
            ),
            child: Center(
              child: Text(
                '+${interviewEvents.length - 3} MORE INTERVIEWS',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  color: BauhausColors.gray,
                  letterSpacing: 1,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildNoInterviewsWidget() {
    final regularEvents = events.where((e) => !e.isInterview).toList();
    
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: BauhausColors.white,
        border: Border.all(color: BauhausColors.black, width: 2),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(
                Icons.work_off,
                size: 30,
                color: BauhausColors.gray,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'NO UPCOMING INTERVIEWS',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        color: BauhausColors.black,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      regularEvents.isNotEmpty
                          ? 'Found ${regularEvents.length} regular events, but no interviews. Practice with general questions!'
                          : 'No interview events found. Practice with general questions to stay ready!',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: BauhausColors.gray,
                      ),
                    ),
                  ],
                ),
              ),
              if (onRefreshTap != null)
                GestureDetector(
                  onTap: onRefreshTap,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: BauhausColors.blue,
                      border: Border.all(color: BauhausColors.black, width: 1),
                    ),
                    child: Icon(
                      Icons.refresh,
                      color: BauhausColors.white,
                      size: 16,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEventCard(CalendarEvent event, {required bool isInterview}) {
    final isToday = event.isToday;
    final isSoon = event.startTime.difference(DateTime.now()).inHours < 2;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isToday ? BauhausColors.yellow.withOpacity(0.1) : BauhausColors.white,
        border: Border.all(
          color: isToday ? BauhausColors.yellow : 
                 isSoon ? BauhausColors.red :
                 isInterview ? BauhausColors.blue : BauhausColors.black,
          width: isToday || isSoon ? 3 : 2,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => onEventTap?.call(event),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Container(
                  width: 45,
                  height: 45,
                  decoration: BoxDecoration(
                    color: isToday ? BauhausColors.yellow :
                           isSoon ? BauhausColors.red :
                           isInterview ? BauhausColors.blue : BauhausColors.gray,
                    border: Border.all(color: BauhausColors.black, width: 2),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        isInterview ? Icons.work : Icons.event,
                        color: (isToday || isSoon) ? BauhausColors.black : BauhausColors.white,
                        size: 16,
                      ),
                      if (isToday || isSoon)
                        Container(
                          width: 4,
                          height: 4,
                          decoration: BoxDecoration(
                            color: BauhausColors.black,
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              event.title,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w900,
                                color: BauhausColors.black,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (isToday || isSoon)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: isToday ? BauhausColors.yellow : BauhausColors.red,
                                border: Border.all(color: BauhausColors.black, width: 1),
                              ),
                              child: Text(
                                isToday ? 'TODAY' : 'SOON',
                                style: TextStyle(
                                  fontSize: 8,
                                  fontWeight: FontWeight.w900,
                                  color: BauhausColors.black,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _formatEventTime(event),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: BauhausColors.gray,
                        ),
                      ),
                      if (event.location.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Icon(
                              Icons.location_on,
                              size: 10,
                              color: BauhausColors.gray,
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                event.location,
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: BauhausColors.gray,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                      if (event.description.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          event.description,
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w600,
                            color: BauhausColors.gray,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                if (isInterview)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    decoration: BoxDecoration(
                      color: BauhausColors.red,
                      border: Border.all(color: BauhausColors.black, width: 1),
                    ),
                    child: Column(
                      children: [
                        Icon(
                          Icons.psychology,
                          color: BauhausColors.white,
                          size: 12,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'PREP',
                          style: TextStyle(
                            fontSize: 8,
                            fontWeight: FontWeight.w900,
                            color: BauhausColors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatEventTime(CalendarEvent event) {
    final now = DateTime.now();
    final eventDate = event.startTime;
    final timeDiff = eventDate.difference(now);
    
    if (eventDate.year == now.year && eventDate.month == now.month && eventDate.day == now.day) {
      if (timeDiff.inHours < 1) {
        return 'Today in ${timeDiff.inMinutes} min - ${_formatTime(eventDate)}';
      }
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
}