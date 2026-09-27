import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'app_theme.dart';
import 'auth_screen.dart';
import 'sa_data.dart';

/// Sits between purpose selection and auth. Collects a short profile
/// (province, city, employment status, age, education, and - if the
/// person has a Diploma/Degree/Postgrad - their institution and field of
/// study) so question generation and the CV builder can personalise
/// without asking twice. Tapping an answer advances straight to the next
/// question - no separate Next button to tap. Nobody is signed in yet at
/// this point, so answers are held locally and written to Firestore the
/// moment sign-in succeeds (see AuthScreen._completeSignIn).
class ProfileSetupScreen extends StatefulWidget {
  final List<CameraDescription> cameras;
  final String selectedPurpose;
  const ProfileSetupScreen({
    super.key,
    required this.cameras,
    required this.selectedPurpose,
  });

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  final _pageCtrl = PageController();
  int _pageIndex = 0;

  String? _province;
  final _cityCtrl = TextEditingController();
  String? _employmentStatus;
  String? _ageRange;
  String? _educationLevel;
  InstitutionType? _institutionType;
  String? _institution;
  final _fieldOfStudyCtrl = TextEditingController();
  String? _targetIndustry;
  String? _careerGoal;

  bool get _showInstitutionStep =>
      _educationLevel != null && SAData.higherEducationLevels.contains(_educationLevel);

  /// Page order, recomputed each build so the Institution page appears
  /// or disappears immediately as the Education answer changes.
  List<_Page> get _pages => [
    _Page('LOCATION', 'Where are you\nbased?', Icons.location_on_rounded, AppColors.blue,
      _locationPage()),
    _Page('WORK STATUS', 'What\'s your situation\nright now?', Icons.work_rounded, AppColors.red,
      _chips(SAData.employmentStatuses, _employmentStatus,
        (v) => _selectAndAdvance(() => _employmentStatus = v))),
    _Page('AGE', 'How old\nare you?', Icons.cake_rounded, AppColors.amber,
      _chips(SAData.ageRanges, _ageRange,
        (v) => _selectAndAdvance(() => _ageRange = v))),
    _Page('EDUCATION', 'What\'s your highest\nqualification?', Icons.school_rounded, AppColors.blue,
      _chips(SAData.educationLevels, _educationLevel,
        (v) => _selectAndAdvance(() => _educationLevel = v))),
    if (_showInstitutionStep)
      _Page('INSTITUTION', 'Where did\nyou study?', Icons.account_balance_rounded, AppColors.red,
        _institutionPage()),
    _Page('TARGET INDUSTRY', 'What field are\nyou aiming for?', Icons.business_center_rounded, AppColors.amber,
      _chips(SAData.targetIndustries, _targetIndustry,
        (v) => _selectAndAdvance(() => _targetIndustry = v))),
    _Page('GOAL', 'What are you\nworking towards?', Icons.flag_rounded, AppColors.blue,
      _chips(SAData.careerGoals, _careerGoal,
        (v) => _selectAndAdvance(() => _careerGoal = v, isLastAnswer: true))),
  ];

  @override
  void dispose() {
    _pageCtrl.dispose();
    _cityCtrl.dispose();
    _fieldOfStudyCtrl.dispose();
    super.dispose();
  }

  Map<String, dynamic> _buildProfileMap() => {
    if (_province != null)         'province': _province,
    if (_cityCtrl.text.trim().isNotEmpty) 'city': _cityCtrl.text.trim(),
    if (_employmentStatus != null) 'employmentStatus': _employmentStatus,
    if (_ageRange != null)         'ageRange': _ageRange,
    if (_educationLevel != null)   'educationLevel': _educationLevel,
    if (_showInstitutionStep && _institution != null) 'institution': _institution,
    if (_showInstitutionStep && _institutionType != null)
      'institutionType': _institutionType!.name,
    if (_showInstitutionStep && _fieldOfStudyCtrl.text.trim().isNotEmpty)
      'fieldOfStudy': _fieldOfStudyCtrl.text.trim(),
    if (_targetIndustry != null)   'targetIndustry': _targetIndustry,
    if (_careerGoal != null)       'careerGoal': _careerGoal,
    'purpose': widget.selectedPurpose,
  };

