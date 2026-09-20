import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../app/app.dart';

Widget createQrScanner({required Function(String link) onScanned}) {
  return _StubQrScanner(onScanned: onScanned);
}

class _StubQrScanner extends StatelessWidget {
  final Function(String link) onScanned;
  const _StubQrScanner({required this.onScanned});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context),
            const Expanded(child: Center(child: Text('Scanner non disponible', style: TextStyle(color: Colors.white54)))),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
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
          const Text('Scanner QR Code', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: Colors.white)),
        ],
      ),
    );
  }
}
