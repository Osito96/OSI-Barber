import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';

import '../core/app_routes.dart';
import '../core/app_theme.dart';
import '../core/constants.dart';
import 'pantalla_admin.dart';
import 'pantalla_bienvenida.dart';
import 'pantalla_chat.dart';
import 'pantalla_editar_perfil.dart';
import 'pantalla_estadisticas.dart';
import 'pantalla_gestion_cupones.dart';
import 'pantalla_gestion_servicios.dart';
import 'pantalla_mis_cupones.dart';
import 'pantalla_mis_citas.dart';
import 'pantalla_reserva.dart';

class PantallaInicio extends StatefulWidget {
  const PantallaInicio({super.key});

  @override
  State<PantallaInicio> createState() => _PantallaInicioState();
}

class _PantallaInicioState extends State<PantallaInicio> {
  bool _esAdmin = false;

  FirebaseFirestore get _db => FirebaseFirestore.instance;
  FirebaseAuth get _auth => FirebaseAuth.instance;

  @override
  void initState() {
    super.initState();
    _cargarRol();
  }

  Future<void> _cargarRol() async {
    final uid = _auth.currentUser!.uid;
    OneSignal.login(uid);
    final doc = await _db
        .collection(Colecciones.clientes).doc(uid).get();
    if (mounted && doc.exists) {
      setState(() => _esAdmin = doc.data()?[Campos.esAdmin] ?? false);
    }
  }

  Future<void> _cerrarSesion() async {
    await _auth.signOut();
    if (mounted) {
      Navigator.pushReplacement(context, AppRoutes.fade(const PantallaBienvenida()));
    }
  }

  void _abrirPantalla(Widget pantalla) {
    Navigator.push(context, AppRoutes.slide(pantalla));
  }

  void _cerrarMenuYAbrir(Widget pantalla) {
    Navigator.pop(context);
    _abrirPantalla(pantalla);
  }

  // ─── Dialog de perfil ───────────────────────────────────────────────────────

