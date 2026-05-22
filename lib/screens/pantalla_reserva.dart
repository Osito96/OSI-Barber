import '../core/constants.dart';
import '../core/app_theme.dart';
import '../utils/ui_utils.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class PantallaReserva extends StatefulWidget {
  final String nombreServicio;
  final int    precio;
  final int    duracion;
  final String nombreCliente;

  const PantallaReserva({
    super.key,
    required this.nombreServicio,
    required this.precio,
    required this.duracion,
    required this.nombreCliente,
  });

  @override
  State<PantallaReserva> createState() => _PantallaReservaState();
}

class _PantallaReservaState extends State<PantallaReserva> {
  DateTime? _fechaSeleccionada;
  String?   _horaSeleccionada;
  bool      _estaGuardando        = false;
  bool      _diaBloqueadoPorAdmin = false;
  List<String> _horasOcupadas     = [];

  final List<String> _horariosTotales = [
    '09:30', '09:45', '10:00', '10:15', '10:30', '10:45', '11:00', '11:15',
    '11:30', '11:45', '12:00', '12:15', '12:30', '12:45', '13:00', '13:15',
    '16:00', '16:15', '16:30', '16:45', '17:00', '17:15', '17:30', '17:45',
    '18:00', '18:15', '18:30', '18:45', '19:00', '19:15', '19:30', '19:45',
  ];

  FirebaseFirestore get _db => FirebaseFirestore.instance;
  FirebaseAuth get _auth => FirebaseAuth.instance;

  // ─── Lógica de reservas ──────────────────────────────────────────────────────

  Future<void> _obtenerCitasDelDia(DateTime fecha) async {
    setState(() {
      _horasOcupadas = [];
      _horaSeleccionada = null;
      _diaBloqueadoPorAdmin = false;
    });

    final idDia = _idDia(fecha);
    final docBloqueado = await _db
        .collection(Colecciones.diasBloqueados).doc(idDia).get();
    if (docBloqueado.exists && docBloqueado.data()?[Campos.bloqueado] == true) {
      setState(() => _diaBloqueadoPorAdmin = true);
      return;
    }

    final inicioDia = _inicioDia(fecha);
    final finDia = _finDia(fecha);
    final snapshot = await _db
        .collection(Colecciones.citas)
        .where(Campos.fecha, isGreaterThanOrEqualTo: Timestamp.fromDate(inicioDia))
        .where(Campos.fecha, isLessThanOrEqualTo:    Timestamp.fromDate(finDia))
        .get();

    final bloqueadas = <String>[];
    for (var doc in snapshot.docs) {
      final horaInicio   = doc[Campos.hora] as String;
      final duracionCita = _leerEntero(doc[Campos.duracion], valorDefecto: 30);
      final bloquesOcup = (duracionCita / 15).ceil();
      final indiceInicio = _horariosTotales.indexOf(horaInicio);
      if (indiceInicio != -1) {
        for (int i = 0; i < bloquesOcup; i++) {
          if (indiceInicio + i < _horariosTotales.length) {
            bloqueadas.add(_horariosTotales[indiceInicio + i]);
          }
        }
      }
    }
    setState(() => _horasOcupadas = bloqueadas);
  }

  List<String> get _horariosDisponibles {
    if (_fechaSeleccionada == null || _diaBloqueadoPorAdmin) return [];
    final ahora = DateTime.now();
    final esHoy = _mismoDia(_fechaSeleccionada!, ahora);
    final bloquesNecesarios = (widget.duracion / 15).ceil();
    return _horariosTotales.where((h) {
      final idx = _horariosTotales.indexOf(h);
      if (esHoy) {
        final partesHora = h.split(':');
        final hh = int.parse(partesHora[0]);
        final mm = int.parse(partesHora[1]);
        if (DateTime(ahora.year, ahora.month, ahora.day, hh, mm).isBefore(ahora)) return false;
      }
      for (int i = 0; i < bloquesNecesarios; i++) {
        final check = idx + i;
        if (check >= _horariosTotales.length) return false;
        if (_horasOcupadas.contains(_horariosTotales[check])) return false;
        if (i < bloquesNecesarios - 1) {
          final sigIdx = check + 1;
          if (sigIdx >= _horariosTotales.length) return false;
          final h1 = int.parse(_horariosTotales[check].split(':')[0]);
          final h2 = int.parse(_horariosTotales[sigIdx].split(':')[0]);
          if ((h2 - h1).abs() > 1) return false;
        }
      }
      return true;
    }).toList();
  }

