import 'dart:typed_data';

import 'package:firebase_ai/firebase_ai.dart';

/// Wrapper around Firebase AI Logic (Gemini) for TaskAI's image and voice
/// analysis features. Uses the app's existing Firebase project for auth —
/// no API key to manage.
class GeminiService {
  static const String _primaryModel = 'gemini-2.5-flash';
  static const String _fallbackModel = 'gemini-flash-latest';

  static const String _imagePrompt = '''
Analiza esta imagen y extrae información sobre tareas universitarias.
Responde ÚNICAMENTE con un objeto JSON válido sin markdown ni texto extra:
{
  "title": "título corto de la tarea máximo 60 caracteres",
  "description": "descripción detallada",
  "category": "trabajo o personal o estudio o urgente",
  "priority": "alta o media o baja",
  "hasTask": true o false
}
Si no hay información de tarea responde con hasTask false.
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
  /// fields (title, description, category, priority, due date hint) as raw
  /// JSON text.
  Future<String?> analyzeVoiceText(String transcribedText) {
    final String prompt = '''
El usuario dictó esta nota para crear una tarea universitaria: $transcribedText
Extrae la información y responde ÚNICAMENTE con JSON válido sin markdown:
{
  "title": "título corto máximo 60 caracteres",
  "description": "descripción completa",
  "category": "trabajo o personal o estudio o urgente",
  "priority": "alta o media o baja",
  "dueDateHint": "descripción de fecha si se menciona ejemplo viernes o mañana o vacío"
}
Infiere categoría y prioridad del contexto.
Si menciona examen o tarea académica usa estudio.
Si menciona urgente o para hoy usa urgente con prioridad alta.
Responde en español.''';

    return _generateWithFallback(() => [Content.text(prompt)]);
  }

  /// Simple connectivity check used during development to confirm the
  /// Firebase AI Logic setup works end to end.
  Future<String?> testConnection() {
    return _generateWithFallback(
      () => [Content.text('Responde únicamente con la palabra: ok')],
    );
  }
}
