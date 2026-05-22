import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// OSI Barber — Sistema visual unificado.
///
/// Un único sitio para colores, tipografías, radios, espaciados y componentes.
/// Cambia aquí → cambia en toda la app.
abstract final class AppTheme {
  // ─── Colores de marca ───────────────────────────────────────────────────────
  /// Dorado principal. Elegante y cálido, NO el amber amarillo genérico.
  static const Color gold        = Color(0xFFCFA84C);
  static const Color goldSoft    = Color(0x25CFA84C); // dorado 15% — fondos y bordes suaves
  static const Color black       = Color(0xFF0D0D0D); // negro profundo base
  static const Color surface     = Color(0xFF161616); // fondo de cards / surfaces
  static const Color surfaceHigh = Color(0xFF222222); // surface levantada (input, chips)
  static const Color divider     = Color(0xFF2E2E2E); // líneas y bordes sutiles
  static const Color textPrimary = Color(0xFFF0F0F0); // texto principal (no blanco puro)
  static const Color textSecond  = Color(0xFF9E9E9E); // texto secundario / labels
  static const Color textHint    = Color(0xFF5A5A5A); // placeholder y texto desactivado
  static const Color success     = Color(0xFF4CAF50); // cita completada / OK
  static const Color error       = Color(0xFFE53935); // error / destructivo
  static const Color warning     = Color(0xFFFF8F00); // ausente / advertencia

  // ─── Radios ─────────────────────────────────────────────────────────────────
  static const double radiusS    = 8.0;
  static const double radiusM    = 12.0;
  static const double radiusL    = 16.0;
  static const double radiusXL   = 24.0;
  static const double radiusFull = 100.0;

  // ─── Espaciados ─────────────────────────────────────────────────────────────
  static const double spaceXS  = 4.0;
  static const double spaceSM  = 8.0;
  static const double spaceMD  = 16.0;
  static const double spaceLG  = 24.0;
  static const double spaceXL  = 32.0;
  static const double spaceXXL = 48.0;

  // ─── Tipografías ────────────────────────────────────────────────────────────
  // Playfair Display → títulos, nombres, precios: carácter y elegancia clásica
  // Inter           → UI, labels, cuerpo: legibilidad y limpieza moderna

  static final TextStyle displayLarge = GoogleFonts.playfairDisplay(
    color: textPrimary, fontSize: 32, fontWeight: FontWeight.w700, letterSpacing: 0.5,
  );
  static final TextStyle displayMedium = GoogleFonts.playfairDisplay(
    color: textPrimary, fontSize: 26, fontWeight: FontWeight.w700,
  );
  static final TextStyle titleLarge = GoogleFonts.playfairDisplay(
    color: textPrimary, fontSize: 22, fontWeight: FontWeight.w700,
  );
  static final TextStyle titleMedium = GoogleFonts.inter(
    color: textPrimary, fontSize: 17, fontWeight: FontWeight.w600,
  );
  static final TextStyle titleSmall = GoogleFonts.inter(
    color: textPrimary, fontSize: 14, fontWeight: FontWeight.w600, letterSpacing: 0.2,
  );
  static final TextStyle bodyLarge = GoogleFonts.inter(
    color: textPrimary, fontSize: 16, fontWeight: FontWeight.w400,
  );
  static final TextStyle bodyMedium = GoogleFonts.inter(
    color: textSecond, fontSize: 14, fontWeight: FontWeight.w400,
  );
  static final TextStyle bodySmall = GoogleFonts.inter(
    color: textHint, fontSize: 12, fontWeight: FontWeight.w400,
  );
  static final TextStyle labelGold = GoogleFonts.inter(
    color: gold, fontSize: 13, fontWeight: FontWeight.w600, letterSpacing: 0.3,
  );
  static final TextStyle priceTag = GoogleFonts.playfairDisplay(
    color: gold, fontSize: 22, fontWeight: FontWeight.w700,
  );
  static final TextStyle appBarTitle = GoogleFonts.playfairDisplay(
    color: textPrimary, fontSize: 19, fontWeight: FontWeight.w700, letterSpacing: 1.5,
  );
  static final TextStyle buttonLabel = GoogleFonts.inter(
    color: black, fontSize: 14, fontWeight: FontWeight.w700, letterSpacing: 0.8,
  );

