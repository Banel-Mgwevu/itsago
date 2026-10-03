import 'dart:async';
import 'package:flutter/material.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'cloud_function_service.dart';
import 'store_config.dart';
import 'analytics_service.dart';
import 'terms_screen.dart';
import 'privacy_policy_detail_screen.dart';
import 'app_theme.dart';
import 'access_service.dart';
import 'subscription_service.dart';

/// Which feature the person tried to use. Only changes the header copy and
/// which perk is highlighted - every feature unlocks with the same plan.
enum PaywallFeature { interview, jobInterview, cvDownload, aiCoach, general }

/// One entry point for every paid feature:
///
///   if (!await Paywall.ensureAccess(context, PaywallFeature.aiCoach)) return;
///
/// Returns true straight away if the person already has access. Otherwise
/// shows the premium modal, whose button opens the Google Play payment
/// sheet directly, and returns true only if they subscribed (or restored).
class Paywall {
  Paywall._();

  static bool _isOpen = false;

  static Future<bool> ensureAccess(
      BuildContext context, PaywallFeature feature) async {
    final bool allowed = (feature == PaywallFeature.interview ||
            feature == PaywallFeature.jobInterview)
        ? await AccessService.canStartInterview()
        : await AccessService.hasFullAccess();
    if (allowed) return true;
    if (!context.mounted) return false;
    return show(context, feature);
  }

  static Future<bool> show(BuildContext context, PaywallFeature feature) async {
    if (_isOpen) return false;
    _isOpen = true;
    Analytics.paywallShown(feature.name);
    try {
      final bool? unlocked = await showGeneralDialog<bool>(
        context: context,
        barrierDismissible: true,
        barrierLabel: 'Close premium',
        barrierColor: AppColors.ink.withOpacity(0.72),
        transitionDuration: const Duration(milliseconds: 360),
        pageBuilder: (_, __, ___) => _PaywallDialog(feature: feature),
        transitionBuilder: (_, anim, __, child) {
          final scale = CurvedAnimation(
              parent: anim, curve: Curves.easeOutBack, reverseCurve: Curves.easeIn);
          return FadeTransition(
            opacity: CurvedAnimation(parent: anim, curve: Curves.easeOut),
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.9, end: 1.0).animate(scale),
              child: child));
        },
      );

      if (unlocked == true && context.mounted) {
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.ink,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.zero,
            side: BorderSide(color: AppColors.amber, width: 2)),
          content: Row(children: [
            const Icon(Icons.workspace_premium_rounded, color: AppColors.amber, size: 20),
            const SizedBox(width: 10),
            Expanded(child: Text("Sharp! Premium is unlocked. Let's get you hired.",
              style: AppText.body.copyWith(color: Colors.white))),
          ]),
        ));
      }
      Analytics.paywallClosed(feature.name, unlocked == true);
      return unlocked == true;
    } finally {
      _isOpen = false;
    }
  }
}

// ── Copy ──────────────────────────────────────────────────────────

class _FeatureCopy {
  final String eyebrow;
  final String headline;
  final String sub;
  final IconData icon;
  final Color accent;
  const _FeatureCopy(this.eyebrow, this.headline, this.sub, this.icon, this.accent);
}

const Map<PaywallFeature, _FeatureCopy> _copy = {
  PaywallFeature.interview: _FeatureCopy(
    'VIDEO INTERVIEW',
    'READY FOR THE HOT SEAT?',
    'Practise on camera and get scored on every answer.',
    Icons.video_camera_front_rounded,
    AppColors.red),
  PaywallFeature.jobInterview: _FeatureCopy(
    'JOB SPECIFIC INTERVIEW',
    'PREP FOR THE ACTUAL JOB',
    'The exact questions for this role. No guessing on the day.',
    Icons.psychology_alt_rounded,
    AppColors.red),
  PaywallFeature.cvDownload: _FeatureCopy(
    'ATS CV BUILDER',
    'YOUR CV IS LOOKING SHARP',
    'Go Premium to download it and send it to recruiters.',
    Icons.description_rounded,
    AppColors.amber),
  PaywallFeature.aiCoach: _FeatureCopy(
    'AI COACH',
    'ENJOYING THE CHAT?',
    "You've used today's 3 free messages. Go Premium for unlimited coaching, or come back tomorrow.",
    Icons.psychology_rounded,
    AppColors.blue),
  PaywallFeature.general: _FeatureCopy(
    'ITSAGO PREMIUM',
    "LET'S GET YOU HIRED",
    'Everything you need to land the job.',
    Icons.workspace_premium_rounded,
    AppColors.amber),
};

