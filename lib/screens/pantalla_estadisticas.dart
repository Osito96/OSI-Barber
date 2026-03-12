import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class PantallaEstadisticas extends StatefulWidget {
  const PantallaEstadisticas({super.key});

  @override
  State<PantallaEstadisticas> createState() => _PantallaEstadisticasState();
}

class _PantallaEstadisticasState extends State<PantallaEstadisticas> {
  bool _cargando = true;
  
  // Guardamos el día que estamos consultando. Por defecto, al entrar es HOY.
  DateTime _fechaReferencia = DateTime.now(); 

  // Variables para almacenar los resultados que mostraremos en las tarjetas
  double _ingresosDia = 0;
  int _citasDia = 0;
  double _ingresosSemana = 0;
  int _citasSemana = 0;
  double _ingresosMes = 0;
  int _citasMes = 0;
  String _servicioEstrella = "Calculando...";

  @override
  void initState() {
    super.initState();
    _calcularEstadisticas();
  }

  // --- Selección de fecha ---
  // Abre el calendario para que el admin pueda auditar días pasados
  Future<void> _elegirFecha() async {
    DateTime? pick = await showDatePicker(
      context: context,
      initialDate: _fechaReferencia,
      firstDate: DateTime(2023), 
      lastDate: DateTime.now(), 
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Colors.amber, onPrimary: Colors.black, surface: Colors.black, onSurface: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );

    if (pick != null && pick != _fechaReferencia) {
      setState(() {
        _fechaReferencia = pick;
        _cargando = true; 
      });
      _calcularEstadisticas(); 
    }
  }

