import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'pantalla_bienvenida.dart';
import 'pantalla_reserva.dart';
import 'pantalla_admin.dart';
import 'pantalla_mis_citas.dart';
import 'pantalla_chat.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'pantalla_gestion_servicios.dart';
import 'pantalla_gestion_cupones.dart';
import 'pantalla_mis_cupones.dart';
import 'pantalla_estadisticas.dart';
import 'pantalla_editar_perfil.dart';
import 'dart:convert';

class PantallaInicio extends StatefulWidget {
  const PantallaInicio({super.key});

  @override
  State<PantallaInicio> createState() => _PantallaInicioState();
}

class _PantallaInicioState extends State<PantallaInicio> {
  // Variable para controlar si el usuario que entra es el dueño (Admin) o un cliente
  bool _esAdmin = false;

  @override
  void initState() {
    super.initState();
    _cargarRol(); // Al arrancar, comprobamos quién es el usuario
  }

  // --- Gestión de Permisos y Notificaciones ---
  Future<void> _cargarRol() async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    
    // Vinculamos este móvil con OneSignal usando el UID de Firebase
    // Así las notificaciones llegarán directas a esta persona
    OneSignal.login(uid); 

    // Buscamos en la base de datos si tiene marcado el "check" de administrador
    var doc = await FirebaseFirestore.instance.collection('clientes').doc(uid).get();
    if (mounted && doc.exists) {
      setState(() { _esAdmin = doc.data()?['esAdmin'] ?? false; });
    }
  }

  // Salida segura de la aplicación
  Future<void> _cerrarSesion() async {
    await FirebaseAuth.instance.signOut();
    if (mounted) {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const PantallaBienvenida()));
    }
  }

  // --- Ventana de información del usuario (Popup) ---
  // Muestra los puntos (Citas V) y faltas (Citas X) en tiempo real
  void _mostrarPerfilUsuario(String uid) {
    showDialog(
      context: context,
      builder: (context) {
        return StreamBuilder<DocumentSnapshot>(
          // Escuchamos Firestore para que si el Admin le suma un punto, el cliente lo vea al momento
          stream: FirebaseFirestore.instance.collection('clientes').doc(uid).snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator(color: Colors.amber));
            }
            if (!snapshot.hasData || !snapshot.data!.exists) {
              return const AlertDialog(title: Text('Error al cargar perfil'));
            }

            var datos = snapshot.data!.data() as Map<String, dynamic>;
            String nombre = datos['nombre'] ?? 'Cliente';
            String telefono = datos['telefono'] ?? ''; 
            String fotoPerfilText = datos['fotoPerfil'] ?? ''; 
            int citasV = datos['citasV'] ?? 0;
            int citasX = datos['citasX'] ?? 0;

            return AlertDialog(
              backgroundColor: Colors.grey[900],
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: const BorderSide(color: Colors.amber, width: 1),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Mostramos la foto decodificada de Base64
                  CircleAvatar(
                    radius: 40,
                    backgroundColor: Colors.black,
                    backgroundImage: fotoPerfilText.isNotEmpty ? MemoryImage(base64Decode(fotoPerfilText)) : null,
                    child: fotoPerfilText.isEmpty ? const Icon(Icons.person, size: 50, color: Colors.white54) : null,
                  ),
                  const SizedBox(height: 15),
                  Text(
                    nombre,
                    style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  const Divider(color: Colors.white24, height: 30),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      Column(
                        children: [
                          const Text('Citas V', style: TextStyle(color: Colors.white70)),
                          Text(
                            citasV.toString(),
                            style: const TextStyle(color: Colors.greenAccent, fontSize: 28, fontWeight: FontWeight.bold),
                          )
                        ],
                      ),
                      Column(
                        children: [
                          const Text('Citas X', style: TextStyle(color: Colors.white70)),
                          Text(
                            citasX.toString(),
                            style: const TextStyle(color: Colors.redAccent, fontSize: 28, fontWeight: FontWeight.bold),
                          )
                        ],
                      )
                    ],
                  ),
                  const SizedBox(height: 25),
                  
                  // Botón para saltar a la edición de datos
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.black,
                        foregroundColor: Colors.amber,
                        side: const BorderSide(color: Colors.amber),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      icon: const Icon(Icons.edit),
                      label: const Text('Editar Perfil'),
                      onPressed: () {
                        Navigator.pop(context); 
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => PantallaEditarPerfil(
                              uid: uid,
                              nombreActual: nombre,
                              telefonoActual: telefono,
                              fotoBase64Actual: fotoPerfilText,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 10),

                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cerrar', style: TextStyle(color: Colors.white54)),
                  )
                ],
              ),
            );
          },
        );
      },
    );
  }

  // --- Sistema de Notificaciones Visuales (Bolita Roja) ---
  // Cuenta cuántos mensajes hay sin leer para avisar al usuario en el menú
  Widget _construirIconoConBolita(Widget iconoBase, String uid) {
    return StreamBuilder<QuerySnapshot>(
      stream: _esAdmin
          ? FirebaseFirestore.instance.collection('chats').where('noLeidosAdmin', isGreaterThan: 0).snapshots()
          : FirebaseFirestore.instance.collection('chats').where('clienteId', isEqualTo: uid).snapshots(),
      builder: (context, snapshot) {
        int total = 0;
        if (snapshot.hasData) {
          for (var doc in snapshot.data!.docs) {
            var data = doc.data() as Map<String, dynamic>;
            // Dependiendo de si es admin o no, miramos un contador u otro
            total += (data[_esAdmin ? 'noLeidosAdmin' : 'noLeidosCliente'] ?? 0) as int;
          }
        }
        return total > 0
            ? Badge(
                backgroundColor: const Color.fromARGB(255, 236, 22, 6), 
                label: Text('$total', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                child: iconoBase,
              )
            : iconoBase;
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final usuarioActual = FirebaseAuth.instance.currentUser;
    if (usuarioActual == null) return const Scaffold();

    return Scaffold(
      appBar: AppBar(
        leading: Builder(
          builder: (context) {
            return IconButton(
              // El icono del menú lateral también avisa si hay mensajes pendientes
              icon: _construirIconoConBolita(const Icon(Icons.menu), usuarioActual.uid),
              onPressed: () => Scaffold.of(context).openDrawer(),
            );
          },
        ),
        title: const Text('OSI BARBER', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.black,
        
        // Foto de perfil arriba a la derecha que se actualiza en vivo
        actions: [
          StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance.collection('clientes').doc(usuarioActual.uid).snapshots(),
            builder: (context, snapshot) {
              String fotoPerfilText = '';
              if (snapshot.hasData && snapshot.data!.exists) {
                var datos = snapshot.data!.data() as Map<String, dynamic>;
                fotoPerfilText = datos['fotoPerfil'] ?? '';
              }
              
              return Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: IconButton(
                  onPressed: () => _mostrarPerfilUsuario(usuarioActual.uid),
                  icon: CircleAvatar(
                    radius: 16,
                    backgroundColor: Colors.amber,
                    backgroundImage: fotoPerfilText.isNotEmpty ? MemoryImage(base64Decode(fotoPerfilText)) : null,
                    child: fotoPerfilText.isEmpty ? const Icon(Icons.person, size: 18, color: Colors.black) : null,
                  ),
                ),
              );
            },
          )
        ],
      ),
      
      // --- Menú Lateral Dinámico ---
      drawer: Drawer(
        backgroundColor: Colors.grey[900],
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            // Cabecera elegante con el logo de la barbería
            DrawerHeader(
              decoration: const BoxDecoration(
                color: Colors.black,
                border: Border(bottom: BorderSide(color: Color(0xFFFFC107), width: 1))
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Image.asset(
                    'assets/logo_osi_barber.png', 
                    height: 90, 
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'OSI BARBER',
                    style: TextStyle(
                      color: Color(0xFFFFC107), 
                      fontSize: 18, 
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2, 
                    ),
                  )
                ],
              ),
            ),
            ListTile(
              leading: const Icon(Icons.home, color: Colors.amber),
              title: const Text('Inicio'),
              onTap: () => Navigator.pop(context),
            ),
            ListTile(
              leading: const Icon(Icons.calendar_month, color: Colors.amber),
              title: const Text('Mis Citas'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (context) => const PantallaMisCitas()));
              },
            ),
            ListTile(
              leading: const Icon(Icons.star, color: Colors.amber),
              title: const Text('CUPONES', style: TextStyle(fontWeight: FontWeight.bold)),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (context) => const PantallaMisCupones()));
              },
            ),
            // El chat solo aparece aquí si no eres el barbero
            if (!_esAdmin)
              ListTile(
                leading: _construirIconoConBolita(const Icon(Icons.chat, color: Colors.amber), usuarioActual.uid),
                title: const Text('Chat con el Barbero'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => PantallaChat(
                        clienteId: usuarioActual.uid,
                        nombreDestinatario: 'OSI Barber',
                      ),
                    ),
                  );
                },
              ),
           
           // --- Bloque de Gestión (Solo visible para el Admin) ---
           if (_esAdmin) ...[
              const Divider(color: Colors.white24),
              ListTile(
                leading: _construirIconoConBolita(const Icon(Icons.admin_panel_settings, color: Colors.amber), usuarioActual.uid),
                title: const Text('PANEL DE BARBERO', style: TextStyle(color: Colors.amber, fontWeight: FontWeight.bold)),
                onTap: () {
                  Navigator.pop(context); 
                  Navigator.push(context, MaterialPageRoute(builder: (context) => const PantallaAdmin()));
                },
              ),
              ListTile(
                leading: const Icon(Icons.cut, color: Colors.amber),
                title: const Text('Gestionar Servicios', style: TextStyle(color: Colors.amber, fontWeight: FontWeight.bold)),
                onTap: () {
                  Navigator.pop(context); 
                  Navigator.push(context, MaterialPageRoute(builder: (context) => const PantallaGestionServicios()));
                },
              ),
              ListTile(
                leading: const Icon(Icons.card_giftcard, color: Colors.amber),
                title: const Text('Gestionar Cupones', style: TextStyle(color: Colors.amber, fontWeight: FontWeight.bold)),
                onTap: () {
                  Navigator.pop(context); 
                  Navigator.push(context, MaterialPageRoute(builder: (context) => const PantallaGestionCupones()));
                },
              ),
              ListTile(
                leading: const Icon(Icons.bar_chart, color: Colors.amber),
                title: const Text('Panel de Ingresos', style: TextStyle(color: Colors.amber, fontWeight: FontWeight.bold)),
                onTap: () {
                  Navigator.pop(context); 
                  Navigator.push(context, MaterialPageRoute(builder: (context) => const PantallaEstadisticas()));
                },
              ),
              const Divider(color: Colors.white24),
            ],
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.redAccent),
              title: const Text('Cerrar Sesión'),
              onTap: _cerrarSesion,
            ),
          ],
        ),
      ),
      
      // --- Lista de Servicios para reservar ---
      body: Column(
        children: [
          const SizedBox(height: 20),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Selecciona un servicio',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.amber),
              ),
            ),
          ),
          const SizedBox(height: 15),
          Expanded(child: _construirListaServicios(usuarioActual.uid)),
        ],
      ),
    );
  }

  // Genera la lista de servicios leyendo directamente de Firestore y respetando el orden elegido
  Widget _construirListaServicios(String uid) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('servicios').orderBy('orden').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(child: Text('No hay servicios.'));
        }

        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            var servicio = snapshot.data!.docs[index].data() as Map<String, dynamic>;
            String nombreS = servicio['nombre'] ?? 'Servicio';
            int precio = servicio['precio'] ?? 0;
            int duracion = servicio['duracion'] ?? 0;

            return Card(
              color: Colors.grey[900],
              margin: const EdgeInsets.only(bottom: 15),
              child: ListTile(
                title: Text(nombreS, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                subtitle: Text('$duracion min', style: const TextStyle(color: Colors.white54)),
                trailing: Text('$precio€', style: const TextStyle(color: Colors.amber, fontSize: 18, fontWeight: FontWeight.bold)),
                onTap: () async {
                  // Antes de pasar a reservar, cargamos el nombre del cliente para agilizar el proceso
                  var userDoc = await FirebaseFirestore.instance.collection('clientes').doc(uid).get();
                  String nombreC = userDoc.data()?['nombre'] ?? 'Cliente';

                  if (mounted) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => PantallaReserva(
                          nombreServicio: nombreS,
                          precio: precio,
                          duracion: duracion,
                          nombreCliente: nombreC,
                        ),
                      ),
                    );
                  }
                },
              ),
            );
          },
        );
      },
    );
  }
}