// ── Dialog ────────────────────────────────────────────────────────

class _PaywallDialog extends StatefulWidget {
  final PaywallFeature feature;
  const _PaywallDialog({required this.feature});

  @override
  State<_PaywallDialog> createState() => _PaywallDialogState();
}

class _PaywallDialogState extends State<_PaywallDialog>
    with SingleTickerProviderStateMixin {
  final SubscriptionService _svc = SubscriptionService();
  StreamSubscription<SubscriptionEvent>? _events;

  ProductDetails? _product;        // monthly
  ProductDetails? _annualProduct;  // annual (null until live in Play)
  bool _annual = false;            // selected plan
  bool _busy = false;       // Google Play sheet is open
  bool _restoring = false;
  bool _pressed = false;
  bool _closed = false;
  String? _status;
  bool _statusIsError = false;

  // The one big moment: the R80 stamp slams onto the ticket.
  late final AnimationController _stampCtrl = AnimationController(
    vsync: this, duration: const Duration(milliseconds: 650));
  late final Animation<double> _stampScale = Tween<double>(begin: 1.9, end: 1.0)
    .animate(CurvedAnimation(parent: _stampCtrl, curve: Curves.elasticOut));
  late final Animation<double> _stampFade = CurvedAnimation(
    parent: _stampCtrl, curve: const Interval(0, 0.25, curve: Curves.easeOut));

  @override
  void initState() {
    super.initState();
    _events = _svc.events.listen(_onEvent);
    _loadProduct();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (MediaQuery.of(context).disableAnimations) {
        _stampCtrl.value = 1; // respect "reduce motion"
      } else {
        Future.delayed(const Duration(milliseconds: 260), () {
          if (mounted) _stampCtrl.forward();
        });
      }
    });
  }

  @override
  void dispose() {
    _events?.cancel();
    _stampCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadProduct() async {
    try {
      await _svc.ensureReady();
      if (mounted) {
        setState(() {
          _product = _svc.monthlyProduct;
          _annualProduct = _svc.annualProduct;
        });
      }
    } catch (_) {
      // Prices fall back to R80 / R828; the button retries when tapped.
    }
  }

  // ── Price text (live from Google Play, R80 fallback) ──
  static String _money(ProductDetails? p, double fallback, {double divideBy = 1}) {
    final has = p != null && p.rawPrice > 0;
    final raw = has ? p.rawPrice / divideBy : fallback;
    final symbol = (has && p.currencySymbol.isNotEmpty) ? p.currencySymbol : 'R';
    final amount = raw == raw.roundToDouble() ? raw.toInt().toString() : raw.toStringAsFixed(2);
    return '$symbol$amount';
  }

  String get _price          => _money(_product, 80);                      // R80
  String get _annualTotal    => _money(_annualProduct, 828);               // R828
  String get _annualPerMonth => _money(_annualProduct, 69, divideBy: 12);  // R69
  String get _stampPrice     => _annual ? _annualPerMonth : _price;

  int get _savePercent {
    final m = (_product?.rawPrice ?? 0) > 0 ? _product!.rawPrice : 80.0;
    final a = (_annualProduct?.rawPrice ?? 0) > 0 ? _annualProduct!.rawPrice : 828.0;
    return ((1 - (a / 12) / m) * 100).round();
  }

  void _selectPlan(bool annual) {
    if (_busy || annual == _annual) return;
    setState(() => _annual = annual);
    if (!MediaQuery.of(context).disableAnimations) _stampCtrl.forward(from: 0.15);
  }

  // ── Actions ──
  void _close(bool unlocked) {
    if (_closed || !mounted) return;
    _closed = true;
    Navigator.of(context).pop(unlocked);
  }

  String _clean(Object e) => e.toString().replaceFirst('Exception: ', '');

  void _onEvent(SubscriptionEvent e) {
    if (!mounted || _closed) return;
    switch (e.type) {
      case SubscriptionEventType.success:
        _close(true);
        break;
      case SubscriptionEventType.cancelled:
        setState(() {
          _busy = false;
          _status = "No stress, payment cancelled. You weren't charged a cent.";
          _statusIsError = false;
        });
        break;
      case SubscriptionEventType.pending:
        setState(() {
          _busy = false;
          _status = 'Payment is pending. Premium switches on as soon as Google Play confirms it.';
          _statusIsError = false;
        });
        break;
      case SubscriptionEventType.error:
        setState(() {
          _busy = false;
          _status = e.message ?? "Eish, the payment didn't go through. Give it another go.";
          _statusIsError = true;
        });
        break;
    }
  }

  Future<void> _subscribe() async {
    if (_busy || _restoring) return;
    setState(() { _busy = true; _status = null; });
    try {
      await _svc.ensureReady();
      if (!_svc.isAvailable) {
        throw Exception(StoreConfig.isIOS
            ? "Eish, the App Store isn't available right now. Check that you're signed in with your Apple ID."
            : "Eish, Google Play isn't available on this phone right now. "
              "Check that you're signed in to the Play Store.");
      }
      final product = _annual ? _svc.annualProduct : _svc.monthlyProduct;
      if (product == null) {
        throw Exception("Couldn't reach ${StoreConfig.storeName}. "
            'Check your data or Wi-Fi and try again.');
      }
      Analytics.subscribeTapped(_annual ? 'annual' : 'monthly', widget.feature.name);
      final started = await _svc.purchaseProduct(product);
      if (!started && mounted) {
        setState(() {
          _busy = false;
          _status = "${StoreConfig.storeName} didn't open. Give it another go.";
          _statusIsError = true;
        });
      }
      // Otherwise the result arrives through _onEvent.
    } catch (e) {
      if (mounted) {
        setState(() { _busy = false; _status = _clean(e); _statusIsError = true; });
      }
    }
  }

  Future<void> _restore() async {
    if (_busy || _restoring) return;
    setState(() { _restoring = true; _status = null; });
    try {
      await _svc.ensureReady();
      await _svc.restorePurchases();
      // Restored purchases arrive on the purchase stream; give it a moment.
      await Future.delayed(const Duration(seconds: 3));
      if (!mounted || _closed) return;
      if (await AccessService.hasFullAccess()) {
        _close(true);
        return;
      }
      if (mounted) {
        setState(() {
          _status = 'No active subscription on this Google account. Signed in with a different one?';
          _statusIsError = true;
        });
      }
    } catch (e) {
      if (mounted) setState(() { _status = _clean(e); _statusIsError = true; });
    } finally {
      if (mounted && !_closed) setState(() => _restoring = false);
    }
  }

  // ── UI ──
  @override
  Widget build(BuildContext context) {
    final c = _copy[widget.feature]!;
    return SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 20),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Material(
              color: Colors.transparent,
              child: Container(
                decoration: AppDecorations.dialog,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _header(c),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(18, 20, 18, 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _ticket(),
                            if (_annualProduct != null) ...[
                              const SizedBox(height: 18),
                              _planToggle(),
                            ],
                            const SizedBox(height: 20),
                            _cta(),
                            if (_status != null) ...[
                              const SizedBox(height: 12),
                              _statusLine(),
                            ],
                            const SizedBox(height: 10),
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Row(mainAxisSize: MainAxisSize.min, children: [
                                _textLink(_restoring ? 'Checking...' : 'Restore purchase',
                                  (_busy || _restoring) ? null : _restore),
                                // Apple doesn't allow unlocking with our own codes (3.1.1).
                                if (!StoreConfig.isIOS) ...[
                                  Container(width: 1, height: 14, color: AppColors.mist),
                                  _textLink('Promo code', (_busy || _restoring) ? null : _openPromo),
                                ],
                                Container(width: 1, height: 14, color: AppColors.mist),
                                _textLink('Maybe later', () => _close(false)),
                              ])),
                            const SizedBox(height: 4),
                            Text(_annual
                                ? 'Billed once a year through ${StoreConfig.storeName}. Renews automatically. Cancel any time.'
                                : 'Billed monthly through ${StoreConfig.storeName}. Renews automatically. Cancel any time.',
                              style: AppText.caption, textAlign: TextAlign.center),
                            const SizedBox(height: 2),
                            // Required by Apple (3.1.2) and good practice on Android.
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Row(mainAxisSize: MainAxisSize.min, children: [
                                _textLink('Terms of Use', _openTerms),
                                Container(width: 1, height: 14, color: AppColors.mist),
                                _textLink('Privacy Policy', _openPrivacy),
                              ])),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _header(_FeatureCopy c) {
    final iconFg = c.accent == AppColors.amber ? AppColors.ink : Colors.white;
    return Container(
      color: AppColors.ink,
      child: Stack(children: [
        // Geometric accents, same language as the menu cards.
        Positioned(right: -22, top: -22,
          child: Transform.rotate(angle: 0.35,
            child: Container(width: 90, height: 90, color: AppColors.amber))),
        Positioned(right: 64, bottom: 16,
          child: Container(width: 12, height: 12,
            decoration: const BoxDecoration(shape: BoxShape.circle, color: AppColors.red))),
        Positioned(left: 0, bottom: 0,
          child: Container(width: 72, height: 4, color: c.accent)),
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 16, 16, 22),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.amber,
                  border: Border.all(color: Colors.white, width: 1)),
                child: Text('ITSAGO PREMIUM',
                  style: AppText.label.copyWith(color: AppColors.ink, letterSpacing: 1.5))),
              const Spacer(),
              Semantics(
                button: true,
                label: 'Close',
                child: GestureDetector(
                  onTap: () => _close(false),
                  child: Container(
                    width: 32, height: 32,
                    decoration: const BoxDecoration(
                      color: AppColors.white, border: AppBorders.ink2),
                    child: const Icon(Icons.close_rounded, color: AppColors.ink, size: 18)))),
            ]),
            const SizedBox(height: 20),
            Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
              Container(
                width: 54, height: 54,
                decoration: BoxDecoration(
                  color: c.accent,
                  border: Border.all(color: Colors.white, width: 2)),
                child: Icon(c.icon, color: iconFg, size: 27)),
              const SizedBox(width: 14),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(c.eyebrow, style: AppText.headerLabel.copyWith(color: AppColors.amber)),
                const SizedBox(height: 6),
                Text(c.headline,
                  style: AppText.headline.copyWith(color: Colors.white, fontSize: 21)),
              ])),
            ]),
            const SizedBox(height: 14),
            Text(c.sub,
              style: AppText.body.copyWith(color: Colors.white70, fontWeight: FontWeight.w500)),
          ]),
        ),
      ]),
    );
  }

  // Stamp + what's included, side by side. Visual, very little text.
  Widget _ticket() {
    return Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
      AnimatedBuilder(
        animation: _stampCtrl,
        builder: (_, child) => Opacity(
          opacity: _stampFade.value,
          child: Transform.scale(scale: _stampScale.value, child: child)),
        child: Transform.rotate(
          angle: -0.08,
          child: Container(
            width: 96, height: 96,
            decoration: const BoxDecoration(
              color: AppColors.amber,
              border: AppBorders.ink3,
              boxShadow: [AppShadows.hard5]),
            child: Stack(children: [
              // Inner dashed-look frame, like a rubber stamp
              Positioned.fill(child: Container(
                margin: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.ink.withOpacity(0.35), width: 1.5)))),
              Center(child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  FittedBox(fit: BoxFit.scaleDown,
                    child: Text(_stampPrice, style: AppText.display.copyWith(fontSize: 38))),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    color: AppColors.ink,
                    child: Text('A MONTH', style: AppText.label.copyWith(
                      color: AppColors.amber, fontSize: 8.5))),
                ]))),
            ]),
          ),
        ),
      ),
      const SizedBox(width: 16),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _included(Icons.video_camera_front_rounded, 'Interviews', AppColors.red),
        const SizedBox(height: 10),
        _included(Icons.description_rounded, 'CV downloads', AppColors.amber),
        const SizedBox(height: 10),
        _included(Icons.psychology_rounded, 'AI Coach', AppColors.blue),
      ])),
    ]);
  }

  Widget _included(IconData icon, String label, Color color) {
    final fg = color == AppColors.amber ? AppColors.ink : Colors.white;
    return Row(children: [
      Container(
        width: 26, height: 26,
        decoration: BoxDecoration(color: color, border: AppBorders.ink2),
        child: Icon(icon, size: 14, color: fg)),
      const SizedBox(width: 10),
      Flexible(child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        child: Text(label, maxLines: 1,
          style: AppText.title.copyWith(fontSize: 13.5)))),
    ]);
  }

  // ── Monthly / Annual picker ──
  Widget _planToggle() {
    return IntrinsicHeight(
      child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Expanded(child: _planTile(
          selected: !_annual,
          title: 'MONTHLY',
          price: '$_price/mo',
          note: 'Pay month to month',
          onTap: () => _selectPlan(false))),
        const SizedBox(width: 10),
        Expanded(child: _planTile(
          selected: _annual,
          title: 'ANNUAL',
          price: '$_annualPerMonth/mo',
          note: '$_annualTotal once a year',
          badge: _savePercent > 0 ? 'SAVE $_savePercent%' : null,
          onTap: () => _selectPlan(true))),
      ]),
    );
  }

  Widget _planTile({
    required bool selected,
    required String title,
    required String price,
    required String note,
    String? badge,
    required VoidCallback onTap,
  }) {
    return Semantics(
      button: true,
      selected: selected,
      label: '$title plan, $price, $note',
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: selected ? AppColors.amberAt(0.16) : AppColors.white,
            border: Border.all(
              color: selected ? AppColors.ink : AppColors.mist,
              width: selected ? 2 : 1.5),
            boxShadow: selected ? const [AppShadows.hard3] : const <BoxShadow>[]),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Icon(selected ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
                size: 15, color: selected ? AppColors.ink : AppColors.dim),
              const SizedBox(width: 6),
              Flexible(child: FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft,
                child: Text(title, style: AppText.label.copyWith(fontSize: 10)))),
            ]),
            const SizedBox(height: 6),
            FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft,
              child: Text(price, style: AppText.title.copyWith(fontSize: 16))),
            const SizedBox(height: 2),
            FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft,
              child: Text(note, style: AppText.caption.copyWith(fontSize: 10))),
            if (badge != null) ...[
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                color: AppColors.red,
                child: Text(badge, style: AppText.label.copyWith(
                  color: Colors.white, fontSize: 8.5))),
            ],
          ]),
        ),
      ),
    );
  }

  void _openTerms() => Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => const TermsScreen(cameras: [])));

  void _openPrivacy() => Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => const PrivacyPolicyDetailScreen()));

  // ── Promo codes ──
  Future<void> _openPromo() async {
    final unlocked = await showDialog<bool>(
      context: context,
      builder: (_) => const _PromoCodeDialog());
    if (unlocked == true && mounted) _close(true);
  }

  Widget _cta() {
    final disabled = _busy || _restoring;
    return Semantics(
      button: true,
      label: _annual
          ? 'Subscribe for $_annualTotal per year'
          : 'Subscribe for $_price per month',
      child: GestureDetector(
        onTapDown: disabled ? null : (_) => setState(() => _pressed = true),
        onTapUp: disabled ? null : (_) => setState(() => _pressed = false),
        onTapCancel: () { if (_pressed) setState(() => _pressed = false); },
        onTap: disabled ? null : _subscribe,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 90),
          height: 58,
          transform: Matrix4.translationValues(_pressed ? 3 : 0, _pressed ? 3 : 0, 0),
          decoration: BoxDecoration(
            color: disabled && !_busy ? AppColors.dim : AppColors.red,
            border: AppBorders.ink2,
            boxShadow: _pressed ? const <BoxShadow>[] : const [AppShadows.hard4]),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Center(
            child: FittedBox(
            fit: BoxFit.scaleDown,
            child: _busy
              ? Row(mainAxisSize: MainAxisSize.min, children: [
                  const SizedBox(width: 18, height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white)),
                  const SizedBox(width: 12),
                  Text('OPENING ${StoreConfig.storeNameCaps}', style: AppText.button),
                ])
              : Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.lock_open_rounded, color: Colors.white, size: 19),
                  const SizedBox(width: 10),
                  Text(_annual
                      ? 'SUBSCRIBE FOR $_annualTotal/YEAR'
                      : 'SUBSCRIBE FOR $_price/MONTH',
                    style: AppText.button.copyWith(fontSize: 14)),
                ]),
          )),
        ),
      ),
    );
  }

  Widget _statusLine() {
    final color = _statusIsError ? AppColors.red : AppColors.ink;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: _statusIsError ? AppColors.redAt(0.08) : AppColors.light,
        border: Border.all(color: color, width: 1.5)),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(_statusIsError ? Icons.error_outline_rounded : Icons.info_outline_rounded,
          color: color, size: 18),
        const SizedBox(width: 8),
        Expanded(child: Text(_status!, style: AppText.body.copyWith(fontSize: 12, color: color))),
      ]),
    );
  }

  Widget _textLink(String label, VoidCallback? onTap) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Text(label,
          style: AppText.body.copyWith(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: onTap == null ? AppColors.dim : AppColors.ink))),
    );
  }
}


