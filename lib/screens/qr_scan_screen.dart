import 'dart:convert';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_mlkit_barcode_scanning/google_mlkit_barcode_scanning.dart';

import '../models/task.dart';
import '../providers/task_provider.dart';
import '../services/permission_service.dart';
import '../services/secure_storage_service.dart';

class QRScanScreen extends ConsumerStatefulWidget {
  const QRScanScreen({super.key});

  @override
  ConsumerState<QRScanScreen> createState() => _QRScanScreenState();
}

class _QRScanScreenState extends ConsumerState<QRScanScreen> {
  CameraController? _cameraController;
  final BarcodeScanner _barcodeScanner = BarcodeScanner(
    formats: [BarcodeFormat.qrCode],
  );
  bool _isProcessing = false;
  bool _cameraReady = false;
  bool _permissionDenied = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  Future<void> _initCamera() async {
    final bool granted =
        await PermissionService.requestCameraPermission(context);
    if (!granted) {
      if (mounted) setState(() => _permissionDenied = true);
      return;
    }

    try {
      final List<CameraDescription> cameras = await availableCameras();
      if (cameras.isEmpty) {
        if (mounted) {
          setState(() => _errorMessage = 'No se encontró cámara disponible.');
        }
        return;
      }

      final CameraDescription camera = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );

      _cameraController = CameraController(
        camera,
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: Platform.isAndroid
            ? ImageFormatGroup.nv21
            : ImageFormatGroup.bgra8888,
      );

      await _cameraController!.initialize();
      if (!mounted) return;

      setState(() => _cameraReady = true);
      _cameraController!.startImageStream(_processFrame);
    } catch (e) {
      if (mounted) {
        setState(() => _errorMessage = 'Error al inicializar la cámara.');
      }
      debugPrint('Camera init error: $e');
    }
  }

  Future<void> _processFrame(CameraImage image) async {
    if (_isProcessing) return;
    _isProcessing = true;

    try {
      final InputImage? inputImage = _toInputImage(image);
      if (inputImage == null) return;

      final List<Barcode> barcodes =
          await _barcodeScanner.processImage(inputImage);
      if (barcodes.isEmpty) return;

      final String? rawValue = barcodes.first.rawValue;
      if (rawValue == null) return;

      await _cameraController?.stopImageStream();
      if (mounted) _onQRDetected(rawValue);
    } finally {
      _isProcessing = false;
    }
  }

  InputImage? _toInputImage(CameraImage image) {
    final int sensorOrientation =
        _cameraController!.description.sensorOrientation;
    final InputImageRotation rotation =
        InputImageRotationValue.fromRawValue(sensorOrientation) ??
            InputImageRotation.rotation0deg;

    final InputImageFormat? format =
        InputImageFormatValue.fromRawValue(image.format.raw);
    if (format == null) return null;

    final Uint8List bytes;
    final int bytesPerRow = image.planes[0].bytesPerRow;

    if (image.planes.length == 1) {
      bytes = image.planes[0].bytes;
    } else {
      final WriteBuffer buffer = WriteBuffer();
      for (final Plane plane in image.planes) {
        buffer.putUint8List(plane.bytes);
      }
      bytes = buffer.done().buffer.asUint8List();
    }

    return InputImage.fromBytes(
      bytes: bytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: format,
        bytesPerRow: bytesPerRow,
      ),
    );
  }

  void _onQRDetected(String rawValue) {
    try {
      final Map<String, dynamic> data =
          json.decode(rawValue) as Map<String, dynamic>;

      final String? title = data['title'] as String?;
      if (title == null || title.isEmpty) {
        _showError('QR inválido: falta el campo "title".');
        _resumeScanning();
        return;
      }

      final String description = (data['description'] as String?) ?? '';
      final String categoryStr = (data['category'] as String?) ?? 'personal';
      final String priorityStr = (data['priority'] as String?) ?? 'media';

      final TaskCategory category = TaskCategory.values.firstWhere(
        (c) => c.name == categoryStr,
        orElse: () => TaskCategory.personal,
      );
      final TaskPriority priority = TaskPriority.values.firstWhere(
        (p) => p.name == priorityStr,
        orElse: () => TaskPriority.media,
      );

      _showPreview(title, description, category, priority);
    } on FormatException {
      _showError('El QR no contiene datos JSON válidos.');
      _resumeScanning();
    } on TypeError {
      _showError('El QR tiene un formato incorrecto.');
      _resumeScanning();
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Theme.of(context).colorScheme.error,
      ),
    );
  }

  void _resumeScanning() {
    if (_cameraController != null && _cameraReady && mounted) {
      _cameraController!.startImageStream(_processFrame);
    }
  }

  void _showPreview(
    String title,
    String description,
    TaskCategory category,
    TaskPriority priority,
  ) {
    if (!mounted) return;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (BuildContext ctx) => _TaskPreviewSheet(
        title: title,
        description: description,
        category: category,
        priority: priority,
        onConfirm: () async {
          final Task task = Task.create(
            title: title,
            description: description,
            category: category,
            priority: priority,
            dueDate: DateTime.now().add(const Duration(days: 1)),
          );
          ref.read(taskProvider.notifier).addTask(task);
          await SecureStorageService.saveValue(
            'last_qr_scan',
            DateTime.now().toIso8601String(),
          );
          if (ctx.mounted) Navigator.pop(ctx);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Tarea "$title" creada')),
            );
            context.go('/');
          }
        },
        onCancel: () {
          Navigator.pop(ctx);
          _resumeScanning();
        },
      ),
    );
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    _barcodeScanner.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_permissionDenied) {
      return _PermissionDeniedView(onBack: () => context.go('/'));
    }
    if (_errorMessage != null) {
      return _ErrorView(message: _errorMessage!, onBack: () => context.go('/'));
    }
    if (!_cameraReady) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        title: const Text('Escanear QR'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/'),
        ),
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          CameraPreview(_cameraController!),
          const _ScanOverlay(),
          const Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: _HelpPanel(),
          ),
        ],
      ),
    );
  }
}

