import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'pantalla_registro.dart';
import 'pantalla_inicio.dart';

class PantallaBienvenida extends StatefulWidget {
  const PantallaBienvenida({super.key});

  @override
  State<PantallaBienvenida> createState() => _PantallaBienvenidaState();
}

class _PantallaBienvenidaState extends State<PantallaBienvenida> {
  // Controlamos si mostramos los botones iniciales o el formulario de login
  bool mostrarLogin = false;
  
  // Para mostrar la ruedecita de carga mientras Firebase responde
  bool _estaCargando = false; 

  final TextEditingController _usuarioController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  // --- Lógica de acceso a la app ---
  Future<void> _entrarApp() async {
    String textoEscrito = _usuarioController.text.trim();
    String contrasena = _passwordController.text;

    // Evitamos que intenten entrar con los campos vacíos
    if (textoEscrito.isEmpty || contrasena.isEmpty) {
      _mostrarMensaje('Rellena todos los campos', Colors.orange);
      return;
    }

    setState(() { _estaCargando = true; });

    try {
      String? correoReal; 

      // Buscamos al cliente en Firestore, primero probamos por su teléfono
      var buscarTelefono = await FirebaseFirestore.instance
          .collection('clientes')
          .where('telefono', isEqualTo: textoEscrito)
          .get();

      if (buscarTelefono.docs.isNotEmpty) {
        correoReal = buscarTelefono.docs.first.data()['correo'];
      } else {
        // Si no lo encontramos por teléfono, probamos a buscar por el nombre exacto
        var buscarNombre = await FirebaseFirestore.instance
            .collection('clientes')
            .where('nombre', isEqualTo: textoEscrito)
            .get();

        if (buscarNombre.docs.isNotEmpty) {
          correoReal = buscarNombre.docs.first.data()['correo'];
        }
      }

      // Si después de buscar no hay ni rastro en la base de datos...
      if (correoReal == null) {
        _mostrarMensaje('Usuario o teléfono no encontrado', Colors.redAccent);
        setState(() { _estaCargando = false; });
        return;
      }

      // Iniciamos sesión en Firebase Auth con el correo que acabamos de averiguar
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: correoReal,
        password: contrasena,
      );

      // Si todo va bien y la pantalla sigue abierta, pasamos al Inicio
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const PantallaInicio()),
        );
      }
    } on FirebaseAuthException catch (e) {
      // Firebase nos avisa si la contraseña está mal o las credenciales no cuadran
      if (e.code == 'wrong-password' || e.code == 'invalid-credential') {
        _mostrarMensaje('La contraseña no es correcta', Colors.redAccent);
      } else {
        _mostrarMensaje('Error al iniciar sesión', Colors.redAccent);
      }
    } catch (e) {
      _mostrarMensaje('Ocurrió un error inesperado', Colors.redAccent);
    } finally {
      // Pase lo que pase, quitamos la ruedecita de carga al terminar
      if (mounted) {
        setState(() { _estaCargando = false; });
      }
    }
  }

  // --- Lógica para recuperar la contraseña ---
  // Muestra una ventanita (Dialog) para pedir el nombre o teléfono
  void _mostrarDialogoRecuperar() {
    final TextEditingController _recuperarController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text('Recuperar contraseña', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Introduce tu Teléfono o Nombre de usuario y te enviaremos un correo para cambiar la contraseña.',
              style: TextStyle(color: Colors.white70, fontSize: 14),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _recuperarController,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'Nombre o Teléfono',
                prefixIcon: Icon(Icons.search, color: Color(0xFFFFC107)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFFC107), foregroundColor: Colors.black),
            onPressed: () async {
              String input = _recuperarController.text.trim();
              if (input.isEmpty) return;
              
              Navigator.pop(context); // Cerramos la ventanita antes de procesar
              _procesarRecuperacion(input); 
            },
            child: const Text('Enviar'),
          ),
        ],
      ),
    );
  }

  // Busca el correo del usuario y le manda el enlace de Firebase para cambiar la clave
  Future<void> _procesarRecuperacion(String input) async {
    try {
      String? correoReal;
      
      var buscarTelefono = await FirebaseFirestore.instance.collection('clientes').where('telefono', isEqualTo: input).get();
      if (buscarTelefono.docs.isNotEmpty) {
        correoReal = buscarTelefono.docs.first.data()['correo'];
      } else {
        var buscarNombre = await FirebaseFirestore.instance.collection('clientes').where('nombre', isEqualTo: input).get();
        if (buscarNombre.docs.isNotEmpty) {
          correoReal = buscarNombre.docs.first.data()['correo'];
        }
      }

      if (correoReal == null) {
        _mostrarMensaje('No hemos encontrado ninguna cuenta con ese dato.', Colors.redAccent);
        return;
      }

      // Pedimos a Firebase que mande el correo automático
      await FirebaseAuth.instance.sendPasswordResetEmail(email: correoReal);
      _mostrarMensaje('¡Listo! Revisa tu bandeja de entrada o la carpeta de Spam.', Colors.green);
    } catch (e) {
      _mostrarMensaje('Ocurrió un error al intentar enviar el correo.', Colors.redAccent);
    }
  }

  // Método auxiliar para no repetir el código del SnackBar (mensajitos de abajo)
  void _mostrarMensaje(String texto, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(texto), backgroundColor: color),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Esto evita que el teclado aplaste el contenido cuando el usuario escribe
      resizeToAvoidBottomInset: true, 
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView( 
            padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // --- El Logo de la App ---
                // El tag 'logo_app' conecta con la pantalla Splash para hacer la animación de vuelo
                Hero(
                  tag: 'logo_app', 
                  child: Image.asset(
                    'assets/logo_osi_barber.png',
                    height: 300, 
                    fit: BoxFit.contain,
                  ),
                ),
                const SizedBox(height: 30), 
                
                // Dependiendo del estado, mostramos los botones o el formulario completo
                mostrarLogin ? _construirFormularioLogin(context) : _construirBotonesIniciales(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // --- Widgets separados para que el build no sea gigante ---

  Widget _construirBotonesIniciales() {
    return Column(
      children: [
        SizedBox(
          width: double.infinity, height: 50,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFFC107), foregroundColor: Colors.black),
            onPressed: () { setState(() => mostrarLogin = true); },
            child: const Text('INICIAR SESIÓN', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ),
        ),
        const SizedBox(height: 15),
        SizedBox(
          width: double.infinity, height: 50,
          child: OutlinedButton(
            style: OutlinedButton.styleFrom(foregroundColor: Colors.white, side: const BorderSide(color: Colors.white, width: 2)),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const PantallaRegistro()),
              );
            },
            child: const Text('REGISTRO', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ),
        ),
      ],
    );
  }

  Widget _construirFormularioLogin(BuildContext context) {
    return Column(
      children: [
        TextField(
          controller: _usuarioController, 
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            labelText: 'Nombre o Teléfono', 
            prefixIcon: Icon(Icons.person, color: Color(0xFFFFC107))
          ),
        ),
        const SizedBox(height: 15),
        TextField(
          controller: _passwordController, 
          obscureText: true, // Esto oculta los caracteres de la contraseña
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            labelText: 'Contraseña', 
            prefixIcon: Icon(Icons.lock, color: Color(0xFFFFC107))
          ),
        ),
        const SizedBox(height: 10),
        
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: _mostrarDialogoRecuperar,
            child: const Text('¿Has olvidado tu contraseña?', style: TextStyle(color: Color(0xFFFFC107), fontSize: 14)),
          ),
        ),
        const SizedBox(height: 15),
        
        SizedBox(
          width: double.infinity, height: 50,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFFC107), foregroundColor: Colors.black),
            // Si está cargando, desactivamos el botón (null) para que no le den 2 veces
            onPressed: _estaCargando ? null : _entrarApp, 
            child: _estaCargando 
              ? const CircularProgressIndicator(color: Colors.black) 
              : const Text('ENTRAR', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ),
        ),
        
        TextButton(
          onPressed: () { setState(() => mostrarLogin = false); },
          child: const Text('Volver', style: TextStyle(color: Colors.grey)),
        )
      ],
    );
  }
}