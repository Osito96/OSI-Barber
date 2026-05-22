import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../core/app_theme.dart';
import '../core/constants.dart';

class PantallaGestionServicios extends StatefulWidget {
  const PantallaGestionServicios({super.key});

  @override
  State<PantallaGestionServicios> createState() => _PantallaGestionServiciosState();
}

class _PantallaGestionServiciosState extends State<PantallaGestionServicios> {
  FirebaseFirestore get _db => FirebaseFirestore.instance;

  void _mostrarDialogoServicio({DocumentSnapshot? documentoActual}) {
    final esEdicion  = documentoActual != null;
    final datosActuales = documentoActual?.data() as Map<String, dynamic>?;
    final nombreCtrl = TextEditingController(text: datosActuales?[Campos.nombre] ?? '');
    final precioCtrl = TextEditingController(text: (datosActuales?[Campos.precio] ?? '').toString());
    final durCtrl    = TextEditingController(text: (datosActuales?[Campos.duracion] ?? '').toString());
    final ordenCtrl  = TextEditingController(
      text: esEdicion ? (datosActuales?[Campos.orden] ?? 0).toString() : '0',
    );

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(esEdicion ? 'Editar servicio' : 'Nuevo servicio'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _inputDialog(nombreCtrl, 'Nombre del servicio', Icons.content_cut_outlined),
              const SizedBox(height: 12),
              _inputDialog(precioCtrl, 'Precio (€)', Icons.euro_outlined,
                  tipo: TextInputType.number),
              const SizedBox(height: 12),
              _inputDialog(durCtrl, 'Duración (minutos)', Icons.schedule_outlined,
                  tipo: TextInputType.number),
              const SizedBox(height: 12),
              _inputDialog(ordenCtrl, 'Orden en lista (1, 2, 3…)', Icons.sort_rounded,
                  tipo: TextInputType.number),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(minimumSize: const Size(100, 44)),
            onPressed: () async {
              if (nombreCtrl.text.isEmpty || precioCtrl.text.isEmpty ||
                  durCtrl.text.isEmpty) return;
              final datos = {
                Campos.nombre:   nombreCtrl.text.trim(),
                Campos.precio:   int.tryParse(precioCtrl.text) ?? 0,
                Campos.duracion: int.tryParse(durCtrl.text)    ?? 0,
                Campos.orden:    int.tryParse(ordenCtrl.text)  ?? 0,
              };
              if (esEdicion) {
                await _db
                    .collection(Colecciones.servicios).doc(documentoActual!.id).update(datos);
              } else {
                await _db
                    .collection(Colecciones.servicios).add(datos);
              }
              if (mounted) Navigator.pop(ctx);
            },
            child: Text(esEdicion ? 'GUARDAR' : 'CREAR'),
          ),
        ],
      ),
    );
  }

  Widget _inputDialog(TextEditingController ctrl, String label, IconData icono,
      {TextInputType tipo = TextInputType.text}) {
    return TextField(
      controller:  ctrl,
      keyboardType: tipo,
      style: TextStyle(color: AppTheme.textPrimary),
      decoration: InputDecoration(
        labelText:  label,
        prefixIcon: Icon(icono),
      ),
    );
  }

  void _confirmarBorrado(String id) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Borrar servicio?'),
        content: const Text(
            'Este servicio desaparecerá de la app y no podrá reservarse.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.error,
              foregroundColor: AppTheme.textPrimary,
              minimumSize: const Size(100, 44),
            ),
            onPressed: () async {
              await _db
                  .collection(Colecciones.servicios).doc(id).delete();
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Borrar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Gestión de servicios')),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppTheme.gold,
        foregroundColor: AppTheme.black,
        icon:  const Icon(Icons.add_rounded),
        label: const Text('Nuevo servicio',
            style: TextStyle(fontWeight: FontWeight.w700)),
        onPressed: () => _mostrarDialogoServicio(),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _db
            .collection(Colecciones.servicios).orderBy(Campos.orden).snapshots(),
        builder: (ctx, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snap.hasData || snap.data!.docs.isEmpty) {
            return Center(
              child: Text('No hay servicios. ¡Añade el primero!',
                  style: AppTheme.bodyMedium),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
            itemCount: snap.data!.docs.length,
            itemBuilder: (ctx, i) {
              final doc      = snap.data!.docs[i];
              final servicio = doc.data() as Map<String, dynamic>;

              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color:        AppTheme.surface,
                    borderRadius: BorderRadius.circular(AppTheme.radiusL),
                    border:       Border.all(color: AppTheme.divider, width: 0.5),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(servicio[Campos.nombre] ?? '',
                                style: AppTheme.titleSmall),
                            const SizedBox(height: 4),
                            Text(
                              '${servicio[Campos.duracion]} min  ·  ${servicio[Campos.precio]}€  ·  Orden: ${servicio[Campos.orden] ?? 0}',
                              style: AppTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.edit_outlined,
                            color: AppTheme.textSecond, size: 20),
                        onPressed: () =>
                            _mostrarDialogoServicio(documentoActual: doc),
                      ),
                      IconButton(
                        icon: Icon(Icons.delete_outline_rounded,
                            color: AppTheme.error, size: 20),
                        onPressed: () => _confirmarBorrado(doc.id),
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
