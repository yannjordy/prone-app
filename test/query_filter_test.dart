import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:connectflow_app/core/backend/backend_adapter.dart';

class _Capture {
  final String path;
  final String method;
  final Map<String, String> query;
  final String body;
  _Capture(this.path, this.method, this.query, this.body);
}

class _Server {
  final HttpServer server;
  final List<_Capture> seen = <_Capture>[];
  final int status;
  final Object? body;
  _Server(this.server, {this.status = 200, this.body});

  Future<void> _handle(HttpRequest req) async {
    final chunks = await req.fold<List<int>>(<int>[], (a, b) => a..addAll(b));
    seen.add(_Capture(
      req.uri.path,
      req.method,
      req.uri.queryParameters,
      utf8.decode(chunks, allowMalformed: true),
    ));
    req.response.statusCode = status;
    req.response.headers.contentType = ContentType.json;
    req.response.write(jsonEncode(body ?? <String, dynamic>{'ok': true}));
    await req.response.close();
  }

  Future<void> close() => server.close(force: true);
}

Future<_Server> _start({int status = 200, Object? body}) async {
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  final wrapper = _Server(server, status: status, body: body);
  server.listen(wrapper._handle);
  return wrapper;
}

void main() {
  group('QueryFilter.parse', () {
    test('lit les six operateurs sans rien inventer', () {
      final eq = QueryFilter.parse('status=paye')!;
      expect(eq.field, 'status');
      expect(eq.op, FilterOp.eq);
      expect(eq.value, 'paye');

      expect(QueryFilter.parse('age!=18')!.op, FilterOp.neq);
      expect(QueryFilter.parse('age>18')!.op, FilterOp.gt);
      expect(QueryFilter.parse('age>=18')!.op, FilterOp.gte);
      expect(QueryFilter.parse('age<18')!.op, FilterOp.lt);
      expect(QueryFilter.parse('age<=18')!.op, FilterOp.lte);
      expect(QueryFilter.parse('nom~jean')!.op, FilterOp.contains);
    });

    test('>= est prioritaire sur > et =', () {
      final f = QueryFilter.parse('age>=18')!;
      expect(f.field, 'age');
      expect(f.op, FilterOp.gte);
      expect(f.value, '18');
    });

    test('null et !=null deviennent des filtres is / not is', () {
      expect(QueryFilter.parse('email=null')!.op, FilterOp.isNull);
      expect(QueryFilter.parse('email!=null')!.op, FilterOp.notNull);
    });

    test('une expression mal formee retourne null', () {
      expect(QueryFilter.parse(''), isNull);
      expect(QueryFilter.parse('=valeur'), isNull);
      expect(QueryFilter.parse('champ='), isNull);
      expect(QueryFilter.parse('pasdoperateur'), isNull);
    });

    test('une valeur contenant = est conservee', () {
      final f = QueryFilter.parse('payload={"a":1}')!;
      expect(f.field, 'payload');
      expect(f.value, '{"a":1}');
    });
  });

  group('QueryFilter.toQuery', () {
    test('forme PostgREST attendue', () {
      String q(QueryFilter f) => f.toQuery(supabase: true)!;
      expect(q(QueryFilter.parse('age>=18')!), 'age=gte.18');
      expect(q(QueryFilter.parse('status=paye')!), 'status=eq.paye');
      expect(q(QueryFilter.parse('age!=18')!), 'age=neq.18');
      expect(q(QueryFilter.parse('email=null')!), 'email=is.null');
      expect(q(QueryFilter.parse('email!=null')!), 'email=not.is.null');
      expect(q(QueryFilter.parse('nom~jean')!), 'nom=ilike.*jean*');
    });

    test('backend generique : seulement eq et neq sont envoyes', () {
      expect(QueryFilter.parse('a=1')!.toQuery(supabase: false), 'a=1');
      expect(QueryFilter.parse('a!=1')!.toQuery(supabase: false), 'a!=1');
      expect(QueryFilter.parse('a>1')!.toQuery(supabase: false), isNull);
    });
  });

  group('orderParam', () {
    test('accepte les noms de colonnes propres', () {
      expect(BackendAdapter.orderParam('created_at'), 'created_at.asc');
      expect(BackendAdapter.orderParam('-created_at'), 'created_at.desc');
      expect(BackendAdapter.orderParam('asc:name'), 'name.asc');
      expect(BackendAdapter.orderParam('desc:name'), 'name.desc');
    });

    test('refuse tout ce qui n est pas un identifiant', () {
      expect(BackendAdapter.orderParam('name; drop table x'), isNull);
      expect(BackendAdapter.orderParam(''), isNull);
      expect(BackendAdapter.orderParam('a b'), isNull);
    });
  });

  group('fetchRows construit la requête réelle', () {
    test('filtres et ordre partent dans la query string', () async {
      final s = await _start(body: <Map<String, dynamic>>[
        {'id': 1}
      ]);
      addTearDown(s.close);

      final res = await BackendAdapter.fetchRows(
        'http://127.0.0.1:${s.server.port}',
        'k',
        'users',
        type: 'supabase',
        filters: [
          QueryFilter.parse('age>=18')!,
          QueryFilter.parse('nom~jean')!,
          QueryFilter.parse('email=null')!,
        ],
        orderBy: '-created_at',
        limit: 10,
      );

      expect(res.ok, isTrue, reason: res.error);
      expect(s.seen, hasLength(1));
      final q = s.seen.first.query;
      expect(q['age'], 'gte.18');
      expect(q['nom'], 'ilike.*jean*');
      expect(q['email'], 'is.null');
      expect(q['order'], 'created_at.desc');
      expect(q['limit'], '10');
      expect(s.seen.first.path, contains('/rest/v1/users'));
    });

    test('une colonne inexistante ne casse pas la lecture', () async {
      final s = await _start(status: 400, body: {
        'code': '42703',
        'message': 'column "ble" of relation "users" does not exist',
      });
      addTearDown(s.close);

      final res = await BackendAdapter.fetchRows(
        'http://127.0.0.1:${s.server.port}',
        'k',
        'users',
        type: 'supabase',
        filters: [QueryFilter.parse('ble=1')!],
      );

      expect(res.ok, isFalse);
      expect(res.error, contains('Colonne inexistante (400)'));
    });
  });

  group('callRpc', () {
    test('POST /rest/v1/rpc/<fn> avec les paramètres JSON', () async {
      final s = await _start(status: 200, body: [
        {'id': 7}
      ]);
      addTearDown(s.close);

      final res = await BackendAdapter.callRpc(
        'http://127.0.0.1:${s.server.port}',
        'k',
        'get_orders',
        params: {'status': 'paye', 'limit': 10},
        type: 'supabase',
      );

      expect(res.ok, isTrue, reason: res.error);
      expect(res.statusCode, 200);
      expect(s.seen, hasLength(1));
      expect(s.seen.first.path, '/rest/v1/rpc/get_orders');
      expect(s.seen.first.method, 'POST');
      final body = jsonDecode(s.seen.first.body) as Map<String, dynamic>;
      expect(body['status'], 'paye');
      expect(body['limit'], 10);
    });

    test('un nom de fonction invalide ne part jamais en réseau', () async {
      final s = await _start();
      addTearDown(s.close);

      final res = await BackendAdapter.callRpc(
        'http://127.0.0.1:${s.server.port}',
        'k',
        'foo; drop table users',
        type: 'supabase',
      );

      expect(res.ok, isFalse);
      expect(res.error, contains('invalide'));
      expect(s.seen, isEmpty);
    });

    test('fonction absente : message clair en français', () async {
      final s = await _start(status: 404, body: {'message': 'function public.nope() does not exist'});
      addTearDown(s.close);

      final res = await BackendAdapter.callRpc(
        'http://127.0.0.1:${s.server.port}',
        'k',
        'nope',
        type: 'supabase',
      );

      expect(res.ok, isFalse);
      expect(res.statusCode, 404);
      expect(res.error, contains('introuvable (404)'));
      expect(res.error, contains('nope'));
    });

    test('erreur métier du backend : libellé traduit', () async {
      final s = await _start(status: 400, body: {'message': 'argument manquant'});
      addTearDown(s.close);

      final res = await BackendAdapter.callRpc(
        'http://127.0.0.1:${s.server.port}',
        'k',
        'f',
        type: 'supabase',
      );

      expect(res.ok, isFalse);
      expect(res.error, contains('400'));
      expect(res.error, contains('argument manquant'));
    });
  });
}
