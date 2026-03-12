import 'dart:io';
import 'dart:convert'; 
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'pantalla_bienvenida.dart';

class PantallaEditarPerfil extends StatefulWidget {
  final String uid;
  final String nombreActual;
  final String telefonoActual;
  // Recibimos la foto actual en formato texto (Base64)
  final String? fotoBase64Actual; 

  const PantallaEditarPerfil({
    super.key,
    required this.uid,
    required this.nombreActual,
    required this.telefonoActual,
    this.fotoBase64Actual,
  });

  @override
  State<PantallaEditarPerfil> createState() => _PantallaEditarPerfilState();
}

class _PantallaEditarPerfilState extends State<PantallaEditarPerfil> {
  // Controladores para los campos de texto con los datos que ya tenía el usuario
  late TextEditingController _nombreCtrl;
  late TextEditingController _telefonoCtrl;
  
  // Para bloquear los botones mientras Firebase guarda los datos
  bool _guardando = false;
  
  // Aquí guardaremos la nueva foto si el usuario decide cambiarla
  File? _imagenSeleccionada; 
  String? _nuevaFotoBase64;

  @override
  void initState() {
    super.initState();
    _nombreCtrl = TextEditingController(text: widget.nombreActual);
    _telefonoCtrl = TextEditingController(text: widget.telefonoActual);
  }

  // --- Lógica para seleccionar y transformar la foto ---
  Future<void> _seleccionarImagen() async {
    // Abrimos la galería del móvil
    final ImagePicker picker = ImagePicker();
    final XFile? imagen = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 50, // Comprimimos al 50% para que el texto Base64 no sea gigantesco
    );

