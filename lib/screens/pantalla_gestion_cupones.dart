import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../core/app_theme.dart';
import '../core/constants.dart';

class PantallaGestionCupones extends StatefulWidget {
  const PantallaGestionCupones({super.key});

  @override
  State<PantallaGestionCupones> createState() => _PantallaGestionCuponesState();
}

class _PantallaGestionCuponesState extends State<PantallaGestionCupones> {
  FirebaseFirestore get _db => FirebaseFirestore.instance;

  void _mostrarDialogoCupon({DocumentSnapshot? documentoActual}) {
    final esEdicion  = documentoActual != null;
    final datosActuales = documentoActual?.data() as Map<String, dynamic>?;
    final tituloCtrl = TextEditingController(text: datosActuales?[Campos.titulo] ?? '');
    final descCtrl   = TextEditingController(text: datosActuales?[Campos.descripcion] ?? '');
    final puntosCtrl = TextEditingController(
        text: esEdicion ? (datosActuales?[Campos.puntosNecesarios] ?? '').toString() : '');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(esEdicion ? 'Editar cupón' : 'Nuevo cupón'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _inputDialog(tituloCtrl, 'Título (ej: Corte gratis)', Icons.card_giftcard_outlined),
              const SizedBox(height: 12),
              _inputDialog(descCtrl, 'Descripción corta', Icons.description_outlined),
              const SizedBox(height: 12),
              _inputDialog(puntosCtrl, 'Citas V necesarias', Icons.star_outline_rounded,
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
              if (tituloCtrl.text.isEmpty || puntosCtrl.text.isEmpty) return;
              final datos = {
                Campos.titulo:           tituloCtrl.text.trim(),
                Campos.descripcion:      descCtrl.text.trim(),
                Campos.puntosNecesarios: int.tryParse(puntosCtrl.text) ?? 0,
              };
              if (esEdicion) {
                await _db
                    .collection(Colecciones.cupones).doc(documentoActual!.id).update(datos);
              } else {
                await _db
                    .collection(Colecciones.cupones).add(datos);
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
      controller:   ctrl,
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
        title: const Text('¿Borrar cupón?'),
        content: const Text('Este premio ya no estará disponible para los clientes.'),
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
                  .collection(Colecciones.cupones).doc(id).delete();
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
      appBar: AppBar(title: const Text('Gestión de cupones')),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppTheme.gold,
        foregroundColor: AppTheme.black,
        icon:  const Icon(Icons.star_rounded),
        label: const Text('Nuevo cupón',
            style: TextStyle(fontWeight: FontWeight.w700)),
        onPressed: () => _mostrarDialogoCupon(),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _db
            .collection(Colecciones.cupones)
            .orderBy(Campos.puntosNecesarios)
            .snapshots(),
        builder: (ctx, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snap.hasData || snap.data!.docs.isEmpty) {
            return Center(
              child: Text('No hay cupones creados.', style: AppTheme.bodyMedium),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
            itemCount: snap.data!.docs.length,
            itemBuilder: (ctx, i) {
              final doc   = snap.data!.docs[i];
              final cupon = doc.data() as Map<String, dynamic>;

              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color:        AppTheme.surface,
                    borderRadius: BorderRadius.circular(AppTheme.radiusL),
                    border:       Border.all(color: AppTheme.goldSoft, width: 1),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 40, height: 40,
                        decoration: const BoxDecoration(
                            color: AppTheme.goldSoft, shape: BoxShape.circle),
                        child: Icon(Icons.card_giftcard_outlined,
                            color: AppTheme.gold, size: 20),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(cupon[Campos.titulo] ?? '', style: AppTheme.titleSmall),
                            const SizedBox(height: 2),
                            Text(
                              '${cupon[Campos.descripcion]}  ·  ${cupon[Campos.puntosNecesarios]} Citas V',
                              style: AppTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.edit_outlined,
                            color: AppTheme.textSecond, size: 20),
                        onPressed: () => _mostrarDialogoCupon(documentoActual: doc),
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