  Future<void> _elegirFecha() async {
    DateTime? fecha = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate:   DateTime.now(),
      lastDate:    DateTime.now().add(const Duration(days: 30)),
      locale: const Locale('es', 'ES'),
      selectableDayPredicate: (d) =>
          d.weekday != DateTime.saturday && d.weekday != DateTime.sunday,
      builder: UiUtils.temaDatePicker,
    );
    if (fecha != null) {
      setState(() => _fechaSeleccionada = fecha);
      _obtenerCitasDelDia(fecha);
    }
  }

  Future<void> _confirmarReserva() async {
    if (_fechaSeleccionada == null || _horaSeleccionada == null || _diaBloqueadoPorAdmin) return;
    final confirma = await _mostrarConfirmacionReserva();
    if (!mounted) return;
    if (confirma != true) return;

    setState(() => _estaGuardando = true);
    try {
      final uid = _auth.currentUser!.uid;
      final inicioDia = _inicioDia(_fechaSeleccionada!);
      final finDia = _finDia(_fechaSeleccionada!);
      final consulta = await _db
          .collection(Colecciones.citas)
          .where(Campos.clienteId, isEqualTo: uid)
          .where(Campos.fecha, isGreaterThanOrEqualTo: Timestamp.fromDate(inicioDia))
          .where(Campos.fecha, isLessThanOrEqualTo:    Timestamp.fromDate(finDia))
          .get();
      final tieneCitaActiva = consulta.docs.any((doc) {
        final datos = doc.data();
        final estado = datos[Campos.estado] as String? ?? EstadoCita.pendiente;
        return estado != EstadoCita.completada;
      });
      if (tieneCitaActiva) {
        if (mounted) UiUtils.mostrarMensaje(context,
          'Ya tienes una cita para este día. Cancela la otra en "Mis Citas" si quieres cambiarla.',
          AppTheme.warning);
        setState(() => _estaGuardando = false); return;
      }
      final partes = _horaSeleccionada!.split(':');
      final fechaCita = DateTime(
        _fechaSeleccionada!.year, _fechaSeleccionada!.month, _fechaSeleccionada!.day,
        int.parse(partes[0]), int.parse(partes[1]),
      );
      await _db.collection(Colecciones.citas).add({
        Campos.clienteId:     uid,
        Campos.nombreCliente: widget.nombreCliente,
        Campos.servicio:      widget.nombreServicio,
        Campos.precio:        widget.precio,
        Campos.duracion:      widget.duracion,
        Campos.fecha:         Timestamp.fromDate(fechaCita),
        Campos.hora:          _horaSeleccionada,
        Campos.estado:        EstadoCita.pendiente,
        Campos.fechaCreacion: DateTime.now(),
      });
      if (mounted) {
        Navigator.pop(context);
        UiUtils.mostrarMensaje(context, '¡Cita reservada con éxito!', AppTheme.success);
      }
    } catch (e) {
      setState(() => _estaGuardando = false);
      debugPrint('🚨 ERROR FIREBASE: $e');
      if (mounted) UiUtils.mostrarMensaje(context, 'Error al reservar. Revisa la consola.', AppTheme.error);
    }
  }

  Future<bool?> _mostrarConfirmacionReserva() {
    final fecha = _fechaSeleccionada;
    final hora = _horaSeleccionada;
    if (fecha == null || hora == null) return Future.value(false);

    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirmar reserva'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('¿Estás seguro de reservar esta cita?', style: AppTheme.bodyMedium),
            const SizedBox(height: 16),
            _filaResumenConfirmacion(
              Icons.calendar_month_outlined,
              'Día',
              UiUtils.formatearFecha(fecha),
            ),
            const SizedBox(height: 10),
            _filaResumenConfirmacion(Icons.access_time_outlined, 'Hora', hora),
            const SizedBox(height: 10),
            _filaResumenConfirmacion(
              Icons.content_cut_outlined,
              'Servicio',
              widget.nombreServicio,
            ),
            const SizedBox(height: 22),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Confirmar'),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancelar'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _filaResumenConfirmacion(IconData icono, String etiqueta, String valor) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icono, color: AppTheme.gold, size: 18),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(etiqueta, style: AppTheme.bodySmall),
              const SizedBox(height: 2),
              Text(valor, style: AppTheme.titleSmall),
            ],
          ),
        ),
      ],
    );
  }

  int _leerEntero(dynamic valor, {int valorDefecto = 0}) {
    if (valor is int) return valor;
    if (valor is num) return valor.toInt();
    if (valor is String) return int.tryParse(valor) ?? valorDefecto;
    return valorDefecto;
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

  bool _mismoDia(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  // ─── UI ─────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Reservar cita')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              _resumenServicio(),
              const SizedBox(height: 28),
              _botonFecha(),
              const SizedBox(height: 28),
              _stepLabel(2, '2. Selecciona la hora'),
              const SizedBox(height: 12),
              Expanded(child: _cuerpoHoras()),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: (_estaGuardando || _diaBloqueadoPorAdmin || _horaSeleccionada == null)
                    ? null
                    : _confirmarReserva,
                child: _estaGuardando
                    ? SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.black))
                    : const Text('CONFIRMAR RESERVA'),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Widget _resumenServicio() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color:        AppTheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusL),
        border:       Border.all(color: AppTheme.divider, width: 0.5),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(widget.nombreServicio, style: AppTheme.titleMedium),
            const SizedBox(height: 5),
            Row(children: [
              Icon(Icons.schedule_outlined, size: 13, color: AppTheme.textHint),
              const SizedBox(width: 4),
              Text('${widget.duracion} min', style: AppTheme.bodySmall),
            ]),
          ]),
          Text('${widget.precio}€', style: AppTheme.priceTag),
        ],
      ),
    );
  }

  Widget _stepLabel(int num, String texto) {
    return Row(
      children: [
        Container(
          width: 24, height: 24,
          decoration: const BoxDecoration(color: AppTheme.gold, shape: BoxShape.circle),
          alignment: Alignment.center,
          child: Text('$num',
              style: AppTheme.bodySmall.copyWith(
                  color: AppTheme.black, fontWeight: FontWeight.bold)),
        ),
        const SizedBox(width: 10),
        Text(texto, style: AppTheme.titleSmall),
      ],
    );
  }

  Widget _botonFecha() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _stepLabel(1, '1. Selecciona el día'),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity, height: 50,
          child: OutlinedButton.icon(
            icon: const Icon(Icons.calendar_month_outlined),
            label: Text(
              _fechaSeleccionada == null
                  ? 'Toca para elegir fecha'
                  : '${_fechaSeleccionada!.day}/${_fechaSeleccionada!.month}/${_fechaSeleccionada!.year}',
            ),
            onPressed: _elegirFecha,
          ),
        ),
      ],
    );
  }

  Widget _cuerpoHoras() {
    if (_fechaSeleccionada == null) {
      return Center(child: Text('Selecciona un día (lunes a viernes)', style: AppTheme.bodyMedium));
    }
    if (_diaBloqueadoPorAdmin) {
      return Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.event_busy_outlined, color: AppTheme.error, size: 52),
          const SizedBox(height: 14),
          Text('Día no disponible',
              style: AppTheme.titleMedium.copyWith(color: AppTheme.error)),
          const SizedBox(height: 8),
          Text('La barbería está cerrada este día.',
              style: AppTheme.bodyMedium, textAlign: TextAlign.center),
        ]),
      );
    }
    final horariosDisponibles = _horariosDisponibles;
    if (horariosDisponibles.isEmpty) {
      return Center(
        child: Text('No hay huecos libres para este servicio hoy.',
            style: AppTheme.bodyMedium, textAlign: TextAlign.center),
      );
    }
    return GridView.builder(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4, childAspectRatio: 2.2,
        crossAxisSpacing: 8, mainAxisSpacing: 8,
      ),
      itemCount: horariosDisponibles.length,
      itemBuilder: (context, index) {
        final hora = horariosDisponibles[index];
        final sel  = _horaSeleccionada == hora;
        return GestureDetector(
          onTap: () => setState(() => _horaSeleccionada = hora),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
            decoration: BoxDecoration(
              color:        sel ? AppTheme.gold : AppTheme.surface,
              border:       Border.all(color: sel ? AppTheme.gold : AppTheme.divider),
              borderRadius: BorderRadius.circular(AppTheme.radiusM),
            ),
            alignment: Alignment.center,
            child: Text(
              hora,
              style: AppTheme.titleSmall.copyWith(
                color:      sel ? AppTheme.black : AppTheme.textSecond,
                fontSize:   13,
              ),
            ),
          ),
        );
      },
    );
  }
}
