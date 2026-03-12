import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class PantallaMisCupones extends StatefulWidget {
  const PantallaMisCupones({super.key});

  @override
  State<PantallaMisCupones> createState() => _PantallaMisCuponesState();
}

class _PantallaMisCuponesState extends State<PantallaMisCupones> {
  final String _miUid = FirebaseAuth.instance.currentUser!.uid;

  // --- Proceso de canjeo de puntos ---
  void _confirmarCanjeo(String tituloCupon, int puntosNecesarios) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Colors.amber, width: 2),
        ),
        title: const Text('¿Canjear Cupón?', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: Text(
          'Vas a gastar $puntosNecesarios Citas V para obtener:\n\n"$tituloCupon"\n\n¿Estás seguro? Enséñale esta pantalla a tu barbero para que te aplique la recompensa.',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.amber),
            onPressed: () async {
              // Restamos los puntos al usuario usando FieldValue.increment con valor negativo
              await FirebaseFirestore.instance.collection('clientes').doc(_miUid).update({
                'citasV': FieldValue.increment(-puntosNecesarios)
              });

              if (mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('🎉 ¡Cupón canjeado con éxito! Enséñaselo al barbero.'),
                    backgroundColor: Colors.green,
                    duration: Duration(seconds: 5),
                  ),
                );
              }
            },
            child: const Text('Sí, Canjear', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('MIS CUPONES', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.black,
      ),
      
      // Implementamos un StreamBuilder doble: primero leemos los puntos del cliente
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('clientes').doc(_miUid).snapshots(),
        builder: (context, userSnapshot) {
          if (userSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Colors.amber));
          }

          int misPuntos = 0;
          if (userSnapshot.hasData && userSnapshot.data!.exists) {
            misPuntos = (userSnapshot.data!.data() as Map<String, dynamic>)['citasV'] ?? 0;
          }

          return Column(
            children: [
              // --- Cabecera: Marcador de Puntos del usuario ---
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.grey[900],
                  border: const Border(bottom: BorderSide(color: Colors.amber, width: 2)),
                ),
                child: Column(
                  children: [
                    const Icon(Icons.star, color: Colors.amber, size: 40),
                    const SizedBox(height: 10),
                    const Text('Tus Puntos Acumulados', style: TextStyle(color: Colors.white70, fontSize: 16)),
                    Text('$misPuntos', style: const TextStyle(color: Colors.amber, fontSize: 40, fontWeight: FontWeight.bold)),
                    const Text('Cada cita completada suma 1 punto.', style: TextStyle(color: Colors.white54, fontSize: 12)),
                  ],
                ),
              ),

              // --- Lista: Catálogo de cupones disponibles ---
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance.collection('cupones').orderBy('puntosNecesarios').snapshots(),
                  builder: (context, cuponesSnapshot) {
                    if (cuponesSnapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator(color: Colors.amber));
                    if (!cuponesSnapshot.hasData || cuponesSnapshot.data!.docs.isEmpty) return const Center(child: Text('No hay cupones disponibles ahora mismo.', style: TextStyle(color: Colors.white54)));

                    return ListView.builder(
                      padding: const EdgeInsets.all(15),
                      itemCount: cuponesSnapshot.data!.docs.length,
                      itemBuilder: (context, index) {
                        var cupon = cuponesSnapshot.data!.docs[index].data() as Map<String, dynamic>;
                        String titulo = cupon['titulo'] ?? '';
                        String descripcion = cupon['descripcion'] ?? '';
                        int puntosNecesarios = cupon['puntosNecesarios'] ?? 1;

                        // Comprobamos si el usuario tiene puntos suficientes para este cupón
                        bool sePuedeCanjear = misPuntos >= puntosNecesarios;
                        
                        // Calculamos el porcentaje para la barra de progreso (máximo 100%)
                        double progresoVisual = misPuntos / puntosNecesarios;
                        if (progresoVisual > 1.0) progresoVisual = 1.0;

                        return Card(
                          color: Colors.grey[900],
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15),
                            side: BorderSide(
                              color: sePuedeCanjear ? Colors.amber : Colors.white10, 
                              width: sePuedeCanjear ? 2 : 1
                            ),
                          ),
                          margin: const EdgeInsets.only(bottom: 20),
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Título y Icono del premio
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        titulo, 
                                        style: TextStyle(
                                          color: sePuedeCanjear ? Colors.amber : Colors.white, 
                                          fontSize: 20, 
                                          fontWeight: FontWeight.bold
                                        )
                                      ),
                                    ),
                                    Icon(Icons.card_giftcard, color: sePuedeCanjear ? Colors.amber : Colors.white24),
                                  ],
                                ),
                                const SizedBox(height: 5),
                                Text(descripcion, style: const TextStyle(color: Colors.white70, fontSize: 14)),
                                const SizedBox(height: 20),

                                // Contador de progreso de puntos
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text('Progreso', style: TextStyle(color: Colors.white54, fontSize: 13)),
                                    Text(
                                      '$misPuntos / $puntosNecesarios Citas', 
                                      style: TextStyle(
                                        color: sePuedeCanjear ? Colors.amber : Colors.white, 
                                        fontWeight: FontWeight.bold
                                      )
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),

                                // Barra de progreso gráfica
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(10),
                                  child: LinearProgressIndicator(
                                    value: progresoVisual,
                                    minHeight: 10,
                                    backgroundColor: Colors.black,
                                    valueColor: AlwaysStoppedAnimation<Color>(sePuedeCanjear ? Colors.amber : Colors.white54),
                                  ),
                                ),
                                const SizedBox(height: 20),

                                // Botón interactivo: Se activa solo si hay puntos suficientes
                                SizedBox(
                                  width: double.infinity,
                                  height: 45,
                                  child: ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: sePuedeCanjear ? Colors.amber : Colors.grey[800],
                                      foregroundColor: sePuedeCanjear ? Colors.black : Colors.white54,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                    ),
                                    onPressed: sePuedeCanjear ? () => _confirmarCanjeo(titulo, puntosNecesarios) : null,
                                    child: Text(
                                      sePuedeCanjear ? 'CANJEAR CUPÓN' : 'FALTAN PUNTOS', 
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)
                                    ),
                                  ),
                                )
                              ],
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
        },
      ),
    );
  }
}