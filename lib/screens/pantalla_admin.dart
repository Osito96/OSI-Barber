import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'pantalla_chat.dart';
import '../core/app_routes.dart';
import '../core/app_theme.dart';
import '../core/constants.dart';

class PantallaAdmin extends StatefulWidget {
  const PantallaAdmin({super.key});

  @override
  State<PantallaAdmin> createState() => _PantallaAdminState();
}

class _PantallaAdminState extends State<PantallaAdmin> {
  DateTime _diaVer = DateTime.now();

  FirebaseFirestore get _db => FirebaseFirestore.instance;

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Panel de barbero'),
          bottom: TabBar(
            tabs: [
              Tab(
                text: 'Agenda',
                icon: StreamBuilder<QuerySnapshot>(
                  stream: _db
                      .collection(Colecciones.citas)
                      .where(Campos.estado, isEqualTo: EstadoCita.pendiente)
                      .snapshots(),
                  builder: (ctx, snap) {
                    final total = snap.hasData ? snap.data!.docs.length : 0;
                    return total > 0
                        ? Badge(
                            backgroundColor: AppTheme.error,
                            label: Text('$total',
                                style: const TextStyle(
                                    color: Colors.white, fontSize: 10)),
                            child: const Icon(Icons.calendar_month_outlined),
                          )
                        : const Icon(Icons.calendar_month_outlined);
                  },
                ),
              ),
              const Tab(
                icon: Icon(Icons.emoji_events_outlined),
                text: 'Ranking',
              ),
              Tab(
                text: 'Mensajes',
                icon: StreamBuilder<QuerySnapshot>(
                  stream: _db
                      .collection(Colecciones.chats)
                      .where(Campos.noLeidosAdmin, isGreaterThan: 0)
                      .snapshots(),
                  builder: (ctx, snap) {
                    int total = 0;
                    if (snap.hasData) {
                      for (var doc in snap.data!.docs) {
                        final d = doc.data() as Map<String, dynamic>;
                        total += _leerEntero(d[Campos.noLeidosAdmin]);
                      }
                    }
                    return total > 0
                        ? Badge(
                            backgroundColor: AppTheme.error,
                            label: Text('$total',
                                style: const TextStyle(
                                    color: Colors.white, fontSize: 10)),
                            child: const Icon(Icons.forum_outlined),
                          )
                        : const Icon(Icons.forum_outlined);
                  },
                ),
              ),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _pestanaAgenda(),
            _pestanaRanking(),
            _pestanaChats(),
          ],
        ),
      ),
    );
  }

  // ─── Agenda ─────────────────────────────────────────────────────────────────

  Widget _pestanaAgenda() {
    final inicio = _inicioDia(_diaVer);
    final fin = _finDia(_diaVer);
    final idDia = _idDia(_diaVer);

    return Column(
      children: [
        // Selector de fecha
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: const BoxDecoration(
            color:  AppTheme.surface,
            border: Border(bottom: BorderSide(color: AppTheme.divider, width: 0.5)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Citas del ${_diaVer.day}/${_diaVer.month}/${_diaVer.year}',
                style: AppTheme.titleSmall,
              ),
              IconButton(
                icon: const Icon(Icons.edit_calendar_outlined),
                onPressed: () async {
                  final pick = await showDatePicker(
                    context: context,
                    initialDate: _diaVer,
                    firstDate: DateTime.now().subtract(const Duration(days: 60)),
                    lastDate:  DateTime.now().add(const Duration(days: 90)),
                  );
                  if (pick != null) setState(() => _diaVer = pick);
                },
              ),
            ],
          ),
        ),
        // Toggle bloqueo del día
        StreamBuilder<DocumentSnapshot>(
          stream: _db
              .collection(Colecciones.diasBloqueados).doc(idDia).snapshots(),
          builder: (ctx, snap) {
            final bloqueado = snap.hasData && snap.data!.exists
                ? snap.data![Campos.bloqueado] as bool? ?? false
                : false;
            return Container(
              color: bloqueado
                  ? AppTheme.error.withValues(alpha: 0.1)
                  : AppTheme.success.withValues(alpha: 0.05),
              child: SwitchListTile(
                title: Text(
                  bloqueado
                      ? '🚫 Día bloqueado — sin reservas'
                      : '✅ Día abierto — reservas activas',
                  style: AppTheme.titleSmall.copyWith(
                    color: bloqueado ? AppTheme.error : AppTheme.success,
                  ),
                ),
                value:    bloqueado,
                onChanged: (val) async {
                  if (val) {
                    await _db
                        .collection(Colecciones.diasBloqueados)
                        .doc(idDia).set({Campos.bloqueado: true});
                  } else {
                    await _db
                        .collection(Colecciones.diasBloqueados).doc(idDia).delete();
                  }
                },
              ),
            );
          },
        ),
        _panelCitasPendientes(),
        // Lista de citas
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: _db
                .collection(Colecciones.citas)
                .where(Campos.fecha, isGreaterThanOrEqualTo: Timestamp.fromDate(inicio))
                .where(Campos.fecha, isLessThanOrEqualTo:    Timestamp.fromDate(fin))
                .orderBy(Campos.fecha)
                .snapshots(),
            builder: (ctx, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (!snap.hasData || snap.data!.docs.isEmpty) {
                return Center(
                    child: Text('No hay citas este día.', style: AppTheme.bodyMedium));
              }
              return ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                itemCount: snap.data!.docs.length,
                itemBuilder: (ctx, i) {
                    final cita = snap.data!.docs[i];
                    final datos = cita.data() as Map<String, dynamic>;
                    final estado =
                        datos[Campos.estado] as String? ?? EstadoCita.pendiente;
                    final clienteId = datos[Campos.clienteId] as String;
                    final nombreCliente = datos[Campos.nombreCliente] as String? ??
                        'Cliente sin nombre';
                  final borderColor = estado == EstadoCita.pendiente
                      ? AppTheme.gold
                      : _colorEstado(estado);

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Container(
                      decoration: BoxDecoration(
                        color:        AppTheme.surface,
                        borderRadius: BorderRadius.circular(AppTheme.radiusL),
                        border: Border.all(color: borderColor, width: 1),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(datos[Campos.hora] as String? ?? '',
                                    style: AppTheme.titleLarge.copyWith(
                                        color: AppTheme.gold)),
                                _chipEstado(estado),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Icon(Icons.person_outline_rounded,
                                    color: AppTheme.gold, size: 16),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text('Cliente: $nombreCliente',
                                      style: AppTheme.titleSmall),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${datos[Campos.servicio] ?? 'Servicio'} · ${datos[Campos.duracion] ?? 0} min',
                              style: AppTheme.bodyMedium,
                            ),
                            if (estado == EstadoCita.pendiente) ...[
                              const SizedBox(height: 14),
                              const Divider(),
                              const SizedBox(height: 4),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                children: [
                                  _actionBtn(Icons.check_circle_outline, AppTheme.success,
                                      '¿Completada?', () => _actualizarCita(
                                          cita.id, clienteId, EstadoCita.completada, Campos.citasV)),
                                  _actionBtn(Icons.warning_amber_rounded, AppTheme.warning,
                                      '¿No asistió?', () => _actualizarCita(
                                          cita.id, clienteId, EstadoCita.ausente, Campos.citasX)),
                                  _actionBtn(Icons.delete_outline_rounded, AppTheme.error,
                                      'Cancelar', () => _confirmarBorrado(cita.id)),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _panelCitasPendientes() {
    return StreamBuilder<QuerySnapshot>(
      stream: _db
          .collection(Colecciones.citas)
          .where(Campos.estado, isEqualTo: EstadoCita.pendiente)
          .snapshots(),
      builder: (ctx, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const LinearProgressIndicator(minHeight: 2);
        }

        final conteosPorDia = <DateTime, int>{};
        if (snap.hasData) {
          for (final doc in snap.data!.docs) {
            final datos = doc.data() as Map<String, dynamic>;
            final fecha = _leerFecha(datos[Campos.fecha]);
            if (fecha == null) continue;
            final dia = DateTime(fecha.year, fecha.month, fecha.day);
            conteosPorDia[dia] = (conteosPorDia[dia] ?? 0) + 1;
          }
        }

        final dias = conteosPorDia.keys.toList()
          ..sort((a, b) => a.compareTo(b));

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
          decoration: const BoxDecoration(
            color: AppTheme.black,
            border: Border(
              bottom: BorderSide(color: AppTheme.divider, width: 0.5),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.pending_actions_outlined,
                      color: AppTheme.error, size: 18),
                  const SizedBox(width: 8),
                  Text('Citas pendientes', style: AppTheme.titleSmall),
                ],
              ),
              const SizedBox(height: 10),
              if (dias.isEmpty)
                Text('No hay citas pendientes', style: AppTheme.bodySmall)
              else
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: dias.map((dia) {
                      final seleccionada = _mismoDia(dia, _diaVer);
                      final total = conteosPorDia[dia] ?? 0;

                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(AppTheme.radiusFull),
                          onTap: () => setState(() => _diaVer = dia),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: seleccionada
                                  ? AppTheme.goldSoft
                                  : AppTheme.surface,
                              borderRadius: BorderRadius.circular(AppTheme.radiusFull),
                              border: Border.all(
                                color: seleccionada
                                    ? AppTheme.gold
                                    : AppTheme.divider,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: const BoxDecoration(
                                    color: AppTheme.error,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  '${_formatoDiaCorto(dia)} · $total',
                                  style: AppTheme.titleSmall.copyWith(
                                    color: seleccionada
                                        ? AppTheme.gold
                                        : AppTheme.textPrimary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _chipEstado(String estado) {
    final color = _colorEstado(estado);
    final label = _textoEstado(estado);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color:        color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(AppTheme.radiusFull),
        border:       Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(label,
          style: AppTheme.bodySmall.copyWith(
              color: color, fontWeight: FontWeight.w600)),
    );
  }

  Color _colorEstado(String estado) {
    if (estado == EstadoCita.completada) return AppTheme.success;
    if (estado == EstadoCita.ausente) return AppTheme.warning;
    return AppTheme.textHint;
  }

  String _textoEstado(String estado) {
    if (estado == EstadoCita.completada) return 'Completada';
    if (estado == EstadoCita.ausente) return 'No presentado';
    return 'Pendiente';
  }

  int _leerEntero(dynamic valor) {
    if (valor is int) return valor;
    if (valor is num) return valor.toInt();
    if (valor is String) return int.tryParse(valor) ?? 0;
    return 0;
  }

  DateTime? _leerFecha(dynamic valor) {
    if (valor is Timestamp) return valor.toDate();
    if (valor is DateTime) return valor;
    return null;
  }

  DateTime _inicioDia(DateTime fecha) {
    return DateTime(fecha.year, fecha.month, fecha.day, 0, 0);
  }

  DateTime _finDia(DateTime fecha) {
    return DateTime(fecha.year, fecha.month, fecha.day, 23, 59);
  }

  String _idDia(DateTime fecha) {
    return '${fecha.year}-${fecha.month.toString().padLeft(2, '0')}-${fecha.day.toString().padLeft(2, '0')}';
  }

  String _formatoDiaCorto(DateTime fecha) {
    final dia = fecha.day.toString().padLeft(2, '0');
    final mes = fecha.month.toString().padLeft(2, '0');
    return '$dia/$mes';
  }

  bool _mismoDia(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  Widget _actionBtn(IconData icono, Color color, String tooltip, VoidCallback onTap) {
    return Tooltip(
      message: tooltip,
      child: IconButton(
        icon:      Icon(icono, color: color, size: 28),
        onPressed: onTap,
      ),
    );
  }

  // ─── Ranking ─────────────────────────────────────────────────────────────────

  Widget _pestanaRanking() {
    return StreamBuilder<QuerySnapshot>(
      stream: _db
          .collection(Colecciones.clientes)
          .orderBy(Campos.citasV, descending: true)
          .snapshots(),
      builder: (ctx, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snap.hasData || snap.data!.docs.isEmpty) {
          return Center(child: Text('No hay clientes.', style: AppTheme.bodyMedium));
        }
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: snap.data!.docs.length,
          itemBuilder: (ctx, i) {
            final c      = snap.data!.docs[i].data() as Map<String, dynamic>;
            final nombre = c[Campos.nombre] as String? ?? 'Desconocido';
            final citasV = _leerEntero(c[Campos.citasV]);
            final citasX = _leerEntero(c[Campos.citasX]);

            Widget posicion;
            if (i == 0) posicion = const Icon(Icons.workspace_premium, color: AppTheme.gold, size: 28);
            else if (i == 1) posicion = const Icon(Icons.workspace_premium, color: Color(0xFFC0C0C0), size: 28);
            else if (i == 2) posicion = const Icon(Icons.workspace_premium, color: Color(0xFFCD7F32), size: 28);
            else posicion = Text('#${i + 1}',
                style: AppTheme.bodyMedium.copyWith(fontWeight: FontWeight.w700));

            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color:        AppTheme.surface,
                  borderRadius: BorderRadius.circular(AppTheme.radiusM),
                  border:       Border.all(color: AppTheme.divider, width: 0.5),
                ),
                child: Row(
                  children: [
                    SizedBox(width: 36, child: Center(child: posicion)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(nombre, style: AppTheme.titleSmall),
                          Text(c[Campos.telefono] ?? '---', style: AppTheme.bodySmall),
                        ],
                      ),
                    ),
                    Row(
                      children: [
                        Icon(Icons.check_circle_outline,
                            color: AppTheme.success, size: 16),
                        const SizedBox(width: 3),
                        Text('$citasV',
                            style: AppTheme.titleSmall.copyWith(color: AppTheme.success)),
                        const SizedBox(width: 14),
                        Icon(Icons.cancel_outlined, color: AppTheme.error, size: 16),
                        const SizedBox(width: 3),
                        Text('$citasX',
                            style: AppTheme.titleSmall.copyWith(color: AppTheme.error)),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // ─── Chats ────────────────────────────────────────────────────────────────────

  Widget _pestanaChats() {
    return StreamBuilder<QuerySnapshot>(
      stream: _db
          .collection(Colecciones.chats)
          .orderBy(Campos.timestamp, descending: true)
          .snapshots(),
      builder: (ctx, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snap.hasData || snap.data!.docs.isEmpty) {
          return Center(child: Text('No hay mensajes.', style: AppTheme.bodyMedium));
        }
        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: snap.data!.docs.length,
          itemBuilder: (ctx, i) {
            final chat         = snap.data!.docs[i].data() as Map<String, dynamic>;
            final clienteId    = chat[Campos.clienteId] as String;
            final ultimoMsg    = chat[Campos.ultimoMensaje] as String? ?? '';
            final noLeidos     = _leerEntero(chat[Campos.noLeidosAdmin]);

            return StreamBuilder<DocumentSnapshot>(
              stream: _db.collection(Colecciones.clientes).doc(clienteId).snapshots(),
              builder: (ctx, clienteSnap) {
                final datosCliente = clienteSnap.hasData && clienteSnap.data!.exists
                    ? clienteSnap.data!.data() as Map<String, dynamic>
                    : <String, dynamic>{};
                final nombre = (datosCliente[Campos.nombre] as String?) ??
                    (chat[Campos.nombreCliente] as String?) ??
                    'Cliente';
                final foto = (datosCliente[Campos.fotoPerfil] as String?) ??
                    (chat[Campos.fotoPerfil] as String?) ??
                    '';

                return _tarjetaChat(
                  clienteId: clienteId,
                  nombre: nombre,
                  foto: foto,
                  ultimoMensaje: ultimoMsg,
                  noLeidos: noLeidos,
                );
              },
            );
          },
        );
      },
    );
  }

  // ─── Helpers ─────────────────────────────────────────────────────────────────

  Widget _tarjetaChat({
    required String clienteId,
    required String nombre,
    required String foto,
    required String ultimoMensaje,
    required int noLeidos,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        tileColor: AppTheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusM),
          side: const BorderSide(color: AppTheme.divider, width: 0.5),
        ),
        leading: CircleAvatar(
          radius: 24,
          backgroundColor: AppTheme.gold,
          backgroundImage: foto.isNotEmpty ? MemoryImage(base64Decode(foto)) : null,
          child: foto.isEmpty ? Icon(Icons.person, color: AppTheme.black) : null,
        ),
        title: Text(
          nombre,
          style: AppTheme.titleSmall.copyWith(
            fontWeight: noLeidos > 0 ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
        subtitle: Text(
          ultimoMensaje,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTheme.bodySmall.copyWith(
            color: noLeidos > 0 ? AppTheme.textSecond : AppTheme.textHint,
          ),
        ),
        trailing: noLeidos > 0
            ? Badge(
                backgroundColor: AppTheme.gold,
                label: Text('$noLeidos',
                    style: TextStyle(
                        color: AppTheme.black,
                        fontWeight: FontWeight.bold,
                        fontSize: 11)),
                child: Icon(Icons.chevron_right_rounded, color: AppTheme.textHint),
              )
            : Icon(Icons.chevron_right_rounded, color: AppTheme.textHint),
        onTap: () => Navigator.push(
          context,
          AppRoutes.slide(PantallaChat(
            clienteId: clienteId,
            nombreDestinatario: nombre,
          )),
        ),
      ),
    );
  }

  Future<void> _actualizarCita(
      String citaId, String clienteId, String nuevoEstado, String campo) async {
    await _db
        .collection(Colecciones.citas).doc(citaId)
        .update({Campos.estado: nuevoEstado});
    await _db
        .collection(Colecciones.clientes).doc(clienteId)
        .update({campo: FieldValue.increment(1)});
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(nuevoEstado == EstadoCita.completada
            ? '✅ Cita completada. Punto sumado.'
            : '⚠️ Falta registrada.'),
        backgroundColor: nuevoEstado == EstadoCita.completada
            ? AppTheme.success : AppTheme.warning,
      ));
    }
  }

  void _confirmarBorrado(String citaId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Cancelar cita?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Se borrará y el hueco quedará libre.'),
            const SizedBox(height: 24),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.error,
                foregroundColor: AppTheme.textPrimary,
                minimumSize: const Size(double.infinity, 44),
              ),
              onPressed: () async {
                await _db.collection(Colecciones.citas).doc(citaId).delete();
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: const Text('Cancelar cita'),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Volver'),
            ),
          ],
        ),
      ),
    );
  }
}
