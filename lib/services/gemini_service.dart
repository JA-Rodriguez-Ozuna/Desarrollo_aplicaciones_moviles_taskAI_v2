import 'dart:typed_data';

import 'package:firebase_ai/firebase_ai.dart';

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

  GenerativeModel _model(String modelName) =>
      FirebaseAI.googleAI().generativeModel(model: modelName);

  Future<String?> _generateWithFallback(
    List<Content> Function() buildPrompt,
  ) async {
    try {
      final GenerateContentResponse response =
          await _model(_primaryModel).generateContent(buildPrompt());
      return response.text;
    } catch (_) {
      final GenerateContentResponse response =
          await _model(_fallbackModel).generateContent(buildPrompt());
      return response.text;
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
