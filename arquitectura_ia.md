# TaskAI v2.0 — Arquitectura de IA On-Device

**Asignatura:** Desarrollo de Aplicaciones Móviles  
**Universidad:** Universidad Iberoamericana  
**Versión:** 2.0  
**Fecha:** Junio 2026

---

## 1. Introducción

TaskAI v2.0 extiende la aplicación de gestión de tareas universitaria con dos funcionalidades de inteligencia artificial que operan completamente en el dispositivo, sin transmisión de datos a servidores externos. El principio rector es la privacidad: el micrófono del usuario y la imagen de la cámara nunca salen del dispositivo.

La arquitectura se mantiene sobre el mismo núcleo de la versión 1.0 (Flutter + Riverpod + go_router), añadiendo una capa de servicios de soporte y dos pantallas nuevas que encapsulan la interacción con los modelos on-device.

---

## 2. Funcionalidad 1 — Captura de Tareas por Voz

### 2.1 Descripción

La pantalla `VoiceScreen` permite al usuario dictar el contenido de una tarea. El audio es procesado localmente por el motor de reconocimiento de voz del dispositivo (Android Speech Recognizer), sin ninguna conexión de red.

### 2.2 Flujo de ejecución

```
Usuario presiona botón
        │
        ▼
PermissionService.requestMicrophonePermission()
        │
  ┌─────┴──────┐
Denegado     Concedido
  │              │
SnackBar     SpeechToText.listen()
             (partialResults = true)
                 │
          Texto en pantalla
          en tiempo real
                 │
        Usuario presiona "Crear tarea"
                 │
          Task.create(
            title: primeras 6 palabras,
            description: texto completo
          )
                 │
        taskProvider.addTask(task)
        SecureStorageService.saveValue(
          'last_voice_capture', timestamp
        )
                 │
          Navegar a HomeScreen
```

### 2.3 Detalles de implementación

- **Clase principal:** `SpeechToText` del paquete `speech_to_text ^7.0.0`
- **API de escucha:** `SpeechListenOptions` (API moderna, sin parámetros deprecados)
- **Tiempo máximo de escucha:** 30 segundos; pausa automática tras 3 segundos de silencio
- **Indicador visual:** `AnimationController` con `Tween<double>(1.0, 1.18)` y `Curves.easeInOut` que escala el botón de micrófono mientras está activo
- **Color del botón:** `colorScheme.primary` en reposo, `colorScheme.error` mientras escucha
- **Permiso:** `Permission.microphone` gestionado por `PermissionService`

---

## 3. Funcionalidad 2 — Creación de Tareas desde QR

### 3.1 Descripción

La pantalla `QRScanScreen` abre la cámara trasera del dispositivo y analiza cada fotograma con Google ML Kit Barcode Scanning, que corre el modelo de detección de código de barras directamente en el CPU/GPU del dispositivo.

### 3.2 Formato del código QR

El código QR debe codificar un objeto JSON con los siguientes campos:

```json
{
  "title": "Entregar informe",
  "description": "Grupo 3 — Sección B",
  "category": "estudio",
  "priority": "alta"
}
```

| Campo | Tipo | Requerido | Valores válidos |
|---|---|---|---|
| `title` | string | Sí | Cualquier texto |
| `description` | string | No | Cualquier texto |
| `category` | string | No | `trabajo`, `personal`, `estudio`, `urgente` |
| `priority` | string | No | `alta`, `media`, `baja` |

Los campos `category` y `priority` tienen valores por defecto (`personal` y `media` respectivamente) si se omiten o son inválidos.

### 3.3 Flujo de ejecución

```
initState()
     │
PermissionService.requestCameraPermission()
     │
availableCameras() → selecciona cámara trasera
     │
CameraController.initialize()
  imageFormatGroup: nv21 (Android) / bgra8888 (iOS)
     │
startImageStream(_processFrame)
     │
Por cada fotograma:
  _toInputImage(CameraImage) → InputImage
  BarcodeScanner.processImage(InputImage)
  Si detecta QR:
    stopImageStream()
    json.decode(rawValue)
    showModalBottomSheet(_TaskPreviewSheet)
         │
    ┌────┴────┐
Cancelar   Confirmar
    │           │
resumeScanning  Task.create() → taskProvider.addTask()
                SecureStorageService.saveValue(timestamp)
                Navegar a HomeScreen
```

