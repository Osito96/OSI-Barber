import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class PantallaGestionCupones extends StatefulWidget {
  const PantallaGestionCupones({super.key});

  @override
  State<PantallaGestionCupones> createState() => _PantallaGestionCuponesState();
}

class _PantallaGestionCuponesState extends State<PantallaGestionCupones> {
  
  // --- Ventana para CREAR o EDITAR cupones ---
  // Si le pasamos un documento, la ventana se rellena para editar. Si no, está vacía para crear.
  void _mostrarDialogoCupon({DocumentSnapshot? documentoActual}) {
    bool esEdicion = documentoActual != null;
    
    // Inicializamos los controladores con los datos existentes si estamos editando
    final _tituloCtrl = TextEditingController(text: esEdicion ? documentoActual['titulo'] : '');
    final _descCtrl = TextEditingController(text: esEdicion ? documentoActual['descripcion'] : '');
    final _puntosCtrl = TextEditingController(text: esEdicion ? documentoActual['puntosNecesarios'].toString() : '');

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.grey[900],
          title: Text(
            esEdicion ? 'Editar Cupón' : 'Nuevo Cupón', 
            style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold)
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: _tituloCtrl, 
                  style: const TextStyle(color: Colors.white), 
                  decoration: const InputDecoration(labelText: 'Título (Ej: Corte Gratis)', labelStyle: TextStyle(color: Colors.white54))
                ),
                TextField(
                  controller: _descCtrl, 
                  style: const TextStyle(color: Colors.white), 
                  decoration: const InputDecoration(labelText: 'Descripción corta', labelStyle: TextStyle(color: Colors.white54))
                ),
                TextField(
                  controller: _puntosCtrl, 
                  style: const TextStyle(color: Colors.white), 
                  keyboardType: TextInputType.number, 
                  decoration: const InputDecoration(labelText: 'Citas V necesarias (Ej: 10)', labelStyle: TextStyle(color: Colors.white54))
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
                // Validación básica de seguridad
                if (_tituloCtrl.text.isEmpty || _puntosCtrl.text.isEmpty) return;

                int puntos = int.tryParse(_puntosCtrl.text) ?? 0;

                Map<String, dynamic> datosCupon = {
                  'titulo': _tituloCtrl.text.trim(),
                  'descripcion': _descCtrl.text.trim(),
                  'puntosNecesarios': puntos,
                };

                // Decidimos si añadir un documento nuevo o actualizar el que ya tenemos
                if (esEdicion) {
                  await FirebaseFirestore.instance.collection('cupones').doc(documentoActual.id).update(datosCupon);
                } else {
                  await FirebaseFirestore.instance.collection('cupones').add(datosCupon);
                }

                if (mounted) Navigator.pop(context);
              },
              child: Text(esEdicion ? 'Guardar' : 'Crear', style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  // --- Confirmación de borrado ---
  void _confirmarBorrado(String idCupon) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.black,
        title: const Text('¿Borrar cupón?', style: TextStyle(color: Colors.white)),
        content: const Text('Este premio ya no estará disponible para los clientes.', style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () {
              FirebaseFirestore.instance.collection('cupones').doc(idCupon).delete();
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
        title: const Text('GESTIÓN DE CUPONES', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.black,
      ),
      // Botón flotante para añadir premios nuevos rápidamente
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: Colors.amber,
        icon: const Icon(Icons.star, color: Colors.black),
        label: const Text('Nuevo Cupón', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        onPressed: () => _mostrarDialogoCupon(), 
      ),
      body: StreamBuilder<QuerySnapshot>(
        // Obtenemos los cupones en tiempo real y los ordenamos por dificultad (puntos necesarios)
        stream: FirebaseFirestore.instance.collection('cupones').orderBy('puntosNecesarios').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator(color: Colors.amber));
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return const Center(child: Text('No hay cupones creados.', style: TextStyle(color: Colors.white54)));

          return ListView.builder(
            padding: const EdgeInsets.all(10),
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              var documento = snapshot.data!.docs[index];
              var cupon = documento.data() as Map<String, dynamic>;

              return Card(
                color: Colors.grey[900],
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: const BorderSide(color: Colors.amber, width: 1), // Efecto visual de ticket VIP
                ),
                margin: const EdgeInsets.only(bottom: 15),
                child: ListTile(
                  contentPadding: const EdgeInsets.all(15),
                  leading: const CircleAvatar(
                    backgroundColor: Colors.amber,
                    child: Icon(Icons.card_giftcard, color: Colors.black),
                  ),
                  title: Text(cupon['titulo'] ?? '', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                  subtitle: Text('${cupon['descripcion']}\nCuesta: ${cupon['puntosNecesarios']} Citas V', style: const TextStyle(color: Colors.white70)),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit, color: Colors.blueAccent),
                        onPressed: () => _mostrarDialogoCupon(documentoActual: documento),
                      ),
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