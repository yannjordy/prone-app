import 'dart:async';

import 'package:app_links/app_links.dart';

/// Ecoute les liens `prone://join/<payload>` ouverts depuis l'exterieur
/// (messagerie, email, QR externe).
///
/// Sans cela, taper le lien ne fait rien : le schema `prone` n'est pas
/// declare dans le manifest et personne ne lit l'intent. La reunion par
/// collage dans « Rejoindre un projet » reste possible en secours.
class DeepLinks {
  DeepLinks._();
  static final DeepLinks instance = DeepLinks._();

  final _controller = StreamController<String>.broadcast();
  StreamSubscription<Uri>? _sub;
  String? _initial;
  bool _started = false;

  /// Liens recus pendant la vie de l'application.
  Stream<String> get joinLinks => _controller.stream;

  /// Lien ayant lance l'application (a consommer par le premier ecran apte).
  String? get initialLink => _initial;

  Future<void> start() async {
    if (_started) return;
    _started = true;
    try {
      final links = AppLinks();
      final uri = await links.getInitialLink();
      _accept(uri);
      _sub = links.uriLinkStream.listen(_accept, onError: (_) {});
    } catch (_) {
      // Plugin indisponible : on ne bloque jamais le demarrage de l'app.
    }
  }

  void _accept(Uri? uri) {
    if (uri == null) return;
    final raw = uri.toString();
    if (!raw.startsWith('prone://')) return;
    _initial ??= raw;
    if (!_controller.isClosed) _controller.add(raw);
  }

  void markInitialHandled() => _initial = null;

  Future<void> stop() async {
    await _sub?.cancel();
    _sub = null;
  }
}
