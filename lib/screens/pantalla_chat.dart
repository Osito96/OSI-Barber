import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class PantallaChat extends StatefulWidget {
  final String clienteId;
  final String nombreDestinatario;

  const PantallaChat({
    super.key,
    required this.clienteId,
    required this.nombreDestinatario,
  });

  @override
  State<PantallaChat> createState() => _PantallaChatState();
}

class _PantallaChatState extends State<PantallaChat> {
  // --- Controladores y Variables ---
  final TextEditingController _controladorMensaje = TextEditingController();
  final String _miUid = FirebaseAuth.instance.currentUser!.uid;
  
  // Saber si soy el barbero o el cliente cambia la lógica de a quién le llega la notificación
  late bool _soyAdmin;
  
  // El "túnel" de conexión constante con la base de datos para leer mensajes
  late Stream<QuerySnapshot> _mensajesStream; 

  @override
  void initState() {
    super.initState();
    // Si mi ID no es el mismo que el ID del cliente del chat, significa que yo soy el Admin
    _soyAdmin = _miUid != widget.clienteId;
    
    _resetearNotificaciones();
    
    // Conectamos el "túnel" ordenando los mensajes para que los nuevos salgan abajo
    _mensajesStream = FirebaseFirestore.instance
        .collection('chats')
        .doc(widget.clienteId)
        .collection('mensajes')
        .orderBy('timestamp', descending: true)
        .snapshots();
  }

  // --- Limpiar contadores (Bolita roja) ---
  // Cuando entramos al chat, le decimos a Firebase que ya hemos leído todo
  void _resetearNotificaciones() {
    FirebaseFirestore.instance.collection('chats').doc(widget.clienteId).set({
      _soyAdmin ? 'noLeidosAdmin' : 'noLeidosCliente': 0,
    }, SetOptions(merge: true));
  }

