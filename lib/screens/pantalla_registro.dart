import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../core/app_routes.dart';
import '../core/app_theme.dart';
import '../core/constants.dart';
import '../utils/ui_utils.dart';
import 'pantalla_inicio.dart';

class PantallaRegistro extends StatefulWidget {
  const PantallaRegistro({super.key});

  @override
  State<PantallaRegistro> createState() => _PantallaRegistroState();
}

class _PantallaRegistroState extends State<PantallaRegistro> {
  final _nombreCtrl   = TextEditingController();
  final _telefonoCtrl = TextEditingController();
  final _emailCtrl    = TextEditingController();
  final _passCtrl     = TextEditingController();

  bool _estaCargando = false;
  bool _verPassword  = false;

  FirebaseFirestore get _db => FirebaseFirestore.instance;
  FirebaseAuth get _auth => FirebaseAuth.instance;

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _telefonoCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _registrarCliente() async {
    final nombre   = _nombreCtrl.text.trim();
    final telefono = _telefonoCtrl.text.trim();
    final email    = _emailCtrl.text.trim();
    final password = _passCtrl.text;

    if (nombre.isEmpty || telefono.isEmpty || email.isEmpty || password.isEmpty) {
      _msg('Rellena todos los campos', AppTheme.warning); return;
    }
    if (telefono.length != 9) {
      _msg('El teléfono debe tener 9 números', AppTheme.warning); return;
    }
    if (!email.contains('@') || !email.contains('.')) {
      _msg('Introduce un correo válido', AppTheme.warning); return;
    }
    if (password.length < 6) {
      _msg('La contraseña debe tener al menos 6 caracteres', AppTheme.warning); return;
    }

    setState(() => _estaCargando = true);
    try {
      final byTelefono = await _db
          .collection(Colecciones.clientes).where(Campos.telefono, isEqualTo: telefono).get();
      if (byTelefono.docs.isNotEmpty) {
        _msg('Este teléfono ya está registrado', AppTheme.error);
        setState(() => _estaCargando = false); return;
      }
      final byNombre = await _db
          .collection(Colecciones.clientes).where(Campos.nombre, isEqualTo: nombre).get();
      if (byNombre.docs.isNotEmpty) {
        _msg('Este nombre ya está en uso', AppTheme.error);
        setState(() => _estaCargando = false); return;
      }

      final cred = await _auth
          .createUserWithEmailAndPassword(email: email, password: password);

      await _db
          .collection(Colecciones.clientes).doc(cred.user!.uid).set({
        Campos.nombre:    nombre,
        Campos.telefono:  telefono,
        Campos.correo:    email,
        Campos.citasV:    0,
        Campos.citasX:    0,
        Campos.esAdmin:   false,
        Campos.fechaRegistro: DateTime.now(),
      });

      if (mounted) Navigator.pushReplacement(context, AppRoutes.fade(const PantallaInicio()));
    } on FirebaseAuthException catch (e) {
      if (e.code == 'email-already-in-use') {
        _msg('Este correo ya está registrado', AppTheme.error);
      } else if (e.code == 'weak-password') {
        _msg('La contraseña es muy débil', AppTheme.error);
      } else {
        _msg('Error al registrar, inténtalo de nuevo', AppTheme.error);
      }
    } catch (_) {
      _msg('Ocurrió un error inesperado', AppTheme.error);
    } finally {
      if (mounted) setState(() => _estaCargando = false);
    }
  }

  void _msg(String t, Color c) => UiUtils.mostrarMensaje(context, t, c);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(leading: const BackButton()),
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 8),
              Text('Crear cuenta', style: AppTheme.displayMedium),
              const SizedBox(height: 6),
              Text('Únete y empieza a reservar', style: AppTheme.bodyMedium),
              const SizedBox(height: 36),

              TextField(
                controller: _nombreCtrl,
                maxLength: 15,
                style: TextStyle(color: AppTheme.textPrimary),
                decoration: const InputDecoration(
                  labelText: 'Nombre de usuario',
                  prefixIcon: Icon(Icons.badge_outlined),
                  counterText: '',
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _telefonoCtrl,
                keyboardType: TextInputType.number,
                maxLength: 9,
                style: TextStyle(color: AppTheme.textPrimary),
                decoration: const InputDecoration(
                  labelText: 'Teléfono (9 dígitos)',
                  prefixIcon: Icon(Icons.phone_outlined),
                  counterText: '',
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _emailCtrl,
                keyboardType: TextInputType.emailAddress,
                style: TextStyle(color: AppTheme.textPrimary),
                decoration: const InputDecoration(
                  labelText: 'Correo electrónico',
                  prefixIcon: Icon(Icons.mail_outline_rounded),
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _passCtrl,
                obscureText: !_verPassword,
                maxLength: 20,
                style: TextStyle(color: AppTheme.textPrimary),
                decoration: InputDecoration(
                  labelText: 'Contraseña (mín. 6 caracteres)',
                  prefixIcon: const Icon(Icons.lock_outline_rounded),
                  counterText: '',
                  suffixIcon: IconButton(
                    icon: Icon(
                      _verPassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                      color: AppTheme.textHint, size: 20,
                    ),
                    onPressed: () => setState(() => _verPassword = !_verPassword),
                  ),
                ),
              ),
              const SizedBox(height: 32),

              ElevatedButton(
                onPressed: _estaCargando ? null : _registrarCliente,
                child: _estaCargando
                    ? SizedBox(
                        height: 20, width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.black),
                      )
                    : const Text('CREAR CUENTA'),
              ),
              const SizedBox(height: 12),
              Center(
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Ya tengo cuenta'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
