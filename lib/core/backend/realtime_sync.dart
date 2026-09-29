import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';

/// Temps reel via **Supabase Realtime** (Phoenix channels sur WebSocket).
///
/// Des que le backend connecte est un Supabase, on ouvre une socket vers
/// `wss://<ref>.supabase.co/realtime/v1/websocket` et on s'abonne aux
/// changements Postgres des trois tables de synchronisation Prone. Chaque
/// evennement declenche un cycle [ProjectSync.syncNow] immediat, sans attendre
/// le prochain tour de polling.
///
/// La socket est un **accelerateur**, jamais une dependance : toute erreur
/// (hors ligne, backend non Supabase, protocole refuse) est avalee et le
/// polling de secours continue de fonctionner.
class SupabaseRealtime {
  SupabaseRealtime._();
  static final SupabaseRealtime instance = SupabaseRealtime._();

  static const List<String> _tables = [
    '_prone_messages',
    '_prone_members',
    '_prone_projects',
  ];

  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _sub;
  Timer? _heartbeat;
  Timer? _debounce;
  String? _attachedKey;
  String _joinRef = '1';
  int _ref = 0;
  bool _joined = false;
  void Function()? _onChange;

  bool get isConnected => _joined;
  bool get isAttached => _attachedKey != null;

  /// Construit l'URL WebSocket d'une instance Supabase, ou null si l'URL
  /// du backend n'est pas une URL Supabase exploitable.
  static String? wsUrl(String url, String apiKey) {
    if (apiKey.trim().isEmpty) return null;
    final raw = url.trim().replaceAll(RegExp(r'/+$'), '');
    if (raw.isEmpty) return null;
    Uri? base;
    try {
      base = Uri.parse(raw);
    } catch (_) {
      return null;
    }
    final scheme = base.scheme == 'http' ? 'ws' : 'wss';
    final host = base.host.toLowerCase();
    if (!host.endsWith('.supabase.co')) return null;
    return '$scheme://${base.host}${base.hasPort ? ':${base.port}' : ''}'
        '/realtime/v1/websocket?apikey=${Uri.encodeQueryComponent(apiKey)}&vsn=1.0.0';
  }

  void attach({
    required String url,
    required String apiKey,
    required String projectId,
    required void Function() onChange,
  }) {
    final key = '$url|$projectId';
    if (_attachedKey == key) {
      _onChange = onChange;
      return;
    }
    detach();
    final ws = wsUrl(url, apiKey);
    if (ws == null) return; // backend non Supabase : on reste en polling
    _attachedKey = key;
    _onChange = onChange;
    _connect(ws);
  }

  void detach() {
    _heartbeat?.cancel();
    _heartbeat = null;
    _debounce?.cancel();
    _debounce = null;
    _joined = false;
    try {
      _sub?.cancel();
    } catch (_) {}
    _sub = null;
    try {
      _channel?.sink.close();
    } catch (_) {}
    _channel = null;
    _attachedKey = null;
    _onChange = null;
  }

  void _connect(String ws) {
    try {
      final channel = WebSocketChannel.connect(Uri.parse(ws));
      _channel = channel;
      _joined = false;
      _sub = channel.stream.listen(
        _onMessage,
        onError: (_) => _joined = false,
        onDone: () => _joined = false,
        cancelOnError: false,
      );
      _join();
      _heartbeat = Timer.periodic(const Duration(seconds: 25), (_) => _send('phoenix', 'heartbeat', {}));
    } catch (_) {
      _joined = false;
    }
  }

  void _join() {
    _send(
      'realtime:*',
      'phx_join',
      {
        'config': {
          'postgres_changes': [
            for (final t in _tables) {'event': '*', 'schema': 'public', 'table': t},
          ],
        },
      },
      join: true,
    );
  }

  void _send(String topic, String event, Map<String, dynamic> payload, {bool join = false}) {
    final channel = _channel;
    if (channel == null) return;
    _ref += 1;
    final ref = '$_ref';
    if (join) _joinRef = ref;
    try {
      channel.sink.add(jsonEncode([_joinRef, ref, topic, event, payload]));
    } catch (_) {}
  }

  void _onMessage(dynamic raw) {
    if (raw is! String) return;
    List<dynamic>? msg;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List && decoded.length >= 4) msg = decoded;
    } catch (_) {
      return;
    }
    if (msg == null) return;
    final event = msg[3]?.toString() ?? '';
    final payload = msg[4];

    if (event == 'phx_reply') {
      final status = payload is Map ? '${payload['status']}' : '';
      if (status == 'ok') {
        _joined = true;
        _notify(); // premier cycle des que la souscription est ouverte
      } else {
        _joined = false;
      }
      return;
    }
    if (event == 'postgres_changes') {
      _notify();
    }
  }

  /// Debounce : un import qui pousse 50 lignes ne doit pas lancer 50 syncs.
  void _notify() {
    if (_debounce?.isActive ?? false) return;
    _debounce = Timer(const Duration(milliseconds: 350), () {
      final cb = _onChange;
      if (cb != null) cb();
    });
  }

  void resetForTest() => detach();
}