  // --- Cálculo de métricas financieras ---
  Future<void> _calcularEstadisticas() async {
    // Definimos los límites del día elegido (de 00:00 a 23:59)
    DateTime inicioDia = DateTime(_fechaReferencia.year, _fechaReferencia.month, _fechaReferencia.day, 0, 0, 0);
    DateTime finDia = DateTime(_fechaReferencia.year, _fechaReferencia.month, _fechaReferencia.day, 23, 59, 59);

    // Calculamos los límites de la semana (desde el lunes hasta el domingo)
    DateTime inicioSemana = inicioDia.subtract(Duration(days: _fechaReferencia.weekday - 1));
    DateTime finSemana = inicioSemana.add(const Duration(days: 6, hours: 23, minutes: 59, seconds: 59));

    // Calculamos los límites del mes completo
    DateTime inicioMes = DateTime(_fechaReferencia.year, _fechaReferencia.month, 1, 0, 0, 0);
    // Usamos el día 0 del mes siguiente para obtener automáticamente el último día del mes actual
    DateTime finMes = DateTime(_fechaReferencia.year, _fechaReferencia.month + 1, 0, 23, 59, 59);

    // Determinamos el rango total de búsqueda para optimizar la lectura de Firebase
    DateTime fechaMinima = inicioMes.isBefore(inicioSemana) ? inicioMes : inicioSemana;
    DateTime fechaMaxima = finMes.isAfter(finSemana) ? finMes : finSemana;

    try {
      // Consultamos todas las citas que ya han sido cobradas (completadas)
      var snapshot = await FirebaseFirestore.instance
          .collection('citas')
          .where('estado', isEqualTo: 'completada')
          .get();

      double iDia = 0, iSemana = 0, iMes = 0;
      int cDia = 0, cSemana = 0, cMes = 0;
      Map<String, int> conteoServicios = {};

      for (var doc in snapshot.docs) {
        var data = doc.data();
        DateTime fechaCita = (data['fecha'] as Timestamp).toDate();

        // Si la cita queda fuera de nuestro rango de interés, pasamos a la siguiente
        if (fechaCita.isBefore(fechaMinima) || fechaCita.isAfter(fechaMaxima)) continue;

        double precio = (data['precio'] ?? 0).toDouble();
        String servicio = data['servicio'] ?? 'Desconocido';

        // Comprobamos si la cita pertenece al MES seleccionado
        if (fechaCita.isAfter(inicioMes.subtract(const Duration(seconds: 1))) && 
            fechaCita.isBefore(finMes.add(const Duration(seconds: 1)))) {
          iMes += precio;
          cMes++;
          // Registramos el servicio para determinar luego cuál es el más popular
          conteoServicios[servicio] = (conteoServicios[servicio] ?? 0) + 1;
        }
        
        // Comprobamos si pertenece a la SEMANA seleccionada
        if (fechaCita.isAfter(inicioSemana.subtract(const Duration(seconds: 1))) && 
            fechaCita.isBefore(finSemana.add(const Duration(seconds: 1)))) {
          iSemana += precio;
          cSemana++;
        }
        
        // Comprobamos si pertenece al DÍA seleccionado
        if (fechaCita.isAfter(inicioDia.subtract(const Duration(seconds: 1))) && 
            fechaCita.isBefore(finDia.add(const Duration(seconds: 1)))) {
          iDia += precio;
          cDia++;
        }
      }

      // Lógica para encontrar el servicio con más éxito en el periodo mensual
      String topServicio = "Ninguno aún";
      int maxCitas = 0;
      conteoServicios.forEach((nombre, cantidad) {
        if (cantidad > maxCitas) {
          maxCitas = cantidad;
          topServicio = nombre;
        }
      });

      if (mounted) {
        setState(() {
          _ingresosDia = iDia;
          _citasDia = cDia;
          _ingresosSemana = iSemana;
          _citasSemana = cSemana;
          _ingresosMes = iMes;
          _citasMes = cMes;
          _servicioEstrella = topServicio;
          _cargando = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() { _cargando = false; });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error al cargar datos.'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    String textoFecha = "${_fechaReferencia.day.toString().padLeft(2, '0')}/${_fechaReferencia.month.toString().padLeft(2, '0')}/${_fechaReferencia.year}";
    bool esHoy = _fechaReferencia.day == DateTime.now().day && _fechaReferencia.month == DateTime.now().month && _fechaReferencia.year == DateTime.now().year;

    return Scaffold(
      appBar: AppBar(
        title: const Text('PANEL DE INGRESOS', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.black,
      ),
      body: Column(
        children: [
          // Botón superior para cambiar la fecha de consulta
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(15),
            color: Colors.grey[900],
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                foregroundColor: Colors.amber,
                side: const BorderSide(color: Colors.amber),
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              icon: const Icon(Icons.calendar_month, size: 24),
              label: Text(
                esHoy ? 'Viendo: HOY ($textoFecha)' : 'Viendo: $textoFecha', 
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)
              ),
              onPressed: _elegirFecha,
            ),
          ),
          
          Expanded(
            child: _cargando
                ? const Center(child: CircularProgressIndicator(color: Colors.amber))
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Resumen Financiero',
                          style: TextStyle(color: Colors.amber, fontSize: 22, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 20),
                        
                        _construirTarjeta(
                          esHoy ? 'Facturación Hoy' : 'Facturación del Día Elegido',
                          _ingresosDia,
                          _citasDia,
                          Icons.today,
                        ),
                        const SizedBox(height: 15),

                        _construirTarjeta(
                          'Facturación de esa Semana',
                          _ingresosSemana,
                          _citasSemana,
                          Icons.date_range,
                        ),
                        const SizedBox(height: 15),

                        _construirTarjeta(
                          'Facturación de ese Mes',
                          _ingresosMes,
                          _citasMes,
                          Icons.calendar_month,
                        ),
                        const SizedBox(height: 30),

                        // Cuadro del servicio estrella
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.grey[900],
                            borderRadius: BorderRadius.circular(15),
                            border: Border.all(color: Colors.amber, width: 1),
                          ),
                          child: Column(
                            children: [
                              const Icon(Icons.star, color: Colors.amber, size: 40),
                              const SizedBox(height: 10),
                              const Text('Servicio más popular de ese mes', style: TextStyle(color: Colors.white70)),
                              const SizedBox(height: 5),
                              Text(
                                _servicioEstrella,
                                textAlign: TextAlign.center,
                                style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        )
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  // Estructura visual para las tarjetas de ingresos
  Widget _construirTarjeta(String titulo, double ingresos, int citas, IconData icono) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.white24),
        boxShadow: [
          BoxShadow(
            color: Colors.amber.withOpacity(0.05),
            blurRadius: 10,
            spreadRadius: 2,
          )
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: Colors.amber,
            radius: 25,
            child: Icon(icono, color: Colors.black, size: 28),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(titulo, style: const TextStyle(color: Colors.white70, fontSize: 16)),
                const SizedBox(height: 5),
                Text(
                  '${ingresos.toStringAsFixed(2)} €',
                  style: const TextStyle(color: Colors.amber, fontSize: 26, fontWeight: FontWeight.bold),
                ),
                Text('$citas citas completadas', style: const TextStyle(color: Colors.white54, fontSize: 13)),
              ],
            ),
          )
        ],
      ),
    );
  }
}