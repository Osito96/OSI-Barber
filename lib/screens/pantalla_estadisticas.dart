import '../core/constants.dart';
import '../core/app_theme.dart';
import '../utils/ui_utils.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class PantallaEstadisticas extends StatefulWidget {
  const PantallaEstadisticas({super.key});

  @override
  State<PantallaEstadisticas> createState() => _PantallaEstadisticasState();
}

class _PantallaEstadisticasState extends State<PantallaEstadisticas> {
  bool     _cargando         = true;
  DateTime _fechaReferencia  = DateTime.now();

  FirebaseFirestore get _db => FirebaseFirestore.instance;

  double _ingresosDia    = 0;
  int    _citasDia       = 0;
  double _ingresosSemana = 0;
  int    _citasSemana    = 0;
  double _ingresosMes    = 0;
  int    _citasMes       = 0;
  String _servicioEstrella = 'Calculando…';

  @override
  void initState() {
    super.initState();
    _calcularEstadisticas();
  }

  Future<void> _elegirFecha() async {
    final pick = await showDatePicker(
      context:     context,
      initialDate: _fechaReferencia,
      firstDate:   DateTime(2023),
      lastDate:    DateTime.now(),
      builder:     UiUtils.temaDatePicker,
    );
    if (pick != null && pick != _fechaReferencia) {
      setState(() { _fechaReferencia = pick; _cargando = true; });
      _calcularEstadisticas();
    }
  }

  Future<void> _calcularEstadisticas() async {
    final f  = _fechaReferencia;
    final inicioDia    = DateTime(f.year, f.month, f.day, 0, 0, 0);
    final finDia       = DateTime(f.year, f.month, f.day, 23, 59, 59);
    final inicioSemana = inicioDia.subtract(Duration(days: f.weekday - 1));
    final finSemana    = inicioSemana.add(const Duration(days: 6, hours: 23, minutes: 59, seconds: 59));
    final inicioMes    = DateTime(f.year, f.month, 1, 0, 0, 0);
    final finMes       = DateTime(f.year, f.month + 1, 0, 23, 59, 59);
    final fechaMin     = inicioMes.isBefore(inicioSemana) ? inicioMes : inicioSemana;
    final fechaMax     = finMes.isAfter(finSemana)       ? finMes    : finSemana;

    try {
      final snap = await _db
          .collection(Colecciones.citas)
          .where(Campos.fecha, isGreaterThanOrEqualTo: Timestamp.fromDate(fechaMin))
          .where(Campos.fecha, isLessThanOrEqualTo:    Timestamp.fromDate(fechaMax))
          .get();

      double iDia = 0, iSemana = 0, iMes = 0;
      int    cDia = 0, cSemana = 0, cMes = 0;
      Map<String, int> conteo = {};

      for (var doc in snap.docs) {
        final data     = doc.data();
        if (data[Campos.estado] != EstadoCita.completada) continue;

        final fecha = _leerFecha(data[Campos.fecha]);
        if (fecha == null) continue;

        final precio   = _leerImporte(data[Campos.precio]);
        final servicio = data[Campos.servicio] as String? ?? 'Desconocido';

        if (fecha.isAfter(inicioMes.subtract(const Duration(seconds: 1))) &&
            fecha.isBefore(finMes.add(const Duration(seconds: 1)))) {
          iMes += precio; cMes++;
          conteo[servicio] = (conteo[servicio] ?? 0) + 1;
        }
        if (fecha.isAfter(inicioSemana.subtract(const Duration(seconds: 1))) &&
            fecha.isBefore(finSemana.add(const Duration(seconds: 1)))) {
          iSemana += precio; cSemana++;
        }
        if (fecha.isAfter(inicioDia.subtract(const Duration(seconds: 1))) &&
            fecha.isBefore(finDia.add(const Duration(seconds: 1)))) {
          iDia += precio; cDia++;
        }
      }

      String top = 'Ninguno aún'; int maxC = 0;
      conteo.forEach((k, v) { if (v > maxC) { maxC = v; top = k; } });

      if (mounted) {
        setState(() {
          _ingresosDia    = iDia;    _citasDia    = cDia;
          _ingresosSemana = iSemana; _citasSemana = cSemana;
          _ingresosMes    = iMes;    _citasMes    = cMes;
          _servicioEstrella = top;
          _cargando = false;
        });
      }
    } catch (e) {
      debugPrint('Error cargando estadísticas: $e');
      if (mounted) {
        setState(() => _cargando = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error al cargar datos.')),
        );
      }
    }
  }

