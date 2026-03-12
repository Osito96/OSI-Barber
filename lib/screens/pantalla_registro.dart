import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'pantalla_inicio.dart';

class PantallaRegistro extends StatefulWidget {
  const PantallaRegistro({super.key});

  @override
  State<PantallaRegistro> createState() => _PantallaRegistroState();
}

class _PantallaRegistroState extends State<PantallaRegistro> {
  final TextEditingController _nombreController = TextEditingController();
  final TextEditingController _telefonoController = TextEditingController();
  final TextEditingController _emailController = TextEditingController(); 
  final TextEditingController _passwordController = TextEditingController();
  
  // Ruedecita de carga para que el usuario sepa que estamos procesando
  bool _estaCargando = false;

  // --- Lógica principal para registrar un cliente nuevo ---
  Future<void> _registrarCliente() async {
    String nombre = _nombreController.text.trim();
    String telefono = _telefonoController.text.trim();
    String email = _emailController.text.trim(); 
    String password = _passwordController.text;

    // 1. Filtros de seguridad básicos (que no nos metan datos en blanco o raros)
    if (nombre.isEmpty || telefono.isEmpty || email.isEmpty || password.isEmpty) {
      _mostrarMensaje('Por favor, rellena todos los campos', Colors.orange);
      return;
    }
    
    // Validamos que el teléfono sea de España (9 dígitos)
    if (telefono.length != 9) {
      _mostrarMensaje('El teléfono debe tener exactamente 9 números', Colors.orange);
      return;
    }

    // Un chequeo rápido para ver si el correo tiene pinta de correo real
    if (!email.contains('@') || !email.contains('.')) {
      _mostrarMensaje('Por favor, introduce un correo electrónico válido', Colors.orange);
      return;
    }

    // Firebase exige contraseñas de al menos 6 caracteres por seguridad
    if (password.length < 6) {
      _mostrarMensaje('La contraseña debe tener al menos 6 caracteres', Colors.orange);
      return;
    }

    // Activamos la ruedecita de carga mientras hablamos con la base de datos
    setState(() { _estaCargando = true; });

    try {
      // 2. Comprobamos si hay algún listillo intentando registrar un teléfono o nombre que ya existe
      var buscarTelefono = await FirebaseFirestore.instance
          .collection('clientes')
          .where('telefono', isEqualTo: telefono)
          .get();

      var buscarNombre = await FirebaseFirestore.instance
          .collection('clientes')
          .where('nombre', isEqualTo: nombre)
          .get();

      if (buscarTelefono.docs.isNotEmpty) {
        _mostrarMensaje('Este teléfono ya está registrado', Colors.redAccent);
        setState(() { _estaCargando = false; });
        return; 
      }

      if (buscarNombre.docs.isNotEmpty) {
        _mostrarMensaje('Este nombre ya está en uso, elige otro', Colors.redAccent);
        setState(() { _estaCargando = false; });
        return; 
      }

      // 3. Todo correcto. Creamos la cuenta oficial en Firebase Auth
      UserCredential credenciales = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(email: email, password: password);

      // 4. Creamos su "Ficha de cliente" en Firestore con los contadores a cero
      await FirebaseFirestore.instance.collection('clientes').doc(credenciales.user!.uid).set({
        'nombre': nombre,
        'telefono': telefono,
        'correo': email,
        'citasV': 0, // Puntos positivos
        'citasX': 0, // Faltas de asistencia
        'esAdmin': false, // Obviamente, un usuario nuevo no es el barbero
        'fecha_registro': DateTime.now(),
      });

      // 5. Si la pantalla sigue abierta, le damos la bienvenida pasándolo a la app principal
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const PantallaInicio()),
        );
      }

    } on FirebaseAuthException catch (e) {
      // Manejamos los errores típicos que nos devuelve Firebase
      if (e.code == 'email-already-in-use') {
         _mostrarMensaje('Este correo ya está registrado.', Colors.redAccent);
      } else if (e.code == 'weak-password') {
        _mostrarMensaje('La contraseña es muy débil.', Colors.redAccent);
      } else {
        _mostrarMensaje('Error al registrar: intenta de nuevo.', Colors.redAccent);
      }
    } catch (e) {
      _mostrarMensaje('Ocurrió un error inesperado', Colors.redAccent);
    } finally {
      // Pase lo que pase, apagamos la ruedecita de carga al terminar
      if (mounted) {
        setState(() { _estaCargando = false; });
      }
    }
  }

  // Método auxiliar para no repetir el código de los mensajitos inferiores
  void _mostrarMensaje(String texto, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(texto), backgroundColor: color),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true, 
      body: SafeArea(
        child: SingleChildScrollView( 
          padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 40),
          child: Column(
            children: [
              // --- Cabecera del formulario ---
              const Icon(Icons.person_add, size: 60, color: Colors.amber),
              const SizedBox(height: 15),
              const Text(
                'NUEVO CLIENTE',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 2),
              ),
              const SizedBox(height: 30),
              
              // --- Inputs del formulario ---
              TextField(
                controller: _nombreController,
                maxLength: 15, 
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'Nombre de Usuario', 
                  prefixIcon: Icon(Icons.badge, color: Colors.amber),
                  counterText: "", // Ocultamos el contador de caracteres para que quede más limpio
                ),
              ),
              const SizedBox(height: 15),
              
              TextField(
                controller: _telefonoController,
                keyboardType: TextInputType.number, 
                maxLength: 9, 
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'Teléfono', 
                  prefixIcon: Icon(Icons.phone, color: Colors.amber),
                  counterText: "",
                ),
              ),
              const SizedBox(height: 15),
              
              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress, 
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'Correo (Para recuperar contraseña)', 
                  prefixIcon: Icon(Icons.email, color: Colors.amber),
                  counterText: "",
                ),
              ),
              const SizedBox(height: 15),
              
              TextField(
                controller: _passwordController,
                obscureText: true, // Oculta la contraseña con asteriscos
                maxLength: 20, 
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'Contraseña (mín 6 letras/números)', 
                  prefixIcon: Icon(Icons.lock, color: Colors.amber),
                  counterText: "",
                ),
              ),
              const SizedBox(height: 35),
              
              // --- Botón de confirmación ---
              SizedBox(
                width: double.infinity, height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.amber, foregroundColor: Colors.black),
                  // Bloqueamos el botón si ya está cargando para evitar que creen 2 cuentas por darle rápido
                  onPressed: _estaCargando ? null : _registrarCliente,
                  child: _estaCargando 
                    ? const CircularProgressIndicator(color: Colors.black)
                    : const Text('CREAR CUENTA', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ),
              ),
              
              // Botón para echarse atrás al Login
              TextButton(
                onPressed: () { Navigator.pop(context); },
                child: const Text('Volver al Login', style: TextStyle(color: Colors.grey)),
              )
            ],
          ),
        ),
      ),
    );
  }
}