import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart'; 
import 'package:onesignal_flutter/onesignal_flutter.dart'; 
import 'firebase_options.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'screens/pantalla_splash.dart';

void main() async {
  // Nos aseguramos de que los motores de Flutter estén listos antes de arrancar nada
  WidgetsFlutterBinding.ensureInitialized();
  
  // Inicialización de la base de datos de Google (Firebase)
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  
  // Configuración del servicio de notificaciones Push (OneSignal)
  OneSignal.initialize("TU_ONE_SIGNAL_APP_ID_AQUI");
  
  runApp(const OsiBarberApp());
}

// Usamos un StatefulWidget para poder vigilar si el usuario cierra la app
class OsiBarberApp extends StatefulWidget {
  const OsiBarberApp({super.key});

  @override
  State<OsiBarberApp> createState() => _OsiBarberAppState();
}

// Añadimos WidgetsBindingObserver para actuar como un "vigilante" del ciclo de vida
class _OsiBarberAppState extends State<OsiBarberApp> with WidgetsBindingObserver {
  
  @override
  void initState() {
    super.initState();
    // Activamos el observador al iniciar la aplicación
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    // Es vital quitar el observador si la app se destruye para no dejar procesos colgando
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // --- LÓGICA DE SEGURIDAD: DETECTAR CIERRE TOTAL ---
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    // Si el estado es 'detached', significa que la app va a ser eliminada de la memoria
    // Por seguridad, cerramos la sesión para que nadie entre si el móvil cambia de manos
    if (state == AppLifecycleState.detached) {
      FirebaseAuth.instance.signOut(); 
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false, // Quitamos la etiqueta de "Debug" para que sea más profesional
      title: 'OSI Barber',
      
      // Configuración para que la app hable español (meses, días, etc.)
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('es', 'ES')],
      
      // Estética de la aplicación (Modo oscuro corporativo)
      theme: ThemeData(
        brightness: Brightness.dark,
        primaryColor: Colors.amber,
        scaffoldBackgroundColor: Colors.black,
      ),
      
      // La pantalla con la que arranca todo siempre
      home: const PantallaSplash(),
    );
  }
}