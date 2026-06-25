import 'package:flutter/material.dart';
import 'calendar_service.dart';
import 'app_theme.dart';

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
    if (!isConnected) return _connectPrompt();
    if (isLoading)    return _loading();
    if (events.isEmpty) return _empty();
    return _list();
  }

  // ── Connect prompt ────────────────────────────────────
  Widget _connectPrompt() => Container(
    padding: const EdgeInsets.all(14),
    decoration: AppDecorations.cardSmall,
    child: Row(children: [
      Container(width: 44, height: 44,
        decoration: const BoxDecoration(
          color: AppColors.blue,
          border: AppBorders.ink2,
          boxShadow: [AppShadows.hard3]),
        child: const Icon(Icons.calendar_today_rounded,
          color: Colors.white, size: 18)),
      const SizedBox(width: 14),
      Expanded(child: Column(
        crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('CONNECT CALENDAR',
          style: AppText.title.copyWith(fontSize: 12)),
        const SizedBox(height: 2),
        Text('Get coaching around your upcoming interviews',
          style: AppText.caption),
      ])),
      const SizedBox(width: 10),
      GestureDetector(
        onTap: onConnectTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: const BoxDecoration(
            color: AppColors.blue,
            border: AppBorders.ink2,
            boxShadow: [AppShadows.hard3]),
          child: Text('CONNECT',
            style: AppText.label.copyWith(
              color: Colors.white, fontSize: 8)))),
    ]));

  // ── Loading ───────────────────────────────────────────
  Widget _loading() => Container(
    padding: const EdgeInsets.all(14),
    decoration: AppDecorations.cardSmall,
    child: Row(children: [
      SizedBox(width: 20, height: 20,
        child: const CircularProgressIndicator(
          color: AppColors.blue, strokeWidth: 2)),
      const SizedBox(width: 14),
      Text('LOADING CALENDAR...',
        style: AppText.label.copyWith(color: AppColors.dim)),
    ]));

  // ── Empty ─────────────────────────────────────────────
  Widget _empty() => Container(
    padding: const EdgeInsets.all(14),
    decoration: AppDecorations.cardSmall,
    child: Row(children: [
      const Icon(Icons.event_busy_rounded,
        color: AppColors.dim, size: 24),
      const SizedBox(width: 12),
      Expanded(child: Column(
        crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('NO UPCOMING INTERVIEWS',
          style: AppText.title.copyWith(fontSize: 11)),
        const SizedBox(height: 2),
        Text('Practice with general questions to stay sharp!',
          style: AppText.caption),
      ])),
      if (onRefreshTap != null)
        GestureDetector(
          onTap: onRefreshTap,
          child: Container(
            width: 32, height: 32,
            decoration: const BoxDecoration(
              color: AppColors.cream, border: AppBorders.ink2),
            child: const Icon(Icons.refresh_rounded,
              color: AppColors.dim, size: 16))),
    ]));

  // ── Event list ────────────────────────────────────────
  Widget _list() {
    final interviews = events.where((e) => e.isInterview).toList();
    if (interviews.isEmpty) return _empty();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
      Row(children: [
        AppWidgets.sectionLabel(
          'UPCOMING INTERVIEWS', accent: AppColors.red),
        const Spacer(),
        if (onRefreshTap != null)
          GestureDetector(
            onTap: onRefreshTap,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 8, vertical: 4),
              decoration: const BoxDecoration(
                color: AppColors.cream,
                border: Border.fromBorderSide(
                  BorderSide(color: AppColors.mist, width: 1.5))),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.refresh_rounded,
                  color: AppColors.dim, size: 12),
                const SizedBox(width: 4),
                Text('REFRESH', style: AppText.label.copyWith(
                  color: AppColors.dim, fontSize: 7)),
              ]))),
      ]),
      const SizedBox(height: 10),
      ...interviews.take(3).map((e) => _eventCard(e)),
      if (interviews.length > 3)
        Container(
          margin: const EdgeInsets.only(top: 8),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.cream,
            border: Border.all(color: AppColors.mist, width: 1.5)),
          child: Center(child: Text(
            '+${interviews.length - 3} MORE INTERVIEWS',
            style: AppText.label.copyWith(color: AppColors.dim)))),
    ]);
  }

  Widget _eventCard(CalendarEvent event) {
    final isToday = event.isToday;
    final isSoon  = event.startTime.difference(DateTime.now()).inHours < 2;
    final accent  = isToday ? AppColors.amber
                 : isSoon  ? AppColors.red
                 : AppColors.blue;
    return GestureDetector(
      onTap: () => onEventTap?.call(event),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: AppColors.white,
          border: Border.all(
            color: isToday || isSoon ? accent : AppColors.mist,
            width: isToday || isSoon ? 2 : 1.5),
          boxShadow: isToday || isSoon
            ? [AppShadows.colored(accent)]
            : const [AppShadows.hard3]),
        child: Row(children: [
          // Date block
          Container(width: 56, height: 64,
            color: accent,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center, children: [
            Text('${event.startTime.day}',
              style: AppText.headline.copyWith(
                color: accent == AppColors.amber
                  ? AppColors.ink : Colors.white,
                fontSize: 20)),
            Text(_monthName(event.startTime.month),
              style: AppText.label.copyWith(
                color: accent == AppColors.amber
                  ? AppColors.inkAt(0.7) : Colors.white.withOpacity(0.8),
                fontSize: 8)),
          ])),
          const SizedBox(width: 12),
          // Info
          Expanded(child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(child: Text(event.title,
                  style: AppText.title.copyWith(fontSize: 12),
                  maxLines: 1, overflow: TextOverflow.ellipsis)),
                if (isToday || isSoon)
                  AppWidgets.badge(
                    isToday ? 'TODAY' : 'SOON',
                    bg: accent,
                    fg: accent == AppColors.amber
                      ? AppColors.ink : Colors.white),
              ]),
              const SizedBox(height: 3),
              Text(_formatTime(event),
                style: AppText.caption),
              if (event.location.isNotEmpty) ...[
                const SizedBox(height: 2),
                Row(children: [
                  const Icon(Icons.location_on_rounded,
                    size: 10, color: AppColors.dim),
                  const SizedBox(width: 4),
                  Expanded(child: Text(event.location,
                    style: AppText.caption, maxLines: 1,
                    overflow: TextOverflow.ellipsis)),
                ]),
              ],
            ]))),
          // Prep arrow
          Container(width: 36, height: 64,
            color: accent,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.psychology_rounded,
              color: accent == AppColors.amber
                ? AppColors.ink : Colors.white,
              size: 16),
            const SizedBox(height: 3),
            Text('PREP',
              style: AppText.label.copyWith(
                color: accent == AppColors.amber
                  ? AppColors.ink : Colors.white,
                fontSize: 7)),
          ])),
        ])));
  }

  String _formatTime(CalendarEvent e) {
    final now  = DateTime.now();
    final diff = e.startTime.difference(now);
    if (e.isToday) {
      if (diff.inHours < 1) return 'In ${diff.inMinutes} min  •  ${_time(e.startTime)}';
      return 'Today  •  ${_time(e.startTime)}';
    }
    if (diff.inDays == 1) return 'Tomorrow  •  ${_time(e.startTime)}';
    if (diff.inDays < 7)  return '${_dayName(e.startTime.weekday)}  •  ${_time(e.startTime)}';
    return '${e.startTime.day}/${e.startTime.month}  •  ${_time(e.startTime)}';
  }

  String _time(DateTime d) {
    final h  = d.hour > 12 ? d.hour - 12 : (d.hour == 0 ? 12 : d.hour);
    final m  = d.minute.toString().padLeft(2, '0');
    final ap = d.hour >= 12 ? 'PM' : 'AM';
    return '$h:$m $ap';
  }

  String _dayName(int w) =>
    const ['Mon','Tue','Wed','Thu','Fri','Sat','Sun'][w - 1];

  String _monthName(int m) =>
    const ['JAN','FEB','MAR','APR','MAY','JUN',
           'JUL','AUG','SEP','OCT','NOV','DEC'][m - 1];
}
