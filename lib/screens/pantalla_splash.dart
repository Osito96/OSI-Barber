import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../core/app_theme.dart';
import '../core/app_routes.dart';
import 'pantalla_bienvenida.dart';
import 'pantalla_inicio.dart';

class PantallaSplash extends StatefulWidget {
  const PantallaSplash({super.key});

  @override
  State<PantallaSplash> createState() => _PantallaSplashState();
}

class _PantallaSplashState extends State<PantallaSplash> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _fadeAnim;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 950));

    _fadeAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: const Interval(0.0, 0.65, curve: Curves.easeOut)),
    );
    _scaleAnim = Tween<double>(begin: 0.88, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: const Interval(0.0, 0.70, curve: Curves.easeOut)),
    );

    _ctrl.forward();

    Future.delayed(const Duration(milliseconds: 2600), () {
      if (!mounted) return;
      final usuario = FirebaseAuth.instance.currentUser;
      if (usuario != null) {
        Navigator.pushReplacement(context, AppRoutes.fade(const PantallaInicio()));
      } else {
        Navigator.pushReplacement(context, AppRoutes.fade(const PantallaBienvenida()));
      }
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.black,
      body: Center(
        child: FadeTransition(
          opacity: _fadeAnim,
          child: ScaleTransition(
            scale: _scaleAnim,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Hero(
                  tag: 'logo_app',
                  child: Image.asset('assets/logo_osi_barber.png', width: 180),
                ),
                const SizedBox(height: 52),
                SizedBox(
                  width: 18, height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 1.5,
                    valueColor: AlwaysStoppedAnimation<Color>(AppTheme.gold),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
