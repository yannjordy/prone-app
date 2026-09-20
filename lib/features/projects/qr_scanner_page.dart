export 'qr_scanner_stub.dart'
    if (dart.library.js_interop) 'qr_scanner_web.dart'
    if (dart.library.io) 'qr_scanner_mobile.dart';