  // ─── ThemeData global ───────────────────────────────────────────────────────
  static ThemeData get theme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: black,

      colorScheme: const ColorScheme.dark(
        primary:        gold,
        onPrimary:      black,
        secondary:      gold,
        onSecondary:    black,
        surface:        surface,
        onSurface:      textPrimary,
        error:          error,
        onError:        textPrimary,
        outline:        divider,
        surfaceTint:    Colors.transparent,
      ),

      // AppBar
      appBarTheme: AppBarTheme(
        backgroundColor:          black,
        elevation:                0,
        scrolledUnderElevation:   0,
        centerTitle:              true,
        titleTextStyle:           appBarTitle,
        iconTheme:                const IconThemeData(color: textPrimary, size: 22),
        surfaceTintColor:         Colors.transparent,
      ),

      // Cards
      cardTheme: CardThemeData(
        color:     surface,
        elevation: 0,
        margin:    EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusL),
          side: const BorderSide(color: divider, width: 0.5),
        ),
      ),

      // ElevatedButton — CTA principal
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: gold,
          foregroundColor: black,
          elevation:       0,
          minimumSize:     const Size(double.infinity, 52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusM)),
          textStyle: buttonLabel,
        ),
      ),

      // OutlinedButton — acción secundaria
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: textPrimary,
          side:            const BorderSide(color: divider),
          minimumSize:     const Size(double.infinity, 52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusM)),
          textStyle: GoogleFonts.inter(
            fontSize: 14, fontWeight: FontWeight.w600, letterSpacing: 0.8,
          ),
        ),
      ),

      // TextButton — acción terciaria
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: gold,
          textStyle: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w500),
        ),
      ),

      // Inputs
      inputDecorationTheme: InputDecorationTheme(
        filled:          true,
        fillColor:       surface,
        contentPadding:  const EdgeInsets.symmetric(horizontal: spaceMD, vertical: spaceMD),
        labelStyle:      GoogleFonts.inter(color: textSecond, fontSize: 14),
        hintStyle:       GoogleFonts.inter(color: textHint, fontSize: 14),
        prefixIconColor: gold,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusM),
          borderSide:   const BorderSide(color: divider, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusM),
          borderSide:   const BorderSide(color: gold, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusM),
          borderSide:   const BorderSide(color: error, width: 1),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusM),
          borderSide:   const BorderSide(color: error, width: 1.5),
        ),
      ),

      // Drawer
      drawerTheme: const DrawerThemeData(backgroundColor: surface, elevation: 0),

      // Divider
      dividerTheme: const DividerThemeData(color: divider, thickness: 0.5, space: 1),

      // Progress Indicator
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: gold, linearTrackColor: surfaceHigh,
      ),

      // TabBar
      tabBarTheme: TabBarThemeData(
        indicatorColor:          gold,
        labelColor:              gold,
        unselectedLabelColor:    textSecond,
        indicatorSize:           TabBarIndicatorSize.tab,
        dividerColor:            divider,
        labelStyle:              GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600),
        unselectedLabelStyle:    GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w400),
      ),

      // Dialogs
      dialogTheme: DialogThemeData(
        backgroundColor: surface,
        elevation:       0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusXL),
          side: const BorderSide(color: divider),
        ),
        titleTextStyle:   GoogleFonts.inter(color: textPrimary, fontSize: 18, fontWeight: FontWeight.w600),
        contentTextStyle: GoogleFonts.inter(color: textSecond,  fontSize: 14),
      ),

      // SnackBar
      snackBarTheme: SnackBarThemeData(
        backgroundColor: surfaceHigh,
        contentTextStyle: GoogleFonts.inter(color: textPrimary, fontSize: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusM)),
        behavior:         SnackBarBehavior.floating,
        insetPadding:     const EdgeInsets.all(16),
      ),

      // Switch (panel admin)
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? black : textSecond,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? gold : surfaceHigh,
        ),
      ),

      // ListTile
      listTileTheme: ListTileThemeData(
        iconColor:        gold,
        textColor:        textPrimary,
        subtitleTextStyle: GoogleFonts.inter(color: textSecond, fontSize: 13),
        titleTextStyle:    GoogleFonts.inter(color: textPrimary, fontSize: 15),
        tileColor:         Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusS)),
      ),
    );
  }
}
