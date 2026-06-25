import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// ═══════════════════════════════════════════════════════════════
//  ITSAGO DESIGN SYSTEM
//  Single source of truth for the entire app.
//  Import this file everywhere — never hardcode colours or styles.
// ═══════════════════════════════════════════════════════════════

class AppColors {
  AppColors._();

  // ── Core palette ──────────────────────────────────────────
  static const Color ink    = Color(0xFF1A1C2A);  // deep navy — text, borders, shadows
  static const Color cream  = Color(0xFFEDE8DC);  // warm paper — page backgrounds
  static const Color white  = Color(0xFFFFFFFF);  // card surfaces
  static const Color red    = Color(0xFFCC3B30);  // tomato red — danger, primary CTA
  static const Color amber  = Color(0xFFE8A200);  // warm gold — accent, badges
  static const Color blue   = Color(0xFF1F66B0);  // royal blue — info, primary action
  static const Color mist   = Color(0xFFE6DFD4);  // dividers, subtle borders
  static const Color dim    = Color(0xFF7A7469);  // muted body text
  static const Color light  = Color(0xFFF5F0E8);  // lighter cream for nested surfaces

  // ── Semantic aliases ──────────────────────────────────────
  static const Color background  = cream;
  static const Color surface     = white;
  static const Color border      = ink;
  static const Color textPrimary = ink;
  static const Color textMuted   = dim;
  static const Color accent      = amber;
  static const Color danger      = red;
  static const Color action      = blue;

  // ── Overlay helpers ───────────────────────────────────────
  static Color inkAt(double opacity)   => ink.withOpacity(opacity);
  static Color amberAt(double opacity) => amber.withOpacity(opacity);
  static Color redAt(double opacity)   => red.withOpacity(opacity);
  static Color blueAt(double opacity)  => blue.withOpacity(opacity);
}

// ── Shadow constants ──────────────────────────────────────────
class AppShadows {
  AppShadows._();

  static const BoxShadow hard4 = BoxShadow(
    color: AppColors.ink, offset: Offset(4, 4), blurRadius: 0);

  static const BoxShadow hard5 = BoxShadow(
    color: AppColors.ink, offset: Offset(5, 5), blurRadius: 0);

  static const BoxShadow hard3 = BoxShadow(
    color: AppColors.ink, offset: Offset(3, 3), blurRadius: 0);

  static const BoxShadow hard6 = BoxShadow(
    color: AppColors.ink, offset: Offset(6, 6), blurRadius: 0);

  static BoxShadow colored(Color c, {double size = 4}) =>
      BoxShadow(color: c, offset: Offset(size, size), blurRadius: 0);
}

// ── Border constants ──────────────────────────────────────────
class AppBorders {
  AppBorders._();

  static const Border ink2 = Border.fromBorderSide(
    BorderSide(color: AppColors.ink, width: 2));

  static const Border ink3 = Border.fromBorderSide(
    BorderSide(color: AppColors.ink, width: 3));

  static const Border amber1 = Border.fromBorderSide(
    BorderSide(color: AppColors.amber, width: 1));

  static Border color(Color c, {double width = 2}) =>
      Border.fromBorderSide(BorderSide(color: c, width: width));
}

// ── Decorations ───────────────────────────────────────────────
class AppDecorations {
  AppDecorations._();

  // White card — hard ink shadow (standard card in the app)
  static const BoxDecoration card = BoxDecoration(
    color: AppColors.white,
    border: AppBorders.ink2,
    boxShadow: [AppShadows.hard5]);

  // White card — smaller shadow (for nested or drawer cards)
  static const BoxDecoration cardSmall = BoxDecoration(
    color: AppColors.white,
    border: AppBorders.ink2,
    boxShadow: [AppShadows.hard3]);

  // Cream surface — for section containers on cream background
  static const BoxDecoration surfaceCream = BoxDecoration(
    color: AppColors.light,
    border: AppBorders.ink2,
    boxShadow: [AppShadows.hard4]);

  // Dialog container
  static const BoxDecoration dialog = BoxDecoration(
    color: AppColors.white,
    border: AppBorders.ink2,
    boxShadow: [AppShadows.hard6]);

  // Input field (enabled)
  static InputDecoration inputDecoration(String label, {String? hint}) =>
      InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: AppText.label,
        hintStyle: AppText.body.copyWith(color: AppColors.dim),
        filled: true,
        fillColor: AppColors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.zero,
          borderSide: const BorderSide(color: AppColors.ink, width: 2)),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.zero,
          borderSide: const BorderSide(color: AppColors.blue, width: 2.5)),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.zero,
          borderSide: const BorderSide(color: AppColors.red, width: 2)),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.zero,
          borderSide: const BorderSide(color: AppColors.red, width: 2.5)),
      );
}