  DateTime? _leerFecha(dynamic valor) {
    if (valor is Timestamp) return valor.toDate();
    if (valor is DateTime) return valor;
    return null;
  }

  double _leerImporte(dynamic valor) {
    if (valor is num) return valor.toDouble();
    if (valor is String) return double.tryParse(valor.replaceAll(',', '.')) ?? 0;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final esHoy = _fechaReferencia.day   == DateTime.now().day &&
                  _fechaReferencia.month == DateTime.now().month &&
                  _fechaReferencia.year  == DateTime.now().year;
    final textoFecha = UiUtils.formatearFecha(_fechaReferencia);

    return Scaffold(
      appBar: AppBar(title: const Text('Panel de ingresos')),
      body: Column(
        children: [
          // Selector de fecha
          Container(
            width:   double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color:  AppTheme.surface,
              border: Border(bottom: BorderSide(color: AppTheme.divider, width: 0.5)),
            ),
            child: OutlinedButton.icon(
              icon:    const Icon(Icons.calendar_month_outlined),
              label:   Text(esHoy ? 'Hoy — $textoFecha' : textoFecha),
              style:   OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 48),
              ),
              onPressed: _elegirFecha,
            ),
          ),
          Expanded(
            child: _cargando
                ? const Center(child: CircularProgressIndicator())
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Resumen financiero', style: AppTheme.displayMedium),
                        const SizedBox(height: 20),
                        _tarjeta(
                          titulo:   esHoy ? 'Facturación de hoy' : 'Facturación del día elegido',
                          ingresos: _ingresosDia,
                          citas:    _citasDia,
                          icono:    Icons.today_outlined,
                        ),
                        const SizedBox(height: 12),
                        _tarjeta(
                          titulo:   'Facturación de esa semana',
                          ingresos: _ingresosSemana,
                          citas:    _citasSemana,
                          icono:    Icons.date_range_outlined,
                        ),
                        const SizedBox(height: 12),
                        _tarjeta(
                          titulo:   'Facturación de ese mes',
                          ingresos: _ingresosMes,
                          citas:    _citasMes,
                          icono:    Icons.calendar_month_outlined,
                        ),
                        const SizedBox(height: 24),
                        // Servicio estrella
                        Container(
                          width:   double.infinity,
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color:        AppTheme.surface,
                            borderRadius: BorderRadius.circular(AppTheme.radiusL),
                            border:       Border.all(color: AppTheme.goldSoft, width: 1),
                          ),
                          child: Column(
                            children: [
                              Icon(Icons.star_rounded, color: AppTheme.gold, size: 36),
                              const SizedBox(height: 10),
                              Text('Servicio más popular del mes', style: AppTheme.bodyMedium),
                              const SizedBox(height: 6),
                              Text(_servicioEstrella,
                                  textAlign: TextAlign.center,
                                  style: AppTheme.titleLarge),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _tarjeta({
    required String   titulo,
    required double   ingresos,
    required int      citas,
    required IconData icono,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color:        AppTheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusL),
        border:       Border.all(color: AppTheme.divider, width: 0.5),
      ),
      child: Row(
        children: [
          Container(
            width: 48, height: 48,
            decoration: const BoxDecoration(
              color: AppTheme.goldSoft, shape: BoxShape.circle,
            ),
            child: Icon(icono, color: AppTheme.gold, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(titulo, style: AppTheme.bodyMedium),
                const SizedBox(height: 4),
                Text('${ingresos.toStringAsFixed(2)} €', style: AppTheme.priceTag),
                const SizedBox(height: 2),
                Text('$citas cita${citas != 1 ? 's' : ''} completada${citas != 1 ? 's' : ''}',
                    style: AppTheme.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
