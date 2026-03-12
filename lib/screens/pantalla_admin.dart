import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'pantalla_chat.dart';
import 'dart:convert'; // Necesario para transformar la foto de perfil (texto base64) en una imagen real

class PantallaAdmin extends StatefulWidget {
  const PantallaAdmin({super.key});

  @override
  State<PantallaAdmin> createState() => _PantallaAdminState();
}

class _PantallaAdminState extends State<PantallaAdmin> {
  // Por defecto, al abrir la agenda queremos ver las citas de "hoy"
  DateTime _diaVer = DateTime.now();

  @override
  Widget build(BuildContext context) {
    // Usamos DefaultTabController para crear las 3 pestañas deslizables de forma sencilla
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('PANEL DE BARBERO', style: TextStyle(fontWeight: FontWeight.bold)),
          backgroundColor: Colors.black,
          bottom: TabBar(
            indicatorColor: Colors.amber,
            labelColor: Colors.amber,
            unselectedLabelColor: Colors.white54,
            tabs: [
              const Tab(icon: Icon(Icons.calendar_month), text: 'Agenda'),
              const Tab(icon: Icon(Icons.emoji_events), text: 'Ranking'),
              
              // --- Pestaña de Mensajes con "Bolita Roja" de notificaciones ---
              Tab(
                // Escuchamos Firebase en tiempo real para ver si hay mensajes nuevos
                icon: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance.collection('chats').where('noLeidosAdmin', isGreaterThan: 0).snapshots(),
                  builder: (context, snapshot) {
                    int totalNoLeidos = 0;
                    
                    // Sumamos todos los mensajes pendientes de todos los clientes
                    if (snapshot.hasData) {
                      for (var doc in snapshot.data!.docs) {
                        var data = doc.data() as Map<String, dynamic>;
                        totalNoLeidos += (data['noLeidosAdmin'] ?? 0) as int;
                      }
                    }
                    
                    // Si hay mensajes, mostramos la bolita roja pura. Si no, solo el icono normal.
                    return totalNoLeidos > 0
                        ? Badge(
                            backgroundColor: const Color.fromARGB(255, 236, 22, 6), 
                            label: Text('$totalNoLeidos', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                            child: const Icon(Icons.forum),
                          )
                        : const Icon(Icons.forum);
                  },
                ),
                text: 'Mensajes',
              ),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _construirPestanaAgenda(),
            _construirPestanaRanking(),
            _construirPestanaChats(),
          ],
        ),
      ),
    );
  }

  // --- 1. Pestaña de Agenda (Gestión de citas diaria) ---
  Widget _construirPestanaAgenda() {
    // Calculamos el inicio y el final del día seleccionado para filtrar en la base de datos
    DateTime inicio = DateTime(_diaVer.year, _diaVer.month, _diaVer.day, 0, 0);
    DateTime fin = DateTime(_diaVer.year, _diaVer.month, _diaVer.day, 23, 59);
    
    // Creamos un ID único para el día de hoy (ejemplo: "2023-10-05") para saber si lo hemos bloqueado
    String idDia = "${_diaVer.year}-${_diaVer.month.toString().padLeft(2, '0')}-${_diaVer.day.toString().padLeft(2, '0')}";

    return Column(
      children: [
        // Selector de Fecha superior
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
          color: Colors.grey[900],
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Citas del: ${_diaVer.day}/${_diaVer.month}/${_diaVer.year}',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
              ),
              IconButton(
                icon: const Icon(Icons.edit_calendar, color: Colors.amber),
                onPressed: () async {
                  // Abrimos el calendario nativo para saltar a otro día
                  DateTime? pick = await showDatePicker(
                    context: context,
                    initialDate: _diaVer,
                    firstDate: DateTime.now().subtract(const Duration(days: 60)), // Dejamos ver hasta 2 meses atrás
                    lastDate: DateTime.now().add(const Duration(days: 90)), // Y hasta 3 meses en el futuro
                  );
                  if (pick != null) setState(() => _diaVer = pick);
                },
              )
            ],
          ),
        ),

        // Interruptor para bloquear el día completo (ideal para festivos o imprevistos)
        StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance.collection('dias_bloqueados').doc(idDia).snapshots(),
          builder: (context, snapshot) {
            bool estaBloqueado = false;
            if (snapshot.hasData && snapshot.data!.exists) {
              estaBloqueado = snapshot.data!['bloqueado'] ?? false;
            }

            return Container(
              color: estaBloqueado ? Colors.red[900]?.withOpacity(0.3) : Colors.black,
              child: SwitchListTile(
                activeColor: Colors.redAccent,
                inactiveThumbColor: Colors.green,
                inactiveTrackColor: Colors.green.withOpacity(0.3),
                title: Text(
                  estaBloqueado ? '🚫 DÍA BLOQUEADO (No se puede reservar)' : '✅ DÍA ABIERTO (Reservas activas)',
                  style: TextStyle(
                    color: estaBloqueado ? Colors.redAccent : Colors.green,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                value: estaBloqueado,
                onChanged: (bool valor) async {
                  if (valor) {
                    // Bloqueamos: creamos el documento en Firebase
                    await FirebaseFirestore.instance.collection('dias_bloqueados').doc(idDia).set({'bloqueado': true});
                  } else {
                    // Desbloqueamos: borramos el documento
                    await FirebaseFirestore.instance.collection('dias_bloqueados').doc(idDia).delete();
                  }
                },
              ),
            );
          },
        ),

        // Lista de las citas programadas para el día seleccionado
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            // Filtramos las citas que caen exactamente entre las 00:00 y las 23:59 del día elegido
            stream: FirebaseFirestore.instance
                .collection('citas')
                .where('fecha', isGreaterThanOrEqualTo: Timestamp.fromDate(inicio))
                .where('fecha', isLessThanOrEqualTo: Timestamp.fromDate(fin))
                .orderBy('fecha')
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return const Center(
                  child: Text('No hay citas en este día.', style: TextStyle(color: Colors.white54)),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.all(10),
                itemCount: snapshot.data!.docs.length,
                itemBuilder: (context, index) {
                  var cita = snapshot.data!.docs[index];
                  var datos = cita.data() as Map<String, dynamic>;
                  String estado = datos['estado'] ?? 'pendiente';
                  String clienteId = datos['clienteId'];

                  return Card(
                    color: Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      // El borde de la tarjeta cambia de color según el estado de la cita
                      side: BorderSide(
                        color: estado == 'completada' ? Colors.green : estado == 'ausente' ? Colors.orange : Colors.amber,
                        width: 1,
                      ),
                    ),
                    margin: const EdgeInsets.only(bottom: 15),
                    child: Padding(
                      padding: const EdgeInsets.all(15),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(datos['hora'], style: const TextStyle(color: Colors.amber, fontSize: 22, fontWeight: FontWeight.bold)),
                              _etiquetaEstado(estado),
                            ],
                          ),
                          const SizedBox(height: 5),
                          Text(datos['nombreCliente'], style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                          Text('${datos['servicio']} - ${datos['duracion']} min', style: const TextStyle(color: Colors.white70)),
                          
                          // Si la cita aún no ha pasado, mostramos los botones de acción
                          if (estado == 'pendiente') ...[
                            const Divider(color: Colors.white24, height: 20),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                // Botón: Cliente asistió (Suma punto V)
                                IconButton(
                                  icon: const Icon(Icons.check_circle, color: Colors.green, size: 30), 
                                  onPressed: () => _actualizarEstadoCita(cita.id, clienteId, 'completada', 'citasV')
                                ),
                                // Botón: Cliente no apareció (Suma falta X)
                                IconButton(
                                  icon: const Icon(Icons.warning_rounded, color: Colors.orange, size: 30), 
                                  onPressed: () => _actualizarEstadoCita(cita.id, clienteId, 'ausente', 'citasX')
                                ),
                                // Botón: Cancelar y borrar la cita
                                IconButton(
                                  icon: const Icon(Icons.delete_forever, color: Colors.redAccent, size: 30), 
                                  onPressed: () => _confirmarBorrado(cita.id)
                                )
                              ],
                            )
                          ]
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        )
      ],
    );
  }

  // --- 2. Pestaña de Ranking (Gamificación y fiabilidad) ---
  Widget _construirPestanaRanking() {
    return StreamBuilder<QuerySnapshot>(
      // Traemos a todos los clientes ordenados por los que más han venido (citasV)
      stream: FirebaseFirestore.instance.collection('clientes').orderBy('citasV', descending: true).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(child: Text('No hay clientes.'));
        }

        return ListView.builder(
          padding: const EdgeInsets.all(10),
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            var cliente = snapshot.data!.docs[index].data() as Map<String, dynamic>;
            String nombre = cliente['nombre'] ?? 'Desconocido';
            int citasV = cliente['citasV'] ?? 0;
            int citasX = cliente['citasX'] ?? 0;

            // Premiamos visualmente a los 3 mejores clientes con medallas de oro, plata y bronce
            Widget iconoPosicion = Text(
              '#${index + 1}',
              style: const TextStyle(color: Colors.white54, fontSize: 18, fontWeight: FontWeight.bold),
            );
            if (index == 0) iconoPosicion = const Icon(Icons.workspace_premium, color: Colors.amber, size: 30);
            if (index == 1) iconoPosicion = const Icon(Icons.workspace_premium, color: Color(0xFFC0C0C0), size: 30);
            if (index == 2) iconoPosicion = const Icon(Icons.workspace_premium, color: Color(0xFFCD7F32), size: 30);

            return Card(
              color: Colors.grey[900],
              margin: const EdgeInsets.only(bottom: 10),
              child: ListTile(
                leading: iconoPosicion,
                title: Text(nombre, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
                subtitle: Text('Tel: ${cliente['telefono'] ?? '---'}', style: const TextStyle(color: Colors.white54)),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.check_circle, color: Colors.green, size: 16),
                    const SizedBox(width: 4),
                    Text('$citasV', style: const TextStyle(color: Colors.green, fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(width: 15),
                    const Icon(Icons.cancel, color: Colors.redAccent, size: 16),
                    const SizedBox(width: 4),
                    Text('$citasX', style: const TextStyle(color: Colors.redAccent, fontSize: 18, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // --- 3. Pestaña de Bandeja de Chats ---
  Widget _construirPestanaChats() {
    return StreamBuilder<QuerySnapshot>(
      // Escuchamos la colección de chats ordenados para que los más recientes salgan arriba
      stream: FirebaseFirestore.instance.collection('chats').orderBy('timestamp', descending: true).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: Colors.amber));
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(child: Text('No hay mensajes nuevos.'));
        }

        return ListView.builder(
          padding: const EdgeInsets.all(10),
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            var chatData = snapshot.data!.docs[index].data() as Map<String, dynamic>;
            String clienteId = chatData['clienteId'];
            String ultimoMensaje = chatData['ultimoMensaje'] ?? '';
            int noLeidos = chatData['noLeidosAdmin'] ?? 0;

            // Como en el documento de 'chats' no tenemos la foto, hacemos una segunda petición
            // rápida a 'clientes' con este FutureBuilder para sacar su avatar y su nombre real.
            return FutureBuilder<DocumentSnapshot>(
              future: FirebaseFirestore.instance.collection('clientes').doc(clienteId).get(),
              builder: (context, userSnapshot) {
                String nombreCliente = 'Cargando...';
                String fotoPerfilText = ''; 

                if (userSnapshot.hasData && userSnapshot.data!.exists) {
                  nombreCliente = userSnapshot.data!['nombre'] ?? 'Cliente';
                  fotoPerfilText = userSnapshot.data!['fotoPerfil'] ?? '';
                }

                return Card(
                  color: Colors.grey[900],
                  margin: const EdgeInsets.only(bottom: 10),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.amber,
                      radius: 25,
                      // Si tiene foto la decodificamos de Base64, si no, le ponemos el icono por defecto
                      backgroundImage: fotoPerfilText.isNotEmpty ? MemoryImage(base64Decode(fotoPerfilText)) : null,
                      child: fotoPerfilText.isEmpty ? const Icon(Icons.person, color: Colors.black) : null,
                    ),
                    title: Text(
                      nombreCliente,
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: noLeidos > 0 ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                    subtitle: Text(
                      ultimoMensaje,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: noLeidos > 0 ? Colors.white : Colors.white54),
                    ),
                    trailing: noLeidos > 0
                        ? Badge(
                            label: Text('$noLeidos', style: const TextStyle(color: Colors.white)),
                            child: const Icon(Icons.chevron_right, color: Colors.amber),
                          )
                        : const Icon(Icons.chevron_right, color: Colors.amber),
                    onTap: () {
                      // Al pulsar, entramos a la conversación completa
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => PantallaChat(
                            clienteId: clienteId,
                            nombreDestinatario: nombreCliente,
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  // --- Funciones Auxiliares ---

  // Devuelve un textito con el color correcto según cómo fue la cita
  Widget _etiquetaEstado(String estado) {
    if (estado == 'completada') {
      return const Text('COMPLETADA', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold));
    }
    if (estado == 'ausente') {
      return const Text('NO PRESENTADO', style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold));
    }
    return const Text('PENDIENTE', style: TextStyle(color: Colors.white54, fontWeight: FontWeight.bold));
  }

  // Al pulsar los botones de la agenda, guardamos el resultado y le sumamos puntos/faltas al cliente
  Future<void> _actualizarEstadoCita(String citaId, String clienteId, String nuevoEstado, String campoPuntos) async {
    await FirebaseFirestore.instance.collection('citas').doc(citaId).update({'estado': nuevoEstado});
    await FirebaseFirestore.instance.collection('clientes').doc(clienteId).update({
      campoPuntos: FieldValue.increment(1) // Suma 1 a citasV o citasX automáticamente
    });
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(nuevoEstado == 'completada' ? '✅ Cita completada. Puntos sumados.' : '⚠️ Falta registrada.'),
          backgroundColor: nuevoEstado == 'completada' ? Colors.green : Colors.orange,
        ),
      );
    }
  }

  // Ventana de aviso antes de borrar una cita por si nos hemos equivocado de botón
  void _confirmarBorrado(String citaId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.black,
        title: const Text('¿Cancelar Cita?', style: TextStyle(color: Colors.white)),
        content: const Text('Se borrará y se liberará el hueco para otro cliente.', style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Volver')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () {
              FirebaseFirestore.instance.collection('citas').doc(citaId).delete();
              Navigator.pop(context);
            },
            child: const Text('Eliminar y Liberar'),
          )
        ],
      ),
    );
  }
}