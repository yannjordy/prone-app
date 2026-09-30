import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:connectflow_app/core/backend/backend_adapter.dart';

/// Serveur qui rejoue une liste de reponses dans l'ordre (la derniere se
/// repete). Chaque reponse declare `status`, `body` et son code PostgREST.
class _ScriptedServer {
  final HttpServer server;
  final List<Map<String, Object?>> script;
  final List<String> seen = <String>[];
  int _i = 0;
  _ScriptedServer(this.server, this.script);

  Future<void> _handle(HttpRequest req) async {
    await req.drain<void>();
    final step = script[_i < script.length ? _i : script.length - 1];
    _i++;
    final payload = step['body'] ?? <String, dynamic>{'id': 1};
    req.response.statusCode = (step['status'] as num?)?.toInt() ?? 200;
    req.response.headers.contentType = ContentType.json;
    req.response.write(jsonEncode(payload));
    await req.response.close();
    seen.add('${req.method} ${req.uri.path}');
  }

  Future<void> close() => server.close(force: true);
}

Future<_ScriptedServer> _start(List<Map<String, Object?>> script) async {
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  final wrapper = _ScriptedServer(server, script);
  server.listen(wrapper._handle);
  return wrapper;
}

void main() {
  group('Codes PostgREST traduits en francais', () {
    test('PGRST205 -> table introuvable avec l indice /tables', () async {
      final s = await _start([
        {
          'status': 404,
          'body': {'code': 'PGRST205', 'message': "Could not find the table 'public.nope' in the schema cache"}
        },
      ]);
      addTearDown(s.close);

      final res = await BackendAdapter.fetchRows(
        'http://127.0.0.1:${s.server.port}',
        'k',
        'nope',
        type: 'supabase',
      );

      expect(res.ok, isFalse);
      expect(res.error, contains('Table introuvable (404)'));
      expect(res.error, contains('/tables'));
      expect(res.error, contains('nope'));
    });

    test('42703 -> colonne inexistante', () async {
      final s = await _start([
        {
          'status': 400,
          'body': {'code': '42703', 'message': 'column "ble" of relation "users" does not exist'}
        },
      ]);
      addTearDown(s.close);

      final res = await BackendAdapter.updateRow(
        'http://127.0.0.1:${s.server.port}',
        'k',
        'users',
        {'ble': 1},
        idColumn: 'id',
        idValue: '1',
        type: 'supabase',
      );

      expect(res.ok, isFalse);
      expect(res.statusCode, 400);
      expect(res.error, contains('Colonne inexistante (400)'));
      expect(res.error, contains('ble'));
    });

    test('22P02 -> valeur incompatible avec le type de la colonne', () async {
      final s = await _start([
        {
          'status': 400,
          'body': {'code': '22P02', 'detail': 'invalid input syntax for type integer: "abc"'}
        },
      ]);
      addTearDown(s.close);

      final res = await BackendAdapter.updateRow(
        'http://127.0.0.1:${s.server.port}',
        'k',
        'users',
        {'age': 'abc'},
        idColumn: 'id',
        idValue: '1',
        type: 'supabase',
      );

      expect(res.ok, isFalse);
      expect(res.error, contains('Valeur incompatible'));
      expect(res.error, contains('400'));
      expect(res.error, contains('abc'));
    });

    test('Code inconnu : libelle avec le statut et le detail', () async {
      final s = await _start([
        {
          'status': 422,
          'body': {'message': 'detail absent'}
        },
      ]);
      addTearDown(s.close);

      final res = await BackendAdapter.insertRow(
        'http://127.0.0.1:${s.server.port}',
        'k',
        'users',
        {'a': 1},
        type: 'supabase',
      );

      expect(res.error, contains('422'));
      expect(res.error, contains('detail absent'));
    });
  });

  group('Lecture resiliente', () {
    test('un 503 transitoire est retente puis reussit', () async {
      final s = await _start([
        {
          'status': 503,
          'body': {'message': 'Service Unavailable'}
        },
        {
          'status': 200,
          'body': [
            {'id': 1}
          ]
        },
      ]);
      addTearDown(s.close);

      final res = await BackendAdapter.fetchRows(
        'http://127.0.0.1:${s.server.port}',
        'k',
        'users',
        type: 'supabase',
      );

      expect(res.ok, isTrue, reason: res.error);
      expect(res.rows, hasLength(1));
      expect(s.seen, hasLength(2));
    });

    test('un 504 permanent est bien signale en francais', () async {
      final s = await _start([
        {
          'status': 504,
          'body': {'message': 'Gateway Timeout'}
        },
      ]);
      addTearDown(s.close);

      final res = await BackendAdapter.fetchRows(
        'http://127.0.0.1:${s.server.port}',
        'k',
        'users',
        type: 'supabase',
      );

      expect(res.ok, isFalse);
      expect(res.error, contains('Backend trop lent'));
      expect(res.error, contains('504'));
      expect(s.seen, hasLength(2), reason: 'la lecture retente une fois');
    });

    test('les ecritures ne sont jamais retentees', () async {
      final s = await _start([
        {
          'status': 503,
          'body': {'message': 'Service Unavailable'}
        },
      ]);
      addTearDown(s.close);

      final res = await BackendAdapter.insertRow(
        'http://127.0.0.1:${s.server.port}',
        'k',
        'users',
        {'a': 1},
        type: 'supabase',
      );

      expect(res.ok, isFalse);
      expect(s.seen, hasLength(1), reason: 'pas de double ecriture');
    });
  });
}