// ── Typography ────────────────────────────────────────────────
class AppText {
  AppText._();

  // Display — massive header text (used in posters/hero areas)
  static const TextStyle display = TextStyle(
    fontSize: 42, fontWeight: FontWeight.w900,
    color: AppColors.ink, letterSpacing: -1.5, height: 0.95);

  // Headline — section titles
  static const TextStyle headline = TextStyle(
    fontSize: 22, fontWeight: FontWeight.w900,
    color: AppColors.ink, letterSpacing: -0.3, height: 1.0);

  // Title — card titles, screen headings
  static const TextStyle title = TextStyle(
    fontSize: 16, fontWeight: FontWeight.w900,
    color: AppColors.ink, letterSpacing: -0.2, height: 1.05);

  // Label — ALL CAPS small labels and badges
  static const TextStyle label = TextStyle(
    fontSize: 9, fontWeight: FontWeight.w900,
    color: AppColors.ink, letterSpacing: 2.0);

  // Body — regular paragraph text
  static const TextStyle body = TextStyle(
    fontSize: 13, fontWeight: FontWeight.w600,
    color: AppColors.ink, height: 1.4);

  // Caption — small muted text
  static const TextStyle caption = TextStyle(
    fontSize: 10, fontWeight: FontWeight.w600,
    color: AppColors.dim, letterSpacing: 0.3);

  // Button — CTA labels
  static const TextStyle button = TextStyle(
    fontSize: 13, fontWeight: FontWeight.w900,
    color: AppColors.white, letterSpacing: 1.5);

  // Poster — large white header on dark backgrounds
  static const TextStyle poster = TextStyle(
    fontSize: 38, fontWeight: FontWeight.w900,
    color: Colors.white, letterSpacing: -1.0, height: 0.95);

  // Header label — small white label on dark background
  static const TextStyle headerLabel = TextStyle(
    fontSize: 9, fontWeight: FontWeight.w900,
    color: Colors.white, letterSpacing: 2.5);

  // Helpers
  static TextStyle colored(Color c) => body.copyWith(color: c);
  static TextStyle titleColored(Color c) => title.copyWith(color: c);
  static TextStyle labelColored(Color c) => label.copyWith(color: c);
}

// ── Reusable Widgets ──────────────────────────────────────────
class AppWidgets {
  AppWidgets._();

  // ── Standard dark poster header ──────────────────────────
  static Widget header({
    required String title,
    required BuildContext context,
    Widget? leading,
    Widget? trailing,
    Color? accentColor,
  }) {
    final accent = accentColor ?? AppColors.amber;
    return Container(
      width: double.infinity,
      color: AppColors.ink,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(children: [
            if (leading != null) ...[leading, const SizedBox(width: 12)],
            Expanded(child: Text(title,
              style: AppText.title.copyWith(color: Colors.white, letterSpacing: 2))),
            // ITSAGO AI amber badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: accent,
                border: Border.all(color: AppColors.ink, width: 1)),
              child: Text('ITSAGO AI',
                style: AppText.label.copyWith(color: AppColors.ink, letterSpacing: 1.5))),
            if (trailing != null) ...[const SizedBox(width: 8), trailing],
          ]),
        ),
      ),
    );
  }

  // ── Back button — white box with hard shadow ──────────────
  static Widget backButton(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.of(context).pop(),
      child: Container(
        width: 38, height: 38,
        decoration: const BoxDecoration(
          color: AppColors.white,
          border: AppBorders.ink2,
          boxShadow: [AppShadows.hard3]),
        child: const Icon(Icons.arrow_back_rounded,
          color: AppColors.ink, size: 18)));
  }

  // ── Primary CTA button ────────────────────────────────────
  static Widget primaryButton({
    required String label,
    required VoidCallback? onTap,
    Color? color,
    double height = 52,
    IconData? icon,
  }) {
    final bg = color ?? AppColors.ink;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity, height: height,
        decoration: BoxDecoration(
          color: onTap != null ? bg : AppColors.dim,
          border: AppBorders.ink2,
          boxShadow: onTap != null ? const [AppShadows.hard4] : null),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          if (icon != null) ...[
            Icon(icon, color: Colors.white, size: 18),
            const SizedBox(width: 8)],
          Text(label, style: AppText.button),
        ])));
  }

  // ── Secondary outlined button ─────────────────────────────
  static Widget secondaryButton({
    required String label,
    required VoidCallback? onTap,
    double height = 48,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity, height: height,
        decoration: const BoxDecoration(
          color: AppColors.white,
          border: AppBorders.ink2),
        child: Center(child: Text(label,
          style: AppText.button.copyWith(color: AppColors.ink)))));
  }

  // ── Bauhaus section label ─────────────────────────────────
  static Widget sectionLabel(String text, {Color? accent}) {
    return Row(children: [
      Container(width: 3, height: 14, color: accent ?? AppColors.red),
      const SizedBox(width: 8),
      Text(text.toUpperCase(), style: AppText.label),
    ]);
  }

  // ── Amber badge ───────────────────────────────────────────
  static Widget badge(String text, {Color? bg, Color? fg}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg ?? AppColors.amber,
        border: Border.all(color: AppColors.ink, width: 1)),
      child: Text(text.toUpperCase(),
        style: AppText.label.copyWith(color: fg ?? AppColors.ink)));
  }

  // ── Bauhaus info card (colour header + white body) ────────
  static Widget infoCard({
    required String title,
    required String body,
    required Color accent,
    IconData? icon,
  }) {
    final isLight = accent == AppColors.amber;
    return Container(
      decoration: AppDecorations.card,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          color: accent,
          child: Row(children: [
            if (icon != null) ...[
              Icon(icon, color: isLight ? AppColors.ink : Colors.white, size: 18),
              const SizedBox(width: 10)],
            Expanded(child: Text(title.toUpperCase(),
              style: AppText.label.copyWith(
                color: isLight ? AppColors.ink : Colors.white, fontSize: 11))),
          ])),
        Padding(
          padding: const EdgeInsets.all(14),
          child: Text(body, style: AppText.body)),
      ]));
  }

  // ── Divider line ──────────────────────────────────────────
  static Widget divider({Color? color}) =>
      Container(height: 1.5, color: color ?? AppColors.mist);

  // ── Geometric accent dot ──────────────────────────────────
  static Widget dot({double size = 10, Color? color}) =>
      Container(width: size, height: size,
        decoration: BoxDecoration(
          color: color ?? AppColors.red,
          shape: BoxShape.circle));

  // ── Geometric accent square ───────────────────────────────
  static Widget square({double size = 10, Color? color}) =>
      Container(width: size, height: size, color: color ?? AppColors.amber);
}

