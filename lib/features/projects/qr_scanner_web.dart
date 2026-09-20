import 'dart:async';
import 'dart:ui_web' as ui_web;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'dart:html' as html;
import '../../app/app.dart';

Widget createQrScanner({required Function(String link) onScanned}) {
  return _WebQrScanner(onScanned: onScanned);
}

class _WebQrScanner extends StatefulWidget {
  final Function(String link) onScanned;
  const _WebQrScanner({required this.onScanned});
  @override
  State<_WebQrScanner> createState() => _WebQrScannerState();
}

class _WebQrScannerState extends State<_WebQrScanner> with SingleTickerProviderStateMixin {
  html.VideoElement? _video;
  html.MediaStream? _stream;
  String? _viewId;
  bool _cameraReady = false;
  bool _hasError = false;
  String _errorMsg = '';
  late AnimationController _lineController;

  @override
  void initState() {
    super.initState();
    _lineController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1800))..repeat();
    _initCamera();
  }

  Future<void> _initCamera() async {
    try {
      // Register platform view factory BEFORE creating video
      _viewId = 'qr-cam-${DateTime.now().millisecondsSinceEpoch}';

      _video = html.VideoElement()
        ..autoplay = true
        ..muted = true
        ..setAttribute('playsinline', '')
        ..style.width = '100%'
        ..style.height = '100%'
        ..style.objectFit = 'cover'
        ..style.backgroundColor = '#000000';

      // Register the factory first
      ui_web.platformViewRegistry.registerViewFactory(_viewId!, (int id) {
        return _video!;
      });

      // Get camera stream
      final mediaDevices = html.window.navigator.mediaDevices;
      if (mediaDevices == null) {
        throw Exception('mediaDevices non disponible');
      }

      _stream = await mediaDevices.getUserMedia({
        'video': {'facingMode': 'environment', 'width': {'ideal': 1280}, 'height': {'ideal': 720}},
        'audio': false,
      });

      _video!.srcObject = _stream;

      // Wait for video to be ready
      await _video!.play();

      if (mounted) {
        setState(() => _cameraReady = true);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _hasError = true;
          _errorMsg = _humanizeError(e);
        });
      }
    }
  }

  String _humanizeError(Object e) {
    final msg = e.toString();
    if (msg.contains('NotAllowedError') || msg.contains('Permission')) {
      return 'Permission camera refusée.\nAutorisez l\'accès dans les paramètres du navigateur.';
    }
    if (msg.contains('NotFoundError') || msg.contains('DevicesNotFound')) {
      return 'Aucune camera détectée sur cet appareil.';
    }
    if (msg.contains('NotReadableError')) {
      return 'Camera utilisée par une autre application.';
    }
    if (msg.contains('OverconstrainedError')) {
      return 'Camera ne supporte pas la résolution demandée.';
    }
    return msg;
  }

  @override
  void dispose() {
    _lineController.dispose();
    try {
      _stream?.getTracks().forEach((t) => t.stop());
      _video?.srcObject = null;
    } catch (_) {}
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(child: _hasError ? _buildErrorView() : _buildCameraView()),
            _buildBottomBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: Colors.white.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 18),
            ),
          ),
          const SizedBox(width: 12),
          SvgPicture.asset('assets/icons/qr_code.svg', width: 20, height: 20, colorFilter: const ColorFilter.mode(AppColors.primary, BlendMode.srcIn)),
          const SizedBox(width: 8),
          const Expanded(child: Text('Scanner QR Code', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: Colors.white))),
        ],
      ),
    );
  }

  Widget _buildCameraView() {
    return Stack(
      alignment: Alignment.center,
      children: [
        // Camera feed
        if (_cameraReady && _viewId != null)
          Positioned.fill(
            child: HtmlElementView(viewType: _viewId!),
          ),

        // Loading
        if (!_cameraReady && !_hasError)
          const Center(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              CircularProgressIndicator(color: AppColors.primary, strokeWidth: 2),
              SizedBox(height: 16),
              Text('Activation de la camera...', style: TextStyle(color: Colors.white54, fontSize: 14)),
            ]),
          ),

        // Overlays (only when camera is ready)
        if (_cameraReady) ...[
          _buildDimOverlay(),
          _buildScanFrame(),
          _buildScanLine(),
          Positioned(
            bottom: 30,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(color: Colors.black.withOpacity(0.7), borderRadius: BorderRadius.circular(20)),
              child: const Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.qr_code_scanner, color: AppColors.primary, size: 16),
                SizedBox(width: 8),
                Text('Placez le QR Code dans le cadre', style: TextStyle(color: Colors.white70, fontSize: 13)),
              ]),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildDimOverlay() {
    return LayoutBuilder(
      builder: (ctx, constraints) {
        final s = constraints.maxWidth * 0.7;
        return CustomPaint(size: Size(constraints.maxWidth, constraints.maxHeight), painter: _DimOverlayPainter(frameSize: s));
      },
    );
  }

  Widget _buildScanFrame() {
    return LayoutBuilder(
      builder: (ctx, constraints) {
        final s = constraints.maxWidth * 0.7;
        return Container(
          width: s, height: s,
          decoration: BoxDecoration(border: Border.all(color: Colors.white24, width: 1.5), borderRadius: BorderRadius.circular(20)),
          child: CustomPaint(painter: _CornerPainter()),
        );
      },
    );
  }

  Widget _buildScanLine() {
    return AnimatedBuilder(
      animation: _lineController,
      builder: (ctx, _) => LayoutBuilder(
        builder: (ctx, constraints) {
          final s = constraints.maxWidth * 0.7;
          final top = (constraints.maxHeight - s) / 2 + (_lineController.value * s);
          return Positioned(
            top: top,
            left: (constraints.maxWidth - s) / 2 + 10,
            child: Container(
              width: s - 20, height: 2,
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [Colors.transparent, AppColors.primary.withOpacity(0.8), Colors.transparent]),
                boxShadow: [BoxShadow(color: AppColors.primary.withOpacity(0.4), blurRadius: 8)],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 80, height: 80, decoration: BoxDecoration(color: AppColors.error.withOpacity(0.1), shape: BoxShape.circle), child: const Icon(Icons.videocam_off, color: AppColors.error, size: 36)),
          const SizedBox(height: 20),
          const Text('Camera indisponible', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.white)),
          const SizedBox(height: 8),
          Text(_errorMsg.isNotEmpty ? _errorMsg : 'Autorisez l\'acces a la camera.', textAlign: TextAlign.center, style: const TextStyle(fontSize: 13, color: Colors.white54)),
        ]),
      ),
    );
  }

  Widget _buildBottomBar() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: GestureDetector(
        onTap: () => Navigator.pop(context),
        child: Container(
          width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(color: Colors.white.withOpacity(0.08), borderRadius: BorderRadius.circular(12)),
          child: const Center(child: Text('Fermer', style: TextStyle(color: Colors.white54, fontSize: 14))),
        ),
      ),
    );
  }
}

