import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../core/app_routes.dart';
import '../core/app_theme.dart';
import '../core/constants.dart';
import '../utils/ui_utils.dart';
import 'pantalla_bienvenida.dart';

class PantallaEditarPerfil extends StatefulWidget {
  final String  uid;
  final String  nombreActual;
  final String  telefonoActual;
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
  late TextEditingController _nombreCtrl;
  late TextEditingController _telefonoCtrl;
  bool    _guardando           = false;
  File?   _imagenSeleccionada;
  String? _nuevaFotoBase64;

  FirebaseFirestore get _db => FirebaseFirestore.instance;
  FirebaseAuth get _auth => FirebaseAuth.instance;

  @override
  void initState() {
    super.initState();
    _nombreCtrl   = TextEditingController(text: widget.nombreActual);
    _telefonoCtrl = TextEditingController(text: widget.telefonoActual);
  }

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _telefonoCtrl.dispose();
    super.dispose();
  }

  Future<void> _seleccionarImagen() async {
    final XFile? imagen = await ImagePicker()
        .pickImage(source: ImageSource.gallery, imageQuality: 50);
    if (imagen != null) {
      final archivo = File(imagen.path);
      final bytes   = await archivo.readAsBytes();
      setState(() {
        _imagenSeleccionada = archivo;
        _nuevaFotoBase64    = base64Encode(bytes);
      });
    }
  }

  Future<void> _guardarCambios() async {
    final nombre   = _nombreCtrl.text.trim();
    final telefono = _telefonoCtrl.text.trim();
    if (nombre.isEmpty || telefono.isEmpty) {
      _msg('Rellena todos los campos', AppTheme.warning); return;
    }
    if (telefono.length != 9) {
      _msg('El teléfono debe tener 9 números', AppTheme.warning); return;
    }
    setState(() => _guardando = true);
    try {
      final datos = <String, dynamic>{
        Campos.nombre:   nombre,
        Campos.telefono: telefono,
      };
      if (_nuevaFotoBase64 != null) datos[Campos.fotoPerfil] = _nuevaFotoBase64;
      await _db
          .collection(Colecciones.clientes).doc(widget.uid).update(datos);
      _msg('¡Perfil actualizado!', AppTheme.success);
      if (mounted) Navigator.pop(context);
    } catch (_) {
      _msg('Error al actualizar el perfil', AppTheme.error);
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  void _confirmarBorrarCuenta() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('¿Eliminar cuenta?',
            style: AppTheme.titleMedium.copyWith(color: AppTheme.error)),
        content: const Text(
            'Perderás tus puntos, historial y reservas pendientes. Acción irreversible.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.error,
              foregroundColor: AppTheme.textPrimary,
              minimumSize: const Size(120, 44),
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              await _ejecutarBorradoTotal();
            },
            child: const Text('Sí, eliminar todo'),
          ),
        ],
      ),
    );
  }

  Future<void> _ejecutarBorradoTotal() async {
    setState(() => _guardando = true);
    try {
      final usuario = _auth.currentUser;
      if (usuario != null) {
        await _db
            .collection(Colecciones.clientes).doc(usuario.uid).delete();
        await usuario.delete();
        if (mounted) {
          Navigator.pushAndRemoveUntil(
            context,
            AppRoutes.fade(const PantallaBienvenida()),
            (_) => false,
          );
        }
      }
    } on FirebaseAuthException catch (e) {
      if (e.code == 'requires-recent-login') {
        _msg('Por seguridad, cierra sesión y vuelve a entrar para eliminar tu cuenta',
            AppTheme.warning);
      } else {
        _msg('Error al borrar la cuenta', AppTheme.error);
      }
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  void _msg(String t, Color c) => UiUtils.mostrarMensaje(context, t, c);

  // ─── UI ─────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mi perfil')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(28),
          child: Column(
            children: [
              // ─── Foto de perfil ──────────────────────────────────────────
              Center(
                child: GestureDetector(
                  onTap: _guardando ? null : _seleccionarImagen,
                  child: Stack(
                    alignment: Alignment.bottomRight,
                    children: [
                      CircleAvatar(
                        radius: 64,
                        backgroundColor: AppTheme.surfaceHigh,
                        backgroundImage: _imagenSeleccionada != null
                            ? FileImage(_imagenSeleccionada!)
                            : (widget.fotoBase64Actual != null &&
                                    widget.fotoBase64Actual!.isNotEmpty)
                                ? MemoryImage(base64Decode(widget.fotoBase64Actual!))
                                    as ImageProvider
                                : null,
                        child: (_imagenSeleccionada == null &&
                                (widget.fotoBase64Actual == null ||
                                    widget.fotoBase64Actual!.isEmpty))
                            ? Icon(Icons.person, size: 64, color: AppTheme.textHint)
                            : null,
                      ),
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: const BoxDecoration(
                          color:  AppTheme.gold,
                          shape:  BoxShape.circle,
                        ),
                        child: Icon(Icons.camera_alt_outlined,
                            color: AppTheme.black, size: 18),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 36),

              // ─── Formulario ──────────────────────────────────────────────
              TextField(
                controller: _nombreCtrl,
                maxLength:  15,
                style: TextStyle(color: AppTheme.textPrimary),
                decoration: const InputDecoration(
                  labelText:   'Nombre',
                  prefixIcon:  Icon(Icons.badge_outlined),
                  counterText: '',
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller:  _telefonoCtrl,
                keyboardType: TextInputType.number,
                maxLength:   9,
                style: TextStyle(color: AppTheme.textPrimary),
                decoration: const InputDecoration(
                  labelText:   'Teléfono',
                  prefixIcon:  Icon(Icons.phone_outlined),
                  counterText: '',
                ),
              ),
              const SizedBox(height: 28),

              ElevatedButton(
                onPressed: _guardando ? null : _guardarCambios,
                child: _guardando
                    ? SizedBox(
                        height: 20, width: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: AppTheme.black))
                    : const Text('GUARDAR CAMBIOS'),
              ),

              const SizedBox(height: 48),
              const Divider(),
              const SizedBox(height: 16),

              // ─── Zona peligrosa ──────────────────────────────────────────
              SizedBox(
                width: double.infinity, height: 50,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.error,
                    side: const BorderSide(color: AppTheme.error),
                  ),
                  icon: const Icon(Icons.delete_forever_outlined),
                  label: const Text('ELIMINAR MI CUENTA'),
                  onPressed: _guardando ? null : _confirmarBorrarCuenta,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
