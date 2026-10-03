import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'app_theme.dart';
import 'cv_build_flow_screen.dart';
import 'ats_cv_builder_screen.dart';

/// Opens from "ATS CV BUILDER" on the menu. One question, two big answers.
///  - YES     -> Revamp (upload + AI rewrite) - premium
///  - NOT YET -> Build (step-by-step form, PDF) - free for now
class CvBuilderChoiceScreen extends StatelessWidget {
  final List<CameraDescription> cameras;
  const CvBuilderChoiceScreen({super.key, required this.cameras});

  void _open(BuildContext context, Widget screen) =>
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.cream,
      body: Column(children: [
        AppWidgets.header(
          title: 'CV BUILDER',
          context: context,
          leading: AppWidgets.backButton(context),
          accentColor: AppColors.amber),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 28, 20, 32),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Text('Do you have\na CV?',
                style: AppText.headline.copyWith(fontSize: 34, height: 1.05)),
              const SizedBox(height: 28),

              _Answer(
                dark: true,
                answer: 'YES',
                action: 'Revamp it',
                dream: 'From overlooked to shortlisted.',
                detail: "Upload your CV and we'll rewrite it so recruiters' "
                    'screening systems actually pick it up.',
                tag: 'PREMIUM',
                onTap: () => _open(context, ATSCVBuilderScreen(cameras: cameras)),
              ),
              const SizedBox(height: 16),
              _Answer(
                dark: false,
                answer: 'NOT YET',
                action: 'Build one',
                dream: 'Every dream job starts with one page.',
                detail: 'Fill in your details step by step and get a clean PDF.',
                tag: 'FREE',
                onTap: () => _open(context, CvBuildFlowScreen(cameras: cameras)),
              ),
            ]),
          ),
        ),
      ]),
    );
  }
}

/// A big typographic answer block. The whole block is the button.
class _Answer extends StatefulWidget {
  final bool dark;
  final String answer;
  final String action;
  final String dream;
  final String detail;
  final String tag;
  final VoidCallback onTap;

  const _Answer({
    required this.dark,
    required this.answer,
    required this.action,
    required this.dream,
    required this.detail,
    required this.tag,
    required this.onTap,
  });

  @override
  State<_Answer> createState() => _AnswerState();
}

class _AnswerState extends State<_Answer> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final bg     = widget.dark ? AppColors.ink : AppColors.white;
    final big    = widget.dark ? AppColors.amber : AppColors.ink;
    final strong = widget.dark ? Colors.white : AppColors.ink;
    final soft   = widget.dark ? Colors.white70 : AppColors.dim;
    final tagFg  = widget.dark ? AppColors.amber : AppColors.blue;
    final dreamFg = widget.dark ? AppColors.amber : AppColors.blue;

    return Semantics(
      button: true,
      label: '${widget.answer}. ${widget.dream} ${widget.action}. ${widget.tag}',
      child: GestureDetector(
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) => setState(() => _pressed = false),
        onTapCancel: () => setState(() => _pressed = false),
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 90),
          transform: Matrix4.translationValues(_pressed ? 4 : 0, _pressed ? 4 : 0, 0),
          padding: const EdgeInsets.fromLTRB(20, 18, 18, 18),
          decoration: BoxDecoration(
            color: bg,
            border: AppBorders.ink2,
            boxShadow: _pressed ? const <BoxShadow>[] : const [AppShadows.hard5]),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(widget.answer,
                  style: AppText.display.copyWith(fontSize: 52, color: big, height: 1)))),
              const SizedBox(width: 12),
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(widget.tag,
                  style: AppText.label.copyWith(color: tagFg, fontSize: 10, letterSpacing: 1.8))),
            ]),
            const SizedBox(height: 10),
            Text(widget.dream,
              style: AppText.body.copyWith(
                fontSize: 16, fontWeight: FontWeight.w700, color: dreamFg, height: 1.3)),
            const SizedBox(height: 14),
            Text(widget.action,
              style: AppText.title.copyWith(fontSize: 20, color: strong)),
            const SizedBox(height: 6),
            Text(widget.detail,
              style: AppText.body.copyWith(color: soft, height: 1.4)),
          ]),
        ),
      ),
    );
  }
}