class _DimOverlayPainter extends CustomPainter {
  final double frameSize;
  _DimOverlayPainter({required this.frameSize});
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.black.withOpacity(0.55);
    final center = Offset(size.width / 2, size.height / 2);
    final rect = RRect.fromRectAndRadius(Rect.fromCenter(center: center, width: frameSize, height: frameSize), const Radius.circular(20));
    final path = Path()..addRect(Rect.fromLTWH(0, 0, size.width, size.height))..addRRect(rect)..fillType = PathFillType.evenOdd;
    canvas.drawPath(path, paint);
  }
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _CornerPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.stroke..strokeWidth = 4..strokeCap = StrokeCap.round..color = AppColors.primary;
    final r = 16.0;
    canvas.drawPath(Path()..moveTo(r, 0)..lineTo(0, 0)..lineTo(0, r), paint);
    canvas.drawPath(Path()..moveTo(size.width - r, 0)..lineTo(size.width, 0)..lineTo(size.width, r), paint);
    canvas.drawPath(Path()..moveTo(0, size.height - r)..lineTo(0, size.height)..lineTo(r, size.height), paint);
    canvas.drawPath(Path()..moveTo(size.width, size.height - r)..lineTo(size.width, size.height)..lineTo(size.width - r, size.height), paint);
  }
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