  Future<void> _finish({bool skip = false}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('pending_profile_data', jsonEncode(
        skip ? {'purpose': widget.selectedPurpose} : _buildProfileMap()));
    if (!mounted) return;
    Navigator.of(context).push(PageRouteBuilder(
      pageBuilder: (_, __, ___) => AuthScreen(
        cameras: widget.cameras, selectedPurpose: widget.selectedPurpose),
      transitionsBuilder: (_, a, __, child) => SlideTransition(
        position: Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero)
            .animate(CurvedAnimation(parent: a, curve: Curves.easeOut)),
        child: child),
      transitionDuration: const Duration(milliseconds: 500)));
  }

  /// Applies the tapped answer, gives a brief moment to see it highlight,
  /// then moves on - to the next page, or to Auth if this was the last
  /// question. This is what replaces a separate "Next" button.
  void _selectAndAdvance(VoidCallback apply, {bool isLastAnswer = false}) {
    setState(apply);
    Future.delayed(const Duration(milliseconds: 220), () {
      if (!mounted) return;
      if (isLastAnswer) { _finish(); return; }
      final pages = _pages;
      if (_pageIndex < pages.length - 1) {
        _pageCtrl.nextPage(
          duration: const Duration(milliseconds: 320), curve: Curves.easeOut);
      } else {
        _finish();
      }
    });
  }

  void _back() {
    if (_pageIndex > 0) {
      _pageCtrl.previousPage(
        duration: const Duration(milliseconds: 320), curve: Curves.easeOut);
    } else {
      Navigator.of(context).maybePop();
    }
  }

  void _pickInstitutionType(InstitutionType type) {
    setState(() {
      _institutionType = type;
      _institution = null; // reset - previous pick may not be in the new type's list
    });
    _openInstitutionPicker();
  }

  void _openInstitutionPicker() {
    if (_institutionType == null) return;
    final all = SAData.institutionsFor(_institutionType!);
    showModalBottomSheet(context: context, isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _InstitutionSearchSheet(
        institutions: all,
        onSelected: (name) {
          setState(() => _institution = name);
          // Institution picked - that's the meaningful answer on this
          // page, so advance now (field of study can still be filled in
          // on later pages' context or left blank).
          Future.delayed(const Duration(milliseconds: 150), () {
            if (!mounted) return;
            final pages = _pages;
            if (_pageIndex < pages.length - 1) {
              _pageCtrl.nextPage(
                duration: const Duration(milliseconds: 320), curve: Curves.easeOut);
            } else {
              _finish();
            }
          });
        }));
  }

  // ── Reusable pieces ──────────────────────────────────────

  Widget _chips(List<String> options, String? selected, void Function(String) onTap) =>
    Wrap(spacing: 8, runSpacing: 8, children: options.map((o) {
      final sel = o == selected;
      return GestureDetector(
        onTap: () => onTap(o),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: sel ? AppColors.ink : Colors.white,
            border: Border.all(color: AppColors.ink, width: sel ? 2.5 : 1.5),
            boxShadow: sel ? const [AppShadows.hard3] : null),
          child: Text(o, style: TextStyle(
            fontSize: 13, fontWeight: FontWeight.w700,
            color: sel ? Colors.white : AppColors.ink))));
    }).toList());

  Widget _textField(TextEditingController c, String hint) => Container(
    decoration: BoxDecoration(color: Colors.white,
      border: Border.all(color: AppColors.mist, width: 1.5)),
    child: TextField(
      controller: c,
      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.ink),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(fontSize: 13, color: AppColors.dim),
        border: InputBorder.none,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14))));

  // ── Page bodies ──────────────────────────────────────────

  Widget _locationPage() => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    _textField(_cityCtrl, 'City or town (optional)'),
    const SizedBox(height: 16),
    _chips(SAData.provinces, _province,
      (v) => _selectAndAdvance(() => _province = v)),
  ]);

  Widget _institutionPage() => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    _textField(_fieldOfStudyCtrl, 'Field of study (optional, e.g. IT, Business)'),
    const SizedBox(height: 16),
    Row(children: [
      _typeChip('University', InstitutionType.university, Icons.account_balance_rounded),
      const SizedBox(width: 8),
      _typeChip('TVET College', InstitutionType.tvet, Icons.build_rounded),
      const SizedBox(width: 8),
      _typeChip('Private College', InstitutionType.private_, Icons.school_rounded),
    ]),
    if (_institutionType != null) ...[
      const SizedBox(height: 10),
      GestureDetector(
        onTap: _openInstitutionPicker,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(color: Colors.white,
            border: Border.all(color: AppColors.mist, width: 1.5)),
          child: Row(children: [
            Icon(Icons.search_rounded, size: 17, color: AppColors.dim),
            const SizedBox(width: 10),
            Expanded(child: Text(
              _institution ?? 'Search for your institution',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
                color: _institution != null ? AppColors.ink : AppColors.dim))),
            Icon(Icons.chevron_right_rounded, color: AppColors.dim, size: 18),
          ]))),
    ],
  ]);

  Widget _typeChip(String label, InstitutionType type, IconData icon) {
    final sel = _institutionType == type;
    return Expanded(child: GestureDetector(
      onTap: () => _pickInstitutionType(type),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: sel ? AppColors.ink : Colors.white,
          border: Border.all(color: AppColors.ink, width: sel ? 2.5 : 1.5),
          boxShadow: sel ? const [AppShadows.hard3] : null),
        child: Column(children: [
          Icon(icon, size: 20, color: sel ? Colors.white : AppColors.ink),
          const SizedBox(height: 6),
          Text(label, textAlign: TextAlign.center, style: TextStyle(
            fontSize: 10.5, fontWeight: FontWeight.w800,
            color: sel ? Colors.white : AppColors.ink)),
        ]))));
  }

  @override
  Widget build(BuildContext context) {
    final pages = _pages;
    if (_pageIndex > pages.length - 1) _pageIndex = pages.length - 1;

    return Scaffold(
      backgroundColor: AppColors.cream,
      body: SafeArea(child: Stack(children: [

        // Decorative accents - matches the geometric language used on
        // AuthScreen/OnboardingScreen so this doesn't feel like a bare
        // form bolted onto the rest of the app.
        Positioned(top: -40, right: -40,
          child: Container(width: 120, height: 120,
            decoration: BoxDecoration(shape: BoxShape.circle,
              color: AppColors.amber.withOpacity(0.10),
              border: Border.all(color: AppColors.amber.withOpacity(0.2), width: 1.5)))),
        Positioned(bottom: 90, left: -30,
          child: Container(width: 80, height: 60,
            color: AppColors.blue.withOpacity(0.06))),

        Column(children: [
          // Header: back + progress dots + visible skip button
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(children: [
              GestureDetector(
                onTap: _back,
                child: Container(width: 40, height: 40,
                  decoration: BoxDecoration(color: Colors.white,
                    border: Border.all(color: AppColors.ink, width: 1.5)),
                  child: const Icon(Icons.arrow_back_rounded, size: 18, color: AppColors.ink))),
              const SizedBox(width: 12),
              Expanded(child: Row(mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(pages.length, (i) => Container(
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: i == _pageIndex ? 22 : 7, height: 7,
                  decoration: BoxDecoration(
                    color: i <= _pageIndex ? AppColors.ink : AppColors.mist))))),
              const SizedBox(width: 12),
              GestureDetector(
                onTap: () => _finish(skip: true),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(color: Colors.white,
                    border: Border.all(color: AppColors.ink, width: 1.5)),
                  child: Text('SKIP', style: AppText.label.copyWith(
                    color: AppColors.ink, fontSize: 10)))),
            ])),

          Expanded(child: PageView(
            controller: _pageCtrl,
            physics: const NeverScrollableScrollPhysics(),
            onPageChanged: (i) => setState(() => _pageIndex = i),
            children: pages.map((p) => SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

                // Big icon block - gives each page real visual weight
                // instead of just a title floating over empty space.
                Container(width: 64, height: 64,
                  decoration: BoxDecoration(
                    color: p.accent.withOpacity(0.12),
                    border: Border.all(color: p.accent, width: 2)),
                  child: Icon(p.icon, color: p.accent, size: 30)),
                const SizedBox(height: 18),

                AppWidgets.sectionLabel(p.label, accent: p.accent),
                const SizedBox(height: 8),
                Text(p.title, style: AppText.headline),
                const SizedBox(height: 4),
                Text('Tap an answer to continue.',
                  style: AppText.caption.copyWith(color: AppColors.dim)),
                const SizedBox(height: 24),

                p.body,
              ]))).toList())),
        ]),
      ])));
  }
}

