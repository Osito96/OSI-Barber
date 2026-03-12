import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class PantallaMisCitas extends StatelessWidget {
  const PantallaMisCitas({super.key});

  // --- Lógica de cancelación (Tu Regla de Oro) ---
  // Esta función es vital: evita que el cliente cancele si la cita es hoy, 
  // protegiendo así el horario del barbero.
  bool _puedeCancelar(DateTime fechaCita) {
    DateTime ahora = DateTime.now();
    // Normalizamos a las 00:00 para comparar solo el día calendario
    DateTime hoy = DateTime(ahora.year, ahora.month, ahora.day);
    DateTime diaCita = DateTime(fechaCita.year, fechaCita.month, fechaCita.day);

    // Solo devolvemos 'true' si el día de la cita es estrictamente posterior a hoy
    return diaCita.isAfter(hoy);
  }

  @override
  Widget build(BuildContext context) {
    // Identificamos al usuario para traer solo su agenda personal
    final String uid = FirebaseAuth.instance.currentUser!.uid;

    return Scaffold(
      appBar: AppBar(
        title: const Text('MIS CITAS', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.black,
      ),
      body: StreamBuilder<QuerySnapshot>(
        // Escuchamos en tiempo real solo las citas pendientes de este cliente concreto
        stream: FirebaseFirestore.instance
            .collection('citas')
            .where('clienteId', isEqualTo: uid)
            .where('estado', isEqualTo: 'pendiente')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('No tienes citas pendientes.', style: TextStyle(color: Colors.white54)));
          }

          var citas = snapshot.data!.docs;

          return ListView.builder(
            padding: const EdgeInsets.all(20),
            itemCount: citas.length,
            itemBuilder: (context, index) {
              var citaDoc = citas[index];
              var datos = citaDoc.data() as Map<String, dynamic>;
              
              DateTime fechaCita = (datos['fecha'] as Timestamp).toDate();
              String servicio = datos['servicio'] ?? 'Servicio';
              String hora = datos['hora'] ?? '--:--';
              
              // Comprobamos si, por fecha, el usuario aún tiene derecho a cancelar
              bool permiteCancelar = _puedeCancelar(fechaCita);

              return Card(
                color: Colors.grey[900],
                margin: const EdgeInsets.only(bottom: 15),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  // Si se puede cancelar, resaltamos un poco el borde en dorado
                  side: BorderSide(color: permiteCancelar ? Colors.amber.withOpacity(0.3) : Colors.white10),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(15),
                  child: Row(
                    children: [
                      // Fecha y Hora de la reserva
                      Column(
                        children: [
                          Text('${fechaCita.day}/${fechaCita.month}', style: const TextStyle(color: Colors.amber, fontSize: 18, fontWeight: FontWeight.bold)),
                          Text(hora, style: const TextStyle(color: Colors.white, fontSize: 16)),
                        ],
                      ),
                      const SizedBox(width: 20),
                      
                      // Información del servicio contratado
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(servicio, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                            const Text('Estado: Pendiente', style: TextStyle(color: Colors.white54, fontSize: 12)),
                          ],
                        ),
                      ),
                      
                      // Botón de acción: Cancelar o Candado informativo
                      if (permiteCancelar)
                        IconButton(
                          icon: const Icon(Icons.delete_forever, color: Colors.redAccent),
                          onPressed: () => _confirmarCancelacion(context, citaDoc.id),
                        )
                      else
                        const Tooltip(
                          message: 'No se puede cancelar el mismo día',
                          child: Icon(Icons.lock_clock, color: Colors.white24),
                        ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  // --- Ventana de confirmación para borrar la cita ---
  void _confirmarCancelacion(BuildContext context, String citaId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.black,
        title: const Text('¿Cancelar cita?', style: TextStyle(color: Colors.white)),
        content: const Text('Esta acción no se puede deshacer y el hueco quedará libre.', style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('No', style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () async {
              // Borramos el documento directamente de la colección de citas
              await FirebaseFirestore.instance.collection('citas').doc(citaId).delete();
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('Sí, cancelar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}