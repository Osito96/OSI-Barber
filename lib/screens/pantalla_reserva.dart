import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class PantallaReserva extends StatefulWidget {
  final String nombreServicio;
  final int precio;
  final int duracion;
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
  // --- Variables de control ---
  DateTime? _fechaSeleccionada;
  String? _horaSeleccionada;
  bool _estaGuardando = false;
  List<String> _horasOcupadas = [];
  
  // Variable crítica: Controla si el administrador ha marcado el día como no laborable
  bool _diaBloqueadoPorAdmin = false; 

  // Listado maestro de fracciones de tiempo (slots de 15 minutos)
  final List<String> _horariosTotales = [
    '09:30', '09:45', '10:00', '10:15', '10:30', '10:45', '11:00', '11:15', 
    '11:30', '11:45', '12:00', '12:15', '12:30', '12:45', '13:00', '13:15',
    '16:00', '16:15', '16:30', '16:45', '17:00', '17:15', '17:30', '17:45', 
    '18:00', '18:15', '18:30', '18:45', '19:00', '19:15', '19:30', '19:45'
  ];

  // --- Lógica de filtrado de Firebase ---
  Future<void> _obtenerCitasDelDia(DateTime fecha) async {
    setState(() { 
      _horasOcupadas = []; 
      _horaSeleccionada = null; 
      _diaBloqueadoPorAdmin = false; 
    });

    // 1. Verificación de seguridad: ¿Está el día cerrado por el Admin?
    String idDia = "${fecha.year}-${fecha.month.toString().padLeft(2, '0')}-${fecha.day.toString().padLeft(2, '0')}";
    var docBloqueado = await FirebaseFirestore.instance.collection('dias_bloqueados').doc(idDia).get();
    
    if (docBloqueado.exists && docBloqueado.data()?['bloqueado'] == true) {
      setState(() { _diaBloqueadoPorAdmin = true; });
      return; 
    }

    // 2. Si el día está abierto, calculamos qué huecos están ya reservados
    DateTime inicioDia = DateTime(fecha.year, fecha.month, fecha.day, 0, 0);
    DateTime finDia = DateTime(fecha.year, fecha.month, fecha.day, 23, 59);

    var snapshot = await FirebaseFirestore.instance
        .collection('citas')
        .where('fecha', isGreaterThanOrEqualTo: Timestamp.fromDate(inicioDia))
        .where('fecha', isLessThanOrEqualTo: Timestamp.fromDate(finDia))
        .get();

    List<String> bloqueadas = [];
    for (var doc in snapshot.docs) {
      String horaInicio = doc['hora'];
      int duracionCita = doc['duracion'] ?? 30;
      
      // Calculamos cuántos tramos de 15 minutos "ocupa" la cita existente
      int bloquesOcupados = (duracionCita / 15).ceil();
      int indiceInicio = _horariosTotales.indexOf(horaInicio);

      if (indiceInicio != -1) {
        for (int i = 0; i < bloquesOcupados; i++) {
          if (indiceInicio + i < _horariosTotales.length) {
            bloqueadas.add(_horariosTotales[indiceInicio + i]);
          }
        }
      }
    }
    setState(() { _horasOcupadas = bloqueadas; });
  }

  // --- El Algoritmo de Disponibilidad ---
  // Este método filtra los horarios basándose en la duración del servicio actual
  List<String> get _horariosDisponibles {
    if (_fechaSeleccionada == null || _diaBloqueadoPorAdmin) return []; 
    
    DateTime ahora = DateTime.now();
    bool esHoy = _fechaSeleccionada!.day == ahora.day && 
                 _fechaSeleccionada!.month == ahora.month &&
                 _fechaSeleccionada!.year == ahora.year;

    // Calculamos cuántos huecos de 15 min seguidos necesitamos
    int bloquesNecesarios = (widget.duracion / 15).ceil();

    return _horariosTotales.where((h) {
      int indiceActual = _horariosTotales.indexOf(h);
      
      // Si la reserva es para hoy, no permitimos elegir horas que ya han pasado
      if (esHoy) {
        int horaH = int.parse(h.split(':')[0]);
        int minH = int.parse(h.split(':')[1]);
        DateTime horaSlot = DateTime(ahora.year, ahora.month, ahora.day, horaH, minH);
        if (horaSlot.isBefore(ahora)) return false;
      }

      // Verificamos si hay espacio suficiente para la duración total del servicio
      for (int i = 0; i < bloquesNecesarios; i++) {
        int indiceAComprobar = indiceActual + i;
        
        if (indiceAComprobar >= _horariosTotales.length) return false;
        if (_horasOcupadas.contains(_horariosTotales[indiceAComprobar])) return false;

        // Validación extra: No permitimos que una cita se solape entre el turno de mañana y tarde
        if (i < bloquesNecesarios - 1) {
          int sigIdx = indiceAComprobar + 1;
          if (sigIdx >= _horariosTotales.length) return false;

          int h1 = int.parse(_horariosTotales[indiceAComprobar].split(':')[0]);
          int h2 = int.parse(_horariosTotales[sigIdx].split(':')[0]);
          if ((h2 - h1).abs() > 1) return false; 
        }
      }
      return true;
    }).toList();
  }

  // --- Selector de Fecha con reglas de negocio ---
  Future<void> _elegirFecha() async {
    DateTime? fechaElegida = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 30)),
      locale: const Locale('es', 'ES'),
      // Excluimos fines de semana porque la barbería cierra
      selectableDayPredicate: (DateTime day) {
        return day.weekday != DateTime.saturday && day.weekday != DateTime.sunday;
      },
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

    if (fechaElegida != null) {
      setState(() => _fechaSeleccionada = fechaElegida);
      _obtenerCitasDelDia(fechaElegida);
    }
  }

  // --- Confirmación y Guardado en Firestore ---
  Future<void> _confirmarReserva() async {
    if (_fechaSeleccionada == null || _horaSeleccionada == null || _diaBloqueadoPorAdmin) return;
    setState(() { _estaGuardando = true; });

    try {
      final String uid = FirebaseAuth.instance.currentUser!.uid;
      
      // Control de Spam: Validamos que el cliente no tenga ya otra cita el mismo día
      DateTime inicioDia = DateTime(_fechaSeleccionada!.year, _fechaSeleccionada!.month, _fechaSeleccionada!.day, 0, 0);
      DateTime finDia = DateTime(_fechaSeleccionada!.year, _fechaSeleccionada!.month, _fechaSeleccionada!.day, 23, 59);

      var consulta = await FirebaseFirestore.instance
          .collection('citas')
          .where('clienteId', isEqualTo: uid)
          .where('fecha', isGreaterThanOrEqualTo: Timestamp.fromDate(inicioDia))
          .where('fecha', isLessThanOrEqualTo: Timestamp.fromDate(finDia))
          .get();

      if (consulta.docs.isNotEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Ya tienes una cita para este día. Si necesitas cambiarla, cancela primero la otra en "Mis Citas".'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 4),
            ),
          );
        }
        setState(() { _estaGuardando = false; });
        return; 
      }

      // Preparamos el objeto final para subirlo a la nube
      List<String> partesHora = _horaSeleccionada!.split(':');
      DateTime fechaCitaCompleta = DateTime(
        _fechaSeleccionada!.year, _fechaSeleccionada!.month, _fechaSeleccionada!.day,
        int.parse(partesHora[0]), int.parse(partesHora[1])
      );

      await FirebaseFirestore.instance.collection('citas').add({
        'clienteId': uid,
        'nombreCliente': widget.nombreCliente,
        'servicio': widget.nombreServicio,
        'precio': widget.precio,
        'duracion': widget.duracion,
        'fecha': Timestamp.fromDate(fechaCitaCompleta),
        'hora': _horaSeleccionada,
        'estado': 'pendiente',
        'fechaCreacion': DateTime.now(),
      });

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('¡Cita reservada con éxito!'), backgroundColor: Colors.green)
        );
      }
    } catch (e) {
      setState(() { _estaGuardando = false; });
      // El print lo mantenemos para depuración rápida en VS Code
      print('🚨 ERROR FIREBASE: $e'); 
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error: Mira la consola de VS Code (Debug Console) para solucionar el problema.'),
            backgroundColor: Colors.redAccent,
            duration: Duration(seconds: 6),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('RESERVAR CITA'), backgroundColor: Colors.black, centerTitle: true),
      // SafeArea protege el contenido de los bordes y el notch del móvil
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              _resumenServicio(),
              const SizedBox(height: 30),
              _botonFecha(),
              const SizedBox(height: 30),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text('2. Selecciona la hora', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.amber)),
              ),
              const SizedBox(height: 10),
              
              // El cuerpo central varía según si el día está elegido, libre o bloqueado
              Expanded(
                child: _fechaSeleccionada == null
                    ? const Center(child: Text('Selecciona un día (Lunes a Viernes)', style: TextStyle(color: Colors.white54)))
                    : _diaBloqueadoPorAdmin 
                        ? const Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.event_busy, color: Colors.redAccent, size: 60),
                                SizedBox(height: 15),
                                Text('DÍA NO DISPONIBLE', style: TextStyle(color: Colors.redAccent, fontSize: 20, fontWeight: FontWeight.bold)),
                                SizedBox(height: 10),
                                Text('La barbería permanecerá cerrada\no no admite más reservas este día.', textAlign: TextAlign.center, style: TextStyle(color: Colors.white70)),
                              ],
                            )
                          )
                        : _horariosDisponibles.isEmpty
                            ? const Center(child: Text('No hay huecos libres para este servicio hoy.', style: TextStyle(color: Colors.redAccent), textAlign: TextAlign.center))
                            : GridView.builder(
                                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 4, childAspectRatio: 2.1, crossAxisSpacing: 8, mainAxisSpacing: 8
                                ),
                                itemCount: _horariosDisponibles.length,
                                itemBuilder: (context, index) {
                                  String hora = _horariosDisponibles[index];
                                  bool sel = _horaSeleccionada == hora;
                                  return GestureDetector(
                                    onTap: () => setState(() => _horaSeleccionada = hora),
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: sel ? Colors.amber : Colors.black,
                                        border: Border.all(color: Colors.amber),
                                        borderRadius: BorderRadius.circular(8)
                                      ),
                                      alignment: Alignment.center,
                                      child: Text(hora, style: TextStyle(color: sel ? Colors.black : Colors.amber, fontWeight: FontWeight.bold, fontSize: 13)),
                                    ),
                                  );
                                },
                              ),
              ),
              const SizedBox(height: 10),
              
              SizedBox(
                width: double.infinity, height: 55,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.amber, foregroundColor: Colors.black),
                  onPressed: (_estaGuardando || _diaBloqueadoPorAdmin) ? null : _confirmarReserva,
                  child: _estaGuardando 
                    ? const CircularProgressIndicator(color: Colors.black) 
                    : const Text('CONFIRMAR RESERVA', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ),
              ),
              const SizedBox(height: 10), 
            ],
          ),
        ),
      ),
    );
  }

  // --- Componentes visuales secundarios ---

  Widget _resumenServicio() {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white12)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(widget.nombreServicio, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
            Text('${widget.duracion} min', style: const TextStyle(color: Colors.white54)),
          ]),
          Text('${widget.precio}€', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.amber)),
        ],
      ),
    );
  }

  Widget _botonFecha() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('1. Selecciona el día', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.amber)),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity, height: 50,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.grey[900], foregroundColor: Colors.white),
            icon: const Icon(Icons.calendar_month, color: Colors.amber),
            label: Text(_fechaSeleccionada == null 
              ? 'Tocar para elegir fecha' 
              : '${_fechaSeleccionada!.day}/${_fechaSeleccionada!.month}/${_fechaSeleccionada!.year}'),
            onPressed: _elegirFecha,
          ),
        ),
      ],
    );
  }
}