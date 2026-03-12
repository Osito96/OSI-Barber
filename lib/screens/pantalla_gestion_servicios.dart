import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class PantallaGestionServicios extends StatefulWidget {
  const PantallaGestionServicios({super.key});

  @override
  State<PantallaGestionServicios> createState() => _PantallaGestionServiciosState();
}

class _PantallaGestionServiciosState extends State<PantallaGestionServicios> {
  
  // --- Ventana interactiva para añadir o modificar servicios ---
  // He unificado ambas funciones en este diálogo: si recibe un "documentoActual", se pone en modo edición.
  void _mostrarDialogoServicio({DocumentSnapshot? documentoActual}) {
    bool esEdicion = documentoActual != null;
    
    // Si estamos editando, cargamos los valores que ya existen en la base de datos.
    // Si el servicio es nuevo, los controladores se inician vacíos o con valores por defecto.
    final _nombreCtrl = TextEditingController(text: esEdicion ? documentoActual['nombre'] : '');
    final _precioCtrl = TextEditingController(text: esEdicion ? documentoActual['precio'].toString() : '');
    final _duracionCtrl = TextEditingController(text: esEdicion ? documentoActual['duracion'].toString() : '');
    final _ordenCtrl = TextEditingController(text: esEdicion ? (documentoActual.data() as Map<String, dynamic>)['orden']?.toString() ?? '0' : '0');

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.grey[900],
          title: Text(
            esEdicion ? 'Editar Servicio' : 'Nuevo Servicio', 
            style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold)
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: _nombreCtrl, 
                  style: const TextStyle(color: Colors.white), 
                  decoration: const InputDecoration(labelText: 'Nombre (Ej: Corte + Barba)', labelStyle: TextStyle(color: Colors.white54))
                ),
                TextField(
                  controller: _precioCtrl, 
                  style: const TextStyle(color: Colors.white), 
                  keyboardType: TextInputType.number, 
                  decoration: const InputDecoration(labelText: 'Precio (€)', labelStyle: TextStyle(color: Colors.white54))
                ),
                TextField(
                  controller: _duracionCtrl, 
                  style: const TextStyle(color: Colors.white), 
                  keyboardType: TextInputType.number, 
                  decoration: const InputDecoration(labelText: 'Duración (minutos)', labelStyle: TextStyle(color: Colors.white54))
                ),
                TextField(
                  controller: _ordenCtrl, 
                  style: const TextStyle(color: Colors.white), 
                  keyboardType: TextInputType.number, 
                  decoration: const InputDecoration(labelText: 'Orden en la lista (1, 2, 3...)', labelStyle: TextStyle(color: Colors.white54))
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar', style: TextStyle(color: Colors.white54)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.amber),
              onPressed: () async {
                // Validación rápida para no guardar datos vacíos que rompan la interfaz
                if (_nombreCtrl.text.isEmpty || _precioCtrl.text.isEmpty || _duracionCtrl.text.isEmpty) return;

                // Transformamos los textos de los inputs a números para que Firebase los guarde correctamente
                int precio = int.tryParse(_precioCtrl.text) ?? 0;
                int duracion = int.tryParse(_duracionCtrl.text) ?? 0;
                int orden = int.tryParse(_ordenCtrl.text) ?? 0;

                Map<String, dynamic> datosServicio = {
                  'nombre': _nombreCtrl.text.trim(),
                  'precio': precio,
                  'duracion': duracion,
                  'orden': orden,
                };

                // Dependiendo de si es edición o creación, usamos 'update' o 'add'
                if (esEdicion) {
                  await FirebaseFirestore.instance.collection('servicios').doc(documentoActual.id).update(datosServicio);
                } else {
                  await FirebaseFirestore.instance.collection('servicios').add(datosServicio);
                }

                if (mounted) Navigator.pop(context);
              },
              child: Text(
                esEdicion ? 'Guardar Cambios' : 'Crear', 
                style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold)
              ),
            ),
          ],
        );
      },
    );
  }

  // --- Confirmación de seguridad antes de borrar ---
  void _confirmarBorrado(String idServicio) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.black,
        title: const Text('¿Borrar servicio?', style: TextStyle(color: Colors.white)),
        content: const Text(
          'Este servicio desaparecerá de la app y los clientes no podrán reservarlo más.', 
          style: TextStyle(color: Colors.white70)
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () {
              FirebaseFirestore.instance.collection('servicios').doc(idServicio).delete();
              Navigator.pop(context);
            },
            child: const Text('Borrar'),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('GESTIÓN DE SERVICIOS', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.black,
      ),
      
      // Botón para añadir un servicio nuevo rápidamente
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: Colors.amber,
        icon: const Icon(Icons.add, color: Colors.black),
        label: const Text('Nuevo Servicio', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        onPressed: () => _mostrarDialogoServicio(), 
      ),
      
      body: StreamBuilder<QuerySnapshot>(
        // Escuchamos la colección de servicios en tiempo real y la ordenamos según el campo 'orden'
        stream: FirebaseFirestore.instance.collection('servicios').orderBy('orden').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Colors.amber));
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Text('No hay servicios. ¡Añade el primero!', style: TextStyle(color: Colors.white54))
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(10),
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              var documento = snapshot.data!.docs[index];
              var servicio = documento.data() as Map<String, dynamic>;

              return Card(
                color: Colors.grey[900],
                margin: const EdgeInsets.only(bottom: 15),
                child: ListTile(
                  contentPadding: const EdgeInsets.all(15),
                  title: Text(
                    servicio['nombre'] ?? '', 
                    style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)
                  ),
                  subtitle: Text(
                    '${servicio['duracion']} min  •  ${servicio['precio']}€\nOrden en lista: ${servicio['orden'] ?? 0}', 
                    style: const TextStyle(color: Colors.white70)
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Acceso rápido para editar los detalles del servicio
                      IconButton(
                        icon: const Icon(Icons.edit, color: Colors.blueAccent),
                        onPressed: () => _mostrarDialogoServicio(documentoActual: documento),
                      ),
                      // Acceso rápido para eliminar el servicio de la oferta
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.redAccent),
                        onPressed: () => _confirmarBorrado(documento.id),
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
}