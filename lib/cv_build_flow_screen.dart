import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app_theme.dart';
import 'ats_cv_builder_screen.dart';
import 'analytics_service.dart';

/// Free "Build your CV" flow for people who don't have a CV yet.
/// Six short steps, saved automatically on the phone, then 4 CV designs.
/// No AI: the professional summary is written from the traits they pick.
class CvBuildFlowScreen extends StatefulWidget {
  final List<CameraDescription> cameras;
  const CvBuildFlowScreen({super.key, required this.cameras});

  @override
  State<CvBuildFlowScreen> createState() => _CvBuildFlowScreenState();
}

// ── Data ───────────────────────────────────────────────────────────

class _ExpEntry {
  String type;
  final TextEditingController title;
  final TextEditingController company;
  final TextEditingController duration;
  final TextEditingController duties;

  _ExpEntry({this.type = 'Job', String t = '', String c = '', String d = '', String du = ''})
      : title = TextEditingController(text: t),
        company = TextEditingController(text: c),
        duration = TextEditingController(text: d),
        duties = TextEditingController(text: du);

  bool get isFilled => title.text.trim().isNotEmpty || company.text.trim().isNotEmpty;

  Map<String, dynamic> toJson() => {
        'type': type,
        'title': title.text,
        'company': company.text,
        'duration': duration.text,
        'duties': duties.text,
      };

  static _ExpEntry fromJson(Map<String, dynamic> j) => _ExpEntry(
        type: (j['type'] ?? 'Job').toString(),
        t: (j['title'] ?? '').toString(),
        c: (j['company'] ?? '').toString(),
        d: (j['duration'] ?? '').toString(),
        du: (j['duties'] ?? '').toString(),
      );

  void dispose() {
    title.dispose();
    company.dispose();
    duration.dispose();
    duties.dispose();
  }
}

class _EduEntry {
  final TextEditingController qualification;
  final TextEditingController school;
  final TextEditingController year;

  _EduEntry({String q = '', String s = '', String y = ''})
      : qualification = TextEditingController(text: q),
        school = TextEditingController(text: s),
        year = TextEditingController(text: y);

  bool get isFilled => qualification.text.trim().isNotEmpty;

  Map<String, dynamic> toJson() => {
        'qualification': qualification.text,
        'school': school.text,
        'year': year.text,
      };

  static _EduEntry fromJson(Map<String, dynamic> j) => _EduEntry(
        q: (j['qualification'] ?? '').toString(),
        s: (j['school'] ?? '').toString(),
        y: (j['year'] ?? '').toString(),
      );

  void dispose() {
    qualification.dispose();
    school.dispose();
    year.dispose();
  }
}

/// A trait the person can pick, with the words used to build the summary.
class _Trait {
  final String label;   // shown on the chip
  final String adj;     // "reliable"
  final String phrase;  // "showing up and delivering, every time"
  const _Trait(this.label, this.adj, this.phrase);
}

const List<_Trait> _traits = [
  _Trait('Reliable', 'reliable', 'showing up and delivering, every time'),
  _Trait('Hard-working', 'hard-working', 'putting in the effort to do the job properly'),
  _Trait('Team player', 'team-oriented', 'working well with others towards shared goals'),
  _Trait('Fast learner', 'quick-learning', 'picking up new skills and systems quickly'),
  _Trait('Good communicator', 'articulate', 'communicating clearly with colleagues and customers'),
  _Trait('Problem solver', 'resourceful', 'finding practical solutions to challenges'),
  _Trait('Organised', 'organised', 'managing time and tasks efficiently'),
  _Trait('Leader', 'proactive', 'taking initiative and guiding others'),
  _Trait('Customer-focused', 'customer-focused', 'giving people a friendly, helpful experience'),
  _Trait('Adaptable', 'adaptable', 'staying flexible when things change'),
  _Trait('Detail-oriented', 'detail-oriented', 'producing careful, accurate work'),
  _Trait('Creative', 'creative', 'bringing fresh ideas to the table'),
  _Trait('Self-motivated', 'self-motivated', 'working independently with little supervision'),
  _Trait('Honest', 'honest', 'acting with integrity and earning trust'),
  _Trait('Calm under pressure', 'composed', 'staying calm and focused under pressure'),
  _Trait('Positive', 'positive', 'bringing energy and a can-do attitude'),
];

const List<String> _statuses = ['Student', 'Recent graduate', 'Some work experience', 'Experienced'];
const List<String> _expTypes = ['Job', 'Internship', 'Volunteer', 'Project'];
const List<String> _verbs = ['Served', 'Managed', 'Assisted', 'Organised', 'Handled', 'Led', 'Built', 'Improved', 'Supported', 'Trained'];
const List<String> _qualQuick = ['Matric (NSC)', 'Higher Certificate', 'Diploma', 'Degree', 'Short course'];
const List<String> _skillSuggestions = [
  'Microsoft Office', 'Excel', 'Customer service', 'Communication', 'Time management',
  'Data capturing', 'Cash handling', 'Sales', 'Admin', 'Social media',
  'Problem solving', 'Teamwork', 'Typing', "Driver's licence (Code 10)",
];
const List<String> _saLanguages = [
  'English', 'isiZulu', 'isiXhosa', 'Afrikaans', 'Sesotho', 'Setswana',
  'Sepedi', 'Xitsonga', 'Tshivenda', 'siSwati', 'isiNdebele',
];

const List<String> _stepNames = ['About you', 'Who you are', 'Experience', 'Education', 'Skills', 'Review'];

// ── Screen ─────────────────────────────────────────────────────────

class _CvBuildFlowScreenState extends State<CvBuildFlowScreen> {
  static const _prefsKey = 'cv_build_flow_v1';

  int _step = 0;
  String? _error;
  bool _loaded = false;
  Timer? _saveTimer;

  // Step 1
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  final _location = TextEditingController();
  final _linkedin = TextEditingController();

  // Step 2
  final _role = TextEditingController();
  final _summary = TextEditingController();
  String? _status;
  final List<String> _picked = [];
  int _variant = 0;
  bool _summaryEdited = false;
  bool _settingSummary = false;

  // Step 3
  final List<_ExpEntry> _exps = [];
  bool _noExperience = false;

  // Step 4
  final List<_EduEntry> _edus = [];

  // Step 5
  final List<String> _skills = [];
  final _skillInput = TextEditingController();
  final Set<String> _langs = {'English'};

  @override
  void initState() {
    super.initState();
    for (final c in [_name, _phone, _email, _location, _linkedin, _role]) {
      c.addListener(_onChanged);
    }
    _role.addListener(_refreshSummary);
    _summary.addListener(() {
      if (!_settingSummary) _summaryEdited = true;
      _onChanged();
    });
    _load();
  }

  @override
  void dispose() {
    _saveTimer?.cancel();
    _save();
    for (final c in [_name, _phone, _email, _location, _linkedin, _role, _summary, _skillInput]) {
      c.dispose();
    }
    for (final e in _exps) { e.dispose(); }
    for (final e in _edus) { e.dispose(); }
    super.dispose();
  }

  // ── Saving ──