// ── Flutter ThemeData ─────────────────────────────────────────
class AppTheme {
  AppTheme._();

  static ThemeData get theme => ThemeData(
    useMaterial3: false,
    fontFamily: 'Arial',
    scaffoldBackgroundColor: AppColors.cream,
    primaryColor: AppColors.blue,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.blue,
      primary:   AppColors.blue,
      secondary: AppColors.red,
      surface:   AppColors.white,
      background: AppColors.cream,
      error:     AppColors.red,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.ink,
      foregroundColor: Colors.white,
      elevation: 0,
      centerTitle: false,
      systemOverlayStyle: SystemUiOverlayStyle.light,
      titleTextStyle: AppText.title,
    ),
    textTheme: const TextTheme(
      displayLarge:  AppText.display,
      headlineLarge: AppText.headline,
      titleLarge:    AppText.title,
      bodyLarge:     AppText.body,
      bodyMedium:    AppText.body,
      labelSmall:    AppText.label,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.ink,
        foregroundColor: Colors.white,
        textStyle: AppText.button,
        shape: const RoundedRectangleBorder(),
        elevation: 0,
      )),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.white,
      labelStyle: AppText.label,
      border: const OutlineInputBorder(
        borderRadius: BorderRadius.zero,
        borderSide: BorderSide(color: AppColors.ink, width: 2)),
      enabledBorder: const OutlineInputBorder(
        borderRadius: BorderRadius.zero,
        borderSide: BorderSide(color: AppColors.ink, width: 2)),
      focusedBorder: const OutlineInputBorder(
        borderRadius: BorderRadius.zero,
        borderSide: BorderSide(color: AppColors.blue, width: 2.5)),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: AppColors.ink,
      contentTextStyle: AppText.body.copyWith(color: Colors.white),
      behavior: SnackBarBehavior.floating,
      shape: const RoundedRectangleBorder(),
    ),
    dialogTheme: const DialogThemeData(
      backgroundColor: AppColors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(),
    ),
    dividerTheme: const DividerThemeData(
      color: AppColors.mist,
      thickness: 1.5,
      space: 0,
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: AppColors.blue,
      linearTrackColor: AppColors.mist,
    ),
    checkboxTheme: CheckboxThemeData(
      fillColor: MaterialStateProperty.resolveWith((s) =>
        s.contains(MaterialState.selected) ? AppColors.blue : AppColors.white),
      side: const BorderSide(color: AppColors.ink, width: 2),
      shape: const RoundedRectangleBorder(),
    ),
  );
}

