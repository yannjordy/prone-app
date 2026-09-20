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
  Timer? _scanTimer;

  @override
  void initState() {
    super.initState();
    _lineController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1800))..repeat();
    _initCamera();
  }

  Future<void> _initCamera() async {
    try {
      _video = html.VideoElement()
        ..autoplay = true
        ..muted = true
        ..style.width = '100%'
        ..style.height = '100%'
        ..style.objectFit = 'cover';
      _video!.setAttribute('playsinline', '');

      _stream = await html.window.navigator.mediaDevices!.getUserMedia({
        'video': {'facingMode': 'environment', 'width': {'ideal': 1280}, 'height': {'ideal': 720}},
        'audio': false,
      });

      _video!.srcObject = _stream;
      await _video!.play();

      _viewId = 'qr-cam-${DateTime.now().millisecondsSinceEpoch}';
      ui_web.platformViewRegistry.registerViewFactory(_viewId!, (int id) => _video!);

      if (mounted) {
        setState(() => _cameraReady = true);
        _startBarcodeDetection();
      }
    } catch (e) {
      if (mounted) setState(() { _hasError = true; _errorMsg = e.toString(); });
    }
  }

  void _startBarcodeDetection() {
    _scanTimer = Timer.periodic(const Duration(milliseconds: 700), (_) => _scanFrame());
  }

  void _scanFrame() {
    if (_video == null || !_cameraReady || _video!.readyState != 4) return;
    try {
      final canvas = html.CanvasElement(width: _video!.videoWidth, height: _video!.videoHeight);
      canvas.context2D.drawImage(_video!, 0, 0);
      // BarcodeDetector API - available in Chrome/Edge
      // If not available, user can paste the link
    } catch (_) {}
  }

  @override
  void dispose() {
    _scanTimer?.cancel();
    _lineController.dispose();
    _stream?.getTracks().forEach((t) => t.stop());
    _video?.srcObject = null;
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
        if (_cameraReady && _viewId != null)
          HtmlElementView(viewType: _viewId!),
        if (!_cameraReady && !_hasError)
          const Center(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              CircularProgressIndicator(color: AppColors.primary, strokeWidth: 2),
              SizedBox(height: 16),
              Text('Activation de la camera...', style: TextStyle(color: Colors.white54, fontSize: 14)),
            ]),
          ),
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
