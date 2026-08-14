import 'package:firebase_ai/firebase_ai.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:flutter/foundation.dart';

/// Thrown when Gemini keeps failing with a transient/overload error after
/// exhausting retries on both models — its [toString] is the user-facing
/// message shown in the UI instead of the raw Firebase exception.
class GeminiBusyException implements Exception {
  @override
  String toString() =>
      'El servidor de IA está ocupado, intenta de nuevo en unos segundos.';
}

/// Wrapper around Firebase AI Logic (Gemini) for TaskAI's image and voice
/// analysis features. Uses the app's existing Firebase project for auth —
/// no API key to manage.
class GeminiService {
  static const String _primaryModel = 'gemini-2.5-flash';
  static const String _fallbackModel = 'gemini-flash-latest';

  /// Intento inicial + hasta 2 reintentos automáticos.
  static const int _maxAttempts = 3;
  static const Duration _retryDelay = Duration(seconds: 3);

  static const String _imagePrompt = '''
Analiza esta imagen con detalle. Primero describe brevemente qué ves en la
imagen en 1-2 líneas. Luego determina si contiene información sobre tareas,
actividades pendientes, ejercicios, fechas de entrega o cualquier cosa que
pueda convertirse en una tarea.
Responde ÚNICAMENTE con este JSON sin markdown:
{
  "imageDescription": "descripción breve de lo que ves",
  "hasTask": true o false,
  "title": "título de la tarea si existe máximo 60 caracteres",
  "description": "descripción detallada",
  "category": "trabajo o personal o estudio o urgente",
  "priority": "alta o media o baja",
  "suggestions": ["acción 1", "acción 2", "acción 3"]
}
Responde en español.''';

  // firebase_ai solo adjunta el header X-Firebase-AppCheck a las peticiones
  // si se le pasa explícitamente la instancia de FirebaseAppCheck — activarlo
  // globalmente en main.dart NO alcanza, FirebaseAI.googleAI() sin este
  // parámetro manda las requests sin token y el backend las rechaza con
  // "App Check token is invalid" aunque el proveedor esté bien configurado.
  GenerativeModel _model(String modelName) => FirebaseAI.googleAI(
        appCheck: FirebaseAppCheck.instance,
      ).generativeModel(model: modelName);

  /// Un error se considera transitorio (servidor sobrecargado) y elegible
  /// para reintento si menciona un 500, "high demand" o "INTERNAL" — los
  /// mensajes típicos de Gemini cuando está temporalmente saturado.
  bool _isRetryable(Object error) {
    final String message = error.toString().toLowerCase();
    return message.contains('500') ||
        message.contains('high demand') ||
        message.contains('internal');
  }

  /// Llama a [modelName] con hasta [_maxAttempts] intentos, reintentando solo
  /// los errores transitorios (ver [_isRetryable]) con una espera de
  /// [_retryDelay] entre cada uno. Cualquier otro tipo de error falla en el
  /// primer intento, sin esperar innecesariamente.
  Future<String?> _generateWithRetry(
    String modelName,
    List<Content> Function() buildPrompt,
  ) async {
    late Object lastError;
    for (int attempt = 1; attempt <= _maxAttempts; attempt++) {
      try {
        final GenerateContentResponse response =
            await _model(modelName).generateContent(buildPrompt());
        return response.text;
      } catch (e) {
        lastError = e;
        debugPrint('Gemini $modelName — intento $attempt/$_maxAttempts falló: $e');
        if (attempt < _maxAttempts && _isRetryable(e)) {
          await Future.delayed(_retryDelay);
          continue;
        }
        break;
      }
    }
    throw lastError;
  }

  /// Loggea el error real de ambos intentos (primario y fallback) — antes el
  /// catch del primario se descartaba en silencio y solo se veía el error
  /// del fallback, lo que ocultó el bug real de App Check por varias rondas.
  ///
  /// Si tras agotar los reintentos el error final sigue siendo transitorio
  /// (servidor ocupado), se lanza [GeminiBusyException] con un mensaje
  /// amigable en vez del error técnico crudo de Firebase.
  Future<String?> _generateWithFallback(
    List<Content> Function() buildPrompt,
  ) async {
    try {
      return await _generateWithRetry(_primaryModel, buildPrompt);
    } catch (primaryError) {
      debugPrint('Gemini primary model ($_primaryModel) error: $primaryError');
      try {
        return await _generateWithRetry(_fallbackModel, buildPrompt);
      } catch (fallbackError) {
        debugPrint(
          'Gemini fallback model ($_fallbackModel) error: $fallbackError',
        );
        if (_isRetryable(fallbackError)) {
          throw GeminiBusyException();
        }
        rethrow;
      }
    }
  }

  /// Sends a photo (blackboard, notes, textbook page, etc.) to Gemini Vision
  /// and asks it to extract task information as raw JSON text.
  Future<String?> analyzeImage(Uint8List imageBytes) {
    return _generateWithFallback(
      () => [
        Content.multi([
          TextPart(_imagePrompt),
          InlineDataPart('image/jpeg', imageBytes),
        ]),
      ],
    );
  }

  /// Sends a voice transcription to Gemini and asks it to extract full task
  /// fields (title, description, category, priority, due date) as raw JSON
  /// text. Includes today's date so Gemini can resolve relative dates like
  /// "mañana" or "el viernes" into real yyyy-MM-dd values.
  Future<String?> analyzeVoiceText(String transcribedText) {
    final DateTime today = DateTime.now();
    final String prompt = '''
Hoy es ${today.day}/${today.month}/${today.year}, día de la semana: ${_getDayName(today.weekday)}.
El usuario dictó esta nota para crear una tarea universitaria: $transcribedText

Extrae la información y responde ÚNICAMENTE con JSON sin markdown:
{
  "title": "título corto máximo 60 caracteres",
  "description": "descripción completa",
  "category": "trabajo o personal o estudio o urgente",
  "priority": "alta o media o baja",
  "hasDueDate": true o false,
  "dueDate": "fecha en formato yyyy-MM-dd si se menciona o null",
  "dueDateHint": "descripción natural de la fecha ejemplo viernes o mañana"
}
Si menciona hoy calcula la fecha de hoy.
Si menciona mañana calcula la fecha de mañana.
Si menciona un día de la semana calcula la fecha del próximo occurrence.
Responde en español.''';

    return _generateWithFallback(() => [Content.text(prompt)]);
  }

  String _getDayName(int weekday) {
    const List<String> days = [
      'lunes',
      'martes',
      'miércoles',
      'jueves',
      'viernes',
      'sábado',
      'domingo',
    ];
    return days[weekday - 1];
  }

  /// Simple connectivity check used during development to confirm the
  /// Firebase AI Logic setup works end to end.
  Future<String?> testConnection() {
    return _generateWithFallback(
      () => [Content.text('Responde únicamente con la palabra: ok')],
    );
  }
}
