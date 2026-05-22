import 'package:flutter/material.dart';

/// Transiciones de pantalla unificadas para OSI Barber.
///
/// Uso:
///   Navigator.push(context, AppRoutes.slide(MiPantalla()));
///   Navigator.pushReplacement(context, AppRoutes.fade(MiPantalla()));
abstract final class AppRoutes {
  /// Slide suave + fade — para navegación hacia adelante (push).
  static Route<T> slide<T>(Widget page) {
    return PageRouteBuilder<T>(
      transitionDuration:        const Duration(milliseconds: 380),
      reverseTransitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (_, __, ___) => page,
      transitionsBuilder: (_, animation, __, child) {
        final curved = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
        return FadeTransition(
          opacity: Tween<double>(begin: 0.0, end: 1.0).animate(curved),
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0.05, 0),
              end:   Offset.zero,
            ).animate(curved),
            child: child,
          ),
        );
      },
    );
  }

  /// Fade puro — para reemplazos de pantalla (pushReplacement, pushAndRemoveUntil).
  static Route<T> fade<T>(Widget page) {
    return PageRouteBuilder<T>(
      transitionDuration:        const Duration(milliseconds: 400),
      reverseTransitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (_, __, ___) => page,
      transitionsBuilder: (_, animation, __, child) {
        return FadeTransition(
          opacity: CurvedAnimation(parent: animation, curve: Curves.easeInOut),
          child: child,
        );
      },
    );
  }
}
