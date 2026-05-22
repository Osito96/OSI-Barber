/// Nombres de las colecciones de Firestore.
///
/// Usa siempre estas constantes en lugar de strings directos.
/// Así si algún día cambias el nombre de una colección,
/// solo lo cambias aquí y se actualiza en toda la app.
///
/// Ejemplo de uso:
///   FirebaseFirestore.instance.collection(Colecciones.clientes)
class Colecciones {
  Colecciones._(); // Evitamos que se pueda instanciar

  static const String clientes = 'clientes';
  static const String citas = 'citas';
  static const String servicios = 'servicios';
  static const String cupones = 'cupones';
  static const String canjesCupones = 'canjes_cupones';
  static const String chats = 'chats';
  static const String mensajes = 'mensajes';
  static const String diasBloqueados = 'dias_bloqueados';
}

/// Campos comunes de los documentos de Firestore.
///
/// Misma idea que Colecciones: un solo lugar para cambiar un nombre de campo.
class Campos {
  Campos._();

  // Clientes
  static const String nombre = 'nombre';
  static const String telefono = 'telefono';
  static const String correo = 'correo';
  static const String esAdmin = 'esAdmin';
  static const String citasV = 'citasV';
  static const String citasX = 'citasX';
  static const String fotoPerfil = 'fotoPerfil';
  static const String fechaRegistro = 'fecha_registro';

  // Citas
  static const String clienteId = 'clienteId';
  static const String nombreCliente = 'nombreCliente';
  static const String servicio = 'servicio';
  static const String precio = 'precio';
  static const String duracion = 'duracion';
  static const String fecha = 'fecha';
  static const String hora = 'hora';
  static const String estado = 'estado';
  static const String fechaCreacion = 'fechaCreacion';

  // Chats
  static const String ultimoMensaje = 'ultimoMensaje';
  static const String timestamp = 'timestamp';
  static const String noLeidosAdmin = 'noLeidosAdmin';
  static const String noLeidosCliente = 'noLeidosCliente';
  static const String emisorId = 'emisorId';
  static const String texto = 'texto';

  // Servicios
  static const String orden = 'orden';

  // Cupones
  static const String titulo = 'titulo';
  static const String descripcion = 'descripcion';
  static const String puntosNecesarios = 'puntosNecesarios';
  static const String cuponTitulo = 'cuponTitulo';
  static const String puntosGastados = 'puntosGastados';
  static const String fechaCanje = 'fechaCanje';

  // Días bloqueados
  static const String bloqueado = 'bloqueado';
}

/// Estados posibles de una cita.
class EstadoCita {
  EstadoCita._();

  static const String pendiente = 'pendiente';
  static const String completada = 'completada';
  static const String ausente = 'ausente';
}
