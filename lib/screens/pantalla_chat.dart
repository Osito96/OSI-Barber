import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../core/app_theme.dart';
import '../core/constants.dart';

class PantallaChat extends StatefulWidget {
  final String clienteId;
  final String nombreDestinatario;

  const PantallaChat({
    super.key,
    required this.clienteId,
    required this.nombreDestinatario,
  });

  @override
  State<PantallaChat> createState() => _PantallaChatState();
}

class _PantallaChatState extends State<PantallaChat> {
  final TextEditingController _ctrlMensaje = TextEditingController();
  final String _miUid = FirebaseAuth.instance.currentUser!.uid;
  late bool _soyAdmin;
  late Stream<QuerySnapshot> _mensajesStream;

  FirebaseFirestore get _db => FirebaseFirestore.instance;

  @override
  void dispose() {
    _ctrlMensaje.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _soyAdmin = _miUid != widget.clienteId;
    _resetearNotificaciones();
    _mensajesStream = _db
        .collection(Colecciones.chats)
        .doc(widget.clienteId)
        .collection(Colecciones.mensajes)
        .orderBy(Campos.timestamp, descending: true)
        .snapshots();
  }

  void _resetearNotificaciones() {
    _db
        .collection(Colecciones.chats)
        .doc(widget.clienteId)
        .set({
      _campoNotificacionesPendientes(): 0,
    }, SetOptions(merge: true));
  }

  String _campoNotificacionesPendientes() {
    return _soyAdmin ? Campos.noLeidosAdmin : Campos.noLeidosCliente;
  }

  String _campoNotificacionesDestino() {
    return _soyAdmin ? Campos.noLeidosCliente : Campos.noLeidosAdmin;
  }

  Future<void> _enviarMensaje() async {
    if (_ctrlMensaje.text.trim().isEmpty) return;
    final texto = _ctrlMensaje.text.trim();
    _ctrlMensaje.clear();

    await _db
        .collection(Colecciones.chats)
        .doc(widget.clienteId)
        .collection(Colecciones.mensajes)
        .add({
      Campos.emisorId:  _miUid,
      Campos.texto:     texto,
      Campos.timestamp: FieldValue.serverTimestamp(),
    });

    final clienteDoc = await _db
        .collection(Colecciones.clientes).doc(widget.clienteId).get();
    final nombreCliente = clienteDoc.data()?[Campos.nombre]     ?? 'Cliente';
    final fotoPerfil    = clienteDoc.data()?[Campos.fotoPerfil] ?? '';

    await _db
        .collection(Colecciones.chats)
        .doc(widget.clienteId)
        .set({
      Campos.ultimoMensaje: texto,
      Campos.timestamp:     FieldValue.serverTimestamp(),
      Campos.clienteId:     widget.clienteId,
      Campos.nombreCliente: nombreCliente,
      Campos.fotoPerfil:    fotoPerfil,
      _campoNotificacionesDestino(): FieldValue.increment(1),
    }, SetOptions(merge: true));

    // Push notification
    String receptorId = '';
    String remitente  = _soyAdmin ? 'OSI Barber' : 'Nuevo mensaje';
    if (_soyAdmin) {
      receptorId = widget.clienteId;
    } else {
      final queryAdmin = await _db
          .collection(Colecciones.clientes)
          .where(Campos.esAdmin, isEqualTo: true).limit(1).get();
      if (queryAdmin.docs.isNotEmpty) receptorId = queryAdmin.docs.first.id;
    }
    if (receptorId.isEmpty) return;

    try {
      await http.post(
        Uri.parse('https://onesignal.com/api/v1/notifications'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Basic TU_CLAVE_REST_API_AQUI',
        },
        body: jsonEncode({
          'app_id':         'TU_ONESIGNAL_ID_APP_AQUI',
          'target_channel': 'push',
          'include_aliases': {'external_id': [receptorId]},
          'headings':  {'en': remitente, 'es': remitente},
          'contents':  {'en': texto,     'es': texto},
        }),
      );
    } catch (e) {
      debugPrint('Error al enviar push: $e');
    }
  }