// ── Promo code dialog ─────────────────────────────────────────────
// ITSAGO codes (TUT pilot, sponsors, events) are checked on the server by
// the redeemPromoCode Cloud Function, which grants Premium for a set number
// of days. No bank card needed. Google Play codes are different: those are
// redeemed inside the Google Play payment sheet ("Redeem code").
class _PromoCodeDialog extends StatefulWidget {
  const _PromoCodeDialog();

  @override
  State<_PromoCodeDialog> createState() => _PromoCodeDialogState();
}

class _PromoCodeDialogState extends State<_PromoCodeDialog> {
  final _ctrl = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _redeem() async {
    final code = _ctrl.text.trim().toUpperCase();
    if (code.isEmpty || _busy) return;
    setState(() { _busy = true; _error = null; });
    try {
      final res = await CloudFunctionService.redeemPromoCode(code);
      if (!mounted) return;
      if (res['ok'] == true) {
        Analytics.promoRedeemed(code);
        Navigator.of(context).pop(true);
        return;
      }
      setState(() { _busy = false; _error = "Eish, that code didn't work. Check it and try again."; });
    } on FirebaseFunctionsException catch (e) {
      if (!mounted) return;
      final msg = e.code == 'not-found'
          ? "That code isn't valid. If it's a Google Play code, tap Subscribe "
            "and choose 'Redeem code' in Google Play."
          : (e.message ?? "Eish, that code didn't work. Try again.");
      setState(() { _busy = false; _error = msg; });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = "Couldn't check the code. Check your data or Wi-Fi and try again.";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        decoration: AppDecorations.dialog,
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('GOT A PROMO CODE?', style: AppText.title),
            const SizedBox(height: 6),
            Text('Enter the code from your university, sponsor or event.',
              style: AppText.body.copyWith(fontSize: 12, color: AppColors.dim)),
            const SizedBox(height: 14),
            TextField(
              controller: _ctrl,
              autofocus: true,
              enabled: !_busy,
              textCapitalization: TextCapitalization.characters,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _redeem(),
              style: AppText.title.copyWith(letterSpacing: 2),
              decoration: InputDecoration(
                hintText: 'E.G. TUTPILOT',
                filled: true,
                fillColor: AppColors.light,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                border: const OutlineInputBorder(
                  borderRadius: BorderRadius.zero,
                  borderSide: BorderSide(color: AppColors.ink, width: 2)),
                enabledBorder: const OutlineInputBorder(
                  borderRadius: BorderRadius.zero,
                  borderSide: BorderSide(color: AppColors.ink, width: 2)),
                focusedBorder: const OutlineInputBorder(
                  borderRadius: BorderRadius.zero,
                  borderSide: BorderSide(color: AppColors.blue, width: 2)),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(_error!, style: AppText.body.copyWith(fontSize: 12, color: AppColors.red)),
            ],
            const SizedBox(height: 16),
            Row(children: [
              Expanded(child: GestureDetector(
                onTap: _busy ? null : () => Navigator.of(context).pop(false),
                child: Container(
                  height: 46,
                  decoration: const BoxDecoration(color: AppColors.white, border: AppBorders.ink2),
                  child: Center(child: Text('CANCEL', style: AppText.label))))),
              const SizedBox(width: 10),
              Expanded(child: GestureDetector(
                onTap: _busy ? null : _redeem,
                child: Container(
                  height: 46,
                  decoration: const BoxDecoration(
                    color: AppColors.red, border: AppBorders.ink2,
                    boxShadow: [AppShadows.hard3]),
                  child: Center(child: _busy
                    ? const SizedBox(width: 18, height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                    : Text('REDEEM', style: AppText.label.copyWith(color: Colors.white)))))),
            ]),
          ],
        ),
      ),
    );
  }
}
