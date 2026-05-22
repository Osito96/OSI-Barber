import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../core/app_theme.dart';
import '../core/constants.dart';
import '../utils/ui_utils.dart';

class PantallaMisCitas extends StatelessWidget {
  const PantallaMisCitas({super.key});

  FirebaseFirestore get _db => FirebaseFirestore.instance;
  FirebaseAuth get _auth => FirebaseAuth.instance;

  bool _puedeCancelar(DateTime fechaCita) {
    final hoy     = DateTime.now();
    final diaCita = DateTime(fechaCita.year,  fechaCita.month,  fechaCita.day);
    final diaHoy  = DateTime(hoy.year,        hoy.month,        hoy.day);
    return diaCita.isAfter(diaHoy);
  }

  @override
  Widget build(BuildContext context) {
    final uid = _auth.currentUser!.uid;

    return Scaffold(
      appBar: AppBar(title: const Text('Mis citas')),
      body: StreamBuilder<QuerySnapshot>(
        stream: _db
            .collection(Colecciones.citas)
            .where(Campos.clienteId, isEqualTo: uid)
            .where(Campos.estado,    isEqualTo: EstadoCita.pendiente)
            .orderBy(Campos.fecha)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Text('No tienes citas pendientes.', style: AppTheme.bodyMedium),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              final citaDoc   = snapshot.data!.docs[index];
              final datos     = citaDoc.data() as Map<String, dynamic>;
              final fechaCita = (datos[Campos.fecha] as Timestamp).toDate();
              final servicio  = datos[Campos.servicio] as String? ?? 'Servicio';
              final hora      = datos[Campos.hora]     as String? ?? '--:--';
              final puedeCanc = _puedeCancelar(fechaCita);

              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Container(
                  decoration: BoxDecoration(
                    color:        AppTheme.surface,
                    borderRadius: BorderRadius.circular(AppTheme.radiusL),
                    border: Border.all(
                      color: puedeCanc ? AppTheme.goldSoft : AppTheme.divider,
                      width: puedeCanc ? 1 : 0.5,
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Row(
                      children: [
                        // Badge de fecha
                        Container(
                          width: 54, height: 60,
                          decoration: BoxDecoration(
                            color:        AppTheme.goldSoft,
                            borderRadius: BorderRadius.circular(AppTheme.radiusM),
                            border: Border.all(
                              color: AppTheme.gold.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                '${fechaCita.day}',
                                style: AppTheme.titleLarge.copyWith(
                                    color: AppTheme.gold, height: 1),
                              ),
                              Text(
                                UiUtils.mesCorto(fechaCita.month).toUpperCase(),
                                style: AppTheme.bodySmall.copyWith(
                                    color: AppTheme.gold, letterSpacing: 0.5),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        // Info del servicio
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(servicio, style: AppTheme.titleSmall),
                              const SizedBox(height: 4),
                              Row(children: [
                                Icon(Icons.access_time_outlined,
                                    size: 13, color: AppTheme.textHint),
                                const SizedBox(width: 4),
                                Text(hora, style: AppTheme.bodyMedium),
                              ]),
                              const SizedBox(height: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color:        AppTheme.surfaceHigh,
                                  borderRadius: BorderRadius.circular(AppTheme.radiusFull),
                                ),
                                child: Text('Pendiente',
                                    style: AppTheme.bodySmall.copyWith(
                                        color: AppTheme.textSecond)),
                              ),
                            ],
                          ),
                        ),
                        // Acción
                        if (puedeCanc)
                          IconButton(
                            icon: Icon(Icons.close_rounded,
                                color: AppTheme.error, size: 20),
                            onPressed: () => _confirmarCancelacion(context, citaDoc.id),
                          )
                        else
                          Tooltip(
                            message: 'No se puede cancelar el mismo día',
                            child: IconButton(
                              icon: Icon(Icons.lock_outline_rounded,
                                  color: AppTheme.gold, size: 20),
                              onPressed: () => _mostrarAvisoNoCancelable(context),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _confirmarCancelacion(BuildContext context, String citaId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Cancelar cita?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Esta acción no se puede deshacer y el hueco quedará libre.',
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.error,
                foregroundColor: AppTheme.textPrimary,
                minimumSize: const Size(double.infinity, 44),
              ),
              onPressed: () async {
                await _db.collection(Colecciones.citas).doc(citaId).delete();
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: const Text('Sí, cancelar'),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('No, mantener'),
            ),
          ],
        ),
      ),
    );
  }

  void _mostrarAvisoNoCancelable(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.lock_outline_rounded, color: AppTheme.gold),
            const SizedBox(width: 10),
            const Text('Cancelación bloqueada'),
          ],
        ),
        content: const Text(
          'No se pueden cancelar citas el mismo día. Si necesitas ayuda, contacta con la barbería.',
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Entendido'),
          ),
        ],
      ),
    );
  }
}
