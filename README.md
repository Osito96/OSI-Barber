# 💈 OSI Barber: Gestión de Barbería 4.0

[![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?logo=flutter&logoColor=white)](https://flutter.dev)
[![Firebase](https://img.shields.io/badge/Firebase-Auth%20%26%20Firestore-FFCA28?logo=firebase&logoColor=black)](https://firebase.google.com/)
[![OneSignal](https://img.shields.io/badge/Notifications-OneSignal-E44B32?logo=onesignal&logoColor=white)](https://onesignal.com/)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

---

### 🌐 Idioma / Language
**[Castellano](#versión-en-español)** | **[English](#english-version)**

---

## Versión en Español

> **OSI Barber** no es solo una app de reservas; es un ecosistema completo para automatizar el flujo de trabajo de una barbería profesional, fidelizar clientes y optimizar la rentabilidad del negocio.

---

## 📖 Guía de la Aplicación

La aplicación se divide en dos experiencias totalmente diferenciadas según el rol del usuario (Cliente o Administrador), gestionadas dinámicamente desde el login.

### 👤 Experiencia del Cliente (Fidelización y Autogestión)
1.  **Reserva en Segundos:** El cliente selecciona un servicio y visualiza un calendario dinámico que solo muestra huecos reales disponibles.
2.  **Gamificación (Citas V):** Por cada asistencia, el usuario suma puntos. Si falta sin avisar, recibe una "Cita X".
3.  **Marketplace de Cupones:** Los puntos acumulados se canjean por servicios gratuitos o descuentos mediante un sistema de validación visual con el barbero.
4.  **Comunicación Directa:** Chat integrado con soporte para notificaciones Push para resolver dudas al instante.

### ✂️ Experiencia del Administrador (Control Total)
1.  **Agenda de Hoy:** Una lista organizada cronológicamente donde el barbero marca la asistencia de los clientes con un solo toque.
2.  **Gestor de Disponibilidad:** ¿Día festivo? ¿Cierre por imprevisto? El admin puede bloquear fechas completas para que nadie pueda reservar.
3.  **Control de Negocio:** Panel de estadísticas que calcula la facturación real y detecta cuál es el "Servicio Estrella" del mes.
4.  **Catálogo Dinámico:** Edición instantánea de precios, duraciones y nuevos premios desde el propio terminal móvil.

---

## 🛠️ Arquitectura Técnica y "Secret Sauce"

Este proyecto implementa soluciones técnicas avanzadas para problemas comunes en el desarrollo móvil:

* **Algoritmo de Colisiones:** El sistema de reservas calcula la duración de cada servicio y busca bloques contiguos de 15 minutos, evitando solapamientos accidentales.
* **Optimización de Imágenes (Base64):** Para evitar costes de almacenamiento extra en servidores externos, las fotos de perfil se procesan, comprimen y convierten a cadenas Base64 almacenadas directamente en Firestore.
* **Sincronización en Tiempo Real:** Uso intensivo de `Streams` para que, si el barbero cancela una cita, el cliente lo vea en su móvil sin necesidad de refrescar la pantalla.
* **Seguridad por Roles:** Implementación de lógica de filtrado en el arranque para proteger las rutas de administración.

---

## 🛡️ Configuración de Seguridad y Credenciales

Este repositorio cumple con las **Buenas Prácticas de Seguridad**. Se han omitido los archivos sensibles mediante `.gitignore`.

Para desplegar una instancia propia, el desarrollador debe:

1.  **Vincular Firebase:** Descargar y colocar `google-services.json` en `android/app/`.
2.  **Configurar OneSignal:**
    * Sustituir la clave en `main.dart`: `OneSignal.initialize("TU_APP_ID")`.
    * Sustituir la API Key en `pantalla_chat.dart`: `"Authorization": "Basic TU_REST_API_KEY"`.
3.  **Habilitar Localizations:** La app está configurada para calendario en español mediante `flutter_localizations`.

---

## 📐 Estructura del Proyecto

```text
lib/
├── screens/                        # Capa de Interfaz de Usuario (UI)
│   ├── pantalla_splash.dart        # Identidad visual corporativa y carga de recursos iniciales.
│   ├── pantalla_bienvenida.dart    # Punto de acceso principal y gestión de flujos de autenticación.
│   ├── pantalla_inicio.dart        # Dashboard central con navegación dinámica según el rol (Admin/Cliente).
│   ├── pantalla_reserva.dart       # Algoritmo de reservas con lógica de bloques de 15 min y disponibilidad.
│   ├── pantalla_mis_citas.dart     # Gestión de agenda del cliente y control de políticas de cancelación.
│   ├── pantalla_mis_cupones.dart   # Visualización de fidelidad, puntos acumulados y catálogo de premios.
│   ├── pantalla_editar_perfil.dart # Administración de datos personales y procesamiento de imágenes en Base64.
│   ├── pantalla_chat.dart          # Comunicación en tiempo real mediante Streams y notificaciones OneSignal.
│   ├── pantalla_admin.dart         # Panel operativo del barbero para control de asistencia y agenda diaria.
│   ├── pantalla_gestion_servicios.dart # CRUD dinámico para la administración de la oferta comercial.
│   ├── pantalla_gestion_cupones.dart   # Configuración del programa de recompensas y puntos necesarios.
│   ├── pantalla_estadisticas.dart  # Business Intelligence: análisis de ingresos y métricas de rendimiento.
│   └── pantalla_login.dart         # Interfaz de acceso seguro vinculada a la base de datos de Firebase Auth.
│
├── firebase_options.dart           # Configuración técnica de Firebase (Excluido de Git por seguridad).
└── main.dart                       # Punto de entrada y observador del ciclo de vida de la aplicación.
assets/
└── images/                         # Recursos gráficos: logos, banners y material promocional.
```





# 💈 OSI Barber: Barbershop Management 4.0

[![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?logo=flutter&logoColor=white)](https://flutter.dev)
[![Firebase](https://img.shields.io/badge/Firebase-Auth%20%26%20Firestore-FFCA28?logo=firebase&logoColor=black)](https://firebase.google.com/)
[![OneSignal](https://img.shields.io/badge/Notifications-OneSignal-E44B32?logo=onesignal&logoColor=white)](https://onesignal.com/)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

## English Version

---

> **OSI Barber** is not just a booking app; it is a complete ecosystem designed to automate the workflow of a professional barbershop, build customer loyalty, and optimize business profitability.

---

## 📖 Application Guide

The application is divided into two completely distinct experiences based on the user's role (Client or Administrator), managed dynamically from login.

### 👤 Client Experience (Loyalty and Self-Management)
1.  **Booking in Seconds:** The client selects a service and views a dynamic calendar showing only real available slots.
2.  **Gamification (V-Points):** For each attendance, the user earns points. If they fail to show up without notice, they receive an "X-Penalty" (Cita X).
3.  **Coupon Marketplace:** Accumulated points can be redeemed for free services or discounts through a visual validation system with the barber.
4.  **Direct Communication:** Integrated chat with Push notification support to resolve questions instantly.

### ✂️ Administrator Experience (Total Control)
1.  **Today's Agenda:** A chronologically organized list where the barber marks client attendance with a single tap.
2.  **Availability Manager:** Public holiday? Unexpected closure? The admin can block entire dates so no one can book.
3.  **Business Control:** Statistics dashboard that calculates real revenue and identifies the "Star Service" of the month.
4.  **Dynamic Catalog:** Instant editing of prices, durations, and new rewards directly from the mobile device.

---

## 🛠️ Technical Architecture and "Secret Sauce"

This project implements advanced technical solutions for common mobile development challenges:

* **Collision Algorithm:** The booking system calculates the duration of each service and finds contiguous 15-minute blocks, preventing accidental overlaps.
* **Image Optimization (Base64):** To avoid extra storage costs on external servers, profile pictures are processed, compressed, and converted into Base64 strings stored directly in Firestore.
* **Real-Time Synchronization:** Intensive use of `Streams` so that if the barber cancels an appointment, the client sees it on their mobile device without needing to refresh the screen.
* **Role-Based Security:** Implementation of filtering logic at startup to protect administrative routes.

---

## 🛡️ Security Configuration and Credentials

This repository complies with **Security Best Practices**. Sensitive files have been omitted using `.gitignore`.

To deploy a custom instance, the developer must:

1.  **Link Firebase:** Download and place `google-services.json` in `android/app/`.
2.  **Configure OneSignal:**
    * Replace the App ID in `main.dart`: `OneSignal.initialize("YOUR_APP_ID")`.
    * Replace the API Key in `pantalla_chat.dart`: `"Authorization": "Basic YOUR_REST_API_KEY"`.
3.  **Enable Localizations:** The app is configured for a Spanish calendar using `flutter_localizations`.

---

## 📐 Project Structure

```text
lib/
├── screens/                        # User Interface (UI) Layer
│   ├── pantalla_splash.dart        # Corporate visual identity and initial resource loading.
│   ├── pantalla_bienvenida.dart    # Main access point and authentication flow management.
│   ├── pantalla_inicio.dart        # Central dashboard with dynamic navigation based on role (Admin/Client).
│   ├── pantalla_reserva.dart       # Booking algorithm with 15-min block logic and availability.
│   ├── pantalla_mis_citas.dart     # Client agenda management and cancellation policy control.
│   ├── pantalla_mis_cupones.dart   # Loyalty visualization, accumulated points, and rewards catalog.
│   ├── pantalla_editar_perfil.dart # Personal data administration and Base64 image processing.
│   ├── pantalla_chat.dart          # Real-time communication via Streams and OneSignal notifications.
│   ├── pantalla_admin.dart         # Barber operational panel for attendance control and daily agenda.
│   ├── pantalla_gestion_servicios.dart # Dynamic CRUD for commercial offer administration.
│   ├── pantalla_gestion_cupones.dart   # Reward program configuration and required points.
│   ├── pantalla_estadisticas.dart  # Business Intelligence: revenue analysis and performance metrics.
│   └── pantalla_login.dart         # Secure access interface linked to the Firebase Auth database.
│
├── firebase_options.dart           # Technical Firebase configuration (Excluded from Git for security).
└── main.dart                       # Entry point and application lifecycle observer.
assets/
└── images/                         # Graphic resources: logos, banners, and promotional material.