  void _mostrarPerfilUsuario(String uid) {
    showDialog(
      context: context,
      builder: (context) => StreamBuilder<DocumentSnapshot>(
        stream: _db
            .collection(Colecciones.clientes).doc(uid).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const AlertDialog(title: Text('Error al cargar perfil'));
          }
          final datos    = snapshot.data!.data() as Map<String, dynamic>;
          final nombre   = datos[Campos.nombre]     ?? 'Cliente';
          final telefono = datos[Campos.telefono]   ?? '';
          final fotob64  = datos[Campos.fotoPerfil] ?? '';
          final citasV   = _leerEntero(datos[Campos.citasV]);
          final citasX   = _leerEntero(datos[Campos.citasX]);

          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusXL),
              side: const BorderSide(color: AppTheme.gold, width: 1),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircleAvatar(
                  radius: 44,
                  backgroundColor: AppTheme.surfaceHigh,
                  backgroundImage: fotob64.isNotEmpty
                      ? MemoryImage(base64Decode(fotob64)) : null,
                  child: fotob64.isEmpty
                      ? Icon(Icons.person, size: 48, color: AppTheme.textHint) : null,
                ),
                const SizedBox(height: 16),
                Text(nombre, style: AppTheme.titleLarge),
                const SizedBox(height: 4),
                Text(telefono, style: AppTheme.bodySmall),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: Divider(),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _statColumn('Citas ✓', citasV.toString(), AppTheme.success),
                    _statColumn('Citas ✗', citasX.toString(), AppTheme.error),
                  ],
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.edit_outlined, size: 18),
                    label: const Text('Editar perfil'),
                    onPressed: () {
                      Navigator.pop(context);
                      _abrirPantalla(PantallaEditarPerfil(
                        uid:             uid,
                        nombreActual:    nombre,
                        telefonoActual:  telefono,
                        fotoBase64Actual: fotob64,
                      ));
                    },
                  ),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cerrar'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _statColumn(String label, String valor, Color color) {
    return Column(
      children: [
        Text(label, style: AppTheme.bodySmall),
        const SizedBox(height: 4),
        Text(valor, style: AppTheme.titleLarge.copyWith(color: color)),
      ],
    );
  }

  int _leerEntero(dynamic valor) {
    if (valor is int) return valor;
    if (valor is num) return valor.toInt();
    if (valor is String) return int.tryParse(valor) ?? 0;
    return 0;
  }

  // ─── Badge de notificaciones ────────────────────────────────────────────────

  Widget _iconoConBolita(Widget icono, String uid) {
    if (!_esAdmin) return _iconoConBolitaCliente(icono, uid);

    return StreamBuilder<QuerySnapshot>(
      stream: _db
          .collection(Colecciones.chats)
          .where(Campos.noLeidosAdmin, isGreaterThan: 0)
          .snapshots(),
      builder: (context, snapshot) {
        int total = 0;
        if (snapshot.hasData) {
          for (var doc in snapshot.data!.docs) {
            final data = doc.data() as Map<String, dynamic>;
            total += _leerEntero(data[Campos.noLeidosAdmin]);
          }
        }
        return _construirIconoConBadge(icono, total);
      },
    );
  }

  Widget _iconoConBolitaCliente(Widget icono, String uid) {
    return StreamBuilder<DocumentSnapshot>(
      stream: _db.collection(Colecciones.chats).doc(uid).snapshots(),
      builder: (context, snapshot) {
        int total = 0;
        if (snapshot.hasData && snapshot.data!.exists) {
          final data = snapshot.data!.data() as Map<String, dynamic>;
          total = _leerEntero(data[Campos.noLeidosCliente]);
        }
        return _construirIconoConBadge(icono, total);
      },
    );
  }

  Widget _construirIconoConBadge(Widget icono, int total) {
    return total > 0
        ? Badge(
            backgroundColor: AppTheme.error,
            label: Text('$total',
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11)),
            child: icono,
          )
        : icono;
  }

  // ─── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final usuario = _auth.currentUser;
    if (usuario == null) return const Scaffold();

    return Scaffold(
      appBar: AppBar(
        leading: Builder(
          builder: (ctx) => IconButton(
            icon: _iconoConBolita(const Icon(Icons.menu_rounded), usuario.uid),
            onPressed: () => Scaffold.of(ctx).openDrawer(),
          ),
        ),
        title: const Text('OSI BARBER'),
        actions: [
          StreamBuilder<DocumentSnapshot>(
            stream: _db
                .collection(Colecciones.clientes).doc(usuario.uid).snapshots(),
            builder: (context, snapshot) {
              String fotob64 = '';
              if (snapshot.hasData && snapshot.data!.exists) {
                fotob64 = (snapshot.data!.data() as Map<String, dynamic>)[Campos.fotoPerfil] ?? '';
              }
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: IconButton(
                  onPressed: () => _mostrarPerfilUsuario(usuario.uid),
                  icon: CircleAvatar(
                    radius: 16,
                    backgroundColor: AppTheme.gold,
                    backgroundImage: fotob64.isNotEmpty
                        ? MemoryImage(base64Decode(fotob64)) : null,
                    child: fotob64.isEmpty
                        ? Icon(Icons.person, size: 18, color: AppTheme.black) : null,
                  ),
                ),
              );
            },
          ),
        ],
      ),

      // ─── Drawer ─────────────────────────────────────────────────────────────
      drawer: Drawer(
        child: SafeArea(
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              // Cabecera
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
                decoration: const BoxDecoration(
                  color: AppTheme.black,
                  border: Border(bottom: BorderSide(color: AppTheme.divider, width: 0.5)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Center(
                      child: Image.asset('assets/logo_osi_barber2.png', height: 105),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'OSI BARBER',
                      style: AppTheme.displayMedium.copyWith(
                        color: AppTheme.textPrimary,
                        letterSpacing: 2,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              _drawerItem(Icons.home_outlined,          'Inicio',              () => Navigator.pop(context)),
              _drawerItem(Icons.calendar_today_outlined, 'Mis Citas',          () => _cerrarMenuYAbrir(const PantallaMisCitas())),
              _drawerItem(Icons.star_outline_rounded,    'Cupones',            () => _cerrarMenuYAbrir(const PantallaMisCupones())),
              if (!_esAdmin)
                ListTile(
                  leading: _iconoConBolita(const Icon(Icons.chat_bubble_outline_rounded), usuario.uid),
                  title: const Text('Chat con el barbero'),
                  onTap: () {
                    _cerrarMenuYAbrir(PantallaChat(
                      clienteId:          usuario.uid,
                      nombreDestinatario: 'OSI Barber',
                    ));
                  },
                ),
              if (_esAdmin) ...[
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Divider(),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: Text('ADMINISTRACIÓN',
                      style: AppTheme.bodySmall.copyWith(letterSpacing: 1.2)),
                ),
                ListTile(
                  leading: _iconoConBolita(
                      const Icon(Icons.admin_panel_settings_outlined), usuario.uid),
                  title: Text('Panel de barbero',
                      style: AppTheme.titleSmall.copyWith(color: AppTheme.gold)),
                  onTap: () => _cerrarMenuYAbrir(const PantallaAdmin()),
                ),
                _drawerItem(Icons.content_cut_outlined, 'Gestionar servicios', () => _cerrarMenuYAbrir(const PantallaGestionServicios())),
                _drawerItem(Icons.card_giftcard_outlined, 'Gestionar cupones', () => _cerrarMenuYAbrir(const PantallaGestionCupones())),
                _drawerItem(Icons.bar_chart_rounded,    'Panel de ingresos',  () => _cerrarMenuYAbrir(const PantallaEstadisticas())),
              ],
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Divider(),
              ),
              ListTile(
                leading: Icon(Icons.logout_rounded, color: AppTheme.error),
                title: Text('Cerrar sesión',
                    style: AppTheme.bodyLarge.copyWith(color: AppTheme.error)),
                onTap: _cerrarSesion,
              ),
            ],
          ),
        ),
      ),

      // ─── Body: lista de servicios ────────────────────────────────────────────
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 28, 20, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Servicios', style: AppTheme.displayMedium),
                const SizedBox(height: 4),
                Text('Elige y reserva tu cita', style: AppTheme.bodyMedium),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const Divider(height: 1),
          const SizedBox(height: 4),
          Expanded(child: _construirListaServicios(usuario.uid)),
        ],
      ),
    );
  }

  Widget _drawerItem(IconData icono, String titulo, VoidCallback onTap) {
    return ListTile(
      leading: Icon(icono),
      title: Text(titulo),
      onTap: onTap,
    );
  }

  // ─── Lista de servicios ──────────────────────────────────────────────────────

  Widget _construirListaServicios(String uid) {
    return StreamBuilder<QuerySnapshot>(
      stream: _db
          .collection(Colecciones.servicios).orderBy(Campos.orden).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Text('No hay servicios disponibles.', style: AppTheme.bodyMedium),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            final servicio = snapshot.data!.docs[index].data() as Map<String, dynamic>;
            final nombreS  = servicio[Campos.nombre] as String? ?? 'Servicio';
            final precio   = _leerEntero(servicio[Campos.precio]);
            final duracion = _leerEntero(servicio[Campos.duracion]);

            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _TarjetaServicio(
                nombre:   nombreS,
                precio:   precio,
                duracion: duracion,
                onTap: () => _abrirReserva(uid, nombreS, precio, duracion),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _abrirReserva(
    String uid,
    String nombreServicio,
    int precio,
    int duracion,
  ) async {
    final userDoc = await _db.collection(Colecciones.clientes).doc(uid).get();
    final nombreCliente = userDoc.data()?[Campos.nombre] ?? 'Cliente';

    if (!mounted) return;

    _abrirPantalla(PantallaReserva(
      nombreServicio: nombreServicio,
      precio:         precio,
      duracion:       duracion,
      nombreCliente:  nombreCliente,
    ));
  }
}

// ─── Widget de tarjeta de servicio ──────────────────────────────────────────────

class _TarjetaServicio extends StatelessWidget {
  final String   nombre;
  final int      precio;
  final int      duracion;
  final VoidCallback onTap;

  const _TarjetaServicio({
    required this.nombre,
    required this.precio,
    required this.duracion,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color:        AppTheme.surface,
      borderRadius: BorderRadius.circular(AppTheme.radiusL),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppTheme.radiusL),
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppTheme.radiusL),
            border: Border.all(color: AppTheme.divider, width: 0.5),
          ),
          padding: const EdgeInsets.all(20),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Nombre + duración
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(nombre, style: AppTheme.titleMedium),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(Icons.schedule_outlined, size: 13, color: AppTheme.textHint),
                        const SizedBox(width: 4),
                        Text('$duracion min', style: AppTheme.bodySmall),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              // Precio + CTA
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('$precio€', style: AppTheme.priceTag),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color:        AppTheme.gold,
                      borderRadius: BorderRadius.circular(AppTheme.radiusFull),
                    ),
                    child: Text(
                      'RESERVAR',
                      style: AppTheme.buttonLabel.copyWith(fontSize: 11),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
