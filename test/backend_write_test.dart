import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:connectflow_app/core/backend/backend_adapter.dart';

class _Captured {
  final String method;
  final String path;
  final String query;
  final Map<String, String> headers;
  final String body;
  _Captured(this.method, this.path, this.query, this.headers, this.body);
}

/// Serveur HTTP local qui enregistre chaque requete recue.
Future<({HttpServer server, List<_Captured> captured})> _startServer({int status = 200, Object? body}) async {
  final captured = <_Captured>[];
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  server.listen((req) async {
    final chunks = <List<int>>[];
    await for (final c in req) {
      chunks.add(c);
    }
    final headerMap = <String, String>{};
    req.headers.forEach((name, values) {
      headerMap[name] = values.join(',');
    });
    final bytes = chunks.expand((e) => e).toList();
    captured.add(_Captured(
      req.method,
      req.uri.path,
      req.uri.query,
      headerMap,
      utf8.decode(bytes, allowMalformed: true),
    ));
    final payload = body ?? <String, dynamic>{'id': 1};
    final text = jsonEncode(payload);
    req.response.statusCode = status;
    req.response.headers.contentType = ContentType.json;
    req.response.write(text);
    await req.response.close();
  });
  return (server: server, captured: captured);
}

void main() {
  group('insertRow', () {
    test('Supabase : POST /rest/v1/<table> avec en-tetes et representation', () async {
      final (:server, :captured) = await _startServer(
        status: 201,
        body: [
          {'id': 42, 'email': 'a@b.c'}
        ],
      );
      addTearDown(() => server.close(force: true));

      final res = await BackendAdapter.insertRow(
        'http://127.0.0.1:${server.port}',
        'test-key',
        'users',
        {'email': 'a@b.c'},
        type: 'supabase',
      );

      expect(res.ok, isTrue, reason: res.error);
      expect(res.statusCode, 201);
      expect(res.affected, 1);
      expect(res.row!['id'], 42);

      final req = captured.single;
      expect(req.method, 'POST');
      expect(req.path, '/rest/v1/users');
      expect(req.headers['apikey'], 'test-key');
      expect(req.headers['authorization'], 'Bearer test-key');
      expect(req.headers['prefer'], 'return=representation');
      expect(jsonDecode(req.body), {'email': 'a@b.c'});
    });

    test('Backend REST generique : POST /<table> sans prefixe REST', () async {
      final (:server, :captured) = await _startServer(status: 200, body: {'ok': true});
      addTearDown(() => server.close(force: true));

      final res = await BackendAdapter.insertRow(
        'http://127.0.0.1:${server.port}',
        'abc',
        'orders',
        {'total': 10},
        type: 'generic',
      );

      expect(res.ok, isTrue, reason: res.error);
      final req = captured.single;
      expect(req.method, 'POST');
      expect(req.path, '/orders');
      expect(req.headers['authorization'], 'Bearer abc');
      expect(req.headers.containsKey('apikey'), isFalse);
    });

    test('URL avec slash final ne produit pas de double slash', () async {
      final (:server, :captured) = await _startServer(status: 201, body: <String, dynamic>{});
      addTearDown(() => server.close(force: true));

      await BackendAdapter.insertRow(
        'http://127.0.0.1:${server.port}/',
        'k',
        'users',
        {'a': 1},
        type: 'supabase',
      );

      expect(captured.single.path, '/rest/v1/users');
    });
  });

  group('updateRow', () {
    test('Supabase : PATCH filtre par id=eq.<valeur>', () async {
      final (:server, :captured) = await _startServer(
        body: [
          {'id': 7, 'email': 'new@b.c'}
        ],
      );
      addTearDown(() => server.close(force: true));

      final res = await BackendAdapter.updateRow(
        'http://127.0.0.1:${server.port}',
        'k',
        'users',
        {'email': 'new@b.c'},
        idColumn: 'id',
        idValue: '7',
        type: 'supabase',
      );

      expect(res.ok, isTrue, reason: res.error);
      final req = captured.single;
      expect(req.method, 'PATCH');
      expect(req.path, '/rest/v1/users');
      expect(req.query, 'id=eq.7');
      expect(jsonDecode(req.body), {'email': 'new@b.c'});
      expect(res.row!['email'], 'new@b.c');
    });

    test('Backend generique : PATCH /<table>/<id>', () async {
      final (:server, :captured) = await _startServer(body: {'ok': true});
      addTearDown(() => server.close(force: true));

      final res = await BackendAdapter.updateRow(
        'http://127.0.0.1:${server.port}',
        'k',
        'orders',
        {'status': 'paid'},
        idColumn: 'id',
        idValue: '99',
        type: 'generic',
      );

      expect(res.ok, isTrue, reason: res.error);
      expect(captured.single.method, 'PATCH');
      expect(captured.single.path, '/orders/99');
    });
  });

  group('deleteRow', () {
    test('Supabase : DELETE filtre par id=eq.<valeur>', () async {
      final (:server, :captured) = await _startServer(
        body: [
          {'id': 3}
        ],
      );
      addTearDown(() => server.close(force: true));

      final res = await BackendAdapter.deleteRow(
        'http://127.0.0.1:${server.port}',
        'k',
        'users',
        idColumn: 'id',
        idValue: '3',
        type: 'supabase',
      );

      expect(res.ok, isTrue, reason: res.error);
      final req = captured.single;
      expect(req.method, 'DELETE');
      expect(req.path, '/rest/v1/users');
      expect(req.query, 'id=eq.3');
    });
  });

  group('Erreurs remontees au lieu de silencie', () {
    test('403 RLS devient un message lisible', () async {
      final (:server, :captured) = await _startServer(
        status: 403,
        body: {'message': 'new row violates row-level security policy'},
      );
      addTearDown(() => server.close(force: true));

      final res = await BackendAdapter.insertRow(
        'http://127.0.0.1:${server.port}',
        'k',
        'users',
        {'a': 1},
        type: 'supabase',
      );

      expect(res.ok, isFalse);
      expect(res.statusCode, 403);
      expect(res.offline, isFalse);
      expect(res.error, contains('403'));
      expect(res.error, contains('row-level security'));
      expect(captured, hasLength(1));
    });

    test('404 table inconnue devient un message lisible', () async {
      final (:server, :captured) = await _startServer(
        status: 404,
        body: {'message': 'relation "public.nope" does not exist'},
      );
      addTearDown(() => server.close(force: true));

      final res = await BackendAdapter.deleteRow(
        'http://127.0.0.1:${server.port}',
        'k',
        'nope',
        idColumn: 'id',
        idValue: '1',
        type: 'supabase',
      );

      expect(res.ok, isFalse);
      expect(res.statusCode, 404);
      expect(res.error, contains('introuvable'));
      expect(res.error, contains('does not exist'));
      expect(captured.single.method, 'DELETE');
    });

    test('serveur injoignable signale hors ligne', () async {
      final res = await BackendAdapter.insertRow(
        'http://127.0.0.1:1',
        'k',
        'users',
        {'a': 1},
        type: 'supabase',
      );

      expect(res.ok, isFalse);
      expect(res.offline, isTrue);
      expect(res.statusCode, 0);
    });
  });
}
