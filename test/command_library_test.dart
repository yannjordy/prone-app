import 'package:flutter_test/flutter_test.dart';
import 'package:connectflow_app/core/commands/command_library.dart';

void main() {
  test('findCommand reconnait toutes les commandes proposees', () {
    final names = CommandLibrary.commands.map((c) => '/${c.name}').toList();
    for (final n in names) {
      expect(CommandLibrary.findCommand(n), isNotNull, reason: '$n doit etre reconnue');
    }
  });

  test('findCommand parse les parametres', () {
    final cmd = CommandLibrary.findCommand('/count users');
    expect(cmd, isNotNull);
    expect(cmd!.name, 'count');
    expect(cmd.currentParams, ['users']);
  });

  test('findCommand gere les espaces en trop', () {
    final cmd = CommandLibrary.findCommand('/ping ');
    expect(cmd, isNotNull);
    expect(cmd!.name, 'ping');
    expect(cmd.currentParams, isEmpty);
  });

  test('findCommand rejecte le texte sans slash', () {
    expect(CommandLibrary.findCommand('bonjour'), isNull);
    expect(CommandLibrary.findCommand(''), isNull);
    expect(CommandLibrary.findCommand('/'), isNull);
  });

  test('noms de commandes uniques', () {
    final names = CommandLibrary.commands.map((c) => c.name).toList();
    expect(names.toSet().length, names.length, reason: 'aucun doublon de commande');
  });

  test('chaque commande a une description et une categorie', () {
    for (final cmd in CommandLibrary.commands) {
      expect(cmd.description.isNotEmpty, isTrue, reason: '/${cmd.name} sans description');
      expect(cmd.category.isNotEmpty, isTrue, reason: '/${cmd.name} sans categorie');
      expect(cmd.icon.startsWith('assets/icons/'), isTrue, reason: '/${cmd.name} icone invalide');
    }
  });

  test('le catalogue ne produit aucune donnee', () {
    expect(CommandLibrary.commands.every((c) => !c.name.contains('mock')), isTrue);
    expect(CommandLibrary.help(), contains('backend connecte'));
  });

  test('les commandes attendues sont bien presentes', () {
    final names = CommandLibrary.commands.map((c) => c.name).toSet();
    for (final expected in [
      'help', 'status', 'ping', 'protect', 'alerts', 'version',
      'tables', 'inspect', 'table', 'count', 'schema', 'last', 'search',
      'endpoints', 'requests', 'errors',
      'workflows', 'run', 'history',
      'users', 'user', 'orders', 'products',
    ]) {
      expect(names.contains(expected), isTrue, reason: '/$expected manquant');
    }
  });

  test('les commandes inventees ont ete supprimees', () {
    final names = CommandLibrary.commands.map((c) => c.name).toSet();
    for (final removed in ['restart', 'query', 'uptime']) {
      expect(names.contains(removed), isFalse, reason: '/$removed doit avoir ete supprime');
    }
  });

  test('help liste chaque commande', () {
    final help = CommandLibrary.help();
    for (final cmd in CommandLibrary.commands) {
      expect(help, contains('/${cmd.name}'), reason: '/${cmd.name} absent du help');
    }
  });
}
