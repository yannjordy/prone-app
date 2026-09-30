import 'package:flutter_test/flutter_test.dart';
import 'package:connectflow_app/core/backend/environments.dart';

void main() {
  group('Environments.parse', () {
    test('transforme les connexions en environnements', () {
      final envs = Environments.parse([
        {'id': 'a', 'name': 'dev', 'url': 'https://dev.example.com/', 'api_key': 'k1'},
        {'id': 'b', 'name': 'prod', 'url': 'https://api.example.com', 'api_key': 'k2'},
      ]);
      expect(envs, hasLength(2));
      expect(envs.first.name, 'dev');
      expect(envs.first.apiKey, 'k1');
      expect(envs.first.isProduction, isFalse);
      expect(envs.last.isProduction, isTrue);
    });

    test('une connexion sans nom prend son URL', () {
      final envs = Environments.parse([
        {'id': 'x', 'name': '', 'url': 'https://a.b'},
      ]);
      expect(envs.single.name, 'https://a.b');
    });

    test('une ligne totalement vide est ignoree', () {
      expect(Environments.parse([
        {'id': 'y', 'name': '', 'url': ''}
      ]), isEmpty);
    });
  });

  group('Environments.sameUrl', () {
    test('ignore les slashs finaux', () {
      expect(Environments.sameUrl('https://a.com', 'https://a.com///'), isTrue);
      expect(Environments.sameUrl('https://a.com', 'https://b.com'), isFalse);
      expect(Environments.sameUrl('', ''), isFalse, reason: 'URL vide = aucun backend');
    });
  });

  group('Environments.find', () {
    final envs = Environments.parse([
      {'id': 'id-1', 'name': 'Dev', 'url': 'https://dev'},
      {'id': 'id-2', 'name': 'Production', 'url': 'https://prod'},
    ]);

    test('recherche par nom, insensible a la casse', () {
      expect(Environments.find(envs, 'dev')!.name, 'Dev');
      expect(Environments.find(envs, 'PRODUCTION')!.name, 'Production');
    });

    test('recherche par identifiant', () {
      expect(Environments.find(envs, 'id-2')!.name, 'Production');
    });

    test('prefixe accepte, inconnu refuse', () {
      expect(Environments.find(envs, 'prod')!.name, 'Production');
      expect(Environments.find(envs, 'staging'), isNull);
      expect(Environments.find(envs, '  '), isNull);
    });
  });

  group('Environments.active', () {
    test('trouve l environnement correspondant au backend actif', () {
      final envs = Environments.parse([
        {'id': '1', 'name': 'dev', 'url': 'https://dev.example.com'},
        {'id': '2', 'name': 'prod', 'url': 'https://api.example.com'},
      ]);
      expect(Environments.active(envs, 'https://api.example.com/')!.name, 'prod');
      expect(Environments.active(envs, 'https://other.com'), isNull);
    });
  });
}
