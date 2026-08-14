import 'package:firebase_ai/firebase_ai.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:flutter/foundation.dart';

/// Wrapper around Firebase AI Logic (Gemini) for TaskAI's image and voice
/// analysis features. Uses the app's existing Firebase project for auth —
/// no API key to manage.
class GeminiService {
  static const String _primaryModel = 'gemini-2.5-flash';
  static const String _fallbackModel = 'gemini-flash-latest';

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

  /// Loggea el error real de ambos intentos (primario y fallback) — antes el
  /// catch del primario se descartaba en silencio y solo se veía el error
  /// del fallback, lo que ocultó el bug real de App Check por varias rondas.
  Future<String?> _generateWithFallback(
    List<Content> Function() buildPrompt,
  ) async {
    try {
      final GenerateContentResponse response =
          await _model(_primaryModel).generateContent(buildPrompt());
      return response.text;
    } catch (primaryError) {
      debugPrint('Gemini primary model ($_primaryModel) error: $primaryError');
      try {
        final GenerateContentResponse response =
            await _model(_fallbackModel).generateContent(buildPrompt());
        return response.text;
      } catch (fallbackError) {
        debugPrint(
          'Gemini fallback model ($_fallbackModel) error: $fallbackError',
        );
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
