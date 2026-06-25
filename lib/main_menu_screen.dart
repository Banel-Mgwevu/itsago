import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import 'app_theme.dart';
import 'remote_config_service.dart';
import 'package:flutter/services.dart';
import 'package:camera/camera.dart';
import 'main.dart';
import 'progress_screen.dart';
import 'cv_library_screen.dart';
import 'setup_screen.dart';
import 'ai_coach_screen.dart';
import 'about_screen.dart';
import 'privacy_rights_screen.dart';
import 'ats_cv_builder_screen.dart';

const Color _ink   = Color(0xFF1A1C2A);
const Color _red   = Color(0xFFCC3B30);
const Color _amber = Color(0xFFE8A200);
const Color _blue  = Color(0xFF1F66B0);
const Color _cream = Color(0xFFEDE8DC);
const Color _mist  = Color(0xFFE6DFD4);
const Color _dim   = Color(0xFF7A7469);

class MainMenuScreen extends StatefulWidget {
  final List<CameraDescription> cameras;
  const MainMenuScreen({super.key, required this.cameras});
  @override
  State<MainMenuScreen> createState() => _MainMenuScreenState();
}

class _MainMenuScreenState extends State<MainMenuScreen>
    with TickerProviderStateMixin {
  late final AnimationController _ac =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 650))..forward();

  @override
  void dispose() { _ac.dispose(); super.dispose(); }

  Animation<double> _fade(double a, double b) => Tween<double>(begin: 0, end: 1)
      .animate(CurvedAnimation(parent: _ac, curve: Interval(a, b, curve: Curves.easeOut)));
  Animation<Offset> _slide(double a, double b) =>
      Tween<Offset>(begin: const Offset(0, 0.04), end: Offset.zero)
          .animate(CurvedAnimation(parent: _ac, curve: Interval(a, b, curve: Curves.easeOut)));

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showWelcomeIfFirst();
      _checkMaintenance();
      _checkAnnouncement();
    });
  }

  Future<void> _showWelcomeIfFirst() async {
    final prefs = await SharedPreferences.getInstance();
    final shown = prefs.getBool('welcome_shown') ?? false;
    if (shown) return;
    await prefs.setBool('welcome_shown', true);
    if (!mounted) return;
    final name = FirebaseAuth.instance.currentUser?.displayName?.split(' ').first ?? 'Champ';
    showDialog(
      context: context,
      barrierDismissible: true,
      barrierColor: AppColors.inkAt(0.6),
      builder: (dlg) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24),
        child: Container(
          decoration: const BoxDecoration(
            color: AppColors.white,
            border: AppBorders.ink3,
            boxShadow: [AppShadows.hard5]),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: double.infinity,
              color: AppColors.ink,
              padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 20),
              child: Row(children: [
                const Text('🇿🇦', style: TextStyle(fontSize: 28)),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('SANIBONANI, $name!',
                    style: AppText.title.copyWith(color: Colors.white, letterSpacing: 1.5)),
                  const SizedBox(height: 2),
                  Text('Welcome to ITSAGO AI',
                    style: AppText.caption.copyWith(color: AppColors.amber)),
                ])),
              ])),
            Padding(padding: const EdgeInsets.all(18),
              child: Column(children: [
                Text(
                  'Lekker to have you here, mfowethu! 💪\nPractice your interviews, fix your CV and walk into your next opportunity sharp sharp.',
                  style: AppText.body.copyWith(height: 1.5),
                  textAlign: TextAlign.center),
                const SizedBox(height: 16),
                GestureDetector(
                  onTap: () => Navigator.pop(dlg),
                  child: Container(
                    width: double.infinity, height: 46,
                    decoration: const BoxDecoration(
                      color: AppColors.ink,
                      border: AppBorders.ink2,
                      boxShadow: [AppShadows.hard3]),
                    child: Center(child: Text('ASIYE — LET\'S GO! 🚀',
                      style: AppText.button.copyWith(letterSpacing: 1.5))))),
              ])),
          ]))));
  }

  Future<void> _checkMaintenance() async {
    if (!RemoteConfigService.maintenanceMode) return;
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => PopScope(
        canPop: false,
        child: Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            decoration: const BoxDecoration(
              color: AppColors.white,
              border: AppBorders.ink3,
              boxShadow: [AppShadows.hard5]),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Container(
                width: double.infinity,
                color: AppColors.amber,
                padding: const EdgeInsets.all(16),
                child: Row(children: [
                  const Icon(Icons.build_rounded, color: AppColors.ink, size: 22),
                  const SizedBox(width: 10),
                  Text('MAINTENANCE MODE',
                    style: AppText.title.copyWith(color: AppColors.ink)),
                ])),
              Padding(padding: const EdgeInsets.all(20),
                child: Text(
                  RemoteConfigService.maintenanceMessage,
                  style: AppText.body.copyWith(height: 1.5),
                  textAlign: TextAlign.center)),
            ])))));  
  }


  Future<void> _checkAnnouncement() async {
    if (!RemoteConfigService.showAnnouncement) return;
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (dlg) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24),
        child: Container(
          decoration: const BoxDecoration(
            color: AppColors.white,
            border: AppBorders.ink3,
            boxShadow: [AppShadows.hard5]),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: double.infinity,
              color: AppColors.blue,
              padding: const EdgeInsets.all(16),
              child: Row(children: [
                const Icon(Icons.campaign_rounded, color: Colors.white, size: 22),
                const SizedBox(width: 10),
                Text('ANNOUNCEMENT',
                  style: AppText.title.copyWith(color: Colors.white)),
              ])),
            Padding(padding: const EdgeInsets.all(20),
              child: Column(children: [
                Text(
                  RemoteConfigService.announcementMessage,
                  style: AppText.body.copyWith(height: 1.5),
                  textAlign: TextAlign.center),
                const SizedBox(height: 16),
                GestureDetector(
                  onTap: () => Navigator.pop(dlg),
                  child: Container(
                    width: double.infinity, height: 46,
                    decoration: const BoxDecoration(
                      color: AppColors.blue,
                      border: AppBorders.ink2,
                      boxShadow: [AppShadows.hard3]),
                    child: Center(child: Text('GOT IT',
                      style: AppText.button)))),
              ])),
          ]))));
  }



  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvoked: (d) { if (!d) _exitDialog(); },
      child: Scaffold(
        backgroundColor: AppColors.cream,
        drawer: _drawer(),
        body: SafeArea(child: AnimatedBuilder(
          animation: _ac,
          builder: (_, __) => Column(children: [
            FadeTransition(opacity: _fade(0.0, 0.4), child: _poster()),
            Expanded(child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
              child: Column(children: [
                FadeTransition(opacity: _fade(0.1, 0.5),
                  child: SlideTransition(position: _slide(0.1, 0.6), child: _eyebrow())),
                const SizedBox(height: 16),
                FadeTransition(opacity: _fade(0.15, 0.55),
                  child: _card(title: 'VIDEO INTERVIEW',
                    sub: 'Practice video interview', accent: _red, badge: '',
                    icon: Icons.video_camera_front_rounded,
                    onTap: () async {
                      if (mounted) _push(SetupScreen(cameras: widget.cameras));
                    })),
                const SizedBox(height: 12),
                FadeTransition(opacity: _fade(0.2, 0.6),
                  child: _card(title: 'ATS CV BUILDER',
                    sub: 'Fix your CV to get noticed', accent: _amber, badge: 'NEW',
                    icon: Icons.auto_fix_high_rounded,
                    onTap: () async {
                      if (mounted) _push(ATSCVBuilderScreen(cameras: widget.cameras));
                    })),
                const SizedBox(height: 12),
                FadeTransition(opacity: _fade(0.25, 0.65),
                  child: _card(title: 'AI COACH',
                    sub: 'Career coaching and tips', accent: _blue, badge: '',
                    icon: Icons.psychology_rounded,
                    onTap: () async {
                      if (mounted) _push(AiCoachScreen(cameras: widget.cameras));
                    })),
                const SizedBox(height: 20),
                FadeTransition(opacity: _fade(0.35, 0.75),
                  child: _grid()),
                const SizedBox(height: 16),
                FadeTransition(opacity: _fade(0.4, 0.8),
                  child: _progressCard()),
                const SizedBox(height: 12),
                FadeTransition(opacity: _fade(0.45, 0.85),
                  child: _cvLibraryTile()),
              ])))])))));
  }

  // ── POSTER ─────────────────────────────────────────────
  Widget _poster() {
    return Container(
      width: double.infinity, height: 230,
      color: _ink,
      child: Stack(children: [
        // Large amber circle — upper right bleed
        Positioned(top: -45, right: -35,
          child: Container(width: 150, height: 150,
            decoration: BoxDecoration(shape: BoxShape.circle,
              color: _amber.withOpacity(0.92),
              border: Border.all(color: _ink, width: 2)))),
        // Smaller red circle
        Positioned(top: 8, right: 18,
          child: Container(width: 42, height: 42,
            decoration: BoxDecoration(shape: BoxShape.circle, color: _red))),
        // Blue vertical strip
        Positioned(right: 0, top: 0, bottom: 0,
          child: Container(width: 7, color: _blue)),
        // Red top rule
        Positioned(left: 0, right: 0, top: 0,
          child: Container(height: 4, color: _red)),
        // Bottom amber bar
        Positioned(left: 0, bottom: 0,
          child: Container(width: 120, height: 5, color: _amber)),
        // ITSAGO AI label
        Positioned(top: 12, left: 70, right: 50,
          child: Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: _amber,
                border: Border.all(color: _ink, width: 1)),
              child: Text('ITSAGO AI', style: TextStyle(
                fontSize: 10, fontWeight: FontWeight.w900,
                color: _ink, letterSpacing: 2))),
            const SizedBox(width: 8),
            Expanded(child: Container(height: 1.5,
              color: Colors.white.withOpacity(0.2))),
          ])),
        // Menu button
        Positioned(top: 10, left: 14,
          child: Builder(builder: (ctx) => GestureDetector(
            onTap: () => Scaffold.of(ctx).openDrawer(),
            child: Container(width: 46, height: 46,
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: _ink, width: 2),
                boxShadow: [BoxShadow(color: _ink, offset: const Offset(3, 3))]),
              child: Icon(Icons.menu_rounded, color: _ink, size: 22))))),
        // Type lockup
        Positioned(left: 20, bottom: 22,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('INTERVIEW', style: TextStyle(
              fontSize: 38, height: 0.95, fontWeight: FontWeight.w900,
              color: Colors.white, letterSpacing: -1)),
            Text('PREP', style: TextStyle(
              fontSize: 38, height: 0.95, fontWeight: FontWeight.w900,
              color: _amber, letterSpacing: -1)),
            const SizedBox(height: 10),
            Row(children: [
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.white.withOpacity(0.5), width: 1.5)),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                child: Text('YOUR CAREER STARTS HERE', style: TextStyle(
                  fontSize: 8, fontWeight: FontWeight.w700,
                  color: Colors.white.withOpacity(0.7), letterSpacing: 2))),
              const SizedBox(width: 8),
              Container(
                decoration: BoxDecoration(
                  color: _red,
                  border: Border.all(color: _ink, width: 1)),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                child: const Text('ZA', style: TextStyle(
                  fontSize: 8, fontWeight: FontWeight.w900,
                  color: Colors.white, letterSpacing: 2))),
            ]),

          ])),
      ]),
    );
  }

  // ── EYEBROW ────────────────────────────────────────────
  Widget _eyebrow() {
    return Row(children: [
      Container(width: 50, height: 50,
        decoration: BoxDecoration(
          color: _amber,
          border: Border.all(color: _ink, width: 2),
          boxShadow: [BoxShadow(color: _ink, offset: const Offset(3, 3))]),
        child: Icon(Icons.home_rounded, color: _ink, size: 24)),
      const SizedBox(width: 14),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('WELCOME BACK', style: TextStyle(
          fontSize: 9, fontWeight: FontWeight.w900,
          color: _dim, letterSpacing: 2.5)),
        const SizedBox(height: 2),
        Text('GET THAT\nJOB', style: TextStyle(
          fontSize: 22, fontWeight: FontWeight.w900,
          color: _ink, letterSpacing: -0.3, height: 1.0)),
      ])),
      Container(width: 5, height: 50, color: _red),
    ]);
  }

  // ── MENU CARD ──────────────────────────────────────────
  Widget _card({
    required String title,
    required String sub,
    required IconData icon,
    required Color accent,
    required String? badge,
    required VoidCallback onTap,
  }) {
    final isAmber = accent == _amber;
    final iconFg  = isAmber ? _ink : Colors.white;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: _ink, width: 2),
          boxShadow: [BoxShadow(color: _ink, offset: const Offset(5, 5), blurRadius: 0)]),
        child: Row(children: [
          SizedBox(width: 86, height: 108,
            child: Stack(children: [
              Positioned.fill(child: Container(color: accent)),
              Positioned(top: 0, right: 0,
                child: Container(width: 22, height: 22,
                  color: isAmber
                    ? Colors.black.withOpacity(0.09)
                    : Colors.white.withOpacity(0.12))),
              Positioned(bottom: 8, left: 8,
                child: Container(width: 8, height: 8,
                  decoration: BoxDecoration(shape: BoxShape.circle,
                    color: isAmber
                      ? Colors.black.withOpacity(0.15)
                      : Colors.white.withOpacity(0.25)))),
              Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(icon, size: 28, color: iconFg),
                const SizedBox(height: 4),
                Container(width: 22, height: 2, color: iconFg.withOpacity(0.4)),
              ])),
              if (badge != null)
                Positioned(top: 0, left: 0,
                  child: Container(
                    color: _ink,
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    child: Text(badge, style: const TextStyle(
                      fontSize: 7, fontWeight: FontWeight.w900,
                      color: Colors.white, letterSpacing: 1.5)))),
            ])),
          Expanded(child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center, children: [
              Text(title, style: TextStyle(
                fontSize: 16, fontWeight: FontWeight.w900,
                color: _ink, letterSpacing: -0.3, height: 1.05)),
              const SizedBox(height: 7),
              Text(sub, style: TextStyle(
                fontSize: 9, fontWeight: FontWeight.w600,
                color: _dim, letterSpacing: 0.4, height: 1.4)),
            ]))),
          Container(width: 34, height: 108,
            color: _ink,
            child: Column(children: [
              Container(height: 5, color: accent),
              Expanded(child: Center(
                child: Text('→', style: const TextStyle(
                  fontSize: 20, color: Colors.white,
                  fontWeight: FontWeight.w900)))),
            ])),
        ]),
      ),
    );
  }

  // ── STAT GRID ──────────────────────────────────────────
  Widget _grid() {
    final items = [
      {'label': 'AI\nPOWERED',    'icon': Icons.psychology_rounded,   'accent': _blue},
      {'label': 'REAL-TIME\nFEEDBACK', 'icon': Icons.bar_chart_rounded, 'accent': _red},
      {'label': 'ATS\nOPTIMISED','icon': Icons.verified_rounded,       'accent': _amber},
    ];
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Container(width: 3, height: 14, color: _red),
        const SizedBox(width: 8),
        Text('PLATFORM FEATURES', style: TextStyle(
          fontSize: 9, fontWeight: FontWeight.w900,
          color: _dim, letterSpacing: 2)),
      ]),
      const SizedBox(height: 10),
      Row(children: List.generate(3, (i) {
        final item   = items[i];
        final accent = item['accent'] as Color;
        final icon   = item['icon']   as IconData;
        final label  = item['label']  as String;
        final isAmb  = accent == _amber;
        return Expanded(child: Row(children: [
          Expanded(child: Container(
            height: 88,
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: _ink, width: 2),
              boxShadow: [BoxShadow(color: _ink,
                offset: const Offset(3, 3), blurRadius: 0)]),
            child: Column(children: [
              Expanded(child: Container(width: double.infinity,
                color: accent,
                child: Icon(icon, size: 20,
                  color: isAmb ? _ink : Colors.white))),
              Container(height: 30, color: Colors.white,
                child: Center(child: Text(label,
                  style: TextStyle(fontSize: 7.5,
                    fontWeight: FontWeight.w900,
                    color: _ink, letterSpacing: 0.5),
                  textAlign: TextAlign.center))),
            ]))),
          if (i < 2) const SizedBox(width: 10),
        ]));
      })),
    ]);
  }

  // ── DRAWER ─────────────────────────────────────────────
  // ── DRAWER ─────────────────────────────────────────────
  Widget _drawer() => Drawer(
    backgroundColor: Colors.white,
    child: Column(children: [
      _drawerHeader(),
      Expanded(child: Column(children: [
        const SizedBox(height: 16),
        _dItem(icon: Icons.video_camera_front_rounded, title: 'PRACTICE INTERVIEW',
          sub: 'Practice video interview', accent: _red,
          onTap: () async {
            Navigator.pop(context);
            if (mounted) _push(SetupScreen(cameras: widget.cameras));
          }),
        const SizedBox(height: 10),
        _dItem(icon: Icons.auto_fix_high_rounded, title: 'ATS CV BUILDER',
          sub: 'Fix your CV - get noticed', accent: _amber, badge: 'NEW',
          onTap: () async {
            Navigator.pop(context);
            if (mounted) _push(ATSCVBuilderScreen(cameras: widget.cameras));
          }),
        const SizedBox(height: 10),
        _dItem(icon: Icons.psychology_rounded, title: 'ASK AI COACH',
          sub: 'Career coaching & advice', accent: _blue,
          onTap: () async {
            Navigator.pop(context);
            if (mounted) _push(AiCoachScreen(cameras: widget.cameras));
          }),
        const SizedBox(height: 10),
        _dItem(icon: Icons.info_outline_rounded, title: 'ABOUT ITSAGO',
          sub: 'About the app', accent: _amber,
          onTap: () { Navigator.pop(context); _push(AboutScreen(cameras: widget.cameras)); }),
        const SizedBox(height: 10),
        _dItem(icon: Icons.shield_rounded, title: 'MY DATA & PRIVACY',
          sub: 'POPIA rights - delete your data', accent: _blue,
          onTap: () { Navigator.pop(context); Navigator.push(context, MaterialPageRoute(builder: (_) => const PrivacyRightsScreen())); }),
        const Spacer(),
        _drawerFooter(),
      ])),
    ]));

  Widget _drawerHeader() => Container(
    width: double.infinity, height: 200, color: _ink,
    child: Stack(children: [
      Positioned(top: -28, right: -28,
        child: Container(width: 110, height: 110,
          decoration: BoxDecoration(shape: BoxShape.circle,
            color: _amber,
            border: Border.all(color: _ink, width: 2)))),
      Positioned(top: 0, left: 0, right: 0,
        child: Container(height: 3, color: _red)),
      Positioned(bottom: 0, left: 0,
        child: Container(width: 80, height: 4, color: _amber)),
      Padding(padding: const EdgeInsets.all(20),
        child: Column(mainAxisAlignment: MainAxisAlignment.end,
          crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(width: 52, height: 52,
            decoration: BoxDecoration(color: Colors.white,
              border: Border.all(color: _ink, width: 2),
              boxShadow: [BoxShadow(color: _ink, offset: const Offset(3, 3))]),
            child: Center(child: Text('IT', style: TextStyle(
              fontSize: 15, fontWeight: FontWeight.w900, color: _ink)))),
          const SizedBox(height: 10),
          const Text('ITSAGO AI', style: TextStyle(
            fontSize: 22, fontWeight: FontWeight.w900,
            color: Colors.white, letterSpacing: 1)),
          Text('INTERVIEW PREP  •  ZA', style: TextStyle(
            fontSize: 9, fontWeight: FontWeight.w700,
            color: _amber, letterSpacing: 1)),
        ])),
    ]));

  Widget _dItem({
    required IconData icon,
    required String title,
    required String sub,
    required Color accent,
    String? badge,
    required VoidCallback onTap,
  }) {
    final isAmb = accent == _amber;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: _ink, width: 2),
            boxShadow: [BoxShadow(color: _ink,
              offset: const Offset(3, 3), blurRadius: 0)]),
          child: Row(children: [
            SizedBox(width: 58, height: 58,
              child: Stack(children: [
                Positioned.fill(child: Container(color: accent)),
                if (badge != null)
                  Positioned(top: 0, right: 0,
                    child: Container(color: _ink,
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                      child: Text(badge, style: const TextStyle(
                        fontSize: 6, fontWeight: FontWeight.w900,
                        color: Colors.white, letterSpacing: 0.5)))),
                Center(child: Icon(icon, size: 22,
                  color: isAmb ? _ink : Colors.white)),
              ])),
            Expanded(child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: TextStyle(fontSize: 12,
                  fontWeight: FontWeight.w900, color: _ink, letterSpacing: 0.3)),
                Text(sub, style: TextStyle(fontSize: 10,
                  color: _dim, fontWeight: FontWeight.w600)),
              ]))),
            Container(width: 24, height: 58, color: _ink,
              child: Center(child: Text('→', style: TextStyle(
                color: Colors.white, fontSize: 14,
                fontWeight: FontWeight.w900)))),
          ]))));
  }

  Widget _drawerFooter() => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(border: Border(top: BorderSide(color: _mist, width: 1.5))),
    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Row(children: [
        Container(width: 11, height: 11, color: _red),
        const SizedBox(width: 3),
        Container(width: 11, height: 11, color: _blue),
        const SizedBox(width: 3),
        Container(width: 11, height: 11, color: _amber),
      ]),
      Text('v1.0.1  •  ITSAGO AI  •  ZA', style: TextStyle(
        fontSize: 8.5, fontWeight: FontWeight.w700,
        color: _dim, letterSpacing: 1)),
    ]));

  void _videoInfoModal() {
    showDialog(context: context, barrierDismissible: true,
      builder: (dlg) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: _ink, width: 2),
            boxShadow: [BoxShadow(color: _ink, offset: const Offset(6,6), blurRadius: 0)]),
          child: Column(mainAxisSize: MainAxisSize.min, children: [

            // Header
            Container(
              width: double.infinity,
              color: _ink,
              child: Column(children: [
                Container(height: 4, color: _red),
                Padding(padding: const EdgeInsets.all(16),
                  child: Row(children: [
                    Container(width: 48, height: 48,
                      decoration: BoxDecoration(
                        color: _red,
                        border: Border.all(color: Colors.white, width: 2),
                        boxShadow: [BoxShadow(color: _red.withOpacity(0.4), offset: const Offset(3,3))]),
                      child: const Icon(Icons.video_camera_front_rounded,
                        color: Colors.white, size: 24)),
                    const SizedBox(width: 14),
                    Expanded(child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('VIDEO INTERVIEW', style: TextStyle(
                        fontSize: 17, fontWeight: FontWeight.w900,
                        color: Colors.white, letterSpacing: 1.5)),
                      Text('PRACTICE MODE', style: TextStyle(
                        fontSize: 10, fontWeight: FontWeight.w700,
                        color: _amber, letterSpacing: 2)),
                    ])),
                  ])),
              ])),

            // What is it
            Padding(padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

                Text('WHAT IS THIS?', style: TextStyle(
                  fontSize: 10, fontWeight: FontWeight.w900,
                  color: _dim, letterSpacing: 2)),
                const SizedBox(height: 8),
                Text('Practise with Lizzy, your AI interviewer. She asks you real questions out loud while the app tracks your confidence and body language — so you are ready when it counts.',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
                    color: _ink, height: 1.5)),



                const SizedBox(height: 16),
                Text('HOW IT WORKS', style: TextStyle(
                  fontSize: 10, fontWeight: FontWeight.w900,
                  color: _dim, letterSpacing: 2)),
                const SizedBox(height: 10),

                _step('1', 'TELL US WHERE YOU ARE APPLYING', 'Enter the company name and paste the job description for questions tailored just for you.', _blue),
                const SizedBox(height: 8),
                _step('2', 'LIZZY INTERVIEWS YOU', '5 questions, one at a time. Lizzy speaks each one aloud — answer naturally, just like the real thing.', _amber),
                const SizedBox(height: 8),
                _step('3', 'ANSWER WITH CONFIDENCE', '20 seconds per answer. Speak naturally — we analyse your words, tone and body language in real time.', _red),
                const SizedBox(height: 8),
                _step('4', 'SEE HOW YOU DID', 'Get your confidence score, personalised tips, and see exactly how to improve before the real interview.', _ink),

                const SizedBox(height: 16),

                // Stats strip
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  color: const Color(0xFFEDE8DC),
                  child: Row(children: [
                    _stat('8', 'QUESTIONS', _blue),
                    Container(width: 1, height: 32, color: _mist),
                    _stat('30s', 'PER ANSWER', _red),
                    Container(width: 1, height: 32, color: _mist),
                    _stat('AI', 'SCORING', _amber),
                    Container(width: 1, height: 32, color: _mist),
                    _stat('LIVE', 'FEEDBACK', _ink),
                  ])),

                const SizedBox(height: 16),
              ])),

            // Actions
            Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Row(children: [
                Expanded(child: GestureDetector(
                  onTap: () => Navigator.pop(dlg),
                  child: Container(
                    height: 48,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: _mist, width: 1.5)),
                    child: Center(child: Text('MAYBE LATER',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900,
                        color: _dim, letterSpacing: 1)))))),
                const SizedBox(width: 12),
                Expanded(flex: 2, child: GestureDetector(
                  onTap: () {
                    Navigator.pop(dlg);
                    _push(SetupScreen(cameras: widget.cameras));
                  },
                  child: Container(
                    height: 48,
                    decoration: BoxDecoration(
                      color: _red,
                      border: Border.all(color: _ink, width: 2),
                      boxShadow: [BoxShadow(color: _ink, offset: const Offset(4,4), blurRadius: 0)]),
                    child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      const Icon(Icons.play_arrow_rounded,
                        color: Colors.white, size: 20),
                      const SizedBox(width: 8),
                      Text('START INTERVIEW',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900,
                          color: Colors.white, letterSpacing: 1.5)),
                    ])))),
              ])),
          ]))));}

  Widget _step(String num, String title, String desc, Color accent) {
    final isAmber = accent == _amber;
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(width: 28, height: 28,
        decoration: BoxDecoration(
          color: accent,
          border: Border.all(color: _ink, width: 1.5)),
        child: Center(child: Text(num, style: TextStyle(
          fontSize: 12, fontWeight: FontWeight.w900,
          color: isAmber ? _ink : Colors.white)))),
      const SizedBox(width: 10),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: TextStyle(
          fontSize: 11, fontWeight: FontWeight.w900, color: _ink, letterSpacing: 0.5)),
        const SizedBox(height: 2),
        Text(desc, style: TextStyle(
          fontSize: 11, fontWeight: FontWeight.w600, color: _dim, height: 1.4)),
      ])),
    ]);}

  Widget _stat(String val, String lbl, Color accent) {
    return Expanded(child: Column(
      mainAxisAlignment: MainAxisAlignment.center, children: [
      Text(val, style: TextStyle(
        fontSize: 14, fontWeight: FontWeight.w900, color: accent)),
      Text(lbl, style: TextStyle(
        fontSize: 7, fontWeight: FontWeight.w900,
        color: _dim, letterSpacing: 0.5)),
    ]));}



  Widget _cvLibraryTile() {
    return GestureDetector(
      onTap: () => _push(const CVLibraryScreen()),
      child: Container(
        width: double.infinity,
        height: 56,
        decoration: BoxDecoration(
          color: AppColors.cream,
          border: AppBorders.ink2,
          boxShadow: [AppShadows.hard3]),
        child: Row(children: [
          Container(width: 6, height: double.infinity,
            color: AppColors.amber),
          const SizedBox(width: 14),
          const Icon(Icons.description_rounded,
            color: AppColors.amber, size: 18),
          const SizedBox(width: 10),
          Expanded(child: Text('MY CVS',
            style: AppText.label.copyWith(fontSize: 11))),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 10, vertical: 6),
            color: AppColors.ink,
            child: const Icon(Icons.arrow_forward_rounded,
              color: Colors.white, size: 14)),
        ])));
  }
  Widget _progressCard() {
    return GestureDetector(
      onTap: () => _push(ProgressScreen(cameras: widget.cameras)),
      child: Container(
        width: double.infinity,
        height: 56,
        decoration: BoxDecoration(
          color: AppColors.cream,
          border: AppBorders.ink2,
          boxShadow: [AppShadows.hard3]),
        child: Row(children: [
          Container(width: 6, height: double.infinity,
            color: AppColors.blue),
          const SizedBox(width: 14),
          const Icon(Icons.bar_chart_rounded,
            color: AppColors.blue, size: 18),
          const SizedBox(width: 10),
          Expanded(child: Text('MY PROGRESS',
            style: AppText.label.copyWith(fontSize: 11))),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 10, vertical: 6),
            color: AppColors.ink,
            child: const Icon(Icons.arrow_forward_rounded,
              color: Colors.white, size: 14)),
        ])));
  }
  void _push(Widget s) => Navigator.of(context).push(PageRouteBuilder(
    pageBuilder: (_, __, ___) => s,
    transitionsBuilder: (_, a, __, child) => SlideTransition(
      position: Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero)
          .animate(CurvedAnimation(parent: a, curve: Curves.easeOut)),
      child: child),
    transitionDuration: const Duration(milliseconds: 380)));

  void _exitDialog() {
    showDialog(context: context, barrierDismissible: false,
      builder: (dlg) => Dialog(backgroundColor: Colors.transparent,
        child: Container(
          decoration: BoxDecoration(color: Colors.white,
            border: Border.all(color: _ink, width: 2),
            boxShadow: [BoxShadow(color: _ink,
              offset: const Offset(6, 6), blurRadius: 0)]),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(width: double.infinity, padding: const EdgeInsets.all(16),
              color: _ink,
              child: Row(children: [
                Container(width: 10, height: 10, color: _red),
                const SizedBox(width: 8),
                const Text('EXIT APP?', style: TextStyle(
                  fontSize: 16, fontWeight: FontWeight.w900,
                  color: Colors.white, letterSpacing: 3)),
              ])),
            Padding(padding: const EdgeInsets.all(20),
              child: Column(children: [
                Text('Are you sure you want to exit ITSAGO AI?',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700,
                    color: _ink), textAlign: TextAlign.center),
                const SizedBox(height: 20),
                Row(children: [
                  Expanded(child: GestureDetector(
                    onTap: () => Navigator.pop(dlg),
                    child: Container(height: 46,
                      decoration: BoxDecoration(color: Colors.white,
                        border: Border.all(color: _ink, width: 2)),
                      child: Center(child: Text('CANCEL', style: TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w900,
                        color: _ink, letterSpacing: 1)))))),
                  const SizedBox(width: 12),
                  Expanded(child: GestureDetector(
                    onTap: () { Navigator.pop(dlg); SystemNavigator.pop(); },
                    child: Container(height: 46,
                      decoration: BoxDecoration(color: _red,
                        border: Border.all(color: _ink, width: 2),
                        boxShadow: [BoxShadow(color: _ink,
                          offset: const Offset(3, 3), blurRadius: 0)]),
                      child: const Center(child: Text('EXIT', style: TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w900,
                        color: Colors.white, letterSpacing: 2)))))),
                ]),
              ])),
          ]))));
  }
}
















