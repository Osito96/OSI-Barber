# 💈 OSI Barber

[![Flutter](https://img.shields.io/badge/Flutter-Mobile%20App-02569B?logo=flutter&logoColor=white)](https://flutter.dev)
[![Firebase](https://img.shields.io/badge/Firebase-Auth%20%2B%20Firestore-FFCA28?logo=firebase&logoColor=black)](https://firebase.google.com/)
[![Dart](https://img.shields.io/badge/Dart-%5E3.11.0-0175C2?logo=dart&logoColor=white)](https://dart.dev/)

**OSI Barber** es una aplicación móvil desarrollada en Flutter para gestionar reservas, clientes, comunicación y fidelización en una barbería.

El proyecto forma parte de un **Trabajo de Fin de Grado de Desarrollo de Aplicaciones Multiplataforma** y busca digitalizar el flujo habitual de una barbería: reserva de citas, control de agenda, comunicación cliente-barbero, gestión de servicios, cupones y estadísticas básicas del negocio.

---

## Índice

- [Funcionalidades principales](#funcionalidades-principales)
- [Roles de usuario](#roles-de-usuario)
- [Tecnologías utilizadas](#tecnologías-utilizadas)
- [Base de datos](#base-de-datos)
- [Arquitectura del proyecto](#arquitectura-del-proyecto)
- [Instalación y ejecución](#instalación-y-ejecución)
- [Generación del APK](#generación-del-apk)
- [Configuración de seguridad](#configuración-de-seguridad)
- [Mejoras futuras](#mejoras-futuras)
- [English summary](#english-summary)

---

## Funcionalidades principales

### Cliente

- Registro e inicio de sesión mediante Firebase Authentication.
- Consulta de servicios disponibles.
- Reserva de citas con cálculo de disponibilidad real.
- Consulta de próximas citas.
- Cancelación de citas con restricciones para evitar cancelaciones de última hora.
- Chat en tiempo real con el administrador.
- Sistema de fidelización mediante **Citas V** y **Citas X**.
- Canje de cupones usando puntos acumulados.
- Edición de perfil e imagen de usuario.

### Administrador

- Panel de agenda diaria.
- Consulta de citas pendientes.
- Marcado de citas como completadas o ausentes.
- Bloqueo de días no disponibles.
- Gestión de servicios, precios y duración.
- Gestión de cupones y recompensas.
- Chat con clientes y badges de mensajes no leídos.
- Consulta de ingresos y estadísticas básicas.

---

## Roles de usuario

La aplicación diferencia entre **cliente** y **administrador** mediante un campo de rol almacenado en Firestore.

| Rol | Acceso principal |
|---|---|
| Cliente | Servicios, reservas, mis citas, chat, cupones y perfil. |
| Administrador | Agenda, citas pendientes, gestión de servicios, cupones, chat e ingresos. |

Este enfoque permite usar una única aplicación con dos experiencias distintas según el tipo de usuario autenticado.

---

## Tecnologías utilizadas

| Tecnología | Uso en el proyecto |
|---|---|
| Flutter | Desarrollo de la aplicación móvil multiplataforma. |
| Dart | Lenguaje principal de desarrollo. |
| Firebase Authentication | Registro, inicio de sesión y control de usuarios. |
| Cloud Firestore | Base de datos en la nube y sincronización en tiempo real. |
| Firebase Core | Inicialización de servicios Firebase. |
| OneSignal | Integración preparada para notificaciones push, pendiente de configuración productiva. |
| HTTP | Envío de peticiones externas para integraciones. |
| Image Picker | Selección de imágenes de perfil. |
| Google Fonts | Tipografías de la interfaz. |
| Git y GitHub | Control de versiones y entrega del código fuente. |

> Nota: OneSignal está contemplado como integración preparada o mejora futura. El repositorio no incluye credenciales reales de producción.

---

## Base de datos

La aplicación utiliza **Cloud Firestore** para almacenar y sincronizar la información principal del sistema.

Colecciones principales:

| Colección | Descripción |
|---|---|
| `clientes` | Datos de usuario, rol, puntos, asistencia y perfil. |
| `citas` | Reservas realizadas, fecha, hora, servicio, estado y cliente asociado. |
| `servicios` | Catálogo de servicios, precios y duración. |
| `cupones` | Recompensas configuradas por el administrador. |
| `canjes_cupones` | Historial de cupones canjeados por los clientes. |
| `chats` | Conversaciones, mensajes y contadores de no leídos. |
| `dias_bloqueados` | Fechas bloqueadas por el administrador para impedir reservas. |

---

## Arquitectura del proyecto

El código se organiza por responsabilidades para facilitar el mantenimiento y separar configuración, pantallas y utilidades comunes.

```text
lib/
├── core/
│   ├── app_routes.dart          # Transiciones y navegación reutilizable.
│   ├── app_theme.dart           # Tema visual de la aplicación.
│   └── constants.dart           # Nombres de colecciones y campos de Firestore.
├── screens/
│   ├── pantalla_splash.dart
│   ├── pantalla_bienvenida.dart
│   ├── pantalla_login.dart
│   ├── pantalla_registro.dart
│   ├── pantalla_inicio.dart
│   ├── pantalla_reserva.dart
│   ├── pantalla_mis_citas.dart
│   ├── pantalla_mis_cupones.dart
│   ├── pantalla_editar_perfil.dart
│   ├── pantalla_chat.dart
│   ├── pantalla_admin.dart
│   ├── pantalla_gestion_servicios.dart
│   ├── pantalla_gestion_cupones.dart
│   └── pantalla_estadisticas.dart
├── utils/
│   └── ui_utils.dart            # Utilidades comunes de interfaz.
├── firebase_options.dart        # Configuración local generada para Firebase.
└── main.dart                    # Punto de entrada de la aplicación.

assets/
├── logo_osi_barber.png
└── logo_osi_barber2.png
```

---

## Lógica destacada

### Cálculo de disponibilidad

El sistema de reservas divide la jornada en bloques de **15 minutos**. Cada servicio tiene una duración determinada, y la aplicación calcula cuántos bloques consecutivos necesita antes de mostrar una hora como disponible.

La disponibilidad se calcula teniendo en cuenta:

- citas ya existentes en Firestore;
- duración del servicio seleccionado;
- días bloqueados por el administrador;
- horarios ocupados;
- prevención de solapamientos.

### Chat y badges

El chat utiliza Firestore para guardar mensajes y mantener contadores separados:

- `noLeidosAdmin`
- `noLeidosCliente`

Al abrir una conversación, el contador correspondiente se reinicia para que el badge desaparezca.

### Fidelización

El sistema diferencia entre:

- **Citas V**: asistencias completadas que suman puntos.
- **Citas X**: ausencias registradas por el administrador.

Los puntos acumulados permiten canjear cupones, quedando el canje registrado en `canjes_cupones`.

---

## Instalación y ejecución

### Requisitos previos

- Flutter SDK compatible con Dart `^3.11.0`.
- Android SDK configurado.
- Proyecto Firebase propio.
- Dispositivo Android físico o emulador.

### Pasos

```bash
git clone https://github.com/Osito96/OSI-Barber.git
cd OSI-Barber
flutter pub get
```

Configurar Firebase:

1. Crear un proyecto en Firebase.
2. Habilitar Firebase Authentication.
3. Habilitar Cloud Firestore.
4. Añadir `google-services.json` en `android/app/`.
5. Generar o configurar `lib/firebase_options.dart` según el proyecto Firebase utilizado.

Ejecutar la aplicación:

```bash
flutter run
```

---

## Generación del APK

Para generar una versión instalable en Android:

```bash
flutter build apk --release
```

El APK resultante se genera normalmente en:

```text
build/app/outputs/flutter-apk/app-release.apk
```

---

## Configuración de seguridad

El repositorio no debe incluir credenciales reales ni claves privadas.

Archivos y valores que deben configurarse localmente:

- `android/app/google-services.json`
- `lib/firebase_options.dart`
- App ID de OneSignal, si se activa la integración.
- REST API Key de OneSignal, si se activa el envío de notificaciones push.

En el código se mantienen placeholders para evitar publicar credenciales sensibles.

---

## Estado del proyecto

Proyecto finalizado como entrega académica de TFG.

Incluye:

- aplicación Flutter funcional;
- conexión con Firebase Authentication y Firestore;
- flujos de cliente y administrador;
- sistema de reservas;
- chat;
- cupones;
- estadísticas;
- generación de APK release.

---

## Mejoras futuras

- Configuración completa de notificaciones push con OneSignal.
- Gestión multiempleado para barberías con varios trabajadores.
- Pasarela de pago online.
- Panel web de administración.
- Publicación en Google Play Store.

---

## English summary

**OSI Barber** is a Flutter mobile application created as a final academic project for barbershop management.

The app includes appointment booking, role-based access, customer and administrator flows, Firestore real-time data, chat, coupons, attendance tracking and basic business statistics.

Main technologies:

- Flutter and Dart
- Firebase Authentication
- Cloud Firestore
- OneSignal integration prepared for future push notifications
- Git and GitHub

To run the project, configure a Firebase project, add the required local Firebase files and execute:

```bash
flutter pub get
flutter run
```

To build the Android release APK:

```bash
flutter build apk --release
```
