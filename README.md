# TaskAI v3.0 — Gestión de Tareas con IA y Persistencia en la Nube

![CI](https://github.com/JA-Rodriguez-Ozuna/Desarrollo_aplicaciones_moviles_taskAI_v2/actions/workflows/ci.yml/badge.svg)

TaskAI es una aplicación móvil de gestión de tareas desarrollada en Flutter. Combina captura de tareas por voz y escaneo QR mediante IA 100% on-device, con autenticación y persistencia en tiempo real vía Firebase (con caché local y sincronización offline), sobre una interfaz Material Design 3.

## ✨ Funcionalidades principales

- 🔐 **Autenticación** con Firebase Auth (registro e inicio de sesión)
- ☁️ **Persistencia en la nube** con Cloud Firestore y sincronización en tiempo real
- 📴 **Modo offline** con caché local (Hive) y sincronización automática al recuperar conexión
- 🎙️ **Captura de tareas por voz**, reconocimiento de voz on-device sin enviar audio a servidores
- 📷 **Escaneo de tareas por código QR** con Google ML Kit, 100% on-device
- ✅ **Gestión completa de tareas**: crear, editar, completar, eliminar con opción de deshacer
- 🔎 **Filtros** por estado (todas / pendientes / completadas) y por categoría (trabajo / personal / estudio / urgente)
- 📊 **Panel de estadísticas** con progreso por categoría
- 🎨 **Material Design 3**: NavigationBar, animaciones, splash screen nativo y modo claro/oscuro/sistema
- 👋 **Onboarding** interactivo en el primer inicio de sesión
- ♿ **Accesibilidad**: semántica, tooltips y objetivos táctiles de 48dp

## 🛠️ Stack tecnológico

| Tecnología | Versión | Uso |
|---|---|---|
| Flutter | 3.44.1+ | Framework UI |
| Dart | 3.12.1+ | Lenguaje |
| flutter_riverpod | 2.6.x | Gestión de estado |
| go_router | 15.x | Navegación |
| firebase_core | 3.x | Inicialización de Firebase |
| firebase_auth | 5.x | Autenticación de usuarios |
| cloud_firestore | 5.x | Base de datos en tiempo real |
| hive_flutter | 1.1.x | Caché local / modo offline |
| connectivity_plus | 6.x | Detección de estado de red |
| speech_to_text | 7.x | Reconocimiento de voz on-device |
| google_mlkit_barcode_scanning | 0.12.x | Escaneo QR con ML Kit |
| camera | 0.11.x | Acceso a cámara en tiempo real |
| flutter_secure_storage | 9.x | Almacenamiento seguro de metadatos |
| permission_handler | 11.x | Gestión de permisos en runtime |
| google_fonts | 6.x | Tipografía Poppins |
| flutter_animate | 4.x | Animaciones declarativas |
| shimmer | 3.x | Placeholders de carga |
| shared_preferences | 2.x | Persistencia de preferencias locales (tema, onboarding) |
| flutter_native_splash | 2.x | Splash screen nativo |
| Material Design 3 | — | Sistema de diseño (seed color `#6B5AED`, tipografía Poppins) |
| mockito / fake_cloud_firestore / firebase_auth_mocks | — | Tests unitarios con mocks de Firebase |

## 📱 Capturas de pantalla

Ver carpeta [`screenshots/`](screenshots/) para las capturas de pantalla actualizadas de la aplicación.

## 📦 Instrucciones de instalación del APK

```bash
# 1. Generar el APK de release (requiere android/app/key.properties configurado localmente)
flutter build apk --release

# 2. El APK firmado se genera en:
build/app/outputs/flutter-apk/app-release.apk

# 3a. Instalar en un dispositivo Android conectado por ADB
adb install build/app/outputs/flutter-apk/app-release.apk

# 3b. Alternativamente, transferir el .apk al dispositivo manualmente
#     y habilitar "Instalar apps de origen desconocido" antes de abrirlo
```

> `key.properties` y el keystore de firma **no** están incluidos en el repositorio por seguridad; deben generarse localmente.

## 🌳 Estructura de branches

El proyecto se desarrolló como una pila incremental de branches, ya integrados en `main`:

```
main
 └─ feature/database        # Firebase Auth, Cloud Firestore, caché offline con Hive
     └─ feature/ai-integration  # Captura de tareas por voz y escaneo QR con ML Kit
         └─ feature/ui-redesign    # Rediseño Material Design 3, onboarding, animaciones
             └─ feature/ci-cd-testing # Pipeline de CI/CD, tests unitarios, firma de release
```

`main` contiene actualmente el código final de TaskAI v3.0 con todas las funcionalidades integradas.

## Requisitos previos

- Flutter 3.38 o superior
- Dart 3.x
- Android SDK 21+ (requerido por ML Kit)
- Dispositivo Android físico o emulador con cámara y micrófono
- Proyecto de Firebase configurado (`flutterfire configure`) para generar `lib/firebase_options.dart` localmente

## Ejecutar desde código fuente

```bash
# 1. Clonar el repositorio
git clone https://github.com/JA-Rodriguez-Ozuna/Desarrollo_aplicaciones_moviles_taskAI_v2.git
cd Desarrollo_aplicaciones_moviles_taskAI_v2

# 2. Instalar dependencias
flutter pub get

# 3. Verificar dispositivos disponibles
flutter devices

# 4. Ejecutar la app
flutter run
```

## Pantallas

#### LoginScreen / RegisterScreen
Autenticación con Firebase Auth (correo y contraseña), con guardas de ruta que protegen las pantallas internas.

#### OnboardingScreen (`/onboarding`)
4 páginas introductorias con `PageView`, dots indicator y persistencia del flag `onboarding_completed` en `shared_preferences`; se muestra una sola vez tras el primer login.

#### HomeScreen (`/`)
Lista principal de tareas sincronizada con Firestore en tiempo real, con caché offline:
- Filtros por estado y por categoría
- Tarjetas con prioridad, categoría y fecha límite
- Swipe-to-delete con confirmación y opción "Deshacer"
- Accesos directos a Voz y QR
- Estados de carga (shimmer) y de error con reintento

#### TaskFormScreen (`/task/new` y `/task/edit/:id`)
Formulario para crear y editar tareas, con validaciones de título requerido y fecha no en el pasado.

#### VoiceScreen (`/voice`)
Captura de tareas mediante reconocimiento de voz on-device, sin envío de audio a servidores. Convierte el texto transcrito en título (primeras 6 palabras) y descripción (texto completo).

#### QRScanScreen (`/qr-scan`)
Escaneo de tareas desde códigos QR on-device con Google ML Kit. Formato esperado:
```json
{"title":"Entregar informe","description":"Grupo 3","category":"estudio","priority":"alta"}
```

#### StatisticsScreen (`/statistics`)
Panel de estadísticas con contadores y progreso por categoría.

#### SettingsScreen (`/settings`)
Selector de tema Sistema/Claro/Oscuro y cierre de sesión.

## Servicios

| Servicio | Responsabilidad |
|---|---|
| `auth_service.dart` | Registro, inicio y cierre de sesión con Firebase Auth |
| `firestore_service.dart` | CRUD y stream en tiempo real de tareas en Cloud Firestore |
| `hive_service.dart` | Caché local de tareas para modo offline |
| `sync_service.dart` | Sincronización entre Firestore y la caché local según conectividad |
| `permission_service.dart` | Gestión de permisos de micrófono y cámara |
| `secure_storage_service.dart` | Almacenamiento cifrado de metadatos de configuración |

## Modelo de datos

```dart
class Task {
  String id;             // UUID v4
  String title;          // Requerido
  String description;    // Opcional
  TaskCategory category; // trabajo | personal | estudio | urgente
  TaskPriority priority; // alta | media | baja
  DateTime dueDate;
  bool isCompleted;
  DateTime createdAt;
  String userId;         // Propietario de la tarea (Firebase Auth uid)
}
```

## Estructura del proyecto

```
lib/
├── main.dart
├── router/
│   └── app_router.dart          # go_router — shell M3 + guardas de auth + rutas
├── theme/
│   └── app_theme.dart           # Tema MD3, seed #6B5AED, Poppins
├── models/
│   └── task.dart
├── providers/
│   ├── auth_provider.dart
│   ├── connectivity_provider.dart
│   ├── onboarding_provider.dart
│   └── task_provider.dart
├── repositories/
│   └── task_repository.dart     # Orquesta Firestore + fallback a Hive
├── services/
│   ├── auth_service.dart
│   ├── firestore_service.dart
│   ├── hive_service.dart
│   ├── sync_service.dart
│   ├── permission_service.dart
│   └── secure_storage_service.dart
├── screens/
│   ├── login_screen.dart
│   ├── register_screen.dart
│   ├── onboarding_screen.dart
│   ├── home_screen.dart
│   ├── task_form_screen.dart
│   ├── statistics_screen.dart
│   ├── settings_screen.dart
│   ├── voice_screen.dart
│   └── qr_scan_screen.dart
└── widgets/
    ├── scaffold_with_nav_bar.dart
    ├── task_card.dart
    ├── filter_chips.dart
    └── stats_card.dart
```

## Configuración nativa Android

| Parámetro | Valor |
|---|---|
| minSdkVersion | 21 (requerido por ML Kit) |
| compileSdkVersion | 34 |
| Permisos | `RECORD_AUDIO`, `CAMERA` |
| Firma de release | Configurada vía `key.properties` (no incluido en el repo) |

---

Proyecto académico — Desarrollo de Aplicaciones Móviles
Universidad Iberoamericana
