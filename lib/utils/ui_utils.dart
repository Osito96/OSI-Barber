import 'package:flutter/material.dart';
import '../core/app_theme.dart';

/// Utilidades de interfaz reutilizables en toda la app.
class UiUtils {
  UiUtils._();

  // ─── Mensajes ───────────────────────────────────────────────────────────────

  /// SnackBar flotante con el texto y color indicados.
  /// El shape y comportamiento floating vienen del SnackBarTheme global.
  static void mostrarMensaje(BuildContext context, String texto, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(texto), backgroundColor: color),
    );
  }

  // ─── Fechas ─────────────────────────────────────────────────────────────────

  /// "27/04/2026"
  static String formatearFecha(DateTime fecha) {
    return '${fecha.day.toString().padLeft(2, '0')}/'
        '${fecha.month.toString().padLeft(2, '0')}/'
        '${fecha.year}';
  }

  /// "09:30"
  static String formatearHora(DateTime fecha) {
    return '${fecha.hour.toString().padLeft(2, '0')}:'
        '${fecha.minute.toString().padLeft(2, '0')}';
  }

  /// Nombre corto del mes (ene, feb, mar…)
  static String mesCorto(int mes) {
    const meses = ['', 'ene', 'feb', 'mar', 'abr', 'may', 'jun',
                        'jul', 'ago', 'sep', 'oct', 'nov', 'dic'];
    return meses[mes];
  }

  // ─── Date Picker ────────────────────────────────────────────────────────────

  /// Tema oscuro premium para los selectores de fecha.
  static Widget temaDatePicker(BuildContext context, Widget? child) {
    return Theme(
      data: ThemeData.dark().copyWith(
        colorScheme: const ColorScheme.dark(
          primary:   AppTheme.gold,
          onPrimary: AppTheme.black,
          surface:   AppTheme.surface,
          onSurface: AppTheme.textPrimary,
        ),
        dialogTheme: DialogThemeData(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusXL),
          ),
        ),
      ),
      child: child!,
    );
  }
}
