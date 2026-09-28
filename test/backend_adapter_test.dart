import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:connectflow_app/core/backend/backend_adapter.dart';

DioException _dioError(DioExceptionType type, {Object? error, Response<dynamic>? response}) {
  return DioException(
    requestOptions: RequestOptions(path: '/x'),
    type: type,
    error: error,
    response: response,
  );
}

void main() {
  group('BackendAdapter.isOfflineError', () {
    test('connectionError est hors ligne', () {
      expect(BackendAdapter.isOfflineError(_dioError(DioExceptionType.connectionError)), isTrue);
    });

    test('timeouts sont hors ligne', () {
      expect(BackendAdapter.isOfflineError(_dioError(DioExceptionType.connectionTimeout)), isTrue);
      expect(BackendAdapter.isOfflineError(_dioError(DioExceptionType.sendTimeout)), isTrue);
      expect(BackendAdapter.isOfflineError(_dioError(DioExceptionType.receiveTimeout)), isTrue);
    });

    test('socket exception dans unknown est hors ligne', () {
      expect(BackendAdapter.isOfflineError(_dioError(DioExceptionType.unknown, error: const SocketExceptionLike())), isTrue);
    });

    test('une reponse HTTP n\'est pas une erreur hors ligne', () {
      expect(BackendAdapter.isOfflineError(_dioError(DioExceptionType.badResponse, response: Response(requestOptions: RequestOptions(path: '/x'), statusCode: 404))), isFalse);
      expect(BackendAdapter.isOfflineError(_dioError(DioExceptionType.connectionError, response: Response(requestOptions: RequestOptions(path: '/x'), statusCode: 500))), isFalse);
    });

    test('badCertificate n\'est pas hors ligne', () {
      expect(BackendAdapter.isOfflineError(_dioError(DioExceptionType.badCertificate)), isFalse);
    });
  });

  group('BackendAdapter.detect', () {
    test('reconnaît supabase', () {
      expect(BackendAdapter.detect('https://xjckbqbqxcwzcrlmuvzf.supabase.co', null), BackendType.supabase);
    });

    test('force le type fourni', () {
      expect(BackendAdapter.detect('https://x.supabase.co', 'fastapi'), BackendType.fastapi);
      expect(BackendAdapter.detect('n\'importe quoi', 'inconnu'), BackendType.generic);
    });

    test('fallback generic', () {
      expect(BackendAdapter.detect('https://example.com/api', null), BackendType.generic);
    });
  });

  group('TableResult', () {
    test('ok quand pas d\'erreur', () {
      const r = TableResult(table: 'users', rows: [], offset: 0, limit: 25);
      expect(r.ok, isTrue);
      expect(r.error, isNull);
    });

    test('pas ok quand erreur', () {
      const r = TableResult(table: 'users', offset: 0, limit: 25, error: 'HTTP 404');
      expect(r.ok, isFalse);
      expect(r.offline, isFalse);
    });

    test('hasMore quand total depasse', () {
      final rows = List.generate(10, (i) => <String, dynamic>{'id': i});
      final r = TableResult(table: 'users', rows: rows, offset: 0, limit: 10, total: 35);
      expect(r.hasMore, isTrue);
      expect(r.pageCount, 4);
      expect(r.pageNumber, 1);
    });

    test('hasMore faux sur la derniere page', () {
      final rows = List.generate(5, (i) => <String, dynamic>{'id': i});
      final r = TableResult(table: 'users', rows: rows, offset: 30, limit: 10, total: 35);
      expect(r.hasMore, isFalse);
      expect(r.pageNumber, 4);
    });

    test('page vide = plus rien a afficher', () {
      const r = TableResult(table: 'users', rows: [], offset: 30, limit: 10, total: 35);
      expect(r.hasMore, isFalse);
    });

    test('sans total on suppose plus tant que la page est pleine', () {
      const full = TableResult(table: 't', offset: 0, limit: 10, rows: []);
      expect(full.hasMore, isFalse);
    });
  });

  group('SchemaResult', () {
    test('ok seulement avec des colonnes', () {
      const empty = SchemaResult(table: 'users');
      expect(empty.ok, isFalse);

      const withCols = SchemaResult(table: 'users', columns: [ColumnInfo(name: 'id', type: 'bigint')]);
      expect(withCols.ok, isTrue);
    });
  });

  group('WriteResult', () {
    test('ok sans erreur', () {
      const r = WriteResult(method: 'POST', url: '/users', statusCode: 201, rows: [{'id': 1}]);
      expect(r.ok, isTrue);
      expect(r.affected, 1);
      expect(r.row, {'id': 1});
    });

    test('pas ok quand erreur presente', () {
      const r = WriteResult(method: 'DELETE', url: '/users/1', statusCode: 403, error: 'refuse');
      expect(r.ok, isFalse);
      expect(r.affected, isNull);
      expect(r.row, isNull);
    });

    test('offline est distinct d\'une erreur HTTP', () {
      const offline = WriteResult(method: 'POST', url: '/users', statusCode: 0, error: 'timeout', offline: true);
      expect(offline.ok, isFalse);
      expect(offline.offline, isTrue);

      const forbidden = WriteResult(method: 'POST', url: '/users', statusCode: 403, error: 'rls');
      expect(forbidden.offline, isFalse);
    });
  });

  group('Garde-fou d\'ecriture', () {
    test('insertRow refuse une map vide sans toucher au reseau', () async {
      final r = await BackendAdapter.insertRow('https://example.com', 'k', 'users', const {});
      expect(r.ok, isFalse);
      expect(r.statusCode, 0);
      expect(r.error, contains('Aucune valeur'));
    });

    test('updateRow refuse une map vide sans toucher au reseau', () async {
      final r = await BackendAdapter.updateRow('https://example.com', 'k', 'users', const {},
          idColumn: 'id', idValue: '1');
      expect(r.ok, isFalse);
      expect(r.error, contains('Aucune valeur'));
    });
  });
}

class SocketExceptionLike implements Exception {
  const SocketExceptionLike();
  @override
  String toString() => 'SocketException: Failed host lookup';
}
