import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../core/app_routes.dart';
import '../core/app_theme.dart';
import '../core/constants.dart';
import '../utils/ui_utils.dart';
import 'pantalla_inicio.dart';
import 'pantalla_registro.dart';

class PantallaBienvenida extends StatefulWidget {
  const PantallaBienvenida({super.key});

  @override
  State<PantallaBienvenida> createState() => _PantallaBienvenidaState();
}

class _PantallaBienvenidaState extends State<PantallaBienvenida> {
  bool _mostrarLogin  = false;
  bool _estaCargando  = false;
  bool _verPassword   = false;

  final TextEditingController _usuarioCtrl  = TextEditingController();
  final TextEditingController _passwordCtrl = TextEditingController();

  FirebaseFirestore get _db => FirebaseFirestore.instance;
  FirebaseAuth get _auth => FirebaseAuth.instance;

  @override
  void dispose() {
    _usuarioCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  // ─── Lógica de acceso ───────────────────────────────────────────────────────

  Future<void> _entrarApp() async {
    final texto     = _usuarioCtrl.text.trim();
    final contrasena = _passwordCtrl.text;
    if (texto.isEmpty || contrasena.isEmpty) {
      _msg('Rellena todos los campos', AppTheme.warning); return;
    }
    setState(() => _estaCargando = true);
    try {
      final correoReal = await _buscarCorreoPorUsuario(texto);
      if (correoReal == null) {
        _msg('Usuario o teléfono no encontrado', AppTheme.error);
        setState(() => _estaCargando = false); return;
      }
      await _auth.signInWithEmailAndPassword(
          email: correoReal, password: contrasena);
      if (mounted) Navigator.pushReplacement(context, AppRoutes.fade(const PantallaInicio()));
    } on FirebaseAuthException catch (e) {
      if (e.code == 'wrong-password' || e.code == 'invalid-credential') {
        _msg('Contraseña incorrecta', AppTheme.error);
      } else {
        _msg('Error al iniciar sesión', AppTheme.error);
      }
    } catch (_) {
      _msg('Ocurrió un error inesperado', AppTheme.error);
    } finally {
      if (mounted) setState(() => _estaCargando = false);
    }
  }

  // ─── Recuperar contraseña ───────────────────────────────────────────────────

  void _mostrarDialogoRecuperar() {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Recuperar contraseña'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Introduce tu teléfono o nombre de usuario y te enviaremos un correo.',
              style: AppTheme.bodyMedium,
            ),
            const SizedBox(height: 20),
            TextField(
              controller: ctrl,
              decoration: const InputDecoration(
                labelText: 'Nombre o Teléfono',
                prefixIcon: Icon(Icons.search_rounded),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(minimumSize: const Size(100, 44)),
            onPressed: () async {
              final input = ctrl.text.trim();
              if (input.isEmpty) return;
              Navigator.pop(ctx);
              _procesarRecuperacion(input);
            },
            child: const Text('ENVIAR'),
          ),
        ],
      ),
    );
  }

  Future<void> _procesarRecuperacion(String input) async {
    try {
      final correoReal = await _buscarCorreoPorUsuario(input);
      if (correoReal == null) {
        _msg('No encontramos ninguna cuenta con ese dato', AppTheme.error); return;
      }
      await _auth.sendPasswordResetEmail(email: correoReal);
      _msg('¡Listo! Revisa tu correo o la carpeta Spam', AppTheme.success);
    } catch (_) {
      _msg('Error al enviar el correo', AppTheme.error);
    }
  }

  Future<String?> _buscarCorreoPorUsuario(String usuarioOTelefono) async {
    final porTelefono = await _db
        .collection(Colecciones.clientes)
        .where(Campos.telefono, isEqualTo: usuarioOTelefono)
        .limit(1)
        .get();

    if (porTelefono.docs.isNotEmpty) {
      return porTelefono.docs.first.data()[Campos.correo] as String?;
    }

    final porNombre = await _db
        .collection(Colecciones.clientes)
        .where(Campos.nombre, isEqualTo: usuarioOTelefono)
        .limit(1)
        .get();

    if (porNombre.docs.isNotEmpty) {
      return porNombre.docs.first.data()[Campos.correo] as String?;
    }

    return null;
  }

  void _msg(String t, Color c) => UiUtils.mostrarMensaje(context, t, c);

  // ─── UI ─────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
          child: Column(
            children: [
              const SizedBox(height: 28),
              // Logo con animación Hero heredada del splash
              Hero(
                tag: 'logo_app',
                child: Image.asset(
                  'assets/logo_osi_barber.png',
                  height: 160,
                  fit: BoxFit.contain,
                ),
              ),
              const SizedBox(height: 22),
              Text(
                'OSI BARBER',
                style: AppTheme.displayMedium.copyWith(letterSpacing: 5),
              ),
              const SizedBox(height: 8),
              Text('Barbería · Estilo · Confianza', style: AppTheme.bodyMedium),
              const SizedBox(height: 48),
              // Transición animada entre botones y formulario
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 320),
                transitionBuilder: (child, anim) => FadeTransition(
                  opacity: anim,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0, 0.04),
                      end:   Offset.zero,
                    ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOut)),
                    child: child,
                  ),
                ),
                child: _mostrarLogin
                    ? SizedBox(key: const ValueKey('form'),    child: _construirFormulario())
                    : SizedBox(key: const ValueKey('buttons'), child: _construirBotonesIniciales()),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _construirBotonesIniciales() {
    return Column(
      children: [
        ElevatedButton(
          onPressed: () => setState(() => _mostrarLogin = true),
          child: const Text('INICIAR SESIÓN'),
        ),
        const SizedBox(height: 14),
        OutlinedButton(
          onPressed: () => Navigator.push(context, AppRoutes.slide(const PantallaRegistro())),
          child: const Text('CREAR CUENTA'),
        ),
      ],
    );
  }

  Widget _construirFormulario() {
    return Column(
      children: [
        TextField(
          controller: _usuarioCtrl,
          style: TextStyle(color: AppTheme.textPrimary),
          decoration: const InputDecoration(
            labelText: 'Nombre o Teléfono',
            prefixIcon: Icon(Icons.person_outline_rounded),
          ),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _passwordCtrl,
          obscureText: !_verPassword,
          style: TextStyle(color: AppTheme.textPrimary),
          decoration: InputDecoration(
            labelText: 'Contraseña',
            prefixIcon: const Icon(Icons.lock_outline_rounded),
            suffixIcon: IconButton(
              icon: Icon(
                _verPassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                color: AppTheme.textHint,
                size: 20,
              ),
              onPressed: () => setState(() => _verPassword = !_verPassword),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: _mostrarDialogoRecuperar,
            child: const Text('¿Olvidaste tu contraseña?'),
          ),
        ),
        const SizedBox(height: 12),
        ElevatedButton(
          onPressed: _estaCargando ? null : _entrarApp,
          child: _estaCargando
              ? SizedBox(
                  height: 20, width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.black),
                )
              : const Text('ENTRAR'),
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: () => setState(() => _mostrarLogin = false),
          child: const Text('← Volver'),
        ),
      ],
    );
  }
}