class _Page {
  final String label, title;
  final IconData icon;
  final Color accent;
  final Widget body;
  const _Page(this.label, this.title, this.icon, this.accent, this.body);
}

/// Searchable bottom sheet for picking an institution from a (potentially
/// long) list, filtered to whichever type (university/TVET/private) the
/// person selected.
class _InstitutionSearchSheet extends StatefulWidget {
  final List<Institution> institutions;
  final void Function(String) onSelected;
  const _InstitutionSearchSheet({required this.institutions, required this.onSelected});

  @override
  State<_InstitutionSearchSheet> createState() => _InstitutionSearchSheetState();
}

class _InstitutionSearchSheetState extends State<_InstitutionSearchSheet> {
  final _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void dispose() { _searchCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final filtered = _query.isEmpty
      ? widget.institutions
      : widget.institutions.where((i) =>
          i.name.toLowerCase().contains(_query.toLowerCase())).toList();

    return DraggableScrollableSheet(
      initialChildSize: 0.75, minChildSize: 0.5, maxChildSize: 0.92,
      builder: (_, scrollCtrl) => Container(
        decoration: const BoxDecoration(
          color: AppColors.cream,
          border: Border(top: BorderSide(color: AppColors.ink, width: 2))),
        child: Column(children: [
          const SizedBox(height: 10),
          Container(width: 40, height: 4, color: AppColors.mist),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
            child: Container(
              decoration: BoxDecoration(color: Colors.white,
                border: Border.all(color: AppColors.ink, width: 1.5)),
              child: TextField(
                controller: _searchCtrl,
                autofocus: true,
                onChanged: (v) => setState(() => _query = v),
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                decoration: InputDecoration(
                  hintText: 'Search institutions...',
                  prefixIcon: const Icon(Icons.search_rounded, size: 20),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 14)))),
          ),
          Expanded(child: filtered.isEmpty
            ? Center(child: Text('No matches - try a different search',
                style: AppText.caption.copyWith(color: AppColors.dim)))
            : ListView.separated(
                controller: scrollCtrl,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: filtered.length,
                separatorBuilder: (_, __) => const Divider(height: 1, color: AppColors.mist),
                itemBuilder: (_, idx) {
                  final inst = filtered[idx];
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(inst.name, style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.ink)),
                    onTap: () {
                      widget.onSelected(inst.name);
                      Navigator.pop(context);
                    });
                })),
        ])));
  }
}