    if (imagen != null) {
      File archivoFisico = File(imagen.path);
      
      // La magia: Leemos los bytes de la foto y los transformamos a texto (Base64)
      List<int> bytesImagen = await archivoFisico.readAsBytes();
      String base64String = base64Encode(bytesImagen);

      setState(() {
        _imagenSeleccionada = archivoFisico;
        _nuevaFotoBase64 = base64String;
      });
    }
  }

  // --- Lógica para guardar los cambios en Firebase ---
  Future<void> _guardarCambios() async {
    String nuevoNombre = _nombreCtrl.text.trim();
    String nuevoTelefono = _telefonoCtrl.text.trim();

    // Validaciones básicas para que no nos dejen campos en blanco o teléfonos raros
    if (nuevoNombre.isEmpty || nuevoTelefono.isEmpty) {
      _mostrarMensaje('Rellena todos los campos', Colors.orange);
      return;
    }
    if (nuevoTelefono.length != 9) {
      _mostrarMensaje('El teléfono debe tener 9 números', Colors.orange);
      return;
    }

    setState(() { _guardando = true; });

    try {
      // Preparamos el "paquete" de datos a actualizar
      Map<String, dynamic> datosActualizados = {
        'nombre': nuevoNombre,
        'telefono': nuevoTelefono,
      };

      // Si el usuario eligió una foto nueva, la añadimos al paquete
      if (_nuevaFotoBase64 != null) {
        datosActualizados['fotoPerfil'] = _nuevaFotoBase64;
      }

      // Mandamos la orden a Firestore
      await FirebaseFirestore.instance.collection('clientes').doc(widget.uid).update(datosActualizados);

      _mostrarMensaje('¡Perfil actualizado con éxito!', Colors.green);
      
      // Volvemos a la pantalla anterior
      if (mounted) Navigator.pop(context);

    } catch (e) {
      _mostrarMensaje('Error al actualizar el perfil', Colors.redAccent);
    } finally {
      if (mounted) setState(() { _guardando = false; });
    }
  }

  // --- Lógica de peligro: Borrar la cuenta ---
  void _confirmarBorrarCuenta() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.black,
        title: const Text('¿Eliminar cuenta?', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
        content: const Text(
          'Perderás tus Citas V, tu historial y tus reservas pendientes. Esta acción es irreversible.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar', style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () async {
              Navigator.pop(context); // Cerramos la ventanita
              await _ejecutarBorradoTotal();
            },
            child: const Text('Sí, eliminar todo', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _ejecutarBorradoTotal() async {
    setState(() { _guardando = true; });

    try {
      User? usuario = FirebaseAuth.instance.currentUser;
      if (usuario != null) {
        // 1. Borramos su "ficha" de nuestra base de datos
        await FirebaseFirestore.instance.collection('clientes').doc(usuario.uid).delete();
        
        // 2. Borramos la cuenta de acceso de Firebase Auth
        await usuario.delete();
        
        // 3. Lo mandamos a la pantalla de bienvenida
        if (mounted) {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (context) => const PantallaBienvenida()),
            (Route<dynamic> route) => false, // Esto destruye todo el historial para que no pueda volver atrás
          );
        }
      }
    } on FirebaseAuthException catch (e) {
      // Firebase a veces pide que el usuario vuelva a iniciar sesión antes de borrar la cuenta por seguridad
      if (e.code == 'requires-recent-login') {
        _mostrarMensaje('Por seguridad, cierra sesión y vuelve a entrar para borrar tu cuenta', Colors.orange);
      } else {
        _mostrarMensaje('Error al borrar la cuenta', Colors.redAccent);
      }
    } finally {
      if (mounted) setState(() { _guardando = false; });
    }
  }

  // Método auxiliar para los mensajes inferiores
  void _mostrarMensaje(String texto, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(texto), backgroundColor: color),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('MI PERFIL', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.black,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(30),
          child: Column(
            children: [
              // --- Zona de la Foto de Perfil ---
              GestureDetector(
                onTap: _guardando ? null : _seleccionarImagen,
                child: Stack(
                  alignment: Alignment.bottomRight,
                  children: [
                    CircleAvatar(
                      radius: 60,
                      backgroundColor: Colors.grey[800],
                      // Lógica de visualización:
                      // 1. Si acaba de elegir una foto de la galería, mostramos el archivo.
                      // 2. Si no, pero tenía una foto en Firebase, la decodificamos de Base64 a Imagen.
                      // 3. Si no tiene nada de nada, mostramos el icono por defecto.
                      backgroundImage: _imagenSeleccionada != null
                          ? FileImage(_imagenSeleccionada!)
                          : (widget.fotoBase64Actual != null && widget.fotoBase64Actual!.isNotEmpty)
                              ? MemoryImage(base64Decode(widget.fotoBase64Actual!)) as ImageProvider
                              : null,
                      child: (_imagenSeleccionada == null && (widget.fotoBase64Actual == null || widget.fotoBase64Actual!.isEmpty))
                          ? const Icon(Icons.person, size: 60, color: Colors.white24)
                          : null,
                    ),
                    // Iconito superpuesto para indicar que se puede editar
                    const CircleAvatar(
                      radius: 18,
                      backgroundColor: Colors.amber,
                      child: Icon(Icons.camera_alt, color: Colors.black, size: 20),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 40),

              // --- Formulario de Datos ---
              TextField(
                controller: _nombreCtrl,
                maxLength: 15,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Nombre',
                  labelStyle: const TextStyle(color: Colors.amber),
                  enabledBorder: OutlineInputBorder(borderSide: const BorderSide(color: Colors.white24), borderRadius: BorderRadius.circular(10)),
                  focusedBorder: OutlineInputBorder(borderSide: const BorderSide(color: Colors.amber), borderRadius: BorderRadius.circular(10)),
                  prefixIcon: const Icon(Icons.badge, color: Colors.amber),
                  counterText: "",
                ),
              ),
              const SizedBox(height: 20),

              TextField(
                controller: _telefonoCtrl,
                keyboardType: TextInputType.number,
                maxLength: 9,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Teléfono',
                  labelStyle: const TextStyle(color: Colors.amber),
                  enabledBorder: OutlineInputBorder(borderSide: const BorderSide(color: Colors.white24), borderRadius: BorderRadius.circular(10)),
                  focusedBorder: OutlineInputBorder(borderSide: const BorderSide(color: Colors.amber), borderRadius: BorderRadius.circular(10)),
                  prefixIcon: const Icon(Icons.phone_android, color: Colors.amber),
                  counterText: "",
                ),
              ),
              const SizedBox(height: 30),

              // --- Botón de Guardar ---
              SizedBox(
                width: double.infinity, 
                height: 50, 
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.amber, 
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))
                  ), 
                  onPressed: _guardando ? null : _guardarCambios, 
                  child: _guardando 
                    ? const CircularProgressIndicator(color: Colors.black) 
                    : const Text('GUARDAR CAMBIOS', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 16))
                )
              ),
              
              const SizedBox(height: 50),
              const Divider(color: Colors.white24),
              const SizedBox(height: 20),
              
              // --- Botón de Peligro ---
              SizedBox(
                width: double.infinity, 
                height: 50, 
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.redAccent, 
                    side: const BorderSide(color: Colors.redAccent), 
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))
                  ), 
                  icon: const Icon(Icons.delete_forever), 
                  label: const Text('ELIMINAR MI CUENTA', style: TextStyle(fontWeight: FontWeight.bold)), 
                  onPressed: _guardando ? null : _confirmarBorrarCuenta
                )
              )
            ],
          ),
        ),
      ),
    );
  }
}