  // ─── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: _tituloChat(),
        titleSpacing: 0,
        centerTitle: false,
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Lista de mensajes
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: _mensajesStream,
                builder: (context, snap) {
                  if (snap.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (!snap.hasData || snap.data!.docs.isEmpty) {
                    return Center(
                      child: Text('Escribe el primer mensaje…', style: AppTheme.bodyMedium),
                    );
                  }
                  return ListView.builder(
                    reverse: true,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    itemCount: snap.data!.docs.length,
                    itemBuilder: (context, index) {
                      final msg    = snap.data!.docs[index].data() as Map<String, dynamic>;
                      final soyYo  = msg[Campos.emisorId] == _miUid;
                      final fecha  = (msg[Campos.timestamp] as Timestamp?)?.toDate() ?? DateTime.now();

                      bool mostrarFecha = false;
                      if (index == snap.data!.docs.length - 1) {
                        mostrarFecha = true;
                      } else {
                        final anterior = snap.data!.docs[index + 1].data() as Map<String, dynamic>;
                        final fechaAnt = (anterior[Campos.timestamp] as Timestamp?)?.toDate();
                        if (fechaAnt != null &&
                            (fecha.day   != fechaAnt.day ||
                             fecha.month != fechaAnt.month ||
                             fecha.year  != fechaAnt.year)) {
                          mostrarFecha = true;
                        }
                      }

                      final burbuja = _burbuja(msg[Campos.texto] ?? '', soyYo, fecha);
                      if (mostrarFecha) {
                        return Column(children: [_cabeceraFecha(fecha), burbuja]);
                      }
                      return burbuja;
                    },
                  );
                },
              ),
            ),
            // Barra de input
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: const BoxDecoration(
                color: AppTheme.surface,
                border: Border(top: BorderSide(color: AppTheme.divider, width: 0.5)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _ctrlMensaje,
                      style: TextStyle(color: AppTheme.textPrimary),
                      decoration: InputDecoration(
                        hintText:    'Mensaje…',
                        hintStyle:   TextStyle(color: AppTheme.textHint),
                        filled:      true,
                        fillColor:   AppTheme.surfaceHigh,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 10),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppTheme.radiusFull),
                          borderSide:   BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppTheme.radiusFull),
                          borderSide:   BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Material(
                    color:  AppTheme.gold,
                    shape:  const CircleBorder(),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: _enviarMensaje,
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Icon(Icons.send_rounded, color: AppTheme.black, size: 20),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Auxiliares ─────────────────────────────────────────────────────────────

  Widget _tituloChat() {
    if (_soyAdmin) {
      return StreamBuilder<DocumentSnapshot>(
        stream: _db.collection(Colecciones.clientes).doc(widget.clienteId).snapshots(),
        builder: (context, snap) {
          final datos = snap.hasData && snap.data!.exists
              ? snap.data!.data() as Map<String, dynamic>
              : <String, dynamic>{};
          return _encabezadoChat(
            (datos[Campos.nombre] as String?) ?? widget.nombreDestinatario,
            (datos[Campos.fotoPerfil] as String?) ?? '',
          );
        },
      );
    }

    return StreamBuilder<QuerySnapshot>(
      stream: _db
          .collection(Colecciones.clientes)
          .where(Campos.esAdmin, isEqualTo: true)
          .limit(1)
          .snapshots(),
      builder: (context, snap) {
        final datos = snap.hasData && snap.data!.docs.isNotEmpty
            ? snap.data!.docs.first.data() as Map<String, dynamic>
            : <String, dynamic>{};
        return _encabezadoChat(
          widget.nombreDestinatario,
          (datos[Campos.fotoPerfil] as String?) ?? '',
        );
      },
    );
  }

  Widget _encabezadoChat(String nombre, String foto) {
    return Row(
      children: [
        CircleAvatar(
          radius: 18,
          backgroundColor: AppTheme.gold,
          backgroundImage: foto.isNotEmpty ? MemoryImage(base64Decode(foto)) : null,
          child: foto.isEmpty
              ? Icon(Icons.person, size: 19, color: AppTheme.black)
              : null,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            nombre,
            overflow: TextOverflow.ellipsis,
            style: AppTheme.titleSmall,
          ),
        ),
      ],
    );
  }

  Widget _cabeceraFecha(DateTime fecha) {
    final ahora = DateTime.now();
    final ayer  = ahora.subtract(const Duration(days: 1));
    String texto;
    if (fecha.year == ahora.year && fecha.month == ahora.month && fecha.day == ahora.day) {
      texto = 'Hoy';
    } else if (fecha.year == ayer.year && fecha.month == ayer.month && fecha.day == ayer.day) {
      texto = 'Ayer';
    } else {
      texto = '${fecha.day.toString().padLeft(2, '0')}/${fecha.month.toString().padLeft(2, '0')}/${fecha.year}';
    }
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 14),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
      decoration: BoxDecoration(
        color:        AppTheme.surfaceHigh,
        borderRadius: BorderRadius.circular(AppTheme.radiusFull),
      ),
      child: Text(texto,
          style: AppTheme.bodySmall.copyWith(color: AppTheme.textSecond)),
    );
  }

  Widget _burbuja(String texto, bool soyYo, DateTime fecha) {
    final hora  = '${fecha.hour.toString().padLeft(2, '0')}:${fecha.minute.toString().padLeft(2, '0')}';
    const miColor    = Color(0xFF3B2800); // fondo oscuro dorado
    const miTexto    = AppTheme.textPrimary;
    const otroColor  = AppTheme.surfaceHigh;
    const otroTexto  = AppTheme.textPrimary;

    return Align(
      alignment: soyYo ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        margin: EdgeInsets.only(
          bottom: 6,
          left:  soyYo ? 48 : 10,
          right: soyYo ? 10 : 48,
        ),
        padding: const EdgeInsets.only(left: 12, right: 10, top: 10, bottom: 6),
        decoration: BoxDecoration(
          color: soyYo ? miColor : otroColor,
          border: soyYo
              ? Border.all(color: AppTheme.gold.withValues(alpha: 0.25), width: 0.5)
              : null,
          borderRadius: BorderRadius.only(
            topLeft:     const Radius.circular(16),
            topRight:    const Radius.circular(16),
            bottomLeft:  soyYo ? const Radius.circular(16) : const Radius.circular(2),
            bottomRight: soyYo ? const Radius.circular(2)  : const Radius.circular(16),
          ),
        ),
        child: Wrap(
          alignment: WrapAlignment.end,
          crossAxisAlignment: WrapCrossAlignment.end,
          children: [
            Text(
              texto,
              style: TextStyle(
                color:      soyYo ? miTexto : otroTexto,
                fontSize:   15,
                fontWeight: soyYo ? FontWeight.w500 : FontWeight.w400,
              ),
            ),
            const SizedBox(width: 8),
            Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: Text(hora,
                  style: TextStyle(
                    color:    soyYo
                        ? AppTheme.gold.withValues(alpha: 0.6)
                        : AppTheme.textHint,
                    fontSize: 11,
                  )),
            ),
          ],
        ),
      ),
    );
  }
}
