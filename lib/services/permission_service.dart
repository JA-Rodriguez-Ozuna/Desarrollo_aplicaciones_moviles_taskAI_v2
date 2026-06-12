import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

class PermissionService {
  static Future<bool> requestMicrophonePermission(
      BuildContext context) async {
    return _request(
      context,
      Permission.microphone,
      'micrófono',
      'para capturar tareas por voz',
    );
  }

  static Future<bool> requestCameraPermission(BuildContext context) async {
    return _request(
      context,
      Permission.camera,
      'cámara',
      'para escanear códigos QR',
    );
  }

  static Future<bool> _request(
    BuildContext context,
    Permission permission,
    String name,
    String reason,
  ) async {
    final PermissionStatus status = await permission.request();

    if (status.isGranted) return true;

    if (!context.mounted) return false;

    if (status.isPermanentlyDenied) {
      await showDialog<void>(
        context: context,
        builder: (BuildContext ctx) => AlertDialog(
          title: Text('Permiso de $name requerido'),
          content: Text(
            'TaskAI necesita acceso al $name $reason. '
            'Ve a Configuración del sistema para habilitarlo.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(ctx);
                openAppSettings();
              },
              child: const Text('Ir a Configuración'),
            ),
          ],
        ),
      );
      return false;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Permiso de $name denegado. Necesario $reason.'),
        duration: const Duration(seconds: 3),
      ),
    );
    return false;
  }
}