  void _onChanged() {
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 600), _save);
  }

  void _watchExp(_ExpEntry e) {
    for (final c in [e.title, e.company, e.duration, e.duties]) {
      c.addListener(_onChanged);
    }
  }

  void _watchEdu(_EduEntry e) {
    for (final c in [e.qualification, e.school, e.year]) {
      c.addListener(_onChanged);
    }
  }

  Future<void> _save() async {
    if (!_loaded) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsKey, jsonEncode({
        'step': _step,
        'name': _name.text, 'phone': _phone.text, 'email': _email.text,
        'location': _location.text, 'linkedin': _linkedin.text,
        'role': _role.text, 'summary': _summary.text, 'status': _status,
        'picked': _picked, 'variant': _variant, 'summaryEdited': _summaryEdited,
        'exps': _exps.map((e) => e.toJson()).toList(),
        'noExperience': _noExperience,
        'edus': _edus.map((e) => e.toJson()).toList(),
        'skills': _skills, 'langs': _langs.toList(),
      }));
    } catch (_) {}
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefsKey);
      if (raw != null && raw.isNotEmpty) {
        final j = jsonDecode(raw) as Map<String, dynamic>;
        _name.text = (j['name'] ?? '').toString();
        _phone.text = (j['phone'] ?? '').toString();
        _email.text = (j['email'] ?? '').toString();
        _location.text = (j['location'] ?? '').toString();
        _linkedin.text = (j['linkedin'] ?? '').toString();
        _role.text = (j['role'] ?? '').toString();
        _status = j['status'] as String?;
        _picked..clear()..addAll(((j['picked'] ?? []) as List).map((e) => e.toString()));
        _variant = (j['variant'] as num?)?.toInt() ?? 0;
        _settingSummary = true;
        _summary.text = (j['summary'] ?? '').toString();
        _settingSummary = false;
        _summaryEdited = j['summaryEdited'] == true;
        for (final e in ((j['exps'] ?? []) as List)) {
          final x = _ExpEntry.fromJson(Map<String, dynamic>.from(e as Map));
          _watchExp(x);
          _exps.add(x);
        }
        _noExperience = j['noExperience'] == true;
        for (final e in ((j['edus'] ?? []) as List)) {
          final x = _EduEntry.fromJson(Map<String, dynamic>.from(e as Map));
          _watchEdu(x);
          _edus.add(x);
        }
        _skills..clear()..addAll(((j['skills'] ?? []) as List).map((e) => e.toString()));
        final langs = ((j['langs'] ?? []) as List).map((e) => e.toString());
        if (langs.isNotEmpty) { _langs..clear()..addAll(langs); }
        _step = ((j['step'] as num?)?.toInt() ?? 0).clamp(0, _stepNames.length - 1);
      }
    } catch (_) {}
    if (_exps.isEmpty) { final e = _ExpEntry(); _watchExp(e); _exps.add(e); }
    if (_edus.isEmpty) { final e = _EduEntry(); _watchEdu(e); _edus.add(e); }
    if (mounted) setState(() => _loaded = true);
  }

  // ── Summary (no AI) ──

  String _buildSummary() {
    final picked = _traits.where((t) => _picked.contains(t.label)).toList();
    if (picked.length < 3) return '';
    final role = _role.text.trim();
    final noun = switch (_status) {
      'Student' => 'student',
      'Recent graduate' => 'graduate',
      'Experienced' => 'experienced professional',
      _ => 'professional',
    };
    final seeking = role.isEmpty ? '' : ' looking for an opportunity as a $role';
    String cap(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
    final a = picked.map((t) => t.adj).toList();
    final p = picked.map((t) => t.phrase).toList();
    final last = p.length > 3 ? p[3] : p[2];

    switch (_variant % 3) {
      case 0:
        return '${cap(a[0])} and ${a[1]} $noun$seeking. '
            'Known for ${p[2]} and $last. '
            'Ready to learn, contribute and grow with a forward-thinking team.';
      case 1:
        return '${cap(noun)} who is ${a[0]}, ${a[1]} and ${a[2]}$seeking. '
            'Recognised for ${p[0]} and $last. '
            'Committed to doing quality work and adding value from day one.';
      default:
        return '${cap(a[0])} $noun$seeking, with a ${a[2]} approach to every task. '
            'Strong at ${p[1]} and ${p[2]}. '
            'Eager to bring this attitude to a team and make a real contribution.';
    }
  }

  void _refreshSummary() {
    if (_summaryEdited) return;
    final s = _buildSummary();
    if (s.isEmpty) return;
    _settingSummary = true;
    _summary.text = s;
    _settingSummary = false;
  }

  void _rewriteSummary() {
    setState(() {
      _variant++;
      _summaryEdited = false;
      _refreshSummary();
    });
    _onChanged();
  }

  void _toggleTrait(String label) {
    setState(() {
      _error = null;
      if (_picked.contains(label)) {
        _picked.remove(label);
      } else if (_picked.length >= 5) {
        _error = 'Pick up to 5 traits. Tap one to remove it first.';
        return;
      } else {
        _picked.add(label);
      }
      _refreshSummary();
    });
    _onChanged();
  }

  // ── Navigation ──

  String? _validate(int step) {
    switch (step) {
      case 0:
        if (_name.text.trim().isEmpty) return 'Add your full name to continue.';
        if (_phone.text.trim().isEmpty && _email.text.trim().isEmpty) {
          return 'Add a phone number or email so employers can reach you.';
        }
        if (_email.text.trim().isNotEmpty && !_email.text.contains('@')) {
          return 'That email address doesn\'t look right.';
        }
        return null;
      case 1:
        if (_picked.length < 3) return 'Pick at least 3 traits that describe you.';
        if (_summary.text.trim().isEmpty) return 'Your summary is empty. Tap "Write it differently".';
        return null;
      case 2:
        if (!_noExperience && !_exps.any((e) => e.isFilled)) {
          return 'Add a job, internship, volunteering or project, or tick "I don\'t have work experience yet".';
        }
        return null;
      case 3:
        if (!_edus.any((e) => e.isFilled)) return 'Add at least one qualification, even if it\'s Matric.';
        return null;
      case 4:
        if (_skills.length < 3) return 'Add at least 3 skills. Tap the suggestions to add them fast.';
        return null;
    }
    return null;
  }

  void _next() {
    FocusScope.of(context).unfocus();
    final err = _validate(_step);
    if (err != null) {
      setState(() => _error = err);
      return;
    }
    if (_step == _stepNames.length - 1) {
      _finish();
      return;
    }
    setState(() { _error = null; _step++; });
    _save();
  }

  void _back() {
    FocusScope.of(context).unfocus();
    if (_step == 0) {
      Navigator.of(context).maybePop();
      return;
    }
    setState(() { _error = null; _step--; });
    _save();
  }

  void _goTo(int step) {
    setState(() { _error = null; _step = step; });
  }

  void _finish() {
    List<String> lines(String text) => text
        .split('\n')
        .map((l) => l.trim().replaceFirst(RegExp(r'^[-*\u2022]+\s*'), ''))
        .where((l) => l.isNotEmpty)
        .toList();

    final experience = _noExperience
        ? <Map<String, dynamic>>[]
        : _exps.where((e) => e.isFilled).map((e) {
            final bullets = lines(e.duties.text);
            final title = e.title.text.trim();
            return <String, dynamic>{
              'title': e.type == 'Job' || title.isEmpty ? title : '$title (${e.type})',
              'company': e.company.text.trim(),
              'duration': e.duration.text.trim(),
              'description': e.duties.text.trim(),
              'bullets': bullets,
              'type': e.type,
            };
          }).toList();

    final education = _edus.where((e) => e.isFilled).map((e) => <String, dynamic>{
          'degree': e.qualification.text.trim(),
          'institution': e.school.text.trim(),
          'year': e.year.text.trim(),
        }).toList();

    String headline = _role.text.trim();
    if (headline.isEmpty && experience.isNotEmpty) headline = experience.first['title'] as String;
    if (headline.isEmpty && education.isNotEmpty) headline = education.first['degree'] as String;

    final data = <String, dynamic>{
      'name': _name.text.trim(),
      'headline': headline,
      'email': _email.text.trim(),
      'phone': _phone.text.trim(),
      'location': _location.text.trim(),
      'linkedin': _linkedin.text.trim(),
      'summary': _summary.text.trim(),
      'experience': experience,
      'education': education,
      'skills': List<String>.from(_skills),
      'certifications': <String>[],
      'achievements': <String>[],
      'awards': <String>[],
      'languages': _langs.toList(),
    };
    _save();
    Analytics.cvBuildCompleted();
    Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => ATSCVBuilderScreen(cameras: widget.cameras, buildData: data)));
  }

  // ── UI ──

  @override
  Widget build(BuildContext context) {
    final last = _step == _stepNames.length - 1;
    return PopScope(
      canPop: _step == 0,
      onPopInvoked: (didPop) { if (!didPop) _back(); },
      child: Scaffold(
        backgroundColor: AppColors.cream,
        body: Column(children: [
          AppWidgets.header(
            title: 'BUILD YOUR CV',
            context: context,
            leading: GestureDetector(
              onTap: _back,
              child: AbsorbPointer(child: AppWidgets.backButton(context))),
            accentColor: AppColors.amber),
          _progress(),
          Expanded(
            child: !_loaded
                ? const Center(child: CircularProgressIndicator(color: AppColors.ink))
                : AnimatedSwitcher(
                    duration: const Duration(milliseconds: 220),
                    transitionBuilder: (child, anim) => FadeTransition(
                      opacity: anim,
                      child: SlideTransition(
                        position: Tween<Offset>(begin: const Offset(0.04, 0), end: Offset.zero).animate(anim),
                        child: child)),
                    child: SingleChildScrollView(
                      key: ValueKey(_step),
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
                      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                      child: _stepBody(),
                    ),
                  ),
          ),
          if (_error != null) _errorBar(),
          _bottomBar(last),
        ]),
      ),
    );
  }

  Widget _progress() {
    return Container(
      color: AppColors.white,
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          for (int i = 0; i < _stepNames.length; i++) ...[
            Expanded(child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              height: 6,
              color: i < _step ? AppColors.ink : i == _step ? AppColors.amber : AppColors.mist)),
            if (i < _stepNames.length - 1) const SizedBox(width: 4),
          ],
        ]),
        const SizedBox(height: 8),
        Text('STEP ${_step + 1} OF ${_stepNames.length}  ·  ${_stepNames[_step].toUpperCase()}',
          style: AppText.label.copyWith(color: AppColors.dim, fontSize: 10)),
      ]),
    );
  }

  Widget _errorBar() => Container(
        width: double.infinity,
        color: AppColors.redAt(0.1),
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Icon(Icons.error_outline_rounded, color: AppColors.red, size: 18),
          const SizedBox(width: 8),
          Expanded(child: Text(_error!, style: AppText.body.copyWith(color: AppColors.red, fontSize: 13))),
        ]),
      );

  Widget _bottomBar(bool last) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.white,
        border: Border(top: BorderSide(color: AppColors.ink, width: 2))),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Row(children: [
            if (_step > 0) ...[
              _PressBox(
                onTap: _back,
                color: AppColors.white,
                width: 96,
                child: Text('BACK', style: AppText.label.copyWith(color: AppColors.ink))),
              const SizedBox(width: 12),
            ],
            Expanded(child: _PressBox(
              onTap: _next,
              color: last ? AppColors.red : AppColors.ink,
              child: Text(
                last ? 'CREATE MY 4 CVS' : 'NEXT: ${_stepNames[_step + 1].toUpperCase()}',
                style: AppText.button.copyWith(fontSize: 14)))),
          ]),
        ),
      ),
    );
  }

  Widget _stepBody() {
    switch (_step) {
      case 0: return _aboutStep();
      case 1: return _whoStep();
      case 2: return _experienceStep();
      case 3: return _educationStep();
      case 4: return _skillsStep();
      default: return _reviewStep();
    }
  }

  // ── Step 1 ──
  Widget _aboutStep() => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _title("Let's start with you", 'How employers will contact you.'),
        _field('FULL NAME', _name, hint: 'e.g. Thandi Mokoena', cap: TextCapitalization.words),
        _field('PHONE', _phone, hint: 'e.g. 072 123 4567', keyboard: TextInputType.phone),
        _field('EMAIL', _email, hint: 'e.g. thandi@gmail.com', keyboard: TextInputType.emailAddress),
        _field('WHERE YOU LIVE', _location, hint: 'e.g. Soshanguve, Pretoria', cap: TextCapitalization.words),
        _field('LINKEDIN (OPTIONAL)', _linkedin, hint: 'linkedin.com/in/yourname', keyboard: TextInputType.url),
      ]);

  // ── Step 2 ──
  Widget _whoStep() => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _title('Who are you?', 'Pick what describes you. We\'ll write your summary.'),
        _label('WHERE ARE YOU RIGHT NOW?'),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final s in _statuses)
            _chip(s, _status == s, () {
              setState(() { _status = s; _refreshSummary(); });
              _onChanged();
            }),
        ]),
        const SizedBox(height: 18),
        _field('JOB YOU WANT', _role, hint: 'e.g. Junior Software Developer', cap: TextCapitalization.words),
        Row(children: [
          Expanded(child: _label('PICK 3 TO 5 TRAITS')),
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text('${_picked.length}/5',
              style: AppText.label.copyWith(
                color: _picked.length >= 3 ? AppColors.blue : AppColors.dim, fontSize: 11))),
        ]),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final t in _traits) _chip(t.label, _picked.contains(t.label), () => _toggleTrait(t.label)),
        ]),
        const SizedBox(height: 22),
        Row(children: [
          Expanded(child: _label('YOUR PROFESSIONAL SUMMARY')),
          if (_picked.length >= 3)
            GestureDetector(
              onTap: _rewriteSummary,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(children: [
                  const Icon(Icons.refresh_rounded, size: 16, color: AppColors.blue),
                  const SizedBox(width: 4),
                  Text('Write it differently',
                    style: AppText.body.copyWith(color: AppColors.blue, fontSize: 12, fontWeight: FontWeight.w700)),
                ]))),
        ]),
        if (_picked.length < 3)
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: AppColors.light, border: Border.all(color: AppColors.mist, width: 1.5)),
            child: Text('Pick at least 3 traits above and your summary will appear here.',
              style: AppText.body.copyWith(color: AppColors.dim, fontSize: 13)))
        else ...[
          _input(_summary, maxLines: 6, hint: ''),
          const SizedBox(height: 6),
          Text('You can edit this however you like.',
            style: AppText.caption.copyWith(fontSize: 11)),
        ],
      ]);

  // ── Step 3 ──
  Widget _experienceStep() => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _title('Your experience', 'Jobs, internships, volunteering or projects all count.'),
        GestureDetector(
          onTap: () {
            setState(() { _noExperience = !_noExperience; _error = null; });
            _onChanged();
          },
          child: Row(children: [
            Container(
              width: 24, height: 24,
              decoration: BoxDecoration(
                color: _noExperience ? AppColors.ink : AppColors.white,
                border: AppBorders.ink2),
              child: _noExperience ? const Icon(Icons.check_rounded, color: Colors.white, size: 16) : null),
            const SizedBox(width: 10),
            Expanded(child: Text("I don't have work experience yet",
              style: AppText.body.copyWith(fontWeight: FontWeight.w700))),
          ])),
        const SizedBox(height: 16),
        if (_noExperience)
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: AppColors.amberAt(0.14), border: AppBorders.ink2),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text("That's okay.", style: AppText.title.copyWith(fontSize: 15)),
              const SizedBox(height: 4),
              Text('A school or varsity project, volunteering or helping in a family business '
                  'shows employers what you can do. Add one if you can.',
                style: AppText.body.copyWith(fontSize: 13, height: 1.4)),
              const SizedBox(height: 10),
              _smallButton('ADD A PROJECT OR VOLUNTEERING', Icons.add_rounded, () {
                setState(() {
                  _noExperience = false;
                  final e = _ExpEntry(type: 'Project');
                  _watchExp(e);
                  if (_exps.length == 1 && !_exps.first.isFilled) {
                    _exps.first.dispose();
                    _exps[0] = e;
                  } else {
                    _exps.add(e);
                  }
                });
                _onChanged();
              }),
            ]))
        else ...[
          for (int i = 0; i < _exps.length; i++) ...[
            _expCard(i),
            const SizedBox(height: 14),
          ],
          _smallButton('ADD ANOTHER', Icons.add_rounded, () {
            setState(() { final e = _ExpEntry(); _watchExp(e); _exps.add(e); });
            _onChanged();
          }),
        ],
      ]);

  Widget _expCard(int i) {
    final e = _exps[i];
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: const BoxDecoration(color: AppColors.white, border: AppBorders.ink2, boxShadow: [AppShadows.hard3]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Expanded(child: Wrap(spacing: 6, runSpacing: 6, children: [
            for (final t in _expTypes)
              _chip(t, e.type == t, () { setState(() => e.type = t); _onChanged(); }, small: true),
          ])),
          if (_exps.length > 1)
            GestureDetector(
              onTap: () {
                setState(() { _exps.removeAt(i).dispose(); });
                _onChanged();
              },
              child: const Padding(
                padding: EdgeInsets.only(left: 8),
                child: Icon(Icons.delete_outline_rounded, color: AppColors.dim, size: 22))),
        ]),
        const SizedBox(height: 14),
        _field(e.type == 'Project' ? 'PROJECT NAME' : 'ROLE / TITLE', e.title,
          hint: e.type == 'Project' ? 'e.g. Final-year app project' : 'e.g. Cashier', cap: TextCapitalization.words),
        _field(e.type == 'Project' ? 'WHERE (OPTIONAL)' : 'COMPANY / ORGANISATION', e.company,
          hint: e.type == 'Project' ? 'e.g. TUT' : 'e.g. Shoprite', cap: TextCapitalization.words),
        _field('WHEN', e.duration, hint: 'e.g. Jan 2024 - Present'),
        _label('WHAT DID YOU DO? (ONE PER LINE)'),
        _input(e.duties, maxLines: 5, hint: 'Served 100+ customers a day\nHandled cash and card payments'),
        const SizedBox(height: 8),
        Text('Tap to start a line:', style: AppText.caption.copyWith(fontSize: 11)),
        const SizedBox(height: 6),
        Wrap(spacing: 6, runSpacing: 6, children: [
          for (final v in _verbs)
            _chip(v, false, () {
              final t = e.duties.text;
              final prefix = t.isEmpty || t.endsWith('\n') ? '' : '\n';
              e.duties.text = '$t$prefix$v ';
              e.duties.selection = TextSelection.collapsed(offset: e.duties.text.length);
            }, small: true),
        ]),
      ]),
    );
  }

  // ── Step 4 ──
  Widget _educationStep() => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _title('Your education', 'Start with your highest qualification. Matric counts.'),
        for (int i = 0; i < _edus.length; i++) ...[
          _eduCard(i),
          const SizedBox(height: 14),
        ],
        _smallButton('ADD ANOTHER', Icons.add_rounded, () {
          setState(() { final e = _EduEntry(); _watchEdu(e); _edus.add(e); });
          _onChanged();
        }),
      ]);

  Widget _eduCard(int i) {
    final e = _edus[i];
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: const BoxDecoration(color: AppColors.white, border: AppBorders.ink2, boxShadow: [AppShadows.hard3]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Expanded(child: Wrap(spacing: 6, runSpacing: 6, children: [
            for (final q in _qualQuick)
              _chip(q, false, () {
                e.qualification.text = q == 'Matric (NSC)' ? q : '$q in ';
                e.qualification.selection = TextSelection.collapsed(offset: e.qualification.text.length);
              }, small: true),
          ])),
          if (_edus.length > 1)
            GestureDetector(
              onTap: () {
                setState(() { _edus.removeAt(i).dispose(); });
                _onChanged();
              },
              child: const Padding(
                padding: EdgeInsets.only(left: 8),
                child: Icon(Icons.delete_outline_rounded, color: AppColors.dim, size: 22))),
        ]),
        const SizedBox(height: 14),
        _field('QUALIFICATION', e.qualification, hint: 'e.g. Diploma in Computer Science', cap: TextCapitalization.words),
        _field('SCHOOL / INSTITUTION', e.school, hint: 'e.g. Tshwane University of Technology', cap: TextCapitalization.words),
        _field('YEAR', e.year, hint: 'e.g. 2025 or In progress', bottom: 0),
      ]),
    );
  }

  // ── Step 5 ──
  void _addSkill(String s) {
    final v = s.trim();
    if (v.isEmpty) return;
    if (_skills.any((x) => x.toLowerCase() == v.toLowerCase())) return;
    setState(() { _skills.add(v); _error = null; });
    _onChanged();
  }

  Widget _skillsStep() => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _title('Your skills', 'Add at least 3. Tap a suggestion to add it.'),
        _label('ADD A SKILL'),
        Row(children: [
          Expanded(child: _input(_skillInput, hint: 'e.g. Python', onSubmitted: (v) {
            _addSkill(v);
            _skillInput.clear();
          })),
          const SizedBox(width: 10),
          _PressBox(
            onTap: () { _addSkill(_skillInput.text); _skillInput.clear(); },
            color: AppColors.ink,
            width: 64,
            child: const Icon(Icons.add_rounded, color: Colors.white)),
        ]),
        const SizedBox(height: 12),
        if (_skills.isNotEmpty)
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final s in _skills)
              GestureDetector(
                onTap: () { setState(() => _skills.remove(s)); _onChanged(); },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                  decoration: const BoxDecoration(color: AppColors.ink, border: AppBorders.ink2),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Text(s, style: AppText.body.copyWith(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700)),
                    const SizedBox(width: 6),
                    const Icon(Icons.close_rounded, color: Colors.white70, size: 14),
                  ]))),
          ]),
        const SizedBox(height: 18),
        _label('SUGGESTIONS'),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final s in _skillSuggestions.where((s) => !_skills.contains(s)))
            _chip('+ $s', false, () => _addSkill(s), small: true),
        ]),
        const SizedBox(height: 24),
        _label('LANGUAGES YOU SPEAK'),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final l in _saLanguages)
            _chip(l, _langs.contains(l), () {
              setState(() { _langs.contains(l) ? _langs.remove(l) : _langs.add(l); });
              _onChanged();
            }, small: true),
        ]),
      ]);

  // ── Step 6 ──
  Widget _reviewStep() {
    final exps = _exps.where((e) => e.isFilled).toList();
    final edus = _edus.where((e) => e.isFilled).toList();
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _title('Looking good', 'Check everything, then we\'ll create 4 CV designs for you.'),
      _reviewBlock('ABOUT YOU', 0, [
        _name.text.trim(),
        [_phone.text.trim(), _email.text.trim()].where((v) => v.isNotEmpty).join('  ·  '),
        _location.text.trim(),
      ]),
      _reviewBlock('SUMMARY', 1, [
        if (_role.text.trim().isNotEmpty) 'Looking for: ${_role.text.trim()}',
        _summary.text.trim(),
      ]),
      _reviewBlock('EXPERIENCE', 2, _noExperience || exps.isEmpty
          ? ['No work experience added']
          : exps.map((e) => [e.title.text.trim(), e.company.text.trim()].where((v) => v.isNotEmpty).join(' at ')).toList()),
      _reviewBlock('EDUCATION', 3, edus.map((e) => [e.qualification.text.trim(), e.school.text.trim()].where((v) => v.isNotEmpty).join(', ')).toList()),
      _reviewBlock('SKILLS & LANGUAGES', 4, [_skills.join(', '), _langs.join(', ')]),
    ]);
  }

  Widget _reviewBlock(String title, int step, List<String> lines) {
    final shown = lines.where((l) => l.trim().isNotEmpty).toList();
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: const BoxDecoration(color: AppColors.white, border: AppBorders.ink2),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(title, style: AppText.label.copyWith(color: AppColors.dim))),
          GestureDetector(
            onTap: () => _goTo(step),
            child: Text('EDIT', style: AppText.label.copyWith(color: AppColors.blue))),
        ]),
        const SizedBox(height: 8),
        for (final l in shown)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(l, style: AppText.body.copyWith(fontSize: 13, height: 1.4))),
      ]),
    );
  }

  // ── Building blocks ──

  Widget _title(String title, String sub) => Padding(
        padding: const EdgeInsets.only(bottom: 20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: AppText.headline.copyWith(fontSize: 26, height: 1.1)),
          const SizedBox(height: 6),
          Text(sub, style: AppText.body.copyWith(color: AppColors.dim)),
        ]),
      );

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(text, style: AppText.label.copyWith(color: AppColors.ink, fontSize: 10.5, letterSpacing: 1.4)),
      );

  Widget _field(String label, TextEditingController c,
      {String hint = '', TextInputType? keyboard, TextCapitalization cap = TextCapitalization.none, double bottom = 16}) {
    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _label(label),
        _input(c, hint: hint, keyboard: keyboard, cap: cap),
      ]),
    );
  }

  Widget _input(TextEditingController c,
      {String hint = '', int maxLines = 1, TextInputType? keyboard,
       TextCapitalization cap = TextCapitalization.sentences, ValueChanged<String>? onSubmitted}) {
    return TextField(
      controller: c,
      maxLines: maxLines,
      minLines: maxLines > 1 ? 3 : 1,
      keyboardType: maxLines > 1 ? TextInputType.multiline : keyboard,
      textCapitalization: cap,
      textInputAction: maxLines > 1 ? TextInputAction.newline : TextInputAction.next,
      onSubmitted: onSubmitted,
      onChanged: (_) { if (_error != null) setState(() => _error = null); },
      style: AppText.body.copyWith(fontSize: 15, color: AppColors.ink),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: AppText.body.copyWith(color: AppColors.dim.withOpacity(0.7), fontSize: 14),
        filled: true,
        fillColor: AppColors.white,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        border: const OutlineInputBorder(
          borderRadius: BorderRadius.zero, borderSide: BorderSide(color: AppColors.ink, width: 2)),
        enabledBorder: const OutlineInputBorder(
          borderRadius: BorderRadius.zero, borderSide: BorderSide(color: AppColors.ink, width: 2)),
        focusedBorder: const OutlineInputBorder(
          borderRadius: BorderRadius.zero, borderSide: BorderSide(color: AppColors.blue, width: 2.5)),
      ),
    );
  }

  Widget _chip(String label, bool selected, VoidCallback onTap, {bool small = false}) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        padding: EdgeInsets.symmetric(horizontal: small ? 10 : 12, vertical: small ? 6 : 9),
        decoration: BoxDecoration(
          color: selected ? AppColors.ink : AppColors.white,
          border: Border.all(color: AppColors.ink, width: selected ? 2 : 1.5),
          boxShadow: selected ? const [AppShadows.hard3] : const <BoxShadow>[]),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (selected) ...[
            const Icon(Icons.check_rounded, size: 14, color: AppColors.amber),
            const SizedBox(width: 5),
          ],
          Text(label, style: AppText.body.copyWith(
            fontSize: small ? 12 : 13.5,
            fontWeight: FontWeight.w700,
            color: selected ? Colors.white : AppColors.ink)),
        ]),
      ),
    );
  }

  Widget _smallButton(String label, IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 46,
        decoration: BoxDecoration(
          color: AppColors.white,
          border: Border.all(color: AppColors.ink, width: 2)),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, size: 18, color: AppColors.ink),
          const SizedBox(width: 6),
          Flexible(child: FittedBox(fit: BoxFit.scaleDown,
            child: Text(label, style: AppText.label.copyWith(color: AppColors.ink)))),
        ]),
      ),
    );
  }
}

/// Button that presses into its hard shadow, like the rest of the app.
class _PressBox extends StatefulWidget {
  final VoidCallback onTap;
  final Color color;
  final Widget child;
  final double? width;
  const _PressBox({required this.onTap, required this.color, required this.child, this.width});

  @override
  State<_PressBox> createState() => _PressBoxState();
}

class _PressBoxState extends State<_PressBox> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _down = true),
      onTapUp: (_) => setState(() => _down = false),
      onTapCancel: () => setState(() => _down = false),
      onTap: widget.onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 80),
        width: widget.width,
        height: 52,
        transform: Matrix4.translationValues(_down ? 3 : 0, _down ? 3 : 0, 0),
        decoration: BoxDecoration(
          color: widget.color,
          border: AppBorders.ink2,
          boxShadow: _down ? const <BoxShadow>[] : const [AppShadows.hard3]),
        child: Center(child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: FittedBox(fit: BoxFit.scaleDown, child: widget.child))),
      ),
    );
  }
}