// ── Overlay ────────────────────────────────────────────────────────────────

class _ScanOverlay extends StatelessWidget {
  const _ScanOverlay();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _OverlayPainter(),
      child: const SizedBox.expand(),
    );
  }
}

class _OverlayPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final double cutout = size.width * 0.68;
    final double left = (size.width - cutout) / 2;
    final double top = (size.height - cutout) / 2;
    final Rect frame = Rect.fromLTWH(left, top, cutout, cutout);

    // Dark overlay with cutout
    final Paint overlay = Paint()..color = Colors.black54;
    final Path path = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
      ..addRRect(RRect.fromRectAndRadius(frame, const Radius.circular(12)))
      ..fillType = PathFillType.evenOdd;
    canvas.drawPath(path, overlay);

    // Corner brackets
    const double arm = 28.0;
    const double strokeW = 3.5;
    final Paint corner = Paint()
      ..color = Colors.white
      ..strokeWidth = strokeW
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final List<List<Offset>> corners = [
      [Offset(left, top + arm), Offset(left, top), Offset(left + arm, top)],
      [
        Offset(left + cutout - arm, top),
        Offset(left + cutout, top),
        Offset(left + cutout, top + arm),
      ],
      [
        Offset(left, top + cutout - arm),
        Offset(left, top + cutout),
        Offset(left + arm, top + cutout),
      ],
      [
        Offset(left + cutout - arm, top + cutout),
        Offset(left + cutout, top + cutout),
        Offset(left + cutout, top + cutout - arm),
      ],
    ];

    for (final List<Offset> pts in corners) {
      canvas.drawLine(pts[0], pts[1], corner);
      canvas.drawLine(pts[1], pts[2], corner);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ── Bottom sheet preview ────────────────────────────────────────────────────

class _TaskPreviewSheet extends StatelessWidget {
  final String title;
  final String description;
  final TaskCategory category;
  final TaskPriority priority;
  final VoidCallback onConfirm;
  final VoidCallback onCancel;

  const _TaskPreviewSheet({
    required this.title,
    required this.description,
    required this.category,
    required this.priority,
    required this.onConfirm,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: colors.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Icon(Icons.qr_code_2, color: colors.primary),
                const SizedBox(width: 8),
                Text(
                  'QR detectado — revisar tarea',
                  style: theme.textTheme.titleMedium
                      ?.copyWith(color: colors.primary),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _Row(label: 'Título', value: title),
            if (description.isNotEmpty) ...[
              const SizedBox(height: 10),
              _Row(label: 'Descripción', value: description),
            ],
            const SizedBox(height: 10),
            _Row(label: 'Categoría', value: category.name),
            const SizedBox(height: 10),
            _Row(label: 'Prioridad', value: priority.name),
            const SizedBox(height: 28),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: onCancel,
                    child: const Text('Cancelar'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: onConfirm,
                    icon: const Icon(Icons.add_task),
                    label: const Text('Crear tarea'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  final String label;
  final String value;
  const _Row({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 100,
          child: Text(
            label,
            style: theme.textTheme.bodyMedium
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ),
        Expanded(
          child: Text(value, style: theme.textTheme.bodyMedium),
        ),
      ],
    );
  }
}

// ── Error / Permission views ────────────────────────────────────────────────

class _PermissionDeniedView extends StatelessWidget {
  final VoidCallback onBack;
  const _PermissionDeniedView({required this.onBack});

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Escanear QR')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.camera_alt_outlined,
                  size: 72, color: theme.colorScheme.outline),
              const SizedBox(height: 20),
              Text(
                'Permiso de cámara requerido',
                style: theme.textTheme.titleLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Habilita el permiso de cámara en Configuración del sistema para escanear códigos QR.',
                style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              FilledButton(
                  onPressed: onBack, child: const Text('Volver al inicio')),
            ],
          ),
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onBack;
  const _ErrorView({required this.message, required this.onBack});

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Escanear QR')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline,
                  size: 72, color: theme.colorScheme.error),
              const SizedBox(height: 20),
              Text(message,
                  style: theme.textTheme.bodyLarge,
                  textAlign: TextAlign.center),
              const SizedBox(height: 32),
              FilledButton(
                  onPressed: onBack, child: const Text('Volver al inicio')),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Help panel (colapsable, máx 30% pantalla) ──────────────────────────────

class _HelpPanel extends StatefulWidget {
  const _HelpPanel();

  @override
  State<_HelpPanel> createState() => _HelpPanelState();
}

class _HelpPanelState extends State<_HelpPanel> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final double expandedH = MediaQuery.of(context).size.height * 0.29;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeInOut,
      height: _expanded ? expandedH : 52,
      decoration: const BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        child: Column(
          children: [
            GestureDetector(
              onTap: () => setState(() => _expanded = !_expanded),
              child: SizedBox(
                height: 52,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline_rounded,
                          color: Colors.white70, size: 18),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          '¿Cómo usar el escáner QR?',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Icon(
                        _expanded
                            ? Icons.keyboard_arrow_down
                            : Icons.keyboard_arrow_up,
                        color: Colors.white70,
                        size: 20,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Divider(color: Colors.white24, height: 1),
                    SizedBox(height: 10),
                    _QRHelpRow('Apunta la cámara al código QR de la tarea'),
                    _QRHelpRow(
                        'El QR debe contener la información en formato JSON'),
                    _QRHelpRow(
                      '{"title":"Mi tarea","description":"...","category":"estudio","priority":"alta"}',
                      isCode: true,
                    ),
                    _QRHelpRow(
                        'Categorías válidas: trabajo, personal, estudio, urgente'),
                    _QRHelpRow('Prioridades válidas: alta, media, baja'),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QRHelpRow extends StatelessWidget {
  final String text;
  final bool isCode;

  const _QRHelpRow(this.text, {this.isCode = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '•  ',
            style: TextStyle(color: Colors.white60, fontSize: 12),
          ),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: isCode ? const Color(0xFFFFD54F) : Colors.white70,
                fontSize: isCode ? 10 : 12,
                fontFamily: isCode ? 'monospace' : null,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
