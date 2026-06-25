import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'app_theme.dart';
import 'progress_service.dart';

class ProgressScreen extends StatefulWidget {
  final List<CameraDescription> cameras;
  const ProgressScreen({super.key, required this.cameras});
  @override
  State<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends State<ProgressScreen> {
  Map<String, dynamic>? _stats;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final stats = await ProgressService.getStats();
    if (mounted) setState(() { _stats = stats; _loading = false; });
  }

  String get _userName {
    final u = FirebaseAuth.instance.currentUser;
    if (u == null) return 'CANDIDATE';
    final name = u.displayName ?? u.email ?? '';
    return name.split(' ').first.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.cream,
      body: SafeArea(child: Column(children: [

        // Header
        Container(
          color: AppColors.ink,
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
          child: Row(children: [
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                width: 38, height: 38,
                decoration: const BoxDecoration(
                  color: AppColors.white, border: AppBorders.ink2,
                  boxShadow: [AppShadows.hard3]),
                child: const Icon(Icons.arrow_back_rounded,
                  color: AppColors.ink, size: 18))),
            const SizedBox(width: 14),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('MY PROGRESS',
                style: AppText.title.copyWith(
                  color: Colors.white, letterSpacing: 2)),
              Text('Hello, $_userName',
                style: AppText.caption.copyWith(color: AppColors.amber)),
            ])),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: AppColors.amber,
                border: Border.all(color: AppColors.white, width: 1.5)),
              child: Text('STATS',
                style: AppText.label.copyWith(
                  color: AppColors.ink, fontSize: 8))),
          ])),

        Expanded(child: _loading
          ? const Center(child: CircularProgressIndicator(
              color: AppColors.blue, strokeWidth: 2))
          : _stats == null || (_stats!['total'] as int) == 0
          ? _emptyState()
          : _dashboard()),
      ])));
  }

  Widget _emptyState() => Padding(
    padding: const EdgeInsets.all(32),
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
      Container(width: 72, height: 72,
        decoration: const BoxDecoration(
          color: AppColors.white, border: AppBorders.ink2,
          boxShadow: [AppShadows.hard4]),
        child: const Icon(Icons.bar_chart_rounded,
          color: AppColors.dim, size: 36)),
      const SizedBox(height: 20),
      Text('NO SESSIONS YET', style: AppText.title),
      const SizedBox(height: 8),
      Text('Complete your first video interview\nto start tracking progress.',
        style: AppText.caption.copyWith(height: 1.5),
        textAlign: TextAlign.center),
    ]));

  Widget _dashboard() {
    final s        = _stats!;
    final total    = s['total']    as int;
    final avgConf  = (s['avgConf'] as double);
    final best     = (s['best']    as double);
    final trend    = (s['trend']   as List).cast<double>();
    final avgFill  = (s['avgFillers'] as double);
    final sessions = (s['sessions'] as List).cast<Map<String, dynamic>>();

    return RefreshIndicator(
      onRefresh: _load,
      color: AppColors.blue,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(children: [

          // Stats strip
          Row(children: [
            _statCard('$total',          'SESSIONS',    AppColors.blue),
            const SizedBox(width: 10),
            _statCard('${avgConf.round()}%', 'AVG CONF', AppColors.amber),
            const SizedBox(width: 10),
            _statCard('${best.round()}%', 'BEST',       AppColors.red),
          ]),

          const SizedBox(height: 16),

          // Confidence trend
          Container(
            decoration: AppDecorations.card,
            child: Column(children: [
              Container(
                width: double.infinity, color: AppColors.ink,
                padding: const EdgeInsets.all(12),
                child: Row(children: [
                  Container(width: 6, height: 20, color: AppColors.amber),
                  const SizedBox(width: 10),
                  Text('CONFIDENCE TREND',
                    style: AppText.label.copyWith(
                      color: Colors.white, letterSpacing: 1.5)),
                  const Spacer(),
                  Text('LAST ${trend.length} SESSIONS',
                    style: AppText.caption.copyWith(
                      color: AppColors.dim, fontSize: 8)),
                ])),
              Padding(
                padding: const EdgeInsets.all(16),
                child: _trendChart(trend)),
            ])),

          const SizedBox(height: 14),

          // Filler words card
          Container(
            decoration: AppDecorations.cardSmall,
            padding: const EdgeInsets.all(14),
            child: Row(children: [
              Container(width: 44, height: 44,
                decoration: BoxDecoration(
                  color: avgFill > 5 ? AppColors.red : AppColors.blue,
                  border: AppBorders.ink2),
                child: Center(child: Text(avgFill.toStringAsFixed(1),
                  style: AppText.title.copyWith(
                    color: Colors.white, fontSize: 14)))),
              const SizedBox(width: 14),
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('AVG FILLER WORDS PER SESSION',
                  style: AppText.label.copyWith(fontSize: 9)),
                const SizedBox(height: 4),
                Text(
                  avgFill <= 2  ? 'Excellent — very clean speech' :
                  avgFill <= 5  ? 'Good — minor fillers only' :
                  avgFill <= 10 ? 'Fair — focus on reducing um/uh/like' :
                  'Needs work — fillers hurting your score',
                  style: AppText.caption.copyWith(height: 1.4)),
              ])),
            ])),

          const SizedBox(height: 14),

          // Recent sessions
          Container(
            decoration: AppDecorations.card,
            child: Column(children: [
              Container(
                width: double.infinity, color: AppColors.ink,
                padding: const EdgeInsets.all(12),
                child: Row(children: [
                  Container(width: 6, height: 20, color: AppColors.red),
                  const SizedBox(width: 10),
                  Text('RECENT SESSIONS',
                    style: AppText.label.copyWith(
                      color: Colors.white, letterSpacing: 1.5)),
                ])),
              ...sessions.asMap().entries.map((e) =>
                _sessionRow(e.value, e.key == sessions.length - 1)),
            ])),

          const SizedBox(height: 24),
        ])));
  }

  Widget _trendChart(List<double> values) {
    if (values.isEmpty) return const SizedBox(height: 80);
    final max  = values.reduce((a, b) => a > b ? a : b).clamp(1.0, 100.0);
    final min  = values.reduce((a, b) => a < b ? a : b).clamp(0.0, 99.0);
    final range= (max - min).clamp(10.0, 100.0);
    return SizedBox(
      height: 80,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: values.asMap().entries.map((e) {
          final h = ((e.value - min) / range).clamp(0.1, 1.0);
          final isLast = e.key == values.length - 1;
          return Expanded(child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
              if (isLast) Text('${e.value.round()}%',
                style: AppText.caption.copyWith(
                  color: AppColors.blue, fontSize: 8)),
              const SizedBox(height: 2),
              Container(
                height: (h * 60).clamp(4.0, 60.0),
                decoration: BoxDecoration(
                  color: isLast ? AppColors.blue
                    : e.value >= values[0] ? AppColors.amber
                    : AppColors.dim.withOpacity(0.3),
                  border: Border.all(color: AppColors.ink, width: 1))),
            ])));
        }).toList()));
  }

  Widget _statCard(String val, String label, Color color) =>
    Expanded(child: Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.white,
        border: AppBorders.ink2,
        boxShadow: [AppShadows.colored(color, size: 4)]),
      child: Column(children: [
        Container(width: 8, height: 8, color: color),
        const SizedBox(height: 8),
        Text(val, style: AppText.title.copyWith(fontSize: 20)),
        const SizedBox(height: 4),
        Text(label, style: AppText.label.copyWith(
          fontSize: 8, color: AppColors.dim)),
      ])));

  Widget _sessionRow(Map<String, dynamic> s, bool isLast) {
    final conf    = (s['overallConfidence'] as num).toDouble();
    final company = s['company'] as String? ?? '';
    final title   = s['jobTitle'] as String? ?? '';
    final ts      = s['timestamp'] as dynamic;
    String dateStr = '';
    if (ts != null) {
      try {
        final dt = (ts as dynamic).toDate() as DateTime;
        dateStr = '${dt.day}/${dt.month}/${dt.year}';
      } catch (_) {}
    }
    final confColor = conf >= 75 ? AppColors.blue
      : conf >= 55 ? AppColors.amber : AppColors.red;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: isLast ? null : Border(
          bottom: BorderSide(color: AppColors.mist, width: 1))),
      child: Row(children: [
        Container(width: 40, height: 40,
          decoration: BoxDecoration(
            color: confColor, border: AppBorders.ink2),
          child: Center(child: Text('${conf.round()}%',
            style: AppText.label.copyWith(
              color: Colors.white, fontSize: 9)))),
        const SizedBox(width: 12),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(company.toUpperCase(),
            style: AppText.label.copyWith(fontSize: 10),
            maxLines: 1, overflow: TextOverflow.ellipsis),
          Text(title,
            style: AppText.caption.copyWith(fontSize: 10),
            maxLines: 1, overflow: TextOverflow.ellipsis),
        ])),
        Text(dateStr,
          style: AppText.caption.copyWith(fontSize: 9, color: AppColors.dim)),
      ]));
  }
}