  // --- Lógica de Envío de Mensaje y Notificación Push ---
  Future<void> _enviarMensaje() async {
    // Evitamos mandar mensajes vacíos o llenos de espacios
    if (_controladorMensaje.text.trim().isEmpty) return;

    String textoMensaje = _controladorMensaje.text.trim();
    _controladorMensaje.clear();

    // 1. Guardamos el mensaje físico dentro de la subcolección 'mensajes' del cliente
    await FirebaseFirestore.instance.collection('chats').doc(widget.clienteId).collection('mensajes').add({
      'emisorId': _miUid,
      'texto': textoMensaje,
      'timestamp': FieldValue.serverTimestamp(),
    });

    // 2. Actualizamos el "resumen" del chat para que salga en la lista general con la bolita roja
    await FirebaseFirestore.instance.collection('chats').doc(widget.clienteId).set({
      'ultimoMensaje': textoMensaje,
      'timestamp': FieldValue.serverTimestamp(),
      'clienteId': widget.clienteId,
      // Si soy admin, le sumo un "no leído" al cliente, y viceversa
      _soyAdmin ? 'noLeidosCliente' : 'noLeidosAdmin': FieldValue.increment(1),
    }, SetOptions(merge: true));

    // ==========================================================
    // 3. INTEGRACIÓN CON ONESIGNAL (NOTIFICACIONES PUSH DINÁMICAS)
    // ==========================================================
    String receptorId = '';
    String remitente = _soyAdmin ? 'OSI Barber' : 'Nuevo mensaje de cliente';

    if (_soyAdmin) {
      // Si yo soy el barbero, el mensaje va directo al móvil del cliente con el que chateo
      receptorId = widget.clienteId;
    } else {
      // Si soy un cliente, busco dinámicamente en la base de datos quién es el administrador actual
      var queryAdmin = await FirebaseFirestore.instance
          .collection('clientes')
          .where('esAdmin', isEqualTo: true)
          .limit(1)
          .get();
          
      if (queryAdmin.docs.isNotEmpty) {
        receptorId = queryAdmin.docs.first.id; // Obtenemos el ID real del admin directamente de Firestore
      }
    }

    // Si por algún motivo raro no hay receptor válido, cancelamos la notificación para que la app no pete
    if (receptorId.isEmpty) return;

    // Construimos la petición HTTP POST hacia la API de OneSignal
    var url = Uri.parse('https://onesignal.com/api/v1/notifications');
    var body = jsonEncode({
      "app_id": "TU_ONESIGNAL_ID_APP_AQUI",
      "target_channel": "push",
      "include_aliases": {
        "external_id": [receptorId] 
      },
      "headings": {"en": remitente, "es": remitente}, // Título de la notificación
      "contents": {"en": textoMensaje, "es": textoMensaje} // Cuerpo del mensaje
    });

    try {
      // Lanzamos la petición a los servidores de OneSignal
      await http.post(
        url,
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Basic TU_CLAVE_REST_API_AQUI" // Clave REST API de OneSignal
        },
        body: body,
      );
    } catch (e) {
      debugPrint("Error al enviar push: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // --- AppBar (Cabecera del chat con foto) ---
      appBar: AppBar(
        backgroundColor: Colors.black,
        // Usamos un StreamBuilder aquí para que si el cliente cambia su foto mientras chateamos, se actualice en directo
        title: StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance.collection('clientes').doc(widget.clienteId).snapshots(),
          builder: (context, snapshot) {
            String fotoPerfilText = '';
            if (snapshot.hasData && snapshot.data!.exists) {
              var datos = snapshot.data!.data() as Map<String, dynamic>;
              fotoPerfilText = datos['fotoPerfil'] ?? '';
            }

            return Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: Colors.amber,
                  backgroundImage: fotoPerfilText.isNotEmpty ? MemoryImage(base64Decode(fotoPerfilText)) : null,
                  child: fotoPerfilText.isEmpty ? const Icon(Icons.person, size: 20, color: Colors.black) : null,
                ),
                const SizedBox(width: 15),
                Expanded(
                  child: Text(
                    widget.nombreDestinatario,
                    overflow: TextOverflow.ellipsis, 
                  ),
                ),
              ],
            );
          },
        ),
      ),
      
      // --- Cuerpo del Chat ---
      body: SafeArea(
        child: Column(
          children: [
            // 1. Zona donde se dibujan los mensajes (Lista invertida)
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: _mensajesStream, 
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator(color: Colors.amber));
                  }
                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return const Center(
                      child: Text('Escribe el primer mensaje...', style: TextStyle(color: Colors.white54))
                    );
                  }

                  return ListView.builder(
                    reverse: true, // Esto hace que los mensajes nuevos empujen desde abajo hacia arriba (estilo WhatsApp)
                    padding: const EdgeInsets.all(10),
                    itemCount: snapshot.data!.docs.length,
                    itemBuilder: (context, index) {
                      var mensajeDoc = snapshot.data!.docs[index];
                      var mensaje = mensajeDoc.data() as Map<String, dynamic>;
                      bool soyYoElEmisor = mensaje['emisorId'] == _miUid;

                      // Protegemos la fecha por si Firebase tarda un milisegundo en procesar el serverTimestamp
                      DateTime fechaMensaje = (mensaje['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now();

                      // Lógica compleja: ¿Mostramos el "Hoy" o "Ayer" encima del mensaje?
                      // Solo lo mostramos si es el primer mensaje de la lista o si el mensaje anterior es de otro día distinto
                      bool mostrarCabeceraFecha = false;
                      if (index == snapshot.data!.docs.length - 1) {
                        mostrarCabeceraFecha = true;
                      } else {
                        var mensajeAnterior = snapshot.data!.docs[index + 1].data() as Map<String, dynamic>;
                        DateTime? fechaAnterior = (mensajeAnterior['timestamp'] as Timestamp?)?.toDate();
                        
                        if (fechaAnterior != null) {
                          if (fechaMensaje.day != fechaAnterior.day || 
                              fechaMensaje.month != fechaAnterior.month || 
                              fechaMensaje.year != fechaAnterior.year) {
                            mostrarCabeceraFecha = true;
                          }
                        }
                      }

                      Widget burbuja = _construirBurbujaMensaje(mensaje['texto'] ?? '', soyYoElEmisor, fechaMensaje);

                      // Si toca poner fecha, metemos la etiqueta y debajo la burbuja
                      if (mostrarCabeceraFecha) {
                        return Column(
                          children: [
                            _construirCabeceraFecha(fechaMensaje),
                            burbuja,
                          ],
                        );
                      }
                      return burbuja; // Si no, solo la burbuja
                    },
                  );
                },
              ),
            ),
            
            // 2. Barra inferior para escribir (Input)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
              color: Colors.grey[900],
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controladorMensaje,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'Mensaje',
                        hintStyle: const TextStyle(color: Colors.white54),
                        filled: true,
                        fillColor: Colors.black,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(25), 
                          borderSide: BorderSide.none
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  CircleAvatar(
                    backgroundColor: Colors.amber,
                    radius: 25,
                    child: IconButton(
                      icon: const Icon(Icons.send, color: Colors.black), 
                      onPressed: _enviarMensaje
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- Widgets Auxiliares ---

  // Crea la etiqueta gris centrada que dice "Hoy", "Ayer" o la fecha completa
  Widget _construirCabeceraFecha(DateTime fecha) {
    DateTime ahora = DateTime.now();
    DateTime ayer = ahora.subtract(const Duration(days: 1));
    String textoFecha = '';

    if (fecha.year == ahora.year && fecha.month == ahora.month && fecha.day == ahora.day) {
      textoFecha = 'Hoy';
    } else if (fecha.year == ayer.year && fecha.month == ayer.month && fecha.day == ayer.day) {
      textoFecha = 'Ayer';
    } else {
      textoFecha = '${fecha.day.toString().padLeft(2, '0')}/${fecha.month.toString().padLeft(2, '0')}/${fecha.year}';
    }

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 15),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.grey[850], 
        borderRadius: BorderRadius.circular(10)
      ),
      child: Text(
        textoFecha, 
        style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold)
      ),
    );
  }

  // Pinta el "globo" de texto. Si soy yo es dorado (derecha), si es el otro es gris oscuro (izquierda)
  Widget _construirBurbujaMensaje(String texto, bool soyYo, DateTime fecha) {
    String horaFormateada = '${fecha.hour.toString().padLeft(2, '0')}:${fecha.minute.toString().padLeft(2, '0')}';

    return Align(
      alignment: soyYo ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        // Para que la burbuja no ocupe toda la pantalla y haga saltos de línea elegantes
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75
        ), 
        margin: const EdgeInsets.only(bottom: 8, left: 10, right: 10),
        padding: const EdgeInsets.only(left: 12, right: 10, top: 10, bottom: 6),
        decoration: BoxDecoration(
          color: soyYo ? Colors.amber : const Color(0xFF202C33), 
          // Este borderRadius hace el efecto del piquito de la burbuja (estilo WhatsApp)
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(15),
            topRight: const Radius.circular(15),
            bottomLeft: soyYo ? const Radius.circular(15) : const Radius.circular(0),
            bottomRight: soyYo ? const Radius.circular(0) : const Radius.circular(15),
          ),
        ),
        child: Wrap(
          alignment: WrapAlignment.end,
          crossAxisAlignment: WrapCrossAlignment.end,
          children: [
            Text(
              texto,
              style: TextStyle(
                color: soyYo ? Colors.black : Colors.white,
                fontSize: 16,
                fontWeight: soyYo ? FontWeight.w500 : FontWeight.normal,
              ),
            ),
            const SizedBox(width: 10), 
            Padding(
              padding: const EdgeInsets.only(bottom: 2), 
              child: Text(
                horaFormateada,
                style: TextStyle(
                  color: soyYo ? Colors.black54 : Colors.white54,
                  fontSize: 11,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}