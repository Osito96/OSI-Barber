import 'package:flutter/material.dart';
import 'pantalla_bienvenida.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'pantalla_inicio.dart'; // Asegúrate de importar la pantalla de inicio

class PantallaSplash extends StatefulWidget {
  const PantallaSplash({super.key});

  @override
  State<PantallaSplash> createState() => _PantallaSplashState();
}

class _PantallaSplashState extends State<PantallaSplash> {
  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 2500), () {
      if (mounted) {
        // --- MAGIA: Comprobamos si hay un usuario logueado ---
        User? usuario = FirebaseAuth.instance.currentUser;

        if (usuario != null) {
          // Si ya está logueado, vamos directo al Inicio
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const PantallaInicio()),
          );
        } else {
          // Si no hay nadie, vamos a la Bienvenida
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const PantallaBienvenida()),
          );
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Hero(
                tag: 'logo_app', // <-- IMPORTANTE: El mismo tag que en bienvenida
                child: Image.asset('assets/logo_osi_barber.png', width: 200),
                ),
            const SizedBox(height: 30),
            const CircularProgressIndicator(color: Color(0xFFFFC107)),
          ],
        ),
      ),
    );
  }
}