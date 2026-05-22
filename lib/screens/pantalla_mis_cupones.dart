import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../core/app_theme.dart';
import '../core/constants.dart';

class PantallaMisCupones extends StatefulWidget {
  const PantallaMisCupones({super.key});

  @override
  State<PantallaMisCupones> createState() => _PantallaMisCuponesState();
}

class _PantallaMisCuponesState extends State<PantallaMisCupones> {
  late final String _miUid;

  FirebaseFirestore get _db => FirebaseFirestore.instance;
  FirebaseAuth get _auth => FirebaseAuth.instance;

  @override
  void initState() {
    super.initState();
    _miUid = _auth.currentUser!.uid;
  }

  void _confirmarCanjeo(String titulo, int puntosNecesarios) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Canjear cupón?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Vas a gastar ${_textoPuntos(puntosNecesarios)} para obtener:\n\n"$titulo"\n\nEnséñale esta pantalla al barbero.',
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () async {
                bool canjeCorrecto;
                try {
                  canjeCorrecto = await _canjearCupon(titulo, puntosNecesarios);
                } catch (e) {
                  debugPrint('Error al canjear cupón: $e');
                  if (!ctx.mounted || !mounted) return;
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: const Text('No se pudo canjear el cupón. Inténtalo de nuevo.'),
                    backgroundColor: AppTheme.error,
                    duration: const Duration(seconds: 5),
                  ));
                  return;
                }
                if (!ctx.mounted || !mounted) return;
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text(canjeCorrecto
                      ? '🎉 ¡Cupón canjeado! Enséñaselo al barbero.'
                      : 'No tienes puntos suficientes para este cupón.'),
                  backgroundColor: canjeCorrecto ? AppTheme.success : AppTheme.warning,
                  duration: const Duration(seconds: 5),
                ));
              },
              child: const Text('CANJEAR'),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mis cupones')),
      body: StreamBuilder<DocumentSnapshot>(
        stream: _db
            .collection(Colecciones.clientes).doc(_miUid).snapshots(),
        builder: (context, userSnap) {
          if (userSnap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final misPuntos = userSnap.hasData && userSnap.data!.exists
              ? _leerEntero((userSnap.data!.data() as Map<String, dynamic>)[Campos.citasV])
              : 0;

          return Column(
            children: [
              // ─── Cabecera de puntos ────────────────────────────────────────
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 24),
                decoration: const BoxDecoration(
                  color: AppTheme.surface,
                  border: Border(bottom: BorderSide(color: AppTheme.divider, width: 0.5)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Column(
                      children: [
                        Icon(Icons.star_rounded, color: AppTheme.gold, size: 32),
                        const SizedBox(height: 10),
                        Text(
                          '$misPuntos',
                          style: AppTheme.displayLarge.copyWith(color: AppTheme.gold),
                        ),
                        const SizedBox(height: 4),
                        Text('Citas completadas', style: AppTheme.bodyMedium),
                        const SizedBox(height: 2),
                        Text('Cada cita suma 1 punto', style: AppTheme.bodySmall),
                      ],
                    ),
                  ],
                ),
              ),
              // ─── Lista de cupones ──────────────────────────────────────────
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: _db
                      .collection(Colecciones.cupones)
                      .orderBy(Campos.puntosNecesarios)
                      .snapshots(),
                  builder: (context, cuponesSnap) {
                    if (cuponesSnap.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (!cuponesSnap.hasData || cuponesSnap.data!.docs.isEmpty) {
                      return Center(
                        child: Text('No hay cupones disponibles.',
                            style: AppTheme.bodyMedium),
                      );
                    }
                    return ListView.builder(
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
                      itemCount: cuponesSnap.data!.docs.length,
                      itemBuilder: (context, index) {
                        final cupon  = cuponesSnap.data!.docs[index].data()
                            as Map<String, dynamic>;
                        final titulo = cupon[Campos.titulo] as String? ?? '';
                        final desc   = cupon[Campos.descripcion] as String? ?? '';
                        final puntosLeidos = _leerEntero(cupon[Campos.puntosNecesarios], valorDefecto: 1);
                        final puntos = puntosLeidos <= 0 ? 1 : puntosLeidos;
                        final puedeC = misPuntos >= puntos;
                        final prog   = (misPuntos / puntos).clamp(0.0, 1.0);

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: Container(
                            decoration: BoxDecoration(
                              color:        AppTheme.surface,
                              borderRadius: BorderRadius.circular(AppTheme.radiusL),
                              border: Border.all(
                                color: puedeC ? AppTheme.gold : AppTheme.divider,
                                width: puedeC ? 1.5 : 0.5,
                              ),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(20),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Título + icono
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          titulo,
                                          style: AppTheme.titleMedium.copyWith(
                                            color: puedeC ? AppTheme.gold : AppTheme.textPrimary,
                                          ),
                                        ),
                                      ),
                                      Icon(
                                        Icons.card_giftcard_outlined,
                                        color: puedeC ? AppTheme.gold : AppTheme.textHint,
                                        size: 22,
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Text(desc, style: AppTheme.bodyMedium),
                                  const SizedBox(height: 20),
                                  // Progreso
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text('Progreso', style: AppTheme.bodySmall),
                                      Text(
                                        '$misPuntos / $puntos',
                                        style: AppTheme.labelGold.copyWith(
                                          color: puedeC ? AppTheme.gold : AppTheme.textSecond,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(AppTheme.radiusFull),
                                    child: LinearProgressIndicator(
                                      value:      prog,
                                      minHeight:  6,
                                      backgroundColor: AppTheme.surfaceHigh,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                          puedeC ? AppTheme.gold : AppTheme.textHint),
                                    ),
                                  ),
                                  const SizedBox(height: 20),
                                  // Botón de canjeo
                                  SizedBox(
                                    width: double.infinity, height: 46,
                                    child: ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: puedeC
                                            ? AppTheme.gold
                                            : AppTheme.surfaceHigh,
                                        foregroundColor: puedeC
                                            ? AppTheme.black
                                            : AppTheme.textHint,
                                        minimumSize: const Size(double.infinity, 46),
                                      ),
                                      onPressed: puedeC
                                          ? () => _confirmarCanjeo(titulo, puntos)
                                          : null,
                                      child: Text(
                                        puedeC ? 'CANJEAR CUPÓN' : 'FALTAN PUNTOS',
                                        style: AppTheme.buttonLabel.copyWith(
                                          color: puedeC ? AppTheme.black : AppTheme.textHint,
                                          fontSize: 13,
                                        ),
                                      ),
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
              ),
            ],
          );
        },
      ),
    );
  }

  int _leerEntero(dynamic valor, {int valorDefecto = 0}) {
    if (valor is int) return valor;
    if (valor is num) return valor.toInt();
    if (valor is String) return int.tryParse(valor) ?? valorDefecto;
    return valorDefecto;
  }

  String _textoPuntos(int puntos) {
    return '$puntos Cita${puntos > 1 ? 's' : ''} V';
  }

  Future<bool> _canjearCupon(String titulo, int puntosNecesarios) async {
    final clienteRef = _db.collection(Colecciones.clientes).doc(_miUid);
    final canjeRef = _db.collection(Colecciones.canjesCupones).doc();

    return _db.runTransaction((transaction) async {
      final clienteDoc = await transaction.get(clienteRef);
      final datosCliente = clienteDoc.data();
      final puntosActuales = _leerEntero(datosCliente?[Campos.citasV]);

      if (puntosActuales < puntosNecesarios) return false;

      transaction.update(clienteRef, {
        Campos.citasV: FieldValue.increment(-puntosNecesarios),
      });
      transaction.set(canjeRef, {
        Campos.clienteId: _miUid,
        Campos.nombreCliente: datosCliente?[Campos.nombre] ?? 'Cliente',
        Campos.cuponTitulo: titulo,
        Campos.puntosGastados: puntosNecesarios,
        Campos.fechaCanje: FieldValue.serverTimestamp(),
      });

      return true;
    });
  }
}