### 3.4 Conversión CameraImage → InputImage

La cámara entrega fotogramas en formato NV21 (Android). ML Kit requiere un `InputImage` con metadatos de rotación y formato. La conversión:

```dart
InputImage.fromBytes(
  bytes: image.planes[0].bytes,  // plano único en NV21
  metadata: InputImageMetadata(
    size: Size(image.width, image.height),
    rotation: InputImageRotationValue.fromRawValue(
      camera.sensorOrientation,   // típicamente 90° en cámara trasera
    ),
    format: InputImageFormatValue.fromRawValue(image.format.raw),
    bytesPerRow: image.planes[0].bytesPerRow,
  ),
)
```

### 3.5 Overlay de escaneo

El widget `_ScanOverlay` usa `CustomPainter` para dibujar:
1. Capa semitransparente oscura sobre toda la pantalla
2. Recorte rectangular centrado (68% del ancho de pantalla) con bordes redondeados
3. Cuatro esquinas en blanco de 28 px para guiar al usuario

---

## 4. Paquetes Utilizados

| Paquete | Versión | Propósito | On-device |
|---|---|---|---|
| `speech_to_text` | ^7.0.0 | Reconocimiento de voz | Sí |
| `google_mlkit_barcode_scanning` | ^0.12.0 | Detección de QR con ML Kit | Sí |
| `camera` | ^0.11.0 | Acceso a la cámara y stream de fotogramas | — |
| `flutter_secure_storage` | ^9.0.0 | Almacenamiento cifrado de metadatos | — |
| `permission_handler` | ^11.0.0 | Gestión unificada de permisos en runtime | — |

---

## 5. Decisiones de Diseño

### 5.1 On-device como restricción, no como opción

Ambas funcionalidades usan exclusivamente los modelos y APIs del dispositivo. Para voz, se emplea el `SpeechRecognizer` nativo de Android; para QR, el modelo bundled de ML Kit que se incluye en el APK (sin descarga posterior). Esto garantiza funcionamiento offline y latencia cero de red.

### 5.2 Confirmación antes de crear

El flujo del escáner QR muestra un `ModalBottomSheet` con vista previa antes de guardar la tarea. Esto protege contra falsos positivos del escáner y da control al usuario. La captura por voz sigue el mismo principio: el texto transcrito se muestra y el usuario decide cuándo crear.

### 5.3 Separación en servicios

`PermissionService` y `SecureStorageService` son clases con métodos estáticos, separados de la lógica de UI. Esto hace las pantallas más delgadas y los servicios reutilizables en futuras pantallas.

### 5.4 Degradación elegante

Ninguna pantalla lanza una excepción no controlada si el permiso es denegado o si el hardware no está disponible. Cada escenario tiene un mensaje de error o informativo explícito para el usuario.

---

## 6. Seguridad y Privacidad

| Aspecto | Solución implementada |
|---|---|
| Audio del usuario | Procesado localmente por Android Speech Recognizer; nunca se envía a servidores |
| Fotogramas de cámara | Procesados en memoria por ML Kit on-device; nunca se persisten ni envían |
| Metadatos de uso | Guardados con `flutter_secure_storage` usando Android KeyStore (cifrado en reposo) |
| Permisos | Solicitados en runtime con `permission_handler`; la app funciona sin ellos (degradada) |
| Tareas del usuario | Almacenadas en memoria (sin base de datos ni red); se pierden al cerrar la app |

El modelo de amenaza principal considerado es la fuga de datos sensibles del usuario. Dado que toda la lógica es on-device, la superficie de ataque de red es cero para las funcionalidades de IA